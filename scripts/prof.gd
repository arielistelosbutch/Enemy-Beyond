extends RefCounted
static var acc := {}
static var cnt := {}
static func add(k: String, t0: int) -> void:
	acc[k] = int(acc.get(k, 0)) + Time.get_ticks_usec() - t0
	cnt[k] = int(cnt.get(k, 0)) + 1
static func report(secs: float) -> String:
	var ks := acc.keys()
	ks.sort_custom(func(a, b): return acc[a] > acc[b])
	var s := ""
	for k in ks:
		s += "\n   %-22s %7.2f ms/s  (%d volání/s)" % [k, acc[k] / 1000.0 / secs, int(cnt[k] / secs)]
	return s
static func reset() -> void:
	acc.clear(); cnt.clear()
