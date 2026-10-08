extends "res://tests/ghost_state_test.gd"
func run() -> void:
	root.size = Vector2i(1280,720)
	var map = load("res://src/world/province_map.tscn").instantiate()
	map.save_path = "user://ghost_scene_%d.json" % OS.get_process_id()
	root.add_child(map)
	await process_frame
	var state = map.state
	learn(state)
	for index in 8:
		finish_case(state,state.side_cases.branches.SB01.quest_ids[index])
	# Fresh opposition isolates the telegraphed-order UI from earlier case days.
	state.ghosts = Ghosts.new()
	map.ghost_button.pressed.emit()
	var panel = map.ghost_panel
	check(panel.visible,"Knight controls open from map")
	var day: int = state.day
	map._end_turn()
	map.side_button.pressed.emit()
	check(state.day == day and not map.side_panel.visible,"Knight panel blocks day and overlapping case panel")
	panel.prepare_button.pressed.emit()
	check(state.ghosts.plan != null and panel.prepare_button.disabled,"Prepare freezes orders once")
	var selected := false
	for index in panel.entries.item_count:
		if panel.entries.get_item_metadata(index) == "NK01":
			panel.entries.select(index)
			panel.entries.item_selected.emit(index)
			selected = true
	check(selected and not panel.target.is_empty(),"Visible knight exposes its intervention target")
	check(panel.first.item_count > 0 and panel.prompt.text.contains("Práctica guiada"),"Counter offers actual inspected evidence and Spanish support")
	panel.input.text = "Mi fuerza demuestra la verdad."
	panel.send_button.pressed.emit()
	check("NK01" not in state.ghosts.countered,"Unsupported Spanish cannot cancel order")
	panel.input.text = state.ghosts.counter_model(state,"NK01",panel.first.get_selected_metadata())
	panel.send_button.pressed.emit()
	check("NK01" in state.ghosts.countered,"Typed evidence-backed counter interrupts order")
	var saved := Save.read_save(map.save_path)
	check(saved.has("state") and "NK01" in saved.state.ghosts.countered,"Counter autosaves proof and interrupted order")
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://ghost-counter-preview.png")
	panel.close()
	check(not map.end_button.disabled,"Close returns turn control")
	map._end_turn()
	check(state.day == day+1,"Map resolves countered turn")
	check(not state.ghosts.effects.has("SB01") or state.ghosts.effects.SB01.knight != "NK01","Interrupted intervention does not return")
	var path: String = map.save_path
	map.queue_free()
	await process_frame
	DirAccess.remove_absolute(path)
	print("Ghost scene checks: %d, failures: %d" % [checks,failures])
	quit(1 if failures else 0)