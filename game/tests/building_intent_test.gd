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
	var map = load("res://src/world/province_map.tscn").instantiate()
	map.persistence_enabled = false
	root.add_child(map)
	await process_frame
	map._open_poi(map.state.hero_cell)
	map.strategy_button.pressed.emit()
	var panel = map.strategy_panel
	var economy = map.state.economy
	panel.town_view.buttons.council_hall.pressed.emit()
	check(not panel.quantity.visible and panel.quantity.value == 1, "Construction is always one selected building")
	check(not panel.prompt.text.contains("cantidad + producto"), "Construction has its own reminder")
	var before: Dictionary = map.state.resources.duplicate()
	for sentence in ["Quiero construirlo.", "¿Puedes construir este edificio?", "Por favor, construye el edificio seleccionado.", "Me gustaría levantarlo aquí.", "Quiero construir administración.", "Quiero construir.", "Quisiera construir la casa de administración."]:
		panel.input.text = sentence
		panel.send_button.pressed.emit()
		check(economy.phase == "price" and economy.pending.get("quantity",0) == 1, "Selected context understood: " + sentence)
		check(map.state.resources == before and economy.buildings.is_empty(), "Request alone cannot pay or build")
		panel.cancel_button.pressed.emit()
	for sentence in ["Quiero destruir la casa de administración.", "Quiero construir dos cuarteles.", "Quiero construir el cuartel.", "No quiero construirlo.", "Quiero construirlo pero no ahora.", "¿Cuánto cuesta construirlo?", "Quiero.", "Quiero construir una nave espacial."]:
		panel.input.text = sentence
		panel.send_button.pressed.emit()
		check(economy.phase == "request" and economy.pending.is_empty() and map.state.resources == before, "Contradictory or incomplete intent cannot order: " + sentence)
	check(not panel.feedback.text.contains("cantidad + producto"), "Retry uses building-specific guidance")
	panel.input.text = "Quiero construirlo."
	panel.send_button.pressed.emit()
	var models: Dictionary = economy.current_models(map.state,"build","council_hall",1)
	for phase in ["price","confirm"]:
		panel.input.text = models[phase]
		panel.send_button.pressed.emit()
	check(economy.buildings.get("LOC01",{}).has("council_hall"), "Contextual request completes one selected building")
	check(map.state.resources.gold == before.gold - 300, "Exactly one building is charged")
	var path := "user://building_intent_%d.json" % OS.get_process_id()
	check(Save.write_save(map.state,path).is_empty(), "New request receipt saves")
	check(Save.read_save(path).has("state"), "New request receipt loads")
	DirAccess.remove_absolute(path)
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://building-intent-preview.png")
	map.queue_free()
	await process_frame
	print("Building intent checks: %d, failures: %d" % [checks,failures])
	quit(1 if failures else 0)
