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
## Audio goes over the network as 16 kHz mono mu-law (about 16 kB/s per talker), cleaned up
## and gated by voice_dsp.gd (0.62: noise floor, pre-roll, jitter cushion, lost-packet fill).

const DSP := preload("res://scripts/voice_dsp.gd")

const RATE := 16000
const CHUNK := 0.06              # seconds of audio per packet
const MAX_SNIPPETS := 6

var mission: Node
var capture: AudioEffectCapture
var mic: AudioStreamPlayer
var talking := false
var on_radio := false
var _acc := PackedFloat32Array()
var _noise_t := 0.0
var _rms := 0.0
var _chan := {}                  # peer -> {near, radio, rx_near, rx_radio, last}
var _test_feed := PackedFloat32Array()   # autotest: fake microphone input at RATE
var _dbg_t := 0.0
var _dbg_n := 0
var speakers := {}               # name -> seconds since heard (for the HUD)

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
	mimic_t = randf_range(35.0, 60.0)
	# the microphone itself belongs to Net/LobbyVoice (one reader for the whole game);
	# here we only take what it heard
	pass

func _exit_tree() -> void:
	# nothing anybody said survives the mission
	snippets.clear()
	_cur.clear()

## Mic (captured, muted), Radio (narrow and dirty), Eerie (slowed, cavernous), Lure (close, dry).
func _buses() -> void:
	capture = DSP.mic_bus()
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
	# radio goes into the teammates' slider, the alien mimicry into the effects one
	AudioServer.set_bus_send(AudioServer.get_bus_index("Radio"), "Voice")
	AudioServer.set_bus_send(AudioServer.get_bus_index("Eerie"), "SFX")
	AudioServer.set_bus_send(AudioServer.get_bus_index("Lure"), "SFX")

# ---- capture and send --------------------------------------------------------------------------
func _process(delta: float) -> void:
	var me: Node = mission.local_player()
	_capture(delta, me)
	if Game.autotest().begins_with("mic"):
		_dbg_t += delta
		if _dbg_t > 2.0:
			_dbg_t = 0.0
			var lv: Node = Net.get_node("LobbyVoice")
			if true:
				pass
			print("[MIC-MISSION %s] raw/s=%d samples/2s=%d fps=%d talking=%s radio=%s sent=%d received=%d level=%.3f go=%s" % [Game.autotest(), lv.frames_in, _dbg_n, Engine.get_frames_per_second(), talking, on_radio, lv.sent, lv.received, Game.mic_level, mission.go])
			_dbg_n = 0
	if multiplayer.is_server() and not mission.finished:
		_mimic_tick(delta)
		_dead_radio_tick()
	for peer in _chan.keys():
		_chan[peer]["last"] = float(_chan[peer]["last"]) + delta
		if is_instance_valid(_chan[peer]["near"]):
			(_chan[peer]["rx_near"] as DSP.Rx).pump(delta)
			(_chan[peer]["rx_radio"] as DSP.Rx).pump(delta)
	for k in speakers.keys():
		speakers[k] = float(speakers[k]) + delta
		if speakers[k] > 0.4:
			speakers.erase(k)

## Autotest: pretend somebody spoke into the microphone (mono floats at RATE).
func test_speak(samples: PackedFloat32Array) -> void:
	_test_feed.append_array(samples)

