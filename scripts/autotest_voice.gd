extends RefCounted
## (0.62) --autotest=voicedsp: the voice chain without a microphone or a network.
##  noise between words pulled down, speech opens the voice activation in time, the first
##  syllable goes out (pre-roll), lost packets get filled in, and how much CPU it costs.

const DSP := preload("res://scripts/voice_dsp.gd")

## Stands in for an AudioStreamGeneratorPlayback (the headless audio driver plays nothing).
class FakePb:
	extends RefCounted
	var frames := 0
	var consumed := 0
	var keep := false
	var out := PackedFloat32Array()
	var starved := 0          # sound card ran out in the middle of a sound (a hard stop = a click)
	var last := 0.0
	func get_frames_available() -> int:
		return 8000 - (frames - consumed)
	func can_push_buffer(n: int) -> bool:
		return true
	func push_buffer(b: PackedVector2Array) -> void:
		frames += b.size()
		if b.size() > 0:
			last = b[b.size() - 1].x
		if keep:
			for v in b:
				out.append(v.x)
	## The sound card plays n samples (what is missing comes out as silence).
	func play(n: int) -> void:
		var have := frames - consumed
		if have < n:
			if keep:
				if absf(last) > 0.01:
					starved += 1
				last = 0.0
				var z := PackedFloat32Array()
				z.resize(n - have)
				out.append_array(z)
			frames += n - have
		consumed += n

## Clicks in what came out: sample-to-sample jumps far beyond what a 200 Hz tone can do.
static func _clicks(s: PackedFloat32Array) -> int:
	var n := 0
	for i in range(1, s.size()):
		if absf(s[i] - s[i - 1]) > 0.08:
			n += 1
	return n

## A jittery line (Radmin, Wi-Fi): every packet late by 0-jit ms, a few lost, a 250 ms hiccup.
## Returns [clicks, starved, lost, late, dropped, target].
static func _line(jit: float, lose: int, seed_n: int) -> Array:
	seed(seed_n)
	var R := DSP.RATE
	var pb := FakePb.new()
	pb.keep = true
	var rx := DSP.Rx.new(pb, 8000)
	var tx := DSP.new()
	var chunk := int(R * 0.06)
	var arrivals := []
	for k in 120:
		var smp := PackedFloat32Array()
		smp.resize(chunk)
		for i in chunk:
			smp[i] = sin(TAU * 200.0 * (k * chunk + i) / R) * 0.2
		var pkt := tx.packet(smp)
		if lose > 0 and k % lose == lose - 1:
			continue
		var at := 1000.0 + k * 60.0 + randf() * jit
		if k >= 60 and k < 64:
			at = 1000.0 + 64 * 60.0 + randf() * 10.0      # a hiccup: four packets arrive at once
		arrivals.append([at, pkt])
	arrivals.sort_custom(func(a, b): return a[0] < b[0])
	var now := 1000.0
	var i := 0
	var step := 1000.0 / 60.0
	while now < 1000.0 + 125 * 60.0 + 600.0:
		while i < arrivals.size() and arrivals[i][0] <= now:
			var pk: PackedByteArray = arrivals[i][1]
			rx.push(pk[0], DSP.decode(pk.slice(1)), int(arrivals[i][0]))
			i += 1
		pb.play(int(R * step / 1000.0))
		rx.pump(step / 1000.0, int(now))
		now += step
	# the sound of the sentence only (skip the silence before it)
	var o := pb.out
	return [_clicks(o), pb.starved, rx.lost, rx.late, rx.dropped, rx.target()]

