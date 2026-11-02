extends Node
## Voice in the mission.
##  - Proximity chat: your microphone comes out of your mercenary's head, quieter
##    with distance (3D). Talking is noise: aliens hear it, the blind Ohař comes.
##  - Radio: a handheld in a hand (or the helmet set after research) sends your
##    voice to everybody who carries a radio, filtered, with static. Aliens near
##    the speaker or the listener garble it.
##  - Mimicry: the host keeps the last few things each player said (RAM only,
##    forgotten when the mission ends, only from players who allow it). Now and
##    then an alien hidden in the dark plays one back - sometimes faithfully, as
##    a lure ("pojď sem..."), sometimes slowed and wrong. A dead mercenary's
##    voice may come over the radio.
## Audio goes over the network as 11 kHz mono mu-law (about 11 kB/s per talker).

const RATE := 11025
const CHUNK := 0.06              # seconds of audio per packet
const MAX_SNIPPETS := 6

var mission: Node
var capture: AudioEffectCapture
var mic: AudioStreamPlayer
var talking := false
var on_radio := false
var _acc := PackedFloat32Array()
var _rs_pos := 0.0
var _rs_sum := 0.0
var _rs_n := 0
var _hold := 0.0
var _noise_t := 0.0
var _rms := 0.0
var _chan := {}                  # peer -> {near, radio, pb_near, pb_radio, last}
var _test_feed := PackedFloat32Array()   # autotest: fake microphone input at RATE

# ---- host: mimicry -----------------------------------------------------------------------
var snippets := {}               # peer -> Array[PackedByteArray]
var _cur := {}                   # peer -> PackedByteArray (utterance being collected)
var _quiet := {}                 # peer -> seconds of silence in the current utterance
var mimic_t := 80.0
var _dead_said := {}

func _ready() -> void:
	name = "Voice"
	mission = get_parent()
	_buses()
	mimic_t = randf_range(70.0, 110.0)
	if Game.voice_mode != "off" and DisplayServer.get_name() != "headless" and Game.autotest() == "":
		mic = AudioStreamPlayer.new()
		mic.stream = AudioStreamMicrophone.new()
		mic.bus = "Mic"
		add_child(mic)
		mic.play()

func _exit_tree() -> void:
	# nothing anybody said survives the mission
	snippets.clear()
	_cur.clear()

## Mic (captured, muted), Radio (narrow and dirty), Eerie (slowed, cavernous), Lure (close, dry).
func _buses() -> void:
	if AudioServer.get_bus_index("Mic") < 0:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, "Mic")
		AudioServer.set_bus_mute(i, true)
		AudioServer.add_bus_effect(i, AudioEffectCapture.new())
	if AudioServer.get_bus_index("Radio") < 0:
		AudioServer.add_bus()
		var r := AudioServer.bus_count - 1
		AudioServer.set_bus_name(r, "Radio")
		var bp := AudioEffectBandPassFilter.new()
		bp.cutoff_hz = 1700.0
		bp.resonance = 0.7
		AudioServer.add_bus_effect(r, bp)
		var ds := AudioEffectDistortion.new()
		ds.mode = AudioEffectDistortion.MODE_OVERDRIVE
		ds.drive = 0.35
		AudioServer.add_bus_effect(r, ds)
	if AudioServer.get_bus_index("Eerie") < 0:
		AudioServer.add_bus()
		var e := AudioServer.bus_count - 1
		AudioServer.set_bus_name(e, "Eerie")
		var ps := AudioEffectPitchShift.new()
		ps.pitch_scale = 0.82
		AudioServer.add_bus_effect(e, ps)
		var rv := AudioEffectReverb.new()
		rv.room_size = 0.85
		rv.wet = 0.45
		AudioServer.add_bus_effect(e, rv)
	if AudioServer.get_bus_index("Lure") < 0:
		AudioServer.add_bus()
		var l := AudioServer.bus_count - 1
		AudioServer.set_bus_name(l, "Lure")
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = 3200.0
		AudioServer.add_bus_effect(l, lp)
	capture = AudioServer.get_bus_effect(AudioServer.get_bus_index("Mic"), 0) as AudioEffectCapture

