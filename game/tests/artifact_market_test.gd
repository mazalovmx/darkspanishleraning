extends "res://tests/economy_scene_test.gd"
func run() -> void:
	root.size = Vector2i(1280,720)
	map = load("res://src/world/province_map.tscn").instantiate()
	map.save_path = "user://artifact_scene_%d.json" % OS.get_process_id()
	root.add_child(map)
	await process_frame
	for resource in map.state.resources:
		map.state.resources[resource] = 10000
	map._open_poi(map.state.hero_cell)
	map.strategy_button.pressed.emit()
	var panel = map.strategy_panel
	check(map.state.economy.artifact_offers.size() == 60,"Sixty merchant offers, no soul components")
	select_offer("artifact","EQ001")
	check(panel.send_button.disabled,"Artifact market required")
	buy("build","council_hall",1)
	panel.close()
	map._close_poi()
	map._end_turn()
	map._open_poi(map.state.hero_cell)
	map.strategy_button.pressed.emit()
	buy("build","artifact_market",1)
	select_offer("artifact","EQ001")
	check(not panel.quantity.editable and panel.quantity.value == 1,"One item per purchase")
	var gold: int = map.state.resources.gold
	var phrases: Dictionary = map.state.economy.current_models(map.state,"artifact","EQ001",1)
	panel.input.text = "Sí"
	panel.send_button.pressed.emit()
	check(map.state.equipment.instances.is_empty(),"Click-like answer cannot buy equipment")
	panel.input.text = phrases.request
	panel.send_button.pressed.emit()
	panel.input.text = phrases.price
	panel.send_button.pressed.emit()
	check(map.state.resources.gold == gold and map.state.equipment.instances.is_empty(),"Quote grants and spends nothing")
	panel.input.text = phrases.confirm
	panel.send_button.pressed.emit()
	check(map.state.equipment.instances.size() == 1,"Confirmed purchase grants one instance")
	var instance: String = map.state.equipment.instances.keys()[0]
	check(map.state.equipment.instances[instance].slot.is_empty(),"Purchased item starts in backpack")
	check(map.state.resources.gold == gold - map.state.economy.cost("artifact","EQ001",1).gold,"Canonical price deducted")
	check(panel.send_button.disabled,"Sold stock disabled")
	check(Save.read_save(map.save_path).state.equipment.instances.has(instance),"Purchase and stock autosave together")
	check(map.state.economy.reason(map.state,"artifact","SP001",1) != "","Quest fragment unavailable for sale")
	check(map.state.economy.reason(map.state,"artifact","SA01",1) != "","Soul assembly unavailable for sale")
	select_offer("artifact","EQ006")
	phrases = map.state.economy.current_models(map.state,"artifact","EQ006",1)
	panel.input.text = phrases.request
	panel.send_button.pressed.emit()
	panel.input.text = phrases.price
	panel.send_button.pressed.emit()
	gold = map.state.resources.gold
	map.state.resources.gold = 0
	panel.input.text = phrases.confirm
	panel.send_button.pressed.emit()
	check(map.state.equipment.instances.size() == 1 and map.state.economy.pending.is_empty(),"Confirmation rechecks funds atomically")
	map.state.resources.gold = gold
	var snapshot: Dictionary = Save.snapshot(map.state)
	for fault in ["missing_item","wrong_item","fake_day","duplicate_sale"]:
		var bad: Dictionary = snapshot.duplicate(true)
		match fault:
			"missing_item": bad.strategy.equipment.instances.erase(instance)
			"wrong_item": bad.strategy.equipment.instances[instance].item = "EQ002"
			"fake_day": bad.strategy.economy.artifact_sales.LOC01.EQ001.day = 1
			"duplicate_sale": bad.strategy.economy.receipts.append(bad.strategy.economy.receipts.back().duplicate(true)); bad.strategy.economy.purchase_count += 1
		check(not Save.decode(bad).has("state"),"Invalid acquisition rejected: " + fault)
	var old: Dictionary = Save.snapshot(load("res://src/world/world_state.gd").new("province_160x120_v1"))
	old.version = 9
	old.erase("npc_memory")
	old.strategy.erase("side_cases")
	old.strategy.erase("ghosts")
	old.strategy.economy.erase("artifact_sales")
	check(Save.decode(old).has("state"),"V9 migrates with empty merchant ledger")
	select_offer("artifact","EQ041")
	check(panel.description.text.contains("mochila"),"Destination explained")
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://artifact-market-preview.png")
	var path: String = map.save_path
	map.queue_free()
	await process_frame
	DirAccess.remove_absolute(path)
	print("Artifact market checks: %d, failures: %d" % [checks,failures])
	quit(1 if failures else 0)
