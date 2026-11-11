extends Node
## 0.70 Facelift II: the echo of the place you stand in. Every sound of the mission's world (Game.play_at,
## play_cut: shots, steps, the aliens) goes through the bus "Room" (-> SFX), whose reverb follows the
## listener: rays from the camera feel the ceiling and the walls - a narrow corridor, a big hangar,
## the metal inside of a UFO, a street between houses (a late, thin echo), the open field (almost dry).
## Only an effect on the sounds the game already has (Ari: no generated sounds). The menus, the radio,
## the music and the voices stay dry. Each machine for its own ears - nothing goes over the net.

const BUS := "Room"
const TICK := 0.25
const REACH := 40.0
var _t := 0.0
var _fx: AudioEffectReverb
var kind := "open"           # what it hears now: open / street / room / hall / metal (autotest reads it)
var target := {}             # the reverb it is heading for
var probe := []              # last feel: [up, walls hit, mean, cam pos] (autotest)
var _metal := false          # base, UFO, alien base: hard walls ring longer

## The bus with its reverb (made once; a dry pass-through when no mission listens).
static func ensure_bus() -> AudioEffectReverb:
	var i := AudioServer.get_bus_index(BUS)
	if i < 0:
		AudioServer.add_bus()
		i = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, BUS)
		AudioServer.set_bus_send(i, "SFX")
		var rv := AudioEffectReverb.new()
		rv.dry = 1.0
		rv.wet = 0.0
		rv.room_size = 0.3
		rv.damping = 0.6
		rv.spread = 0.8
		rv.hipass = 0.15
		AudioServer.add_bus_effect(i, rv)
	return AudioServer.get_bus_effect(i, 0) as AudioEffectReverb

## Which bus a sound in the world goes to.
static func bus() -> String:
	return BUS if AudioServer.get_bus_index(BUS) >= 0 else "SFX"

func _ready() -> void:
	name = "RoomEcho"
	_fx = ensure_bus()
	var mt := String(Net.mission_params.get("type", ""))
	_metal = mt in ["base", "home", "alienbase"]
	_feel()
	for k in target:
		_fx.set(k, target[k])

func _exit_tree() -> void:
	if _fx:
		_fx.wet = 0.0          # (the globe, the menus: dry)
		_fx.dry = 1.0

func _process(delta: float) -> void:
	_t -= delta
	if _t <= 0.0:
		_t = TICK
		_feel()
	# glide towards it (no jump when stepping through a door)
	var k := clampf(delta * 3.0, 0.0, 1.0)
	for p in target:
		_fx.set(p, lerpf(float(_fx.get(p)), float(target[p]), k))

## Rays from the ears: up to the ceiling, eight round at head height. -> kind + target.
func _feel() -> void:
	var cam := get_viewport().get_camera_3d() if get_viewport() else null
	if cam == null or not cam.is_inside_tree():
		return
	var ss := cam.get_world_3d().direct_space_state
	var at := cam.global_position
	var up := _ray(ss, at, at + Vector3.UP * 25.0)
	var hits := 0
	var sum := 0.0
	for i in 8:
		var a := TAU * i / 8.0
		var d := _ray(ss, at, at + Vector3(cos(a), 0, sin(a)) * REACH)
		if d < REACH * 0.75:
			hits += 1
		sum += d
	var mean := sum / 8.0
	probe = [up, hits, mean, at]
	# under the hull of the UFO (the saucer is round its centre; a big ship's rooms are listed in ufo_inside)
	var inside_ufo := false
	var m := get_parent()
	var mp: Dictionary = m.get("map") if m and m.get("map") is Dictionary else {}
	if mp.has("ufo") and (mp["ufo"] as Vector3) != Vector3.ZERO:
		var u: Vector3 = mp["ufo"]
		inside_ufo = Vector2(at.x - u.x, at.z - u.z).length() < 9.0 and at.y - u.y < 6.0 and hits >= 6
		for q in mp.get("ufo_inside", []):
			if (q as Vector3).distance_to(at) < 7.0:
				inside_ufo = true
	# a roof and walls round (many ceilings are only drawn, not solid: walls close all round count too)
	var shut := (up < 25.0 and hits >= 6) or (hits >= 7 and mean < 9.0) or (inside_ufo and hits >= 7)
	if shut:
		# the size of it is the length of the echo
		var h := up if up < 25.0 else 3.5
		var size := clampf(((mean + h) * 0.5 - 1.5) / 12.0, 0.0, 1.0)
		var hard := _metal or inside_ufo
		kind = "metal" if hard else ("hall" if size > 0.55 else "room")
		target = {"room_size": 0.3 + 0.6 * size, "wet": (0.2 if hard else 0.15) + 0.16 * size, "dry": 0.92,
			"damping": 0.25 if hard else 0.55, "predelay_msec": 6.0 + 30.0 * size, "predelay_feedback": 0.15 if hard else 0.05}
	elif (hits >= 5 and mean < 20.0) or (hits >= 3 and mean < 14.0):
		# walls round but the sky over: a street, a yard - a late thin echo off the houses
		kind = "street"
		target = {"room_size": 0.55, "wet": 0.06 + 0.02 * hits / 8.0, "dry": 1.0, "damping": 0.7,
			"predelay_msec": clampf(mean * 2.0 / 0.343, 40.0, 140.0), "predelay_feedback": 0.25}
	else:
		kind = "open"
		target = {"room_size": 0.25, "wet": 0.025, "dry": 1.0, "damping": 0.85, "predelay_msec": 80.0, "predelay_feedback": 0.1}

func _ray(ss: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(a, b, Game.WORLD | Game.GLASS)
	var r := ss.intersect_ray(q)
	return a.distance_to(r["position"]) if not r.is_empty() else a.distance_to(b)
