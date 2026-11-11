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
	# (0.61) only the same version of the game plays together: the players say their versions
	# before anything else goes over the line (see _auth)
	var sm := multiplayer as SceneMultiplayer
	sm.auth_callback = _auth
	sm.auth_timeout = 8.0
	sm.peer_authenticating.connect(_on_authenticating)
	sm.peer_authentication_failed.connect(_on_auth_failed)
	multiplayer.server_disconnected.connect(_on_server_gone)
	add_child(preload("res://scripts/lobby_voice.gd").new())
	var tm := Timer.new()
	tm.wait_time = 2.0
	tm.autostart = true
	tm.timeout.connect(func():
		_watch_link()
		var sc := get_tree().current_scene
		if multiplayer.is_server() and is_online() and Campaign.active and sc and sc.name != "Mission":
			broadcast_team())
	add_child(tm)
	var lt := Timer.new()
	lt.wait_time = 1.0
	lt.autostart = true
	lt.timeout.connect(_link_tick)
	add_child(lt)

## A client whose connection died without a word (a long load, a hiccup on the line): ENet stays
## "not connected" and every message fails - thousands of errors and a broken game. Notice it and
## go back to the menu properly.
func _watch_link() -> void:
	var peer := multiplayer.multiplayer_peer
	if peer is ENetMultiplayerPeer and not multiplayer.is_server() and not roster.is_empty():
		if peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
			_on_server_gone()
			back_to_menu()

## Long scene loads (building a map, the first shaders) must not cut a friend off: generous timeouts.
func _patient(peer: ENetMultiplayerPeer, id: int) -> void:
	var p := peer.get_peer(id)
	if p:
		p.set_timeout(64, 30000, 90000)

## The version check (0.61). Different versions of the game do not understand each other's
## messages (the calls are numbered by the scripts, the synced values listed by them): with
## a mismatch the host got thousands of broken packets and games fell. So before a peer counts as
## connected (no call, no sync yet), both say "EB <version>" and go on only if it is the same.
## An older host or client that does not know this says nothing: the wait runs out and the
## connection is closed with a word on why.
func _ver() -> String:
	return Game.cmd_arg("fakever", Game.VERSION_NUM) if Game.autotest() != "" else Game.VERSION_NUM     # (the test plays an other version)

func _on_authenticating(id: int) -> void:
	(multiplayer as SceneMultiplayer).send_auth(id, ("EB " + _ver()).to_utf8_buffer())

func _auth(id: int, data: PackedByteArray) -> void:
	var sm := multiplayer as SceneMultiplayer
	var said := data.get_string_from_utf8()
	var theirs := said.substr(3) if said.begins_with("EB ") else "?"
	if theirs == _ver():
		sm.complete_auth(id)
		return
	if multiplayer.is_server():
		_ver_refused[id] = true
		note.emit("Hráč s jinou verzí hry (%s) se nemohl připojit - ty máš %s." % [theirs, _ver()])
		if Game.autotest() != "": print("[NET] refused version %s (mine %s)" % [theirs, _ver()])
		# (a moment for it to read our version and say why itself)
		get_tree().create_timer(1.5).timeout.connect(func():
			if sm.get_authenticating_peers().has(id):
				sm.disconnect_peer(id))
	else:
		_version_why = "Hostitel má jinou verzi hry (%s), ty máš %s. Spolu hrát jde jen se stejnou verzí - aktualizujte hru oba na nejnovější." % [theirs, _ver()]
		_version_fail.call_deferred()

var _version_why := ""
var _ver_refused := {}       # host: peers already told off for their version (one note is enough)
func _on_auth_failed(id: int) -> void:
	if multiplayer.is_server():
		if _ver_refused.erase(id):
			return
		note.emit("Hráč se nepřipojil: nejspíš má starší verzi hry (ty máš %s)." % _ver())
		if Game.autotest() != "": print("[NET] peer %d gave no version (mine %s)" % [id, _ver()])
		return
	if _version_why == "":
		_version_why = "Hostitel neodpověděl na kontrolu verze - nejspíš má starší verzi hry (ty máš %s). Spolu hrát jde jen se stejnou verzí - aktualizujte hru oba na nejnovější." % _ver()
	_version_fail.call_deferred()

