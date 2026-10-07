extends "res://tests/equipment_state_test.gd"
var map: Node
func run() -> void:
	root.size = Vector2i(1280,720)
	map = load("res://src/world/world_map.tscn").instantiate()
	map.save_path = "user://equipment_scene_%d.json" % OS.get_process_id()
	root.add_child(map)
	await process_frame
	var state = map.state
	var gear = state.equipment
	# Acquisition is an explicit fixture here; merchant acquisition has its own scene test.
	var boots: String = gear.grant("EQ043","inquisitor")
	map.equipment_button.pressed.emit()
	var panel = map.equipment_panel
	check(panel.visible and panel.inventory.item_count == 1,"Map opens owned equipment")
	check(panel.slot.item_count == 14,"All fourteen slots displayed")
	panel.equip_button.pressed.emit()
	check(gear.instances[boots].slot == "feet","UI equips item in selected slot")
	check(Save.read_save(map.save_path).state.equipment.instances[boots].slot == "feet","Equipment action autosaves")
	var day: int = state.day
	map._end_turn()
	map._switch_hero("smuggler")
	map.language_button.pressed.emit()
	check(state.day == day and state.party.active_id == "inquisitor" and not map.lessons.visible,"Equipment modal blocks world actions")
	panel.remove_button.pressed.emit()
	check(gear.instances[boots].slot.is_empty(),"UI moves equipment back to backpack")
	panel.transfer_button.pressed.emit()
	check(gear.instances[boots].owner == "smuggler" and panel.inventory.item_count == 0,"Co-located delivery updates both inventory owners")
	check(panel.equip_button.disabled,"Empty inventory cannot equip")
	panel.close_button.pressed.emit()
	map._switch_hero("smuggler")
	map.equipment_button.pressed.emit()
	check(panel.inventory.item_count == 1,"Recipient sees delivered item")
	panel.equip_button.pressed.emit()
	panel.close()
	map._end_turn()
	check(map.state.movement_remaining == 20 and map.status.text.contains("20 / 20"),"HUD shows actual enhanced movement")
	map._switch_hero("inquisitor")
	for part: Dictionary in gear.sets.SA01.components:
		var id: String = gear.grant(part.item_id,"inquisitor")
		check(gear.equip(state,id,part.slot),"Explicit soul component fixture")
	map.equipment_button.pressed.emit()
	panel.tabs.current_tab = 1
	check(panel.send_button.disabled and panel.prompt.text.contains("Consolida"),"Soul UI respects ordered curriculum")
	panel.close()
	learn(state)
	map.equipment_button.pressed.emit()
	panel.tabs.current_tab = 1
	for stage: String in gear.STAGES:
		if stage == "delayed_recall":
			check(panel.send_button.disabled,"Recall UI requires later world day")
			panel.close()
			map._end_turn()
			map.equipment_button.pressed.emit()
			panel.tabs.current_tab = 1
		check(panel.input.text.is_empty(),"Each stage requires fresh typed production")
		if stage == "compare_memories":
			panel.memory_a.select(0)
			panel.memory_b.select(0)
			panel.input.text = gear.expected("SA01",stage)
			panel.send_button.pressed.emit()
			check(gear.ritual_stage("inquisitor","SA01") == stage,"Same memory cannot fill both sources through UI")
			panel.memory_b.select(1)
		if stage == "independent_argument":
			check(not panel.prompt.text.contains(gear.expected("SA01",stage)) and not panel.soul_text.text.contains(gear.expected("SA01",stage)),"Independent answer not displayed")
			if DisplayServer.get_name() != "headless":
				await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("C:/dev/game/tools/local/soul-conversation-preview.png")
		panel.input.text = gear.expected("SA01",stage)
		panel.send_button.pressed.emit()
	check(not panel.assemble_button.disabled and gear.consent("inquisitor","SA01"),"Full staged dialogue unlocks assembly")
	panel.assemble_button.pressed.emit()
	check(gear.assemblies.has("SA01"),"UI assembly retains equipped components")
	var restored := Save.read_save(map.save_path)
	check(restored.has("state") and restored.state.equipment.consent("inquisitor","SA01"),"Soul consent autosaved")
	check(Rect2(Vector2.ZERO,root.size).encloses(panel.close_button.get_global_rect()),"Equipment controls fit viewport")
	panel.disassemble_button.pressed.emit()
	check(not gear.assemblies.has("SA01") and gear.components("inquisitor","SA01").size() == 4,"UI disassembly preserves parts")
	panel.assemble_button.pressed.emit()
	panel.transfer_set_button.pressed.emit()
	check(gear.assemblies.SA01.owner == "inquisitor","Recipient occupied feet prevent partial set transfer")
	panel.tabs.current_tab = 0
	panel.refresh()
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/dev/game/tools/local/equipment-preview.png")
	map._load_game()
	check(not panel.visible and panel.world_state == map.state,"Load closes and rebinds stale equipment view")
	var path: String = map.save_path
	map.queue_free()
	await process_frame
	DirAccess.remove_absolute(path)
	print("Equipment scene checks: %d, failures: %d" % [checks,failures])
	quit(1 if failures else 0)
