extends Node
## Networking: one player hosts (ENet), up to three join. Solo play uses the
## same code with the offline peer (we are the "server" then).

signal roster_changed
signal connected_ok
signal connection_failed(reason: String)
signal mission_started

const PORT := 7777
const MAX_PLAYERS := 4

## peer id -> {"name": ..., "merc": {...}}
var roster := {}
var mission_seed := 0
var mission_difficulty := "normal"

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(func(): connection_failed.emit("Nepodařilo se připojit."))
	multiplayer.server_disconnected.connect(_on_server_gone)

func is_online() -> bool:
	return not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer)

func play_solo() -> void:
	close()
	roster = {1: {"name": Game.merc["name"], "merc": Game.merc}}

func host(port := PORT) -> String:
	close()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS - 1)
	if err != OK:
		return "Port %d je obsazený nebo blokovaný." % port
	multiplayer.multiplayer_peer = peer
	roster = {1: {"name": Game.merc["name"], "merc": Game.merc}}
	roster_changed.emit()
	return ""

func join(ip: String, port := PORT) -> String:
	close()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port)
	if err != OK:
		return "Nelze se připojit na %s." % ip
	multiplayer.multiplayer_peer = peer
	return ""

func close() -> void:
	if multiplayer.multiplayer_peer and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	roster = {}

func _on_connected() -> void:
	_register.rpc_id(1, Game.merc)
	connected_ok.emit()

func _on_peer_connected(_id: int) -> void:
	pass

func _on_peer_disconnected(id: int) -> void:
	if roster.erase(id):
		roster_changed.emit()
		if multiplayer.is_server():
			_set_roster.rpc(roster)

func _on_server_gone() -> void:
	close()
	connection_failed.emit("Hostitel ukončil hru.")

@rpc("any_peer", "reliable")
func _register(merc: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	roster[id] = {"name": str(merc.get("name", "Žoldák")), "merc": merc}
	_set_roster.rpc(roster)
	roster_changed.emit()

@rpc("authority", "call_local", "reliable")
func _set_roster(r: Dictionary) -> void:
	roster = r
	roster_changed.emit()

var mission_params := {}   # campaign mission (type, biome, night, stash...) or empty for a quick mission
var last_result := ""      # shown on the globe when the team comes back

## Host: everybody into the mission (same seed = same random map everywhere).
func start_mission(params := {}) -> void:
	if not multiplayer.is_server():
		return
	var s := Game.seed_override if Game.seed_override >= 0 else randi() % 1000000
	if params.has("seed") and Game.seed_override < 0:
		s = int(params["seed"])
	_start.rpc(s, Game.difficulty, params)

@rpc("authority", "call_local", "reliable")
func _start(s: int, diff := "normal", params := {}) -> void:
	mission_seed = s
	mission_difficulty = diff
	mission_params = params
	mission_started.emit()
	get_tree().change_scene_to_file("res://scenes/Mission.tscn")

func back_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

## After a mission: the campaign host returns to the globe (co-op stays
## connected), clients go back to the lobby, quick missions to the menu.
func after_mission() -> void:
	var campaign := not mission_params.is_empty()
	mission_params = {}
	if campaign and multiplayer.is_server() and Campaign.active:
		if not is_online():
			close()
		get_tree().change_scene_to_file("res://scenes/Geoscape.tscn")
	elif is_online() and not multiplayer.is_server():
		get_tree().change_scene_to_file("res://scenes/Main.tscn")
	else:
		close()
		get_tree().change_scene_to_file("res://scenes/Main.tscn")
