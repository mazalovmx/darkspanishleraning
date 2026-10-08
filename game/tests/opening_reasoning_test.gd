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
func select_id(selector: OptionButton, id: String) -> void:
	for index in selector.item_count:
		if selector.get_item_metadata(index) == id:
			selector.select(index)
			return
	check(false, "Missing selector item: " + id)
func run() -> void:
	var map = load("res://src/world/world_map.tscn").instantiate()
	map.persistence_enabled = false
	root.add_child(map)
	await process_frame
	var evidence = map.state.evidence
	check(evidence.reviewable_ids(1).is_empty(), "No premature conclusions")
	map.state.move_to(Vector2i(6, 11), true)
	map.state.end_turn()
	map.state.move_to(Vector2i(7, 10), true)
	map.state.move_to(Vector2i(12, 10), true)
	map._open_poi(Vector2i(12, 10))
	map.dialogue.client.config.dev_flags.offline_mode = true
	evidence.record("travel_food", "LOC01", "Hay comida.", "observation", 2)
	map.dialogue.submit("¿Qué dice la comunidad?")
	var notebook = map.notebook
	notebook.open_journal(map.state)
	notebook.compare_button.pressed.emit()
	check(notebook.active_id == "food_hypothesis" and notebook.exercise.visible, "First comparison available")
	check(not notebook.body.text.contains("La comida admite"), "Unanswered comparison does not show final canonical result")
	notebook.note.text = "La comida no demuestra la causa."
	select_id(notebook.category, "suicide")
	select_id(notebook.support_a, "travel_food")
	select_id(notebook.support_b, "monastery_claim")
	notebook.record_button.pressed.emit()
	check(not evidence.has_evidence("food_hypothesis"), "Wrong hypothesis rejected")
	check(notebook.feedback.text.contains("no prueba"), "Wrong hypothesis gets explanation")
	select_id(notebook.category, "open")
	select_id(notebook.support_b, "travel_food")
	notebook.record_button.pressed.emit()
	check(not evidence.has_evidence("food_hypothesis"), "Duplicate supporting clue cannot count twice")
	select_id(notebook.support_b, "monastery_claim")
	notebook.note.text = ""
	notebook.record_button.pressed.emit()
	check(not evidence.has_evidence("food_hypothesis"), "Clicks without Spanish cannot solve")
	notebook.note.text = "La comida no demuestra la causa."
	notebook.record_button.pressed.emit()
	check(evidence.has_evidence("food_hypothesis"), "Corrected interpretation recorded")
	notebook.close()
	for id in ["brass_tube", "tower_blood", "scraped_boot", "missing_notebook", "preservation_order"]:
		var clue: Dictionary = evidence.node(id)
		check(evidence.record(id, "LOC01", clue.language.sample, clue.classification, 2), "Physical/document collection")
	map.dialogue.open_conversation("LOC01_GABRIEL")
	for question in ["¿Qué oye por la noche?", "¿Oye un caballo?", "¿Por qué cambia su relato?"]:
		map.dialogue.submit(question)
	map.dialogue.open_conversation("LOC01_LEONOR")
	map.dialogue.submit("¿Qué indica la herida?")
	check(not evidence.record_reasoning("opening_conclusion", "Hay un golpe mortal antes de la caída.", "blow_first", ["tower_blood", "medical_report"], 2), "Cannot skip horse comparison")
	notebook.open_journal(map.state)
	notebook.open_reasoning()
	check(notebook.active_id == "horse_hypothesis", "Second comparison selected")
	select_id(notebook.category, "gabriel")
	select_id(notebook.support_a, "horse_sound")
	select_id(notebook.support_b, "wine_secret")
	notebook.note.text = "El caballo no identifica al visitante."
	notebook.record_button.pressed.emit()
	check(not evidence.has_evidence("horse_hypothesis"), "Irrelevant lie cannot prove murder")
	select_id(notebook.category, "uncertain")
	notebook.record_button.pressed.emit()
	check(evidence.has_evidence("horse_hypothesis"), "Honest observation separated from inference")
	# Save/reload between interpretation and causal reconstruction.
	var decoded := Save.decode(Save.snapshot(map.state))
	check(decoded.has("state"), "Intermediate investigation restores")
	map.state = decoded.state
	map.dialogue.world_state = map.state
	evidence = map.state.evidence
	notebook.open_journal(map.state)
	notebook.open_reasoning()
	check(notebook.active_id == "opening_conclusion", "Causal reconstruction opens after prerequisites")
	select_id(notebook.category, "fall_first")
	select_id(notebook.support_a, "tower_blood")
	select_id(notebook.support_b, "medical_report")
	notebook.note.text = "Hay un golpe mortal antes de la caída."
	notebook.record_button.pressed.emit()
	check(not evidence.has_evidence("opening_conclusion"), "Reversed chronology rejected")
	select_id(notebook.category, "blow_first")
	select_id(notebook.support_b, "monastery_claim")
	notebook.record_button.pressed.emit()
	check(not evidence.has_evidence("opening_conclusion"), "Institutional authority cannot replace clinical support")
	select_id(notebook.support_b, "medical_report")
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://opening-reasoning-preview.png")
	notebook.record_button.pressed.emit()
	check(evidence.has_evidence("opening_conclusion"), "Supported causal chain recorded")
	check(evidence.progress().opening_conclusion.classification == "causal_conclusion", "Conclusion has distinct classification")
	check(notebook.body.text.contains("no identifican"), "Limits of conclusion remain visible")
	check(not evidence.record("opening_conclusion", "LOC01", notebook.note.text, "causal_conclusion", 2), "Inspection cannot bypass reasoning")
	var snapshot := Save.snapshot(map.state)
	check(Save.decode(snapshot).has("state"), "Completed conclusion saves")
	var bad := snapshot.duplicate(true)
	bad.evidence.erase("horse_hypothesis")
	check(not Save.decode(bad).has("state"), "Save cannot skip comparison")
	bad = snapshot.duplicate(true)
	bad.evidence.opening_conclusion.found_day = 1
	check(not Save.decode(bad).has("state"), "Conclusion cannot predate evidence")
	check(map.state.learner.grammar.present == 0, "Guided exercises do not fabricate mastery")
	map.queue_free()
	await process_frame
	print("Opening reasoning checks: %d, failures: %d" % [checks, failures])
	quit(1 if failures else 0)