# ---- capture and send --------------------------------------------------------------------------
func _process(delta: float) -> void:
	var me: Node = mission.local_player()
	_capture(delta, me)
	if multiplayer.is_server() and not mission.finished:
		_mimic_tick(delta)
		_dead_radio_tick()
	for peer in _chan.keys():
		_chan[peer]["last"] = float(_chan[peer]["last"]) + delta

## Autotest: pretend somebody spoke into the microphone (mono floats at RATE).
func test_speak(samples: PackedFloat32Array) -> void:
	_test_feed.append_array(samples)

func _capture(delta: float, me: Node) -> void:
	var fresh := PackedFloat32Array()
	if capture and mic and mic.playing:
		var n := capture.get_frames_available()
		if n > 0:
			var buf := capture.get_buffer(n)
			var ratio := AudioServer.get_mix_rate() / float(RATE)
			for f in buf:
				_rs_sum += (f.x + f.y) * 0.5 * Game.mic_gain
				_rs_n += 1
				_rs_pos += 1.0
				if _rs_pos >= ratio:
					_rs_pos -= ratio
					fresh.append(_rs_sum / _rs_n)
					_rs_sum = 0.0
					_rs_n = 0
	if not _test_feed.is_empty():
		var k := mini(_test_feed.size(), int(RATE * delta) + 1)
		fresh.append_array(_test_feed.slice(0, k))
		_test_feed = _test_feed.slice(k)
	# level
	var e := 0.0
	for v in fresh:
		e += v * v
	if fresh.size() > 0:
		_rms = lerp(_rms, sqrt(e / fresh.size()), 0.5)
		Game.mic_level = _rms
	var alive: bool = me != null and not me.dead
	var want := false
	if alive and Game.voice_mode != "off":
		var ptt: bool = Input.is_action_pressed("talk") or me.radio_button
		if Game.voice_mode == "ptt":
			want = ptt
		else:
			if _rms > Game.mic_gate or ptt:
				_hold = 0.45
			_hold -= delta
			want = _hold > 0.0
	if not _test_feed.is_empty() or (fresh.size() > 0 and Game.autotest() == "voice"):
		want = alive
	talking = want
	on_radio = want and alive and me.radio_tx() and (me.radio_button or Input.is_action_pressed("talk") or Game.voice_mode == "open" or Game.autotest() == "voice")
	if not want:
		_acc.clear()
		return
	_acc.append_array(fresh)
	# talking is noise
	_noise_t -= delta
	if _noise_t <= 0 and _rms > 0.03:
		_noise_t = 0.5
		mission.noise(me.global_position, 8.0 + clampf(_rms * 60.0, 0.0, 10.0))
	while _acc.size() >= int(RATE * CHUNK):
		var part := _acc.slice(0, int(RATE * CHUNK))
		_acc = _acc.slice(int(RATE * CHUNK))
		var bytes := encode(part)
		_voice.rpc(bytes, on_radio, Game.mimic_ok)
		if multiplayer.is_server() and Game.mimic_ok:
			_store(1, bytes)

@rpc("any_peer", "unreliable_ordered")
func _voice(bytes: PackedByteArray, radio: bool, may_mimic: bool) -> void:
	var from := multiplayer.get_remote_sender_id()
	if multiplayer.is_server() and may_mimic:
		_store(from, bytes)
	_play(from, bytes, radio)

# ---- playback -------------------------------------------------------------------------------------
func _channel(peer: int, p: Node) -> Dictionary:
	if _chan.has(peer) and is_instance_valid(_chan[peer]["near"]):
		return _chan[peer]
	var near := AudioStreamPlayer3D.new()
	var g := AudioStreamGenerator.new()
	g.mix_rate = RATE
	g.buffer_length = 0.5
	near.stream = g
	near.unit_size = 3.0
	near.max_distance = 30.0
	near.volume_db = 2.0
	p.add_child(near)
	near.position = Vector3(0, 1.6, 0)
	near.play()
	var rad := AudioStreamPlayer.new()
	var g2 := AudioStreamGenerator.new()
	g2.mix_rate = RATE
	g2.buffer_length = 0.5
	rad.stream = g2
	rad.bus = "Radio"
	rad.volume_db = -2.0
	add_child(rad)
	rad.play()
	_chan[peer] = {"near": near, "radio": rad, "pb_near": near.get_stream_playback(), "pb_radio": rad.get_stream_playback(), "last": 9.0}
	return _chan[peer]