func _version_fail() -> void:
	if _version_why == "":
		return
	var why := _version_why
	_version_why = ""
	if Game.autotest() != "": print("[NET] version refused: %s" % why)
	close()
	var sc := get_tree().current_scene
	if sc == null or sc.name == "Main":
		connection_failed.emit(why)
	else:
		drop_reason = why
		back_to_menu()

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
	_kick_why = ""
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
	link = {}
	if Campaign.viewer:
		Campaign.viewer = false
		Campaign.data = {}

func _on_connected() -> void:
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		_patient(multiplayer.multiplayer_peer, 1)
	Game.merc["sick"] = Game.heal_days_left(Game.merc)
	_register.rpc_id(1, Game.merc)
	connected_ok.emit()

func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server() and multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		_patient(multiplayer.multiplayer_peer, id)
		# sent away a moment ago: not back in so soon
		var addr := _addr(id)
		if _banned.has(addr) and Time.get_ticks_msec() < int(_banned[addr]):
			_refused[id] = true
			var mins := ceili((int(_banned[addr]) - Time.get_ticks_msec()) / 60000.0)
			_kicked.rpc_id(id, "Hostitel tě před chvílí vyhodil. Znovu se připojit můžeš za %d min." % mins)
			_cut.call_deferred(id)

func _on_peer_disconnected(id: int) -> void:
	_refused.erase(id)
	link.erase(id)
	if multiplayer.is_server() and roster.has(id):
		_note.rpc("%s odešel ze hry." % roster[id]["name"])
	if roster.erase(id):
		roster_changed.emit()
		if multiplayer.is_server():
			_set_roster.rpc(roster)

func _on_server_gone() -> void:
	var why := _kick_why if _kick_why != "" else "Hostitel ukončil hru."
	_kick_why = ""
	close()
	var sc := get_tree().current_scene
	if sc == null or sc.name == "Main":
		connection_failed.emit(why)
	else:
		# on the host's globe or walking our base copy: back to the menu, which says why
		drop_reason = why
		back_to_menu()

