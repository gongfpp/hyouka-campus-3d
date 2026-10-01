extends RefCounted
# Privacy-first local events only. No network requests, identity, device IDs or positions.
const PATH := "user://events.json"
var events: Array = []
func record(kind: String, context: Dictionary = {}) -> void:
	events.append({"event": kind, "context": context, "session_seconds": Time.get_ticks_msec() / 1000})
	if events.size() > 200:
		events.pop_front()
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(events))
func clear() -> void:
	events.clear()
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file:
		file.store_string("[]")
