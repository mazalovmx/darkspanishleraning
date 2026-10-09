extends SceneTree
## Title screen and player settings; never touches the player's real files.
const Settings = preload("res://src/common/settings.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	var settings_path := "user://settings_test_%d.json" % OS.get_process_id()
	var save_path := "user://title_save_test_%d.json" % OS.get_process_id()
	check(ProjectSettings.get_setting("application/run/main_scene") == "res://src/ui/title_menu.tscn", "The game starts on the title screen")
	var menu = load("res://src/ui/title_menu.tscn").instantiate()
	menu.save_path = save_path
	menu.settings_path = settings_path
	root.add_child(menu)
	await process_frame
	check(not menu.continue_button.visible and menu.new_button.visible and menu.settings_button.visible and menu.quit_button.visible, "Without a save there is nothing to continue")
	menu.settings_button.pressed.emit()
	check(menu.settings_panel.visible, "Settings open from the title screen")
	# Interface size: a window size or full screen, kept beside the audio settings.
	check(Settings.display(settings_path) == "1280x720" and menu.display_choice.item_count == 4 and menu.display_choice.get_selected_metadata() == "1280x720", "Interface size starts at the base window and offers four choices")
	menu.display_choice.select(3)
	menu.display_choice.item_selected.emit(3)
	check(Settings.display(settings_path) == "fullscreen", "The chosen interface size is saved")
	menu.music_slider.value = -20.0
	check(Settings.display(settings_path) == "fullscreen" and is_equal_approx(Settings.audio({}, settings_path).music_db, -20.0), "Saving the sound keeps the interface size, and the reverse")
	check(not Settings.save_display("9999x1", settings_path) and Settings.display(settings_path) == "fullscreen", "An unknown size is refused")
	check(Settings.toggle_fullscreen(root, settings_path) == "1280x720" and Settings.toggle_fullscreen(root, settings_path) == "fullscreen", "F11 switches between full screen and the base window")
	Settings.save_display("1280x720", settings_path)
	menu.music_slider.value = -30.0
	menu.sfx_toggle.button_pressed = false
	var audio: Dictionary = Settings.audio({"audio": {"music": true, "music_db": -16.0, "sfx": true, "sfx_db": -8.0}}, settings_path)
	check(is_equal_approx(float(audio.music_db), -30.0) and audio.sfx == false and audio.music == true, "Settings are saved and override the defaults")
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"SFX")), "Disabled sounds mute the battle bus")
	menu.sfx_toggle.button_pressed = true
	menu.sfx_slider.value = -20.0
	check(not AudioServer.is_bus_mute(AudioServer.get_bus_index(&"SFX")) and is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"SFX")), -20.0), "The battle bus follows the sound volume")
	menu.sfx_toggle.button_pressed = false
	var file := FileAccess.open(settings_path, FileAccess.WRITE)
	file.store_string("{\"audio\": {\"music_db\": 99, \"sfx\": \"loud\"}}")
	file = null
	audio = Settings.audio({"audio": {"sfx": true, "music_db": -16.0}}, settings_path)
	check(is_equal_approx(float(audio.music_db), 0.0) and audio.sfx == true, "Out-of-range or malformed settings are clamped or ignored")
	menu.queue_free()
	file = FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string("{}")
	file = null
	var again = load("res://src/ui/title_menu.tscn").instantiate()
	again.save_path = save_path
	again.settings_path = settings_path
	root.add_child(again)
	await process_frame
	check(again.continue_button.visible, "With a save the player can continue")
	again.queue_free()
	await process_frame
	var map = load("res://src/world/province_map.tscn").instantiate()
	map.persistence_enabled = false
	root.add_child(map)
	await process_frame
	check(map.menu_button.visible and map.menu_button.text == "Menú principal", "The map offers a way back to the title screen")
	map.queue_free()
	await process_frame
	DirAccess.remove_absolute(settings_path)
	DirAccess.remove_absolute(save_path)
	print("Title menu checks: %d, failures: %d" % [checks, failures])
	quit(1 if failures else 0)