@rpc("any_peer", "reliable")
func _register(merc: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if _refused.has(id):
		return
	var fresh := not roster.has(id)
	if Campaign.active:
		# the campaign's mercenaries are kept by the host: an older copy on the client is replaced
		var kept := Campaign.keep_merc(merc)
		if kept != merc:
			merc = kept
			_adopt_merc.rpc_id(id, merc)
	roster[id] = {"name": str(merc.get("name", "Voják")), "merc": merc}
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
	note.emit("Hostitel má v kampani novější záznam o vojákovi %s - používáš ten." % str(m.get("name", "?")))

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
			blocked.emit("Na marodce: %s.\nZraněný voják nemůže na misi, dokud neuplyne doba léčení (herní čas). Hráč si může vybrat jiného ze svých vojáků v \"Můj voják\"." % ", ".join(sick))
			return false
	var s := Game.seed_override if Game.seed_override >= 0 else randi() % 1000000
	if params.has("seed") and Game.seed_override < 0:
		s = int(params["seed"])
	var diff: String = Campaign.difficulty() if Campaign.active and params.has("cid") else Game.difficulty
	if Game.autotest() != "": print("[NET] start_mission -> _start.rpc to %s" % [multiplayer.get_peers()])
	_start.rpc(s, diff, params, Game.friendly_fire)
	return true

var friendly_fire := true
@rpc("authority", "call_local", "reliable")
func _start(s: int, diff := "normal", params := {}, ff := true) -> void:
	if Game.autotest() != "": print("[NET] _start received (server %s)" % multiplayer.is_server())
	friendly_fire = ff
	mission_seed = s
	mission_difficulty = diff
	mission_params = params
	var real := params.has("cid") and String(params.get("type", "")) != "home"
	if real and multiplayer.is_server() and Campaign.active:
		Campaign.mission_begun(int(params.get("id", -1)))
	if real and not Game.skirmish and Game.autotest() == "":
		Game.mission_out(true)      # (0.57) until the mission's end: a crash on the way counts as missing
	mission_started.emit()
	Game.load_scene("res://scenes/Mission.tscn")

## Host: everybody into the air fight (pilots fly, the rest watch from the host's wing).
func start_intercept(params: Dictionary) -> void:
	if multiplayer.is_server():
		_start_intercept.rpc(params)

@rpc("authority", "call_local", "reliable")
func _start_intercept(params: Dictionary) -> void:
	mission_params = params
	Game.load_scene("res://scenes/Intercept.tscn")

## Host: everybody into the escort fight (the transport was jumped on the way).
func start_escort(params: Dictionary) -> void:
	if multiplayer.is_server():
		_start_escort.rpc(params)

@rpc("authority", "call_local", "reliable")
func _start_escort(params: Dictionary) -> void:
	mission_params = params
	Game.load_scene("res://scenes/Escort.tscn")

## A co-op client: down into the base alone (own copy, offline branch) while the host is on the globe.
func start_local_base(params: Dictionary) -> void:
	mission_params = params.duplicate()
	mission_params["local"] = true
	mission_seed = randi() % 100000
	Game.load_scene("res://scenes/Mission.tscn")

func back_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

## After a mission: the campaign host returns to the globe (co-op stays
## connected), clients go back to the lobby, quick missions to the menu.
func after_mission() -> void:
	Game.end_skirmish()       # a quick mission's merc goes back in the drawer
	Game.camo = ""
	var campaign := not mission_params.is_empty()
	mission_params = {}
	if campaign and multiplayer.is_server() and Campaign.active:
		if not is_online():
			close()
		Game.load_scene("res://scenes/Geoscape.tscn")
	elif is_online() and not multiplayer.is_server():
		get_tree().change_scene_to_file("res://scenes/Main.tscn")
	else:
		close()
		if Game.autotest() == "":
			Game.open_screen = "quick"      # 0.66: back to the quick mission screen, one level up (not the main menu)
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

## Host on the globe: four times a second the moving parts (clock, UFOs, our crafts, reports)
## go to everybody, so their globe turns and the crafts fly as on the host's screen.
## (Lost packets do not matter - the next one is a quarter of a second away.)
var geo_speed := 0.0          # days per second on the host's globe (clients run the clock on)
func send_geo_live(spd: float) -> void:
	if not multiplayer.is_server() or not is_online() or not Campaign.active:
		return
	_geo_live.rpc({"day": Campaign.data["day"], "missions": Campaign.data["missions"], "flights": Campaign.data.get("flights", []),
		"crafts": Campaign.data.get("crafts", []), "speed": spd})

@rpc("authority", "unreliable_ordered")
func _geo_live(d: Dictionary) -> void:
	if not Campaign.viewer:
		return
	for k in ["day", "missions", "flights", "crafts"]:
		Campaign.data[k] = d[k]
	geo_speed = float(d.get("speed", 0.0))

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
	if not Campaign.unlocked(item) or Campaign.workshop_item(item) or int(wallets.get(from, 0)) < price:
		return
	_add_money(from, -price)
	Campaign.data["moskovium"] = Campaign.moskovium() - int(Campaign.SHOP_MK.get(item, 0))
	Campaign.order(item)
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
	elif is_online() and multiplayer.is_server() and roster.has(1):
		# (0.57) the host changed his own (parts on a gun): the campaign keeps it, the others see it
		roster[1] = {"name": Game.merc["name"], "merc": Game.merc}
		if Campaign.active:
			Campaign.keep_merc(Game.merc)
		_set_roster.rpc(roster)

# ---- (0.61) the lobby: everyone's ping and microphone, the host can send a player away -----
## peer -> {"ping": ms to the host, "mic": "off" | "ptt" | "open" | "dead"}. The host measures
## the pings and collects the microphones; everyone gets the table once a second.
var link := {}
var drop_reason := ""      # why the connection ended, for the menu after a scene change
const KICK_BAN_MS := 5 * 60 * 1000   # a kicked player may come back after five minutes
var _banned := {}          # host: address -> until (msec)
var _refused := {}         # host: peers being shown the door (their messages are ignored)
var _kick_why := ""        # client: the host said why he is cutting us off

func _addr(id: int) -> String:
	var p := multiplayer.multiplayer_peer
	if p is ENetMultiplayerPeer and (p as ENetMultiplayerPeer).get_peer(id):
		return (p as ENetMultiplayerPeer).get_peer(id).get_remote_address()
	return ""

## Round trip to the host in milliseconds (the host to a client, a client to the host); -1 = unknown.
func _rtt(id: int) -> int:
	var p := multiplayer.multiplayer_peer
	if not (p is ENetMultiplayerPeer):
		return -1
	var pp := (p as ENetMultiplayerPeer).get_peer(id)
	if pp == null or not pp.is_active():     # (just disconnected)
		return -1
	return int(pp.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))