static func _speech(n: int, t0: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var x := t0 + float(i) / DSP.RATE
		var syl := maxf(0.0, sin(TAU * 3.0 * x))
		var f0 := 140.0 + 25.0 * sin(TAU * 0.7 * x)
		out[i] = (sin(TAU * f0 * x) * 0.5 + sin(TAU * f0 * 2.0 * x) * 0.3 + sin(TAU * 900.0 * x) * 0.12) * syl * 0.12
	return out

static func _noise(n: int, a: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = randf_range(-1.0, 1.0) * a
	return out

static func _rms(s: PackedFloat32Array, a: int, b: int) -> float:
	var e := 0.0
	for i in range(a, b):
		e += s[i] * s[i]
	return sqrt(e / maxf(1.0, b - a))

static func run() -> void:
	seed(7)
	var R := DSP.RATE
	# 1.5 s room noise, 1.5 s speech in the noise, 1.5 s noise
	var noise := _noise(int(R * 4.5), 0.01)
	var sig := noise.duplicate()
	var sp := _speech(int(R * 1.5), 0.0)
	for i in sp.size():
		sig[int(R * 1.5) + i] += sp[i]
	var res := {}
	for clean in [false, true]:
		var d := DSP.new()
		var out := PackedFloat32Array()
		var first_voice := -1.0
		var blk := int(R * 0.016)
		var i := 0
		while i < sig.size():
			var o := d.process_mono(sig.slice(i, i + blk), clean, 0.03)
			if d.voiced and first_voice < 0 and i > int(R * 1.5):
				first_voice = (i - R * 1.5) / R
			out.append_array(o)
			i += blk
		var n_out := _rms(out, int(R * 1.0), int(R * 1.5))
		var s_out := _rms(out, int(R * 1.6), int(R * 2.9))
		res[clean] = [20.0 * log(s_out / maxf(n_out, 1e-6)) / log(10.0), first_voice]
	var n_in := _rms(sig, int(R * 1.0), int(R * 1.5))
	var s_in := _rms(sig, int(R * 1.6), int(R * 2.9))
	var snr_in := 20.0 * log(s_in / n_in) / log(10.0)
	print("[VOICEDSP] snr in %.1f dB, out plain %.1f dB, out clean %.1f dB, voice opens after %.3f s" % [snr_in, res[false][0], res[true][0], res[true][1]])
	# pre-roll: voice activation, the speech starts at 1.5 s - the first packet carries the 0.2 s before
	var d2 := DSP.new()
	var blk2 := int(R * 0.016)
	var first_len := 0
	var i2 := 0
	while i2 < sig.size():
		var fr := d2.process_mono(sig.slice(i2, i2 + blk2), true, 0.03)
		var o2 := d2.transmit(fr, false, true, 0.016)
		if not o2.is_empty() and first_len == 0:
			first_len = o2.size()
		i2 += blk2
	# push-to-talk tail
	var d3 := DSP.new()
	var tail := 0
	for k in 60:
		var o3 := d3.transmit(_noise(256, 0.01), k < 20, false, 0.016)
		if k >= 20:
			tail += o3.size()
	print("[VOICEDSP] preroll %.2f s, ptt tail %.2f s" % [float(first_len) / R, float(tail) / R])
	# lost packets: every 5th one missing, plus a duplicate (an even line)
	var pb := FakePb.new()
	var rx := DSP.Rx.new(pb, 8000)
	var tx := DSP.new()
	var chunk := int(R * 0.06)
	var now := 1000
	for k in 50:
		var pkt := tx.packet(_speech(chunk, k * 0.06))
		for st in 4:
			pb.play(chunk / 4)
			rx.pump(0.015, now + st * 15)
		now += 60
		if k % 5 == 3:
			continue
		rx.push(pkt[0], DSP.decode(pkt.slice(1)), now)
		if k == 10:
			rx.push(pkt[0], DSP.decode(pkt.slice(1)), now)    # the same one again
	for st in 40:
		pb.play(chunk / 4)
		rx.pump(0.015, now + st * 15)
	var expect := 50 * chunk
	print("[VOICEDSP] lost %d rescued %d late %d frames %d of %d" % [rx.lost, rx.rescued, rx.late, pb.frames, expect])
	# (0.70) a jittery line: no clicks, the sound card never runs dry mid-sentence
	var bad := _line(140.0, 17, 3)
	var calm := _line(15.0, 0, 4)
	print("[VOICEDSP] jitter line: clicks %d starved %d lost %d late %d dropped %d cushion %.0f ms" % [bad[0], bad[1], bad[2], bad[3], bad[4], bad[5] * 1000.0])
	print("[VOICEDSP] calm line: clicks %d starved %d cushion %.0f ms" % [calm[0], calm[1], calm[5] * 1000.0])
	# cost: 3 s of 48 kHz stereo input
	var raw := PackedVector2Array()
	raw.resize(48000 * 3)
	for k in raw.size():
		var v := randf_range(-0.05, 0.05)
		raw[k] = Vector2(v, v)
	var d4 := DSP.new()
	var t0 := Time.get_ticks_usec()
	var got := 0
	for k in 3 * 60:
		got += d4.process(raw.slice(k * 800, k * 800 + 800), 48000.0, 1.0, true, 0.03).size()
	var ms := (Time.get_ticks_usec() - t0) / 1000.0 / 3.0
	print("[VOICEDSP] cpu %.1f ms per second of audio, out %d (want %d)" % [ms, got, R * 3])
	var ok: bool = res[true][0] > res[false][0] + 10.0 and res[true][1] >= 0.0 and res[true][1] < 0.12 \
		and first_len >= int(R * 0.18) and tail >= int(R * 0.25) and rx.rescued == 12 and rx.late == 1 \
		and bad[0] == 0 and bad[1] == 0 and calm[0] == 0 and calm[1] == 0 and calm[5] < 0.12 and ms < 40.0 and absi(got - R * 3) < 400
	print("RESULT voicedsp %s" % ("ok" if ok else "CHYBA"))
