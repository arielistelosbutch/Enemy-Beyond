extends RefCounted
## (0.62) Voice processing shared by the lobby, the globe and the mission.
##
## Sending (LobbyVoice is the one reader of the microphone):
##  - the Mic bus filters natively before the capture: high-pass 90 Hz (hum, rumble, breath on
##    the mic, DC) and low-pass 7 kHz (anti-alias: the old box average let 8-16 kHz fold back as hiss)
##  - resampling to 16 kHz by interpolation
##  - every 10 ms: the room noise floor is tracked; below it the signal is pulled down
##    (expander, max -24 dB) so fans, keyboards and hiss do not go out between words
##  - automatic level only from speech (silence is no longer pumped up)
##  - voice activation from the noise floor (adapts to a loud or quiet room) + the threshold
##    from the settings; while a teammate is heard the threshold rises (speakers -> echo)
##  - 0.2 s of pre-roll (the first syllable is no longer cut off) and 0.3 s of tail after Tab
## Receiving (Rx): a small jitter cushion at the start of a sentence and after a gap, lost
## packets filled with a fading copy of the previous one, latency capped at ~0.35 s.

const RATE := 16000
const FRAME := 160                 # 10 ms at RATE
const PRE_ROLL := 0.2
const PTT_TAIL := 0.3
const VAD_HOLD := 0.6
const TARGET := 0.12               # speech RMS after the automatic level

## Mic bus: high-pass, low-pass, capture (all native). Returns the capture effect.
static func mic_bus() -> AudioEffectCapture:
	var i := AudioServer.get_bus_index("Mic")
	if i < 0:
		AudioServer.add_bus()
		i = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, "Mic")
		AudioServer.set_bus_volume_db(i, -80.0)   # silent, but the capture still hears it (some systems give a muted bus nothing)
	var has_hp := false
	var cap: AudioEffectCapture = null
	for k in AudioServer.get_bus_effect_count(i):
		var fx := AudioServer.get_bus_effect(i, k)
		if fx is AudioEffectHighPassFilter:
			has_hp = true
		if fx is AudioEffectCapture:
			cap = fx
	if not has_hp:
		var hp := AudioEffectHighPassFilter.new()
		hp.cutoff_hz = 90.0
		hp.db = AudioEffectFilter.FILTER_12DB
		AudioServer.add_bus_effect(i, hp, 0)
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = 7000.0
		lp.db = AudioEffectFilter.FILTER_24DB
		AudioServer.add_bus_effect(i, lp, 1)
	if cap == null:
		cap = AudioEffectCapture.new()
		cap.buffer_length = 0.6      # a slow frame (map loading) must not lose speech
		AudioServer.add_bus_effect(i, cap)
	return cap

# ---- sending ---------------------------------------------------------------------------------
var floor_rms := 0.004            # room noise
var agc := 1.0
var voiced := false               # speech somewhere in the last processed block
var voiced_ms := -100000          # when speech was last heard (settings screen)
var level := 0.0                  # RMS after processing (meter)
var _gain := 1.0                  # expander
var _rs_pos := 0.0
var _rs_prev := 0.0
var _pend := PackedFloat32Array()

## Raw stereo frames at in_rate -> processed mono at RATE (only whole 10 ms frames; the rest waits).
func process(buf: PackedVector2Array, in_rate: float, gain: float, clean: bool, gate: float) -> PackedFloat32Array:
	var step := in_rate / float(RATE)
	# resample by linear interpolation (the bus already low-passed it)
	var pos := _rs_pos
	var prev := _rs_prev
	var n := buf.size()
	var i := 0
	while i < n:
		var cur := (buf[i].x + buf[i].y) * 0.5 * gain
		while pos <= 1.0:
			_pend.append(prev + (cur - prev) * pos)
			pos += step
		pos -= 1.0
		prev = cur
		i += 1
	_rs_pos = pos
	_rs_prev = prev
	return _frames(clean, gate)

## Already mono at RATE (autotest).
func process_mono(smp: PackedFloat32Array, clean: bool, gate: float) -> PackedFloat32Array:
	_pend.append_array(smp)
	return _frames(clean, gate)

func _frames(clean: bool, gate: float) -> PackedFloat32Array:
	var nf := _pend.size() / FRAME
	var out := PackedFloat32Array()
	out.resize(nf * FRAME)
	voiced = false
	var e_out := 0.0
	for f in nf:
		var o := f * FRAME
		var e := 0.0
		for k in FRAME:
			var v := _pend[o + k]
			e += v * v
		var rms := sqrt(e / FRAME)
		# noise floor: follows quiet quickly, creeps up slowly (+1.7 dB/s) so speech does not lift it
		if rms < floor_rms:
			floor_rms = lerpf(floor_rms, rms, 0.25)
		else:
			floor_rms *= 1.002
		floor_rms = clampf(floor_rms, 0.0004, 0.05)
		var speech := rms > floor_rms * 3.0 and rms > 0.003
		if speech:
			var want := clampf(TARGET / maxf(rms, 0.0001), 0.7, 6.0)
			agc = lerpf(agc, want, 0.3 if want < agc else 0.03)    # fast down (a shout), slow up (a whisper)
		if speech and rms * agc > gate * Rx.duck():
			voiced = true
			voiced_ms = Time.get_ticks_msec()
		# expander: below 3x the noise floor the signal goes down quadratically, -24 dB at most
		var g := 1.0
		if clean:
			var r := rms / (floor_rms * 3.0)
			g = 1.0 if r >= 1.0 else maxf(r * r, 0.063)
		var g0 := _gain
		_gain = lerpf(_gain, g, 0.7 if g > _gain else 0.12)     # opens in ~10 ms, closes in ~80 ms
		for k in FRAME:
			var x := _pend[o + k] * agc * lerpf(g0, _gain, float(k) / FRAME)
			x = x / (1.0 + absf(x) * 0.6)                       # soft limiter
			out[o + k] = x
			e_out += x * x
	if nf > 0:
		level = sqrt(e_out / (nf * FRAME))
		_pend = _pend.slice(nf * FRAME)
	return out