func _play(peer: int, bytes: PackedByteArray, radio: bool) -> void:
	var p: Node = mission.actors.get_node_or_null("P%d" % peer)
	if p == null or p.dead:
		return
	var ch := _channel(peer, p)
	var vol := linear_to_db(maxf(0.001, Game.peer_volume(p.display_name)))
	(ch["near"] as AudioStreamPlayer3D).volume_db = 2.0 + vol
	(ch["radio"] as AudioStreamPlayer).volume_db = -2.0 + vol
	var smp := decode(bytes)
	var frames := PackedVector2Array()
	frames.resize(smp.size())
	for i in smp.size():
		frames[i] = Vector2(smp[i], smp[i])
	var pn: AudioStreamGeneratorPlayback = ch["pb_near"]
	if pn and pn.can_push_buffer(frames.size()):
		pn.push_buffer(frames)
	var me: Node = mission.local_player()
	if radio and me and me != p and me.has_radio():
		var bad := _interference(p, me)
		var rf := PackedVector2Array()
		rf.resize(smp.size())
		var drop := randf() < bad * 0.5
		for i in smp.size():
			var v := 0.0 if drop else smp[i]
			v += randf_range(-1.0, 1.0) * (0.03 + bad * 0.25)
			rf[i] = Vector2(v, v)
		if float(ch["last"]) > 0.4:
			Game.play_ui(mission, "radio", -16)
			mission.hud.radio_from(p.display_name)
		var pr: AudioStreamGeneratorPlayback = ch["pb_radio"]
		if pr and pr.can_push_buffer(rf.size()):
			pr.push_buffer(rf)
	ch["last"] = 0.0

## 0..1: how badly the aliens' presence garbles the radio between these two.
func _interference(a: Node, b: Node) -> float:
	var worst := 0.0
	for al in mission.aliens():
		if al.dead:
			continue
		var d: float = min(al.global_position.distance_to(a.global_position), al.global_position.distance_to(b.global_position))
		worst = max(worst, clampf(1.0 - d / 18.0, 0.0, 1.0))
	if Game.has_research("vysilacky"):
		worst *= 0.6
	return worst

# ---- mimicry (host decides, everybody hears) -------------------------------------------------------
func _store(peer: int, bytes: PackedByteArray) -> void:
	var smp := decode(bytes)
	var e := 0.0
	for v in smp:
		e += v * v
	var loud := sqrt(e / max(1, smp.size())) > 0.035
	if not _cur.has(peer):
		_cur[peer] = PackedByteArray()
		_quiet[peer] = 0.0
	var cur: PackedByteArray = _cur[peer]
	if loud:
		cur.append_array(bytes)
		_quiet[peer] = 0.0
	elif cur.size() > 0:
		cur.append_array(bytes)
		_quiet[peer] = float(_quiet[peer]) + CHUNK
	_cur[peer] = cur
	var secs := cur.size() / float(RATE)
	if (cur.size() > 0 and float(_quiet[peer]) > 0.35) or secs > 4.5:
		if secs > 0.7:
			if not snippets.has(peer):
				snippets[peer] = []
			snippets[peer].append(cur)
			if snippets[peer].size() > MAX_SNIPPETS:
				snippets[peer].pop_front()
			if Game.autotest() != "":
				print("[VOICE] stored snippet from %d: %.1f s (%d kept)" % [peer, secs, snippets[peer].size()])
		_cur[peer] = PackedByteArray()
		_quiet[peer] = 0.0

