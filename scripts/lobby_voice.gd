extends Node
## Voice outside the mission: in the lobby and on the globe the team can plan.
## Plain voice (no distance, no radio), same 11 kHz mu-law stream as in the mission.
## Also the microphone test: your own voice played back a moment later, and the level.

const Voice := preload("res://scripts/voice.gd")
const DSP := preload("res://scripts/voice_dsp.gd")
var mic: AudioStreamPlayer
var capture: AudioEffectCapture
var dsp := DSP.new()       # (0.62) filters, noise floor, level, voice activation, pre-roll
var _acc := PackedFloat32Array()
var _chan := {}            # peer -> {player, rx, last}
var testing := false       # microphone test: hear yourself
var _echo: AudioStreamPlayer
var _echo_pb: AudioStreamGeneratorPlayback
var talking := false
var _mission_feed := PackedFloat32Array()   # what the mission's Voice takes each frame
# diagnostics for the settings screen: is the microphone delivering, is anything going out / coming in
var frames_in := 0          # raw microphone frames in the last second
var _frames_acc := 0
var _stat_t := 0.0
var sent := 0
var received := 0
var opened_at := 0
var _retries := 0
var _since_open := 0
var dbg_rx := PackedFloat32Array()

func _ready() -> void:
	name = "LobbyVoice"

## In a real mission the mission's own Voice takes the microphone. A co-op client walking our
## base alone (an offline copy) still talks to the team on the globe through the lobby voice.
func _in_mission() -> bool:
	var sc := get_tree().current_scene
	return sc != null and sc.name == "Mission" and not (sc.has_method("local") and sc.local())

## One reader of the microphone for the whole game (menu test, lobby, globe and the mission).
func _want_mic() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	if testing:
		return true
	if (Game.voice_mode == "off" and not Game.mic_live) or (Game.autotest() != "" and not Game.autotest().begins_with("mic")):
		return false
	return Net.is_online() or _in_mission()

## The mission's Voice: everything heard since the last call (already resampled and levelled).
func take_for_mission() -> PackedFloat32Array:
	var out := _mission_feed
	_mission_feed = PackedFloat32Array()
	return out

func _process(delta: float) -> void:
	var want := _want_mic()
	if want and mic == null:
		_open()
	elif not want and mic != null:
		if Game.autotest() != "":
			print("[MIC] closing: online=%s mission=%s mode=%s scene=%s" % [Net.is_online(), _in_mission(), Game.voice_mode, get_tree().current_scene.name if get_tree().current_scene else "-"])
		mic.queue_free()
		mic = null
		capture = null
		_acc.clear()
	if mic == null:
		Game.mic_level = lerpf(Game.mic_level, 0.0, 0.2)
		return
	var fresh := PackedFloat32Array()
	var n := capture.get_frames_available() if capture else 0
	_frames_acc += n
	# Windows sometimes opens the device silently dead: try again a few times
	_since_open += n
	if _since_open == 0 and Time.get_ticks_msec() - opened_at > 2500 and _retries < 3:
		_retries += 1
		reopen()
		return
	_stat_t += delta
	if _stat_t >= 1.0:
		frames_in = int(_frames_acc / _stat_t)
		_frames_acc = 0
		_stat_t = 0.0
	if n > 0:
		fresh = dsp.process(capture.get_buffer(n), AudioServer.get_mix_rate(), Game.mic_gain, Game.mic_clean, Game.mic_gate)
	if fresh.size() > 0:
		Game.mic_level = lerpf(Game.mic_level, dsp.level, 0.5)
	if testing:
		_play_echo(fresh)
	if _in_mission():
		_mission_feed.append_array(fresh)
		if _mission_feed.size() > Voice.RATE:      # nobody took it (no Voice node): keep a second at most
			_mission_feed = _mission_feed.slice(_mission_feed.size() - Voice.RATE)
		return
	if not Net.is_online() or multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	var out := transmit(fresh, Input.is_action_pressed("talk"), Game.voice_mode == "open" or Game.mic_live, delta)
	if out.is_empty():
		_acc.clear()
		return
	_acc.append_array(out)
	var chunk := int(Voice.RATE * Voice.CHUNK)
	while _acc.size() >= chunk:
		var part := _acc.slice(0, chunk)
		_acc = _acc.slice(chunk)
		_lobby_voice.rpc(dsp.packet(part))
		sent += 1

## (0.62) Push-to-talk / voice activation with pre-roll and tail; what to send now.
## The mission's Voice calls this too (only one of them reads the microphone at a time).
func transmit(fresh: PackedFloat32Array, ptt: bool, open: bool, delta: float) -> PackedFloat32Array:
	var out := dsp.transmit(fresh, ptt, open, delta)
	talking = dsp.talking
	return out

## The microphone the player picked in the settings (or the system default).
static func apply_device() -> void:
	var want: String = Game.mic_device
	if want != "" and want in AudioServer.get_input_device_list():
		AudioServer.input_device = want
	else:
		AudioServer.input_device = "Default"

## Close and reopen (after choosing another device).
func reopen() -> void:
	if mic:
		mic.queue_free()
		mic = null
		capture = null

func _open() -> void:
	apply_device()
	opened_at = Time.get_ticks_msec()
	_since_open = 0
	capture = DSP.mic_bus()
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
	var d := DSP.decode(DSP.encode(fresh))     # exactly what the others will hear
	for i in d.size():
		fr[i] = Vector2(d[i], d[i])
	if _echo_pb.can_push_buffer(fr.size()):
		_echo_pb.push_buffer(fr)

func stop_test() -> void:
	testing = false
	if _echo:
		_echo.queue_free()
		_echo = null

@rpc("any_peer", "unreliable_ordered", "call_remote", 3)
func _lobby_voice(bytes: PackedByteArray) -> void:
	if _in_mission():
		return
	var from := multiplayer.get_remote_sender_id()
	received += 1
	if not _chan.has(from) or not is_instance_valid(_chan[from]["player"]):
		var ap := AudioStreamPlayer.new()
		var g := AudioStreamGenerator.new()
		g.mix_rate = Voice.RATE
		g.buffer_length = 0.5
		ap.stream = g
		ap.bus = "Voice"
		add_child(ap)
		ap.play()
		var pb0 := ap.get_stream_playback()
		_chan[from] = {"player": ap, "rx": DSP.Rx.new(pb0, pb0.get_frames_available()), "last": 0}
	var ch: Dictionary = _chan[from]
	(ch["player"] as AudioStreamPlayer).volume_db = linear_to_db(maxf(0.001, Game.peer_volume(Net.roster.get(from, {}).get("name", ""))))
	ch["last"] = Time.get_ticks_msec()
	var smp := DSP.decode(bytes.slice(1))
	if Game.autotest().begins_with("mic"):
		dbg_rx.append_array(smp)
	(ch["rx"] as DSP.Rx).push(bytes[0] if bytes.size() > 0 else -1, smp)

## Who is speaking right now (for the lobby list).
func speaking(peer: int) -> bool:
	if peer == Net.my_id():
		return talking
	return _chan.has(peer) and Time.get_ticks_msec() - int(_chan[peer]["last"]) < 300

## (0.61) For the lobby list: is my microphone off, on Tab, open, or open but silent (a dead device).
func mic_state() -> String:
	if Game.voice_mode == "off" and not Game.mic_live:
		return "off"
	if mic != null and Time.get_ticks_msec() - opened_at > 3000 and frames_in == 0:
		return "dead"
	return "open" if Game.voice_mode == "open" or Game.mic_live else "ptt"