## What the lobby shows by a player: his ping to the host (the host himself 0).
func ping_of(id: int) -> int:
	if id == 1:
		return 0
	if not multiplayer.is_server() and id == my_id():
		return _rtt(1)
	if multiplayer.is_server():
		return _rtt(id)
	return int(link.get(id, {}).get("ping", -1))

func mic_of(id: int) -> String:
	if id == my_id():
		return get_node("LobbyVoice").mic_state()
	return str(link.get(id, {}).get("mic", ""))

func _link_tick() -> void:
	if not is_online() or multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	var sc := get_tree().current_scene
	if sc and sc.name == "Mission":
		return      # the lobby table is not needed in a mission (keep the line for the game)
	var mine: String = get_node("LobbyVoice").mic_state()
	if multiplayer.is_server():
		for id in roster:
			if not link.has(id):
				link[id] = {}
			link[id]["ping"] = 0 if id == 1 else _rtt(id)
		link[1]["mic"] = mine
		for id in link.keys():
			if not roster.has(id):
				link.erase(id)
		_set_link.rpc(link)
	else:
		_mic_report.rpc_id(1, mine)

@rpc("any_peer", "unreliable_ordered")
func _mic_report(state: String) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not multiplayer.is_server() or not roster.has(id) or not state in ["off", "ptt", "open", "dead"]:
		return
	if not link.has(id):
		link[id] = {}
	link[id]["mic"] = state

@rpc("authority", "unreliable_ordered")
func _set_link(l: Dictionary) -> void:
	link = l

## The host sends a player away (from the lobby). He hears why and may come back in five minutes.
func kick(id: int) -> void:
	if not multiplayer.is_server() or not is_online() or id == 1 or not roster.has(id):
		return
	var who := str(roster[id]["name"])
	var addr := _addr(id)
	if addr != "":
		_banned[addr] = Time.get_ticks_msec() + KICK_BAN_MS
	_refused[id] = true
	_kicked.rpc_id(id, "Hostitel tě vyhodil ze hry.")
	roster.erase(id)
	wallets.erase(id)
	link.erase(id)
	_set_roster.rpc(roster)
	roster_changed.emit()
	_note.rpc("%s byl vyhozen ze hry." % who)
	_cut.call_deferred(id)

## Let the last word reach him first, then cut the line.
func _cut(id: int) -> void:
	await get_tree().create_timer(0.4).timeout
	var p := multiplayer.multiplayer_peer
	if p is ENetMultiplayerPeer and (p as ENetMultiplayerPeer).get_peer(id):
		(p as ENetMultiplayerPeer).disconnect_peer(id)

@rpc("authority", "reliable")
func _kicked(why: String) -> void:
	_kick_why = why
