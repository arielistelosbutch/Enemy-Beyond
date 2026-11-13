extends SceneTree
## Download test: serve a big file on 127.0.0.1:8765/big.pck, then
## godot --headless --path . -s tools/test/updtest.gd
var worst := 0.0
var last := 0
var t0 := 0
var prints := 0
func _initialize() -> void:
	await process_frame
	var g = root.get_node("Game")
	t0 = Time.get_ticks_msec()
	last = Time.get_ticks_usec()
	var body := JSON.stringify({"version": "9.99", "min_build": "0", "pck": "http://127.0.0.1:8765/big.pck"}).to_utf8_buffer()
	g._on_version_info(0, 200, PackedStringArray(), body)
	g.update_changed.connect(func():
		prints += 1
		if prints % 8 == 0 or g.upd_state != "downloading":
			var mb: Vector2 = g.update_mb()
			print("[UPD] %s %d %% %.1f/%.1f MB worst frame %.1f ms" % [g.upd_state, int(g.update_progress() * 100), mb.x, mb.y, worst]))
func _process(_d: float) -> bool:
	var now := Time.get_ticks_usec()
	if Time.get_ticks_msec() - t0 > 1500:
		worst = maxf(worst, (now - last) / 1000.0)
		if (now - last) > 20000: print("[UPD] slow frame %.1f ms at %.1f s state %s" % [(now - last) / 1000.0, (Time.get_ticks_msec() - t0) / 1000.0, root.get_node("Game").upd_state])
	last = now
	var g = root.get_node("Game")
	if g.upd_state in ["ready", "error"]:
		print("[UPD] done %s %s in %.1f s, updates %d, worst frame %.1f ms" % [g.upd_state, g.upd_error, (Time.get_ticks_msec() - t0) / 1000.0, prints, worst])
		return true
	return false