func _mimic_tick(delta: float) -> void:
	mimic_t -= delta
	if mimic_t > 0 or mission.calm() or snippets.is_empty():
		return
	mimic_t = randf_range(30.0, 60.0) if Game.veteran() else randf_range(45.0, 90.0)
	# a listener, and a hidden alien 8-30 m from him
	var pairs := []
	for p in mission.players():
		if p.dead:
			continue
		for a in mission.aliens():
			if a.dead or a.state == a.S.COMBAT:
				continue
			var d: float = a.global_position.distance_to(p.global_position)
			if d > 8.0 and d < 40.0:
				pairs.append([p, a])
	if pairs.is_empty():
		mimic_t = 8.0
		return
	var pick: Array = pairs[randi() % pairs.size()]
	var listener: Node = pick[0]
	var alien: Node = pick[1]
	# whose voice: somebody who is NOT there (far away, or dead) is the cruellest
	var best_peer := -1
	var best_score := -1.0
	for peer in snippets:
		if snippets[peer].is_empty():
			continue
		var q: Node = mission.actors.get_node_or_null("P%d" % peer)
		var score := randf()
		if q == listener:
			score -= 0.5
		elif q == null or q.dead:
			score += 1.0
		elif q.global_position.distance_to(alien.global_position) > 20.0:
			score += 0.8
		if score > best_score:
			best_score = score
			best_peer = peer
	if best_peer < 0:
		return
	var arr: Array = snippets[best_peer]
	var snip: PackedByteArray = arr[randi() % arr.size()]
	var own: bool = mission.actors.get_node_or_null("P%d" % best_peer) == listener
	var mode := "eerie" if own or randf() < 0.45 else "lure"
	_mimic.rpc(alien.name, snip, mode)

@rpc("authority", "call_local", "reliable")
func _mimic(alien_name: String, bytes: PackedByteArray, mode: String) -> void:
	var a: Node = mission.actors.get_node_or_null(alien_name)
	if a == null:
		return
	var ap := AudioStreamPlayer3D.new()
	ap.stream = _wav(bytes, RATE if mode == "lure" else int(RATE * 0.86))
	ap.bus = "Lure" if mode == "lure" else "Eerie"
	ap.unit_size = 4.0 if mode == "lure" else 6.0
	ap.max_distance = 35.0
	ap.volume_db = 1.0
	a.add_child(ap)
	ap.position = Vector3(0, 1.5, 0)
	ap.play()
	ap.finished.connect(ap.queue_free)
	if Game.autotest() != "":
		print("[MIMIC] %s plays %.1f s as %s" % [alien_name, bytes.size() / float(RATE), mode])

## A dead mercenary's voice over the radio, once, a while after the death.
func _dead_radio_tick() -> void:
	for p in mission.players():
		if not p.dead or _dead_said.has(p.name):
			continue
		if not p.has_meta("dead_at"):
			p.set_meta("dead_at", mission.t)
		var peer := int(String(p.name).substr(1))
		if mission.t - float(p.get_meta("dead_at")) < randf_range(25.0, 50.0) or not snippets.has(peer) or snippets[peer].is_empty():
			continue
		_dead_said[p.name] = true
		var arr: Array = snippets[peer]
		_dead_radio.rpc(arr[randi() % arr.size()], p.display_name)

@rpc("authority", "call_local", "reliable")
func _dead_radio(bytes: PackedByteArray, who: String) -> void:
	var me: Node = mission.local_player()
	if me == null or me.dead or not me.has_radio():
		return
	Game.play_ui(mission, "static", -10)
	var ap := AudioStreamPlayer.new()
	ap.stream = _wav(bytes, int(RATE * 0.93))
	ap.bus = "Radio"
	add_child(ap)
	ap.play()
	ap.finished.connect(ap.queue_free)
	mission.hud.radio_from(who)
	me.stress = min(100.0, me.stress + 20.0)
	if Game.autotest() != "":
		print("[MIMIC] dead radio: %s" % who)

func _wav(bytes: PackedByteArray, rate: int) -> AudioStreamWAV:
	var smp := decode(bytes)
	var pcm := PackedByteArray()
	pcm.resize(smp.size() * 2)
	for i in smp.size():
		pcm.encode_s16(i * 2, int(clampf(smp[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = pcm
	return w

# ---- mu-law ---------------------------------------------------------------------------------------
static func encode(smp: PackedFloat32Array) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(smp.size())
	var k := 1.0 / log(256.0)
	for i in smp.size():
		var x := clampf(smp[i] * 1.6, -1.0, 1.0)   # a little gain: mics are quiet
		var m := log(1.0 + 255.0 * absf(x)) * k
		var b := int(m * 127.0)
		if x < 0:
			b |= 128
		out[i] = b
	return out

static func decode(bytes: PackedByteArray) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(bytes.size())
	for i in bytes.size():
		var b := bytes[i]
		var m := float(b & 127) / 127.0
		var x := (pow(256.0, m) - 1.0) / 255.0
		out[i] = -x if b & 128 else x
	return out
