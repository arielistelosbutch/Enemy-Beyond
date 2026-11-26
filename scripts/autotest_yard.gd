extends RefCounted
## yardtest (2026-11-26, Ari: „dřevo u schodů“ – hromada dřeva s přístřeškem stála v patrovém domě
## u schodů): mapa posouvá volné věci, které se srazí se zdí (map_gen._untangle). Dřív mohla věc
## z dvora skončit uvnitř domu (místnost nemá na zemi nic, do čeho by narazila).
## Test projde všechny posunuté věci: když stála venku (nad ní nic), musí zůstat venku.
## Navíc hlásí hromady dřeva, které musela mapa posunout (= stojí na místě, kde zasahují do domu).
## Výsledek: RESULT yardtest moved N, indoors I, woodpiles W moved_wood M

static var why := ""
static func _covered(space: PhysicsDirectSpaceState3D, p: Vector3, skip: Array, own: Node = null) -> bool:
	# a roof or a ceiling over the spot (2.2 m and higher above the ground; the thing itself does not count)
	for off in [Vector3.ZERO, Vector3(0.4, 0, 0), Vector3(-0.4, 0, 0), Vector3(0, 0, 0.4), Vector3(0, 0, -0.4)]:
		var rq := PhysicsRayQueryParameters3D.create(p + off + Vector3(0, 25, 0), p + off + Vector3(0, 2.2, 0), Game.WORLD)
		rq.exclude = skip.duplicate()
		var h := space.intersect_ray(rq)
		while not h.is_empty() and own != null and (own == h.collider or own.is_ancestor_of(h.collider)):
			rq.exclude = rq.exclude + [h.rid]
			h = space.intersect_ray(rq)
		if h.is_empty():
			return false
		why = "%s y %.1f" % [str((h.collider as Node).get_path()).right(60), (h.position as Vector3).y]
	return true

static func run(at: Node, p: Node) -> void:
	if p == null: return
	at._skip_brief()
	if at.step > 0 or not at.m().started(): return
	at.step = 1
	p.hp = 1.0e6
	await at.get_tree().create_timer(0.5).timeout
	var space: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	var skip := [p.get_rid()]
	var moves: Array = at.m().map.get("untangle_moves", [])
	var indoors := 0
	var wood_moved := 0
	for mv in moves:
		var nm: String = mv[0]
		var home: Vector3 = mv[1]
		var now: Vector3 = mv[2]
		var own: Node = mv[3] if mv.size() > 3 and is_instance_valid(mv[3]) else null
		if nm.contains("woodpile"):
			wood_moved += 1
		if not _covered(space, home, skip, own) and _covered(space, now, skip, own):
			indoors += 1
			at.out("[YARD] %s z venku dovnitř: %s -> %s (%s)" % [nm, str(home), str(now), why])
	var woods := 0
	for n in at.m().find_children("v_woodpile*", "Node3D", true, false):
		woods += 1
		if _covered(space, (n as Node3D).global_position, skip, n):
			indoors += 1
			at.out("[YARD] dřevo pod střechou: %s" % str((n as Node3D).global_position))
	for mv in moves:
		if String(mv[0]).contains("woodpile"):
			at.out("[YARD] dřevo posunuto %s -> %s" % [str(mv[1]), str(mv[2])])
	at.out("RESULT yardtest moved %d, indoors %d, woodpiles %d moved_wood %d" % [moves.size(), indoors, woods, wood_moved])
	at.get_tree().quit()
