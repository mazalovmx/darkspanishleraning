extends RefCounted
## Player settings kept outside the project (res:// is read-only in an export).
const PATH := "user://settings.json"

## The audio settings of config/game.json, overridden by the player's saved choices.
static func audio(config: Dictionary, path := PATH) -> Dictionary:
	var result: Dictionary = config.get("audio", {}).duplicate()
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	if saved is Dictionary and saved.get("audio") is Dictionary:
		for key in ["music", "sfx"]:
			if saved.audio.get(key) is bool:
				result[key] = saved.audio[key]
		for key in ["music_db", "sfx_db"]:
			var value: Variant = saved.audio.get(key)
			if (value is float or value is int) and is_finite(value):
				result[key] = clampf(float(value), -40.0, 0.0)
	return result

static func save_audio(values: Dictionary, path := PATH) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"audio": values}))
	return true
