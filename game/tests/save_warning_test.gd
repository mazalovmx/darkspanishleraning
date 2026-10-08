extends SceneTree
## A failed save is shown clearly: a red notice and, once per session, a dialog.
## It never ends the session on its own (menu, new game).
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
	root.size = Vector2i(1280, 720)
	var map = load("res://src/world/province_map.tscn").instantiate()
	# A path inside a folder that does not exist cannot be written.
	map.save_path = "user://missing_folder_for_save_warning/deeper/save.json"
	root.add_child(map)
	await process_frame
	map._save_game(true)
	check(map.save_notice.text.begins_with("No se pudo guardar"), "Failure named in the notice")
	check(map.save_notice.has_theme_color_override("font_color"), "Failure notice is highlighted")
	check(map.save_failed.visible and map.save_failure_warned, "A dialog explains the failed save")
	map.save_failed.hide()
	map._save_game(true)
	check(not map.save_failed.visible, "The dialog is shown only once per session")
	# Returning to the menu after a failed save keeps the session and asks first.
	map.state.day = 4
	map.menu_button.pressed.emit()
	await process_frame
	check(map.is_inside_tree() and map.state.day == 4, "A failed save keeps the game open")
	check(map.leave_unsaved.visible, "Leaving without a save needs the player's choice")
	map.leave_unsaved.hide()
	map.save_path = "user://save_warning_test.json"
	map._save_game(true)
	check(map.save_notice.text == "Partida guardada." and not map.save_notice.has_theme_color_override("font_color"), "A later success clears the warning")
	check(map._save_game(true), "A written save reports success")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save_warning_test.json"))
	# A new game needs the copy of the old save first; without it the old game stays.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://save_warning_new/blocked.json.bak"))
	map.save_path = "user://save_warning_new/blocked.json"
	map._save_game(true)
	map.state.day = 6
	map._new_game()
	check(map.state.day == 6 and map.save_notice.text.contains("no se empezó"), "No copy of the old save, no new game")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save_warning_new/blocked.json.bak"))
	map._new_game()
	check(map.state.day == 1 and FileAccess.file_exists("user://save_warning_new/blocked.json.bak"), "With the copy the new game starts")
	for leftover in ["blocked.json", "blocked.json.bak"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save_warning_new/" + leftover))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save_warning_new"))
	map.queue_free()
	await process_frame
	print("Save warning checks: %d, failures: %d" % [checks, failures])
	quit(1 if failures else 0)
