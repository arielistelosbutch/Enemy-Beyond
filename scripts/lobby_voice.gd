extends Node
## Voice outside the mission: in the lobby and on the globe the team can plan.
## Plain voice (no distance, no radio), same 11 kHz mu-law stream as in the mission.
## Also the microphone test: your own voice played back a moment later, and the level.

const Voice := preload("res://scripts/voice.gd")
var mic: AudioStreamPlayer
var capture: AudioEffectCapture
var _rs_pos := 0.0
var _rs_sum := 0.0
var _rs_n := 0
var _acc := PackedFloat32Array()
var _hold := 0.0
var _chan := {}            # peer -> {player, pb}
var testing := false       # microphone test: hear yourself
var _echo: AudioStreamPlayer
var _echo_pb: AudioStreamGeneratorPlayback
var talking := false

func _ready() -> void:
	name = "LobbyVoice"

func _in_mission() -> bool:
	var sc := get_tree().current_scene
	return sc != null and sc.name == "Mission"

func _want_mic() -> bool:
	if Game.voice_mode == "off" or DisplayServer.get_name() == "headless" or Game.autotest() != "":
		return testing and DisplayServer.get_name() != "headless"
	return testing or (Net.is_online() and not _in_mission())

func _process(delta: float) -> void:
	var want := _want_mic()
	if want and mic == null:
		_open()
	elif not want and mic != null:
		mic.queue_free()
		mic = null
		capture = null
		_acc.clear()
	if mic == null:
		Game.mic_level = lerpf(Game.mic_level, 0.0, 0.2)
		return
	var fresh := PackedFloat32Array()
	var n := capture.get_frames_available() if capture else 0
	if n > 0:
		var buf := capture.get_buffer(n)
		var ratio := AudioServer.get_mix_rate() / float(Voice.RATE)
		for f in buf:
			_rs_sum += (f.x + f.y) * 0.5 * Game.mic_gain
			_rs_n += 1
			_rs_pos += 1.0
			if _rs_pos >= ratio:
				_rs_pos -= ratio
				fresh.append(_rs_sum / _rs_n)
				_rs_sum = 0.0
				_rs_n = 0
	var e := 0.0
	for v in fresh:
		e += v * v
	if fresh.size() > 0:
		Game.mic_level = lerpf(Game.mic_level, sqrt(e / fresh.size()), 0.5)
	if testing:
		_play_echo(fresh)
	if not Net.is_online() or _in_mission():
		return
	var send := Input.is_action_pressed("talk")
	if Game.voice_mode == "open":
		if Game.mic_level > Game.mic_gate:
			_hold = 0.45
		_hold -= delta
		send = send or _hold > 0.0
	talking = send
	if not send:
		_acc.clear()
		return
	_acc.append_array(fresh)
	var chunk := int(Voice.RATE * Voice.CHUNK)
	while _acc.size() >= chunk:
		var part := _acc.slice(0, chunk)
		_acc = _acc.slice(chunk)
		_lobby_voice.rpc(Voice.encode(part))

func _open() -> void:
	if AudioServer.get_bus_index("Mic") < 0:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, "Mic")
		AudioServer.set_bus_mute(i, true)
		AudioServer.add_bus_effect(i, AudioEffectCapture.new())
	capture = AudioServer.get_bus_effect(AudioServer.get_bus_index("Mic"), 0) as AudioEffectCapture
	mic = AudioStreamPlayer.new()
	mic.stream = AudioStreamMicrophone.new()
	mic.bus = "Mic"
	add_child(mic)
	mic.play()

## The microphone test: what you say comes back about half a second later.
func _play_echo(fresh: PackedFloat32Array) -> void:
	if _echo == null:
		_echo = AudioStreamPlayer.new()
		var g := AudioStreamGenerator.new()
		g.mix_rate = Voice.RATE
		g.buffer_length = 1.0
		_echo.stream = g
		add_child(_echo)
		_echo.play()
		_echo_pb = _echo.get_stream_playback()
		# half a second of silence first, so you hear yourself after you speak
		var pad := PackedVector2Array()
		pad.resize(int(Voice.RATE * 0.5))
		_echo_pb.push_buffer(pad)
	var fr := PackedVector2Array()
	fr.resize(fresh.size())
	var d := Voice.decode(Voice.encode(fresh))     # exactly what the others will hear
	for i in d.size():
		fr[i] = Vector2(d[i], d[i])
	if _echo_pb.can_push_buffer(fr.size()):
		_echo_pb.push_buffer(fr)

func stop_test() -> void:
	testing = false
	if _echo:
		_echo.queue_free()
		_echo = null

@rpc("any_peer", "unreliable_ordered")
func _lobby_voice(bytes: PackedByteArray) -> void:
	if _in_mission():
		return
	var from := multiplayer.get_remote_sender_id()
	if not _chan.has(from) or not is_instance_valid(_chan[from]["player"]):
		var ap := AudioStreamPlayer.new()
		var g := AudioStreamGenerator.new()
		g.mix_rate = Voice.RATE
		g.buffer_length = 0.5
		ap.stream = g
		add_child(ap)
		ap.play()
		_chan[from] = {"player": ap, "pb": ap.get_stream_playback(), "last": 0.0}
	var ch: Dictionary = _chan[from]
	(ch["player"] as AudioStreamPlayer).volume_db = linear_to_db(maxf(0.001, Game.peer_volume(Net.roster.get(from, {}).get("name", ""))))
	ch["last"] = Time.get_ticks_msec()
	var smp := Voice.decode(bytes)
	var fr := PackedVector2Array()
	fr.resize(smp.size())
	for i in smp.size():
		fr[i] = Vector2(smp[i], smp[i])
	var pb: AudioStreamGeneratorPlayback = ch["pb"]
	if pb.can_push_buffer(fr.size()):
		pb.push_buffer(fr)

## Who is speaking right now (for the lobby list).
func speaking(peer: int) -> bool:
	if peer == Net.my_id():
		return talking
	return _chan.has(peer) and Time.get_ticks_msec() - int(_chan[peer]["last"]) < 300
