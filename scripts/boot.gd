extends Node
## The first autoload. If the game has downloaded an update (a resource pack from
## GitHub), it is mounted here - before any other game script is loaded, so the
## new scripts, models and texts replace the ones inside the .exe.
## (Project settings and the list of autoloads come from the .exe; a change to
## those needs a new full download.)

const UPDATE_PCK := "user://update.pck"
const UPDATE_INFO := "user://update.json"
## The version built into this .exe (the update must be newer to be used).
const BUILD_VERSION := "0.25"

var update_version := ""

func _init() -> void:
	if OS.has_feature("editor"):
		return
	if not FileAccess.file_exists(UPDATE_PCK) or not FileAccess.file_exists(UPDATE_INFO):
		return
	var info = JSON.parse_string(FileAccess.get_file_as_string(UPDATE_INFO))
	if typeof(info) != TYPE_DICTIONARY:
		return
	var v := String(info.get("version", ""))
	if newer(v, BUILD_VERSION) and ProjectSettings.load_resource_pack(UPDATE_PCK, true):
		update_version = v

## "0.13" > "0.12.1"? (numbers compared part by part)
static func newer(a: String, b: String) -> bool:
	var pa := a.split(".")
	var pb := b.split(".")
	for i in maxi(pa.size(), pb.size()):
		var x := int(pa[i]) if i < pa.size() else 0
		var y := int(pb[i]) if i < pb.size() else 0
		if x != y:
			return x > y
	return false
