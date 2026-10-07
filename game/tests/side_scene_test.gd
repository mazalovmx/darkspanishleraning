extends "res://tests/campaign_test.gd"
var map: Node
func choose(id: String) -> void:
	var panel = map.side_panel
	for i in panel.entries.item_count:
		if panel.entries.get_item_metadata(i) == id:
			panel.entries.select(i)
			panel.entries.item_selected.emit(i)
			return
	check(false,"Missing available case: " + id)
func choose_option(control: OptionButton,id: String) -> void:
	for i in control.item_count:
		if control.get_item_metadata(i) == id:
			control.select(i)
			control.item_selected.emit(i)
			return
	check(false,"Missing interpretation: " + id)
func answer(message: String) -> void:
	map.side_panel.input.text = message
	map.side_panel.send_button.pressed.emit()
func clear_with_ui(id: String) -> void:
	var state = map.state
	var knight: String = state.ghosts.blocked(state,id)
	if knight.is_empty():
		return
	map.side_panel.close()
	map.ghost_button.pressed.emit()
	var counters = map.ghost_panel
	for option in counters.entries.item_count:
		if counters.entries.get_item_metadata(option) == knight:
			counters.entries.select(option)
			counters.entries.item_selected.emit(option)
	counters.input.text = state.ghosts.counter_model(state,knight,counters.first.get_selected_metadata())
	counters.send_button.pressed.emit()
	check(state.ghosts.blocked(state,id).is_empty(),"Real UI counter removes case-stage obstruction")
	counters.close()

func run() -> void:
	root.size = Vector2i(1280,720)
	map = load("res://src/world/province_map.tscn").instantiate()
	map.save_path = "user://side_scene_%d.json" % OS.get_process_id()
	root.add_child(map)
	await process_frame
	var state = map.state
	var cases = state.side_cases
	var panel = map.side_panel
	map.side_button.pressed.emit()
	check(panel.visible and not panel.send_button.visible,"Unpractised case displays its lesson gate")
	panel.close()
	learn(state)
	map.side_button.pressed.emit()
	choose("SX001")
	var day: int = state.day
	map._end_turn()
	map.equipment_button.pressed.emit()
	check(state.day == day and not map.equipment_panel.visible,"Case work blocks world turn and other panels")
	panel.battle_button.pressed.emit()
	check(map.arena.visible and not panel.visible,"Case launches real battle arena")
	var steps := 0
	while state.active_battle.outcome.is_empty() and steps < 200:
		var target := -1
		for i in state.active_battle.stacks.size():
			if state.active_battle.stacks[i].side == 1 and state.active_battle.count_at(i) > 0:
				target = i
				break
		state.active_battle.act("attack",target)
		steps += 1
	map.arena.refresh()
	map.arena.finish_button.pressed.emit()
	check(panel.visible and not panel.battle_button.visible and cases.records.is_empty(),"Victory returns to custody request, not a solved case")
	for number in range(1,10):
		var id := "SX%03d" % number
		clear_with_ui(id)
		if not panel.visible:
			map.side_button.pressed.emit()
		choose(id)
		var node: Dictionary = cases.quests[id]
		var models: Dictionary = cases.models(id)
		if node.has("access_puzzle"):
			panel.cipher.text = "incorrecto"
			answer(models.access)
			check(cases.stage(id) == "access","Acrostic blocks premature access through UI")
			panel.cipher.text = node.access_puzzle.answer
			if DisplayServer.get_name() != "headless":
				await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("C:/dev/game/tools/local/side-acrostic-preview.png")
		answer(models.access)
		check(cases.stage(id) == "inspect","Spanish request recorded through UI: " + id)
		panel.send_button.pressed.emit()
		check(cases.stage(id) == "puzzle","Inspection reveals comparison")
		choose_option(panel.choice,"overreach")
		choose_option(panel.rejected,"supported")
		panel.send_button.pressed.emit()
		check(cases.stage(id) == "puzzle","Wrong interpretation preserves retry")
		choose_option(panel.choice,"supported")
		choose_option(panel.rejected,"overreach")
		panel.send_button.pressed.emit()
		answer(models.supported)
		check(cases.stage(id) == "independent","Guided phrase leads to changed structure")
		answer(models.supported)
		check(cases.stage(id) == "independent","Copy does not complete changed structure")
		answer(models.independent)
		check(panel.send_button.disabled,"Recall waits for later world day")
		panel.close()
		map._end_turn()
		clear_with_ui(id)
		map.side_button.pressed.emit()
		choose(id)
		check(not panel.prompt.text.contains(models.supported),"Recall hides the practised model")
		answer(models.supported)
		if not node.final_choice.is_empty():
			clear_with_ui(id)
			if not panel.visible:
				map.side_button.pressed.emit()
				choose(id)
			choose_option(panel.choice,node.final_choice[1])
			answer(cases.choice_model(node.final_choice[1]))
		check(cases.complete(id,cases.records),"Case completed through panel")
		check(Save.read_save(map.save_path).state.side_cases.complete(id,Save.read_save(map.save_path).state.side_cases.records),"Every completed case autosaves")
	check(state.equipment.instances.size() == 2,"First branch grants its two bound soul components")
	check(panel.body.text.contains("datos privados"),"Final protected-copy consequence visible")
	check(Rect2(Vector2.ZERO,root.size).encloses(panel.close_button.get_global_rect()),"Case controls fit viewport")
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/dev/game/tools/local/side-case-preview.png")
	map._load_game()
	check(not panel.visible and panel.world_state == map.state,"Load rebinds and closes case view")
	var path: String = map.save_path
	map.queue_free()
	await process_frame
	DirAccess.remove_absolute(path)
	print("Side scene checks: %d, failures: %d" % [checks,failures])
	quit(1 if failures else 0)