# ---- what goes out: push-to-talk / voice activation, pre-roll and tail -----------------------------
var _pre := PackedFloat32Array()
var _tx := false
var _tail := 0.0
var _hold := 0.0
var talking := false

## fresh = processed audio of this frame. Returns what to send now (empty = nothing).
func transmit(fresh: PackedFloat32Array, ptt: bool, open: bool, delta: float) -> PackedFloat32Array:
	var active := ptt
	if open:
		if voiced:
			_hold = VAD_HOLD
		_hold -= delta
		active = active or _hold > 0.0
	if ptt:
		_tail = PTT_TAIL
	elif not active and _tail > 0.0:
		_tail -= delta
		active = true
	var out := PackedFloat32Array()
	if active:
		if not _tx:
			out = _pre.duplicate()          # the start of the first syllable
		out.append_array(fresh)
		_pre.clear()
	else:
		_pre.append_array(fresh)
		var keep := int(RATE * PRE_ROLL)
		if _pre.size() > keep:
			_pre = _pre.slice(_pre.size() - keep)
	_tx = active
	talking = active
	return out

func reset() -> void:
	_tx = false
	_tail = 0.0
	_hold = 0.0
	talking = false

# ---- packets -------------------------------------------------------------------------------------
var _seq := 0

## One packet: a sequence byte + mu-law.
func packet(smp: PackedFloat32Array) -> PackedByteArray:
	var b := PackedByteArray([_seq & 255])
	_seq += 1
	b.append_array(encode(smp))
	return b

static func encode(smp: PackedFloat32Array) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(smp.size())
	var k := 127.0 / log(256.0)
	for i in smp.size():
		var x := clampf(smp[i] * 1.2, -1.0, 1.0)
		var b := mini(127, int(log(1.0 + 255.0 * absf(x)) * k + 0.5))
		if x < 0:
			b |= 128
		out[i] = b
	return out

static func decode(bytes: PackedByteArray) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(bytes.size())
	for i in bytes.size():
		var b := bytes[i]
		var x := (pow(256.0, float(b & 127) / 127.0) - 1.0) / 255.0
		out[i] = -x if b & 128 else x
	return out

# ---- receiving -------------------------------------------------------------------------------------
## One incoming voice into one AudioStreamGenerator playback.
class Rx:
	extends RefCounted
	static var _heard_ms := -100000      # anybody's voice played lately (raises the voice activation threshold)
	var pb                               # AudioStreamGeneratorPlayback (or a stand-in in the autotest)
	var cap := 0
	var last_seq := -1
	var last_ms := -100000
	var prev := PackedFloat32Array()
	var lost := 0
	var dropped := 0
	var rescued := 0

	func _init(playback, frames: int) -> void:
		pb = playback
		cap = frames

	## 2.5 while somebody is heard (their voice from my speakers must not open my microphone).
	static func duck() -> float:
		return 2.5 if Time.get_ticks_msec() - _heard_ms < 300 else 1.0

	func fill() -> int:
		return cap - int(pb.get_frames_available())

	## Push one packet's samples (seq < 0 = no sequence number).
	func push(seq: int, smp: PackedFloat32Array, now_ms: int = -1) -> void:
		if pb == null:
			return
		var now := Time.get_ticks_msec() if now_ms < 0 else now_ms
		_heard_ms = Time.get_ticks_msec()
		var start := now - last_ms > 250
		var have := fill()
		if start:
			_silence(int(RATE * 0.08))            # cushion for late packets
		elif seq >= 0 and last_seq >= 0:
			var gap := (seq - last_seq) & 255
			if gap == 0 or gap > 128:
				return                            # a duplicate or one that came after its successor
			if gap > 1:
				lost += gap - 1
				# fill up to two lost packets with a fading copy of the last one, more as silence
				for k in mini(gap - 1, 3):
					var f := PackedFloat32Array()
					f.resize(prev.size())
					var a0 := 0.6 / (k + 1)
					var a1 := 0.6 / (k + 2) if k < 1 else 0.0
					for j in prev.size():
						f[j] = prev[j] * lerpf(a0, a1, float(j) / prev.size())
					if k >= 2:
						f.fill(0.0)
					_put(f)
					rescued += 1
		if not start and have <= 0:
			_silence(int(RATE * 0.04))            # ran dry mid-sentence: a short cushion again
		if fill() > int(RATE * 0.35):
			dropped += 1                          # too far behind: skip this one, catch up
			last_seq = seq
			last_ms = now
			return
		var s := smp
		if start:
			s = smp.duplicate()
			for j in mini(80, s.size()):
				s[j] *= float(j) / 80.0           # fade in (no click)
		_put(s)
		prev = smp
		last_seq = seq
		last_ms = now

	func _silence(n: int) -> void:
		var f := PackedFloat32Array()
		f.resize(n)
		_put(f)

	func _put(smp: PackedFloat32Array) -> void:
		var fr := PackedVector2Array()
		fr.resize(smp.size())
		for i in smp.size():
			fr[i] = Vector2(smp[i], smp[i])
		if pb.can_push_buffer(fr.size()):
			pb.push_buffer(fr)
