extends RefCounted
## Appends one JSON line per game event to user://logs/play.log so a live session can
## be read afterwards. Player text and replies are logged; keys and prompts never are.
## Headless runs (the test suites) write nothing.
const PATH := "user://logs/play.log"
const MAX_BYTES := 5000000

static func write(event: String, data: Dictionary = {}) -> void:
	if DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute("user://logs")
	if FileAccess.file_exists(PATH) and FileAccess.get_file_as_bytes(PATH).size() > MAX_BYTES:
		DirAccess.rename_absolute(PATH, PATH + ".old")
	var file := FileAccess.open(PATH, FileAccess.READ_WRITE) if FileAccess.file_exists(PATH) else FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	var line := {"time": Time.get_datetime_string_from_system(), "event": event}
	line.merge(data)
	file.store_line(JSON.stringify(line))
	file.close()
