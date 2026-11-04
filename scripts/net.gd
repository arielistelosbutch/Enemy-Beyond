extends Node
## Networking: one player hosts (ENet), up to three join. Solo play uses the
## same code with the offline peer (we are the "server" then).

signal roster_changed
signal connected_ok
signal connection_failed(reason: String)
signal mission_started
signal blocked(why: String)

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
	add_child(preload("res://scripts/lobby_voice.gd").new())
	var tm := Timer.new()
	tm.wait_time = 2.0
	tm.autostart = true
	tm.timeout.connect(func():
		var sc := get_tree().current_scene
		if multiplayer.is_server() and is_online() and Campaign.active and sc and sc.name != "Mission":
			broadcast_team())
	add_child(tm)

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
	wallets = {}
	if Campaign.viewer:
		Campaign.viewer = false
		Campaign.data = {}

func _on_connected() -> void:
	Game.merc["sick"] = Game.heal_days_left(Game.merc)
	_register.rpc_id(1, Game.merc)
	connected_ok.emit()

func _on_peer_connected(_id: int) -> void:
	pass

func _on_peer_disconnected(id: int) -> void:
	if multiplayer.is_server() and roster.has(id):
		_note.rpc("%s odešel ze hry." % roster[id]["name"])
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
	var fresh := not roster.has(id)
	if Campaign.active:
		# the campaign's mercenaries are kept by the host: an older copy on the client is replaced
		var kept := Campaign.keep_merc(merc)
		if kept != merc:
			merc = kept
			_adopt_merc.rpc_id(id, merc)
	roster[id] = {"name": str(merc.get("name", "Žoldák")), "merc": merc}
	if fresh:
		_note.rpc("%s se připojil ke hře (%d/%d)." % [roster[id]["name"], roster.size(), MAX_PLAYERS])
	wallets[id] = int(merc.get("money", 0))
	_set_roster.rpc(roster)
	roster_changed.emit()
	broadcast_team()

## Client: the host's campaign has a newer record of this mercenary - play that one.
@rpc("authority", "reliable")
func _adopt_merc(m: Dictionary) -> void:
	Game.merc = m
	Game.save_merc()
	note.emit("Hostitel má v kampani novější záznam o žoldákovi %s - používáš ten." % str(m.get("name", "?")))

@rpc("authority", "call_local", "reliable")
func _set_roster(r: Dictionary) -> void:
	roster = r
	roster_changed.emit()

var mission_params := {}   # campaign mission (type, biome, night, stash...) or empty for a quick mission
var last_result := ""      # shown on the globe when the team comes back

## Host: everybody into the mission (same seed = same random map everywhere).
func start_mission(params := {}) -> bool:
	if not multiplayer.is_server():
		return false
	if params.has("cid"):
		var sick := sick_in_team()
		if not sick.is_empty():
			blocked.emit("Na marodce: %s.\nZraněný žoldák nemůže na misi, dokud neuplyne doba léčení (herní čas). Hráč si může vybrat jiného ze svých žoldáků v \"Můj žoldák\"." % ", ".join(sick))
			return false
	var s := Game.seed_override if Game.seed_override >= 0 else randi() % 1000000
	if params.has("seed") and Game.seed_override < 0:
		s = int(params["seed"])
	var diff: String = Campaign.difficulty() if Campaign.active and params.has("cid") else Game.difficulty
	_start.rpc(s, diff, params, Game.friendly_fire)
	return true

var friendly_fire := true
@rpc("authority", "call_local", "reliable")
func _start(s: int, diff := "normal", params := {}, ff := true) -> void:
	friendly_fire = ff
	mission_seed = s
	mission_difficulty = diff
	mission_params = params
	mission_started.emit()
	get_tree().change_scene_to_file("res://scenes/Mission.tscn")

## Host: everybody into the air fight (pilots fly, the rest watch from the host's wing).
func start_intercept(params: Dictionary) -> void:
	if multiplayer.is_server():
		_start_intercept.rpc(params)

@rpc("authority", "call_local", "reliable")
func _start_intercept(params: Dictionary) -> void:
	mission_params = params
	get_tree().change_scene_to_file("res://scenes/Intercept.tscn")

## Host: everybody into the escort fight (the transport was jumped on the way).
func start_escort(params: Dictionary) -> void:
	if multiplayer.is_server():
		_start_escort.rpc(params)

@rpc("authority", "call_local", "reliable")
func _start_escort(params: Dictionary) -> void:
	mission_params = params
	get_tree().change_scene_to_file("res://scenes/Escort.tscn")

## A co-op client: down into the base alone (own copy, offline branch) while the host is on the globe.
func start_local_base(params: Dictionary) -> void:
	mission_params = params.duplicate()
	mission_params["local"] = true
	mission_seed = randi() % 100000
	get_tree().change_scene_to_file("res://scenes/Mission.tscn")

func back_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

## After a mission: the campaign host returns to the globe (co-op stays
## connected), clients go back to the lobby, quick missions to the menu.
func after_mission() -> void:
	Game.end_skirmish()       # a quick mission's merc goes back in the drawer
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

# ---- team economy: personal money, gifts, buying for the host's base -----------------------
## Peer id -> money. The host's purse is the campaign treasury (or his own money in quick games).
var wallets := {}
signal wallets_changed
signal base_changed

func my_id() -> int:
	return multiplayer.get_unique_id() if is_online() else 1

func my_money() -> int:
	if multiplayer.is_server():
		return _host_purse()
	return int(Game.merc.get("money", 0))

