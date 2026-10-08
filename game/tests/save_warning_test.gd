extends SceneTree
## A failed save is shown clearly: a red notice and, once per session, a dialog.
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
	map.save_path = "user://save_warning_test.json"
	map._save_game(true)
	check(map.save_notice.text == "Partida guardada." and not map.save_notice.has_theme_color_override("font_color"), "A later success clears the warning")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save_warning_test.json"))
	map.queue_free()
	await process_frame
	print("Save warning checks: %d, failures: %d" % [checks, failures])
	quit(1 if failures else 0)
