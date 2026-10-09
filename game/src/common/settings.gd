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

## Sounds played on the "SFX" bus (battle) follow the effects setting.
static func apply_effects(audio: Dictionary) -> void:
	var bus := AudioServer.get_bus_index(&"SFX")
	if bus >= 0:
		AudioServer.set_bus_mute(bus, not bool(audio.get("sfx", true)))
		AudioServer.set_bus_volume_db(bus, float(audio.get("sfx_db", -8.0)))

static func save_audio(values: Dictionary, path := PATH) -> bool:
	return _store("audio", values, path)

## Window sizes offered as "interface size": the canvas is stretched, so a larger window
## makes every text and control proportionally larger. "fullscreen" uses the whole screen.
const DISPLAYS := ["1280x720", "1600x900", "1920x1080", "fullscreen"]

static func display(path := PATH) -> String:
	var saved: Variant = _read(path).get("display")
	return saved if saved is String and saved in DISPLAYS else DISPLAYS[0]

static func save_display(mode: String, path := PATH) -> bool:
	return mode in DISPLAYS and _store("display", mode, path)

## Resizes the game window; does nothing without a real window (headless runs).
static func apply_display(mode: String, window: Window) -> void:
	if DisplayServer.get_name() == "headless" or mode not in DISPLAYS:
		return
	if mode == "fullscreen":
		window.mode = Window.MODE_FULLSCREEN
		return
	window.mode = Window.MODE_WINDOWED
	var parts := mode.split("x")
	var wanted := Vector2i(int(parts[0]), int(parts[1]))
	var screen := DisplayServer.screen_get_usable_rect(window.current_screen)
	window.size = Vector2i(mini(wanted.x, screen.size.x), mini(wanted.y, screen.size.y))
	window.position = screen.position + (screen.size - window.size) / 2

## F11: full screen on, or back to the first window size. Returns the new mode.
static func toggle_fullscreen(window: Window, path := PATH) -> String:
	var mode: String = DISPLAYS[0] if display(path) == "fullscreen" else "fullscreen"
	save_display(mode, path)
	apply_display(mode, window)
	return mode

static func _read(path: String) -> Dictionary:
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	return saved if saved is Dictionary else {}

## Writes one section and keeps the others.
static func _store(section: String, value: Variant, path: String) -> bool:
	var all := _read(path)
	all[section] = value
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(all))
	return true
