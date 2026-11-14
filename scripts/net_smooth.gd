class_name NetSmooth
extends Node
## (0.70) Sync and smooth movement of what other machines own (players, aliens, civilians).
##
## Before: every synchronized property went out every rendered frame (144x a second at 144 FPS,
## ~150 packets and ~80 kB/s from the host to each client with 8 aliens). Over Radmin and similar
## VPNs this filled the line, and the first thing to suffer was the voice. Now:
##  - position, rotation (and a player's head pitch) go out RATE times a second, unreliably
##  - everything else (health, gear, states) only when it changes, reliably (delta sync)
## The remote copies would then step 30x a second; this node, a child of the actor, hides that: when a
## new position arrives, the visual body keeps where it was and slides to the new place within
## about one update (the collision and the logic stay exactly where the owner says). Big jumps
## (teleport, respawn, > SNAP m) are not smoothed.

const RATE := 30.0
const DELTA_RATE := 20.0
const SNAP := 4.0
const FOLLOW := 22.0          # 1/s: how fast the picture catches up

var actor: Node3D
var body: Node3D
var vertical := false         # players: smooth the height too (aliens/civilians move their body's y themselves)
var yaw := true
var _off := Vector3.ZERO      # world-space offset of the picture from the real place
var _off_yaw := 0.0
var _last_pos := Vector3.ZERO
var _last_yaw := 0.0
var _base := Vector3.ZERO
var _base_yaw := 0.0
var _on := false

## Sets the sync rates on a synchronizer and the modes: `always` = continuous, the rest on change.
static func setup(sync: MultiplayerSynchronizer, cfg: SceneReplicationConfig, always: Array) -> void:
	if Game.cmd_arg("oldsync", "") != "":
		return            # (A/B tests: as before 0.70)
	for p in cfg.get_properties():
		var name := String(p).trim_prefix(".").trim_prefix(":")
		var cont := name in always
		cfg.property_set_replication_mode(p, SceneReplicationConfig.REPLICATION_MODE_ALWAYS if cont else SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	sync.replication_interval = 1.0 / RATE
	sync.delta_interval = 1.0 / DELTA_RATE

## Adds the smoothing to an actor (it acts only where this machine is not the owner).
static func attach(a: Node3D, sync: MultiplayerSynchronizer, b: Node3D, smooth_y: bool, smooth_yaw: bool = true) -> Node:
	var n := new()
	n.name = "NetSmooth"
	n.actor = a
	n.body = b
	n.vertical = smooth_y
	n.yaw = smooth_yaw
	a.add_child(n)
	sync.synchronized.connect(n._arrived)
	return n

func _ready() -> void:
	_last_pos = actor.position
	_last_yaw = actor.rotation.y
	_base = body.position
	_base_yaw = body.rotation.y

func _arrived() -> void:
	if actor.is_multiplayer_authority() or Game.cmd_arg("nosmooth", "") != "":
		_last_pos = actor.position
		_last_yaw = actor.rotation.y
		return
	var jump := _last_pos - actor.position
	if jump.length() > SNAP:
		_off = Vector3.ZERO
		_off_yaw = 0.0
	else:
		_off += jump
		_off_yaw = wrapf(_off_yaw + wrapf(_last_yaw - actor.rotation.y, -PI, PI), -PI, PI)
	if not vertical:
		_off.y = 0.0
	_last_pos = actor.position
	_last_yaw = actor.rotation.y
	_on = true

func _process(delta: float) -> void:
	if not _on or not is_instance_valid(body):
		return
	if bool(actor.get("dead")):
		_off = Vector3.ZERO
		_off_yaw = 0.0
	# the owner may also move it between updates (e.g. a host-side push): keep the base fresh
	var k := 1.0 - exp(-FOLLOW * delta)
	_off = _off.lerp(Vector3.ZERO, k)
	_off_yaw = lerpf(_off_yaw, 0.0, k)
	var local := actor.global_transform.basis.orthonormalized().inverse() * _off
	body.position.x = _base.x + local.x
	body.position.z = _base.z + local.z
	if vertical:
		body.position.y = _base.y + local.y
	if yaw:
		body.rotation.y = _base_yaw + _off_yaw
	if _off.length_squared() < 0.000001 and absf(_off_yaw) < 0.0005:
		_off = Vector3.ZERO
		_off_yaw = 0.0
		body.position.x = _base.x
		body.position.z = _base.z
		if vertical:
			body.position.y = _base.y
		if yaw:
			body.rotation.y = _base_yaw
		_on = false