func _capture(delta: float, me: Node) -> void:
	var fresh := PackedFloat32Array()
	var lv: Node = Net.get_node_or_null("LobbyVoice")
	if lv:
		fresh = lv.take_for_mission()
	_dbg_n += fresh.size()
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
	var ptt := false
	var open := false
	var vmode: String = "open" if Game.mic_live else Game.voice_mode
	if alive and (vmode != "off" or Input.is_action_pressed("radio_talk")):
		ptt = Input.is_action_pressed("talk") or Input.is_action_pressed("radio_talk") or me.radio_button
		open = vmode == "open"
	if alive and (not _test_feed.is_empty() or (fresh.size() > 0 and Game.autotest() == "voice")):
		ptt = true
	# pre-roll, tail and voice activation are shared with the lobby (voice_dsp.gd)
	var out: PackedFloat32Array = lv.transmit(fresh, ptt, open, delta) if lv else (fresh if ptt else PackedFloat32Array())
	var want: bool = alive and not out.is_empty()
	if not alive and lv:
		lv.dsp.reset()
	talking = want
	# the radio: hold K (or the hand button with the radio in it); a radio on the belt is enough.
	# It stays keyed through the short tail after the button is let go.
	if want and alive and me.radio_tx() and (me.radio_button or Input.is_action_pressed("radio_talk") or Game.autotest() == "voice"):
		on_radio = true
	elif not want:
		on_radio = false
	if not want:
		_acc.clear()
		return
	_acc.append_array(out)
	# talking is noise
	_noise_t -= delta
	if _noise_t <= 0 and _rms > 0.03:
		_noise_t = 0.5
		mission.noise(me.global_position, 8.0 + clampf(_rms * 60.0, 0.0, 10.0))
	while _acc.size() >= int(RATE * CHUNK):
		var part := _acc.slice(0, int(RATE * CHUNK))
		_acc = _acc.slice(int(RATE * CHUNK))
		var pkt: PackedByteArray = lv.dsp.packet(part) if lv else (PackedByteArray([0]) + encode(part))
		if lv:
			lv._lobby_voice.rpc(pkt, on_radio, Game.mimic_ok)
		if lv: lv.sent += 1
		if multiplayer.is_server() and Game.mimic_ok:
			_store(1, pkt.slice(1))

## (0.70) Voice packets come through LobbyVoice (one channel for the whole game). True when the
## speaker is in this mission and was played here; false = LobbyVoice plays it plainly.
func on_packet(from: int, pkt: PackedByteArray, radio: bool, may_mimic: bool) -> bool:
	var p: Node = mission.actors.get_node_or_null("P%d" % from)
	if p == null:
		return false
	var bytes := pkt.slice(1)
	if multiplayer.is_server() and may_mimic:
		_store(from, bytes)
	_play(from, bytes, radio, pkt[0])
	return true

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
	near.bus = "Voice"
	p.add_child(near)
	near.position = Vector3(0, 1.6, 0)
	near.play()
	var pbn := near.get_stream_playback()
	var rad := AudioStreamPlayer.new()
	var g2 := AudioStreamGenerator.new()
	g2.mix_rate = RATE
	g2.buffer_length = 0.5
	rad.stream = g2
	rad.bus = "Radio"
	rad.volume_db = -2.0
	add_child(rad)
	rad.play()
	var pbr := rad.get_stream_playback()
	_chan[peer] = {"near": near, "radio": rad, "rx_near": DSP.Rx.new(pbn, pbn.get_frames_available()),
		"rx_radio": DSP.Rx.new(pbr, pbr.get_frames_available()), "last": 9.0}
	return _chan[peer]

func _play(peer: int, bytes: PackedByteArray, radio: bool, seq: int = -1) -> void:
	var p: Node = mission.actors.get_node_or_null("P%d" % peer)
	if p == null or p.dead:
		return
	var ch := _channel(peer, p)
	var vol := linear_to_db(maxf(0.001, Game.peer_volume(p.display_name)))
	(ch["near"] as AudioStreamPlayer3D).volume_db = 2.0 + vol
	(ch["radio"] as AudioStreamPlayer).volume_db = -2.0 + vol
	var smp := decode(bytes)
	(ch["rx_near"] as DSP.Rx).push(seq, smp)      # jitter cushion, lost packets filled in
	speakers[p.display_name] = 0.0
	var me: Node = mission.local_player()
	if Game.autotest() != "" and randf() < 0.05:
		print("[VOICE-RX] from %s radio=%s me_has_radio=%s rms=%.3f" % [p.display_name, radio, me.has_radio() if me else false, _rms_of(smp)])
	if radio and me and me != p and me.has_radio():
		var bad := _interference(p, me)
		var rf := PackedFloat32Array()
		rf.resize(smp.size())
		# the voice stays clear; aliens close by add hiss and, when very close, short dropouts
		var drop := bad > 0.6 and randf() < (bad - 0.6)
		for i in smp.size():
			var v := 0.0 if drop else smp[i] * 1.4
			v += randf_range(-1.0, 1.0) * (0.004 + bad * 0.05)
			rf[i] = v
		if float(ch["last"]) > 0.4:
			Game.play_ui(mission, "radio", -16)
			if bad > 0.5:
				Game.play_ui(mission, "radio_jam", -20 + bad * 6.0)     # they are close: the set screams
			mission.hud.radio_from(p.display_name)
		(ch["rx_radio"] as DSP.Rx).push(seq, rf)
	ch["last"] = 0.0