## Everyone, the host too, has his own mercenary's money; the base has its own budget.
func _host_purse() -> int:
	return int(Game.merc.get("money", 0))

func _add_money(id: int, amount: int) -> void:
	if id == 1:
		Game.merc["money"] = int(Game.merc.get("money", 0)) + amount
		Game.save_merc()
	wallets[id] = int(wallets.get(id, 0)) + amount

## Put own money into the base budget (anyone, the host included).
func donate(amount: int) -> void:
	_req_donate.rpc_id(1, amount)

@rpc("any_peer", "call_local", "reliable")
func _req_donate(amount: int) -> void:
	if not multiplayer.is_server() or not Campaign.active:
		return
	var from := multiplayer.get_remote_sender_id()
	if from == 0:
		from = 1
	wallets[1] = _host_purse()
	if amount <= 0 or int(wallets.get(from, 0)) < amount:
		return
	_add_money(from, -amount)
	Campaign.data["credits"] = int(Campaign.data["credits"]) + amount
	Campaign.save()
	Campaign.changed.emit()
	_note.rpc("%s přispěl do rozpočtu základny %d kr." % [roster.get(from, {}).get("name", "?"), amount])
	broadcast_team()

## Host: refresh everybody's view of the purses (and of the base, if a campaign runs).
func broadcast_team() -> void:
	if not multiplayer.is_server() or not is_online():
		return
	wallets[1] = _host_purse()
	_wallets.rpc(wallets)
	if Campaign.active:
		_base_snapshot.rpc(Campaign.data)

@rpc("authority", "call_local", "reliable")
func _wallets(w: Dictionary) -> void:
	wallets = w
	var me := my_id()
	if not multiplayer.is_server() and wallets.has(me):
		Game.merc["money"] = int(wallets[me])
		Game.save_merc()
	wallets_changed.emit()

## Clients: a read-only copy of the host's campaign (globe, base, research, armory).
@rpc("authority", "reliable")
func _base_snapshot(d: Dictionary) -> void:
	Campaign.data = d
	Campaign.viewer = true
	if d.has("difficulty"):
		Game.difficulty = String(d["difficulty"])     # the host's campaign decides
	# days passed on the host's globe: our wounds heal - tell him when we are fit again
	var was := float(Game.merc.get("sick", 0.0))
	if was > 0.0 and Game.heal_days_left(Game.merc) <= 0.0:
		Game.save_merc()
		reregister()
	base_changed.emit()

func give_money(to: int, amount: int) -> void:
	_req_give.rpc_id(1, to, amount)

@rpc("any_peer", "call_local", "reliable")
func _req_give(to: int, amount: int) -> void:
	if not multiplayer.is_server():
		return
	var from := multiplayer.get_remote_sender_id()
	if from == 0:
		from = 1
	wallets[1] = _host_purse()
	if amount <= 0 or to == from or not roster.has(to) or int(wallets.get(from, 0)) < amount:
		return
	_add_money(from, -amount)
	_add_money(to, amount)
	_note.rpc("%s poslal %d kr hráči %s." % [roster.get(from, {}).get("name", "?"), amount, roster.get(to, {}).get("name", "?")])
	broadcast_team()

## A client buys for the host's base with his own money (only what the base can buy).
func buy_for_base(item: String) -> void:
	_req_buy.rpc_id(1, item)

@rpc("any_peer", "call_local", "reliable")
func _req_buy(item: String) -> void:
	if not multiplayer.is_server() or not Campaign.active or not Campaign.SHOP.has(item):
		return
	var from := multiplayer.get_remote_sender_id()
	if from == 0 or from == 1:
		Campaign.buy(item)
		broadcast_team()
		return
	var price: int = Campaign.price(item)
	if not Campaign.unlocked(item) or int(wallets.get(from, 0)) < price or Campaign.moskovium() < int(Campaign.SHOP_MK.get(item, 0)):
		return
	_add_money(from, -price)
	Campaign.data["moskovium"] = Campaign.moskovium() - int(Campaign.SHOP_MK.get(item, 0))
	Campaign.data["armory"][item] = int(Campaign.data["armory"].get(item, 0)) + 1
	Campaign.save()
	Campaign.changed.emit()
	_note.rpc("%s koupil pro základnu: %s." % [roster.get(from, {}).get("name", "?"), Game.ITEMS[item]["name"]])
	broadcast_team()

signal note(text: String)
@rpc("authority", "call_local", "reliable")
func _note(t: String) -> void:
	note.emit(t)

## The player picked another mercenary (or his wounds changed): the host gets the new one.
func reregister() -> void:
	Game.tick_injury(Game.merc)
	Game.merc["sick"] = Game.heal_days_left(Game.merc)
	if not is_online() or multiplayer.is_server():
		if roster.has(1) or not is_online():
			roster[1] = {"name": Game.merc["name"], "merc": Game.merc}
			if is_online():
				_set_roster.rpc(roster)
			roster_changed.emit()
	else:
		_register.rpc_id(1, Game.merc)

## Who cannot go: mercenaries still on the sick bay (game time).
func sick_in_team() -> Array:
	var out := []
	Game.merc["sick"] = Game.heal_days_left(Game.merc)
	for id in roster:
		var m: Dictionary = Game.merc if id == 1 else roster[id].get("merc", {})
		if float(m.get("sick", 0.0)) > 0.0:
			out.append(str(m.get("name", "?")))
	return out

## A client changed his mercenary (talent, looks): tell the host.
func update_merc() -> void:
	if is_online() and not multiplayer.is_server():
		_register.rpc_id(1, Game.merc)
