extends SceneTree
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
	map.persistence_enabled = false
	root.add_child(map)
	await process_frame
	for resource in map.state.resources:
		map.state.resources[resource] = 10000
	var panel = map.strategy_panel
	panel.open_site(map.state)
	var city = panel.town_view
	check(city.buttons.size() == map.state.economy.catalog.town_buildings.LOC01.size(), "All local building sites are visible")
	check(city.income.is_empty() and city.built_ids.is_empty(), "Unbuilt town promises no existing income")
	var before: Dictionary = map.state.resources.duplicate()
	city.buttons.council_hall.pressed.emit()
	check(panel.entries.get_selected_metadata().id == "council_hall" and map.state.resources == before, "Building picture only selects a request")
	var models: Dictionary = map.state.economy.current_models(map.state, "build", "council_hall", 1)
	panel.input.text = models.request
	panel.send_button.pressed.emit()
	check(city.buttons.barracks.disabled, "Quoted order locks town selection until cancelled or completed")
	for phase in ["price", "confirm"]:
		panel.input.text = models[phase]
		panel.send_button.pressed.emit()
	check(city.built_ids.has("council_hall") and city.income.get("gold") == 40, "Completed administration appears and adds its exact daily income")
	check(city.summary.text.contains("40"), "Next-day town income is visible")
	panel.close()
	map.state.end_turn()
	panel.open_site(map.state)
	city.buttons.archery_range.pressed.emit()
	check(panel.description.text.contains("cuartel"), "Missing prerequisite is named")
	check(panel.send_button.disabled, "Town click never bypasses prerequisites")
	city.buttons.barracks.pressed.emit()
	for frame in 8:
		await process_frame
	var screen := Rect2(0,0,1280,720)
	for id: String in city.buttons:
		check(city.textures.has(id), "Building has licensed artwork: " + id)
		check(screen.encloses(city.buttons[id].get_global_rect()), "Building target stays on screen: " + id)
	for control: Control in [panel.input, panel.send_button, panel.close_button]:
		check(screen.encloses(control.get_global_rect()), "Order controls remain visible beside city")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://town-preview.png")
	map.queue_free()
	await process_frame
	print("Town view checks: %d, failures: %d" % [checks,failures])
	quit(1 if failures else 0)
