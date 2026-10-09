extends SceneTree
const Save = preload("res://src/save/save_game.gd")
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
	root.size = Vector2i(1280,720)
	var map = load("res://src/world/world_map.tscn").instantiate()
	map.save_path = "user://picker_auto_%d.json" % OS.get_process_id()
	map.slot_directory = "user://picker_slots_%d" % OS.get_process_id()
	root.add_child(map)
	await process_frame
	map._save_game(true)
	var original_auto := FileAccess.get_file_as_string(map.save_path)
	map.save_button.pressed.emit()
	await process_frame
	check(map.save_picker.visible and map.save_picker.saving, "Save button opens filename chooser")
	check(not map.save_picker.current_file.is_empty() and map.save_picker.current_file.ends_with(".save.json"), "Automatic name is proposed")
	var day: int = map.state.day
	map._end_turn()
	check(map.state.day == day, "Choosing a save does not advance the world")
	var first: String = map.slot_directory.path_join(map.save_picker.current_file)
	map.save_picker.get_ok_button().pressed.emit()
	check(Save.read_save(first).has("state"), "Automatic filename creates a checkpoint")
	check(FileAccess.get_file_as_string(map.save_path) == original_auto, "Named checkpoint does not replace autosave")
	map.state.end_turn()
	map.dialogue.histories.LOC11 = [{"player":"¿Quién eres?", "reply":"Soy el posadero.", "day":map.state.day}]
	map.save_button.pressed.emit()
	var second: String = map.slot_directory.path_join("Mi viaje español.save.json")
	map.save_picker.current_file = second.get_file()
	map.save_picker.file_selected.emit(second)
	check(Save.read_save(second).state.day == day + 1, "Custom Unicode filename saves selected state")
	check(FileAccess.file_exists(second.get_basename() + ".talks.json"), "Checkpoint keeps its own dialogue transcript")
	map.load_button.pressed.emit()
	check(map.save_picker.visible and not map.save_picker.saving and map.save_picker.load_autosave.visible, "Load button offers named saves and autosave")
	map.save_picker.current_file = first.get_file()
	map.save_picker.get_ok_button().pressed.emit()
	check(map.state.day == day, "Chosen earlier checkpoint loads")
	map.load_button.pressed.emit()
	map.save_picker.file_selected.emit(second)
	check(map.state.day == day + 1 and map.dialogue.histories.LOC11[0].player == "¿Quién eres?", "Another selected checkpoint restores its own dialogue")
	check(map.dialogue.talks_path == map.save_path.get_basename() + ".talks.json", "Future autosaves still use autosave transcript")
	var bad: String = map.slot_directory.path_join("Broken.save.json")
	var file := FileAccess.open(bad,FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	var kept = map.state
	map.load_button.pressed.emit()
	map.save_picker.file_selected.emit(bad)
	check(map.state == kept and not map.save_locked, "Invalid named save neither replaces state nor locks healthy autosave")
	check(not map.save_picker.accepts("user://outside.save.json"), "Picker cannot overwrite unrelated userdata")
	map.load_button.pressed.emit()
	map.save_picker.load_autosave.pressed.emit()
	check(map.state.day == day, "Autosave remains separately loadable")
	map.save_button.pressed.emit()
	var unchanged := FileAccess.get_file_as_string(first)
	map.save_picker.hide()
	map.save_picker.canceled.emit()
	check(FileAccess.get_file_as_string(first) == unchanged, "Cancel never changes a checkpoint")
	map.save_button.pressed.emit()
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		map.save_picker.get_texture().get_image().save_png("user://save-picker-preview.png")
	map.save_picker.hide()
	var folder: String = map.slot_directory
	var autosave: String = map.save_path
	map.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(filename))
	DirAccess.remove_absolute(folder)
	for path in [autosave, autosave.get_basename() + ".talks.json"]:
		DirAccess.remove_absolute(path)
	print("Save picker checks: %d, failures: %d" % [checks,failures])
	quit(1 if failures else 0)