static func _rms_of(smp: PackedFloat32Array) -> float:
	var e := 0.0
	for v in smp:
		e += v * v
	return sqrt(e / maxf(1.0, smp.size()))

## 0..1: how badly the aliens' presence garbles the radio between these two.
func _interference(a: Node, b: Node) -> float:
	var worst := 0.0
	for al in mission.aliens():
		if al.dead:
			continue
		var d: float = min(al.global_position.distance_to(a.global_position), al.global_position.distance_to(b.global_position))
		worst = max(worst, clampf(1.0 - d / 18.0, 0.0, 1.0))
	# COM-01 is an ordinary set: distance, concrete and rock between the two eat the signal
	var pa: Vector3 = (a as Node3D).global_position + Vector3.UP * 1.5
	var pb: Vector3 = (b as Node3D).global_position + Vector3.UP * 1.5
	var path := clampf((pa.distance_to(pb) - 45.0) / 150.0, 0.0, 0.35)
	var space := (mission as Node3D).get_world_3d().direct_space_state if mission is Node3D else null
	if space:
		var q := PhysicsRayQueryParameters3D.create(pa, pb, 1)
		q.exclude = [a.get_rid(), b.get_rid()] if a is CollisionObject3D and b is CollisionObject3D else []
		if not space.intersect_ray(q).is_empty():
			path += 0.2
	if String(Net.mission_params.get("type", "")) in ["alienbase", "mars"]:
		path += 0.15          # (deep under their hulls and rock)
	worst = maxf(worst, path)
	if Game.has_research("vysilacky"):
		worst *= 0.6
	return worst

# ---- mimicry (host decides, everybody hears) -------------------------------------------------------
func _store(peer: int, bytes: PackedByteArray) -> void:
	var smp := decode(bytes)
	var e := 0.0
	for v in smp:
		e += v * v
	var loud := sqrt(e / max(1, smp.size())) > minf(0.02, Game.mic_gate * 0.8)
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
		if secs > 0.5:
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
	mimic_t = randf_range(18.0, 35.0) if Game.veteran() else randf_range(25.0, 50.0)
	# a listener, and a hidden alien 6-50 m from him. The Greys love it: they do it even in a
	# fight and get picked three times as often (they are the clever, cruel ones)
	var pairs := []
	for p in mission.players():
		if p.dead:
			continue
		for a in mission.aliens():
			var grey := String(a.get("race")).begins_with("grey")
			if a.dead or (a.state == a.S.COMBAT and not grey):
				continue
			var d: float = a.global_position.distance_to(p.global_position)
			if d > 6.0 and d < 50.0:
				for k in (3 if grey else 1):
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
	_to_present(_mimic, [alien.name, snip, mode])

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
## (0.70) Only to the machines still in this mission (one in the transporter or the menu has no
## Mission/Voice node: the packet would be an error there) - and here.
func _to_present(f: Callable, args: Array) -> void:
	f.callv(args)
	for p in mission.players():
		var id: int = p.get_multiplayer_authority()
		if id != multiplayer.get_unique_id() and id in multiplayer.get_peers():
			callv("rpc_id", [id, f.get_method()] + args)

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
		_to_present(_dead_radio, [arr[randi() % arr.size()], p.display_name])

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

# ---- mu-law (voice_dsp.gd) -------------------------------------------------------------------------
static func encode(smp: PackedFloat32Array) -> PackedByteArray:
	return DSP.encode(smp)

static func decode(bytes: PackedByteArray) -> PackedFloat32Array:
	return DSP.decode(bytes)
