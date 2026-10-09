extends "res://tests/campaign_test.gd"
func choose(selector: OptionButton, id: String) -> void:
	for index in selector.item_count:
		if selector.get_item_metadata(index) == id:
			selector.select(index)
			return
	check(false,"Required UI proof exists: " + id)
func run() -> void:
	root.size = Vector2i(1280,720)
	var map = load("res://src/world/province_map.tscn").instantiate()
	map.save_path = "user://campaign_panel_%d.json" % OS.get_process_id()
	root.add_child(map)
	await process_frame
	complete_opening(map.state)
	map.campaign_button.pressed.emit()
	var panel = map.campaign_journal
	check(panel.visible and panel.active_id == panel.SUMMARY and panel.entries.get_item_metadata(1) == "sealed_order", "The journal opens on the task summary, with the next act's task listed")
	var overview: String = panel.body.text
	check(overview.contains("HISTORIA PRINCIPAL · acto 2 de 7") and overview.contains("✓ La muerte de Tomás") and overview.contains("▶ El sello y la propiedad — "), "Summary: finished opening, main task in progress with its place")
	check(overview.contains("TAREAS SECUNDARIAS") and overview.contains("○ 17 tareas secundarias todavía sin abrir.") and overview.contains("○ 12 investigaciones sin empezar."), "Summary: optional tasks and local investigations not started are counted")
	check(not overview.contains("La resolución del Consejo") and not overview.contains("Pan de ayer"), "Summary never names a task that is not open yet")
	check(not panel.answer.visible and panel.submit_button.disabled, "The summary page takes no answer")
	panel.entries.select(1)
	panel.entries.item_selected.emit(1)
	check(panel.active_id == "sealed_order", "A task is chosen from the list")
	map._refresh()
	check(map.objective_button.visible and map.objective_button.text.begins_with("▶ AHORA: El sello y la propiedad — "), "The map panel names the current main task")
	check(map.end_button.get_parent() != map.campaign_button.get_parent() and map.end_button.get_index() == map.end_button.get_parent().get_child_count() - 1, "End of day stands apart, last on the panel")
	check(not panel.show_button.disabled, "An open task can be shown on the map")
	panel.show_button.pressed.emit()
	check(not panel.visible and (map.save_notice.text.begins_with("El mapa muestra: ") or map.save_notice.text.contains("todavía no está descubierto")), "Show on map closes the journal and reports where the map went")
	map.objective_button.pressed.emit()
	check(panel.visible and panel.active_id == panel.SUMMARY, "Clicking the objective opens the journal")
	panel.entries.select(1)
	panel.entries.item_selected.emit(1)
	check(panel.submit_button.disabled and not panel.body.text.contains("firma del obispo"), "Untaught/remote task exposes no document contents")
	var day: int = map.state.day
	map._end_turn()
	check(map.state.day == day, "Journal blocks ending day")
	map._switch_hero("smuggler")
	check(map.state.party.active_id == "inquisitor", "Journal blocks hero switching")
	panel.close_button.pressed.emit()
	learn(map.state)
	for id: String in map.state.campaign.definitions:
		var node: Dictionary = map.state.campaign.definitions[id]
		if node.hero != "any":
			check(map.state.select_hero(node.hero), "Story hero selectable after earned introduction")
		visit(map.state,node.location)
		if node.get("reunite",false):
			for member in map.state.party.heroes.values():
				member.cell = map.state.hero_cell
			map.state._reveal_from(map.state.hero_cell)
		map._refresh()
		map.campaign_button.pressed.emit()
		panel.active_id = id
		panel.refresh()
		check(not panel.submit_button.disabled and panel.body.text.contains(node.speaker), "Authored source available on location: " + id)
		check(panel.answer.text.is_empty(), "Answer is never auto-filled")
		panel.hint_button.pressed.emit()
		if node.has("outcomes"):
			check(panel.feedback.text.contains("propuestas") and panel.answer.text.is_empty(), "Council hint points to the proposals")
		else:
			check(panel.feedback.text.begins_with("Tu frase necesita:") and not panel.feedback.text.contains(node.answers[0]) and panel.answer.text.is_empty(), "Hint names what to say, never the model")
		panel.answer.text = node.answers[0]
		panel.category.select(map.state.campaign.CLASSIFICATIONS.find(node.classification)+1)
		var supports: Array = node.get("supports",[])
		if not supports.is_empty():
			choose(panel.support_a,supports[0])
			choose(panel.support_b,supports[1])
		panel.submit_button.pressed.emit()
		check(map.state.campaign.records.has(id), "Task submitted through interface: " + id)
		if id == "sealed_order":
			var shown: String = panel.feedback.text
			var language := {"meaning_understood": true, "confidence": 0.9, "successful_grammar": [], "new_vocabulary": [],
				"errors": [{"type": "present", "original": "la situacion", "better": "la situación", "severity": "minor"},
				{"type": "present", "original": "los cuaderno", "better": "los cuadernos", "severity": "minor"}]}
			var recorded: String = map.state.campaign.records[id].answer
			panel.review = {"id": id, "world": map.state, "answer": recorded, "serial": panel.feedback_serial}
			panel._on_review(language)
			check(panel.feedback.text.begins_with(shown) and panel.feedback.text.contains("los cuaderno → los cuadernos") and not panel.feedback.text.contains("situación"), "Review adds grammar feedback, drops tilde-only notes before the last block")
			check(map.state.campaign.records.has(id) and panel.review.is_empty(), "Review never changes the record")
			# A review that arrives after the feedback line moved on stays with its record.
			panel.review = {"id": id, "world": map.state, "answer": recorded, "serial": panel.feedback_serial}
			# The next submission takes the feedback line (as _submit does).
			panel.feedback_serial += 1
			panel.feedback.text = "Anotado. Otra tarea."
			var moved_on: String = panel.feedback.text
			panel._on_review(language)
			check(panel.feedback.text == moved_on, "A late review never lands under another line")
			panel.active_id = id
			panel.refresh()
			check(panel.body.text.contains("los cuaderno → los cuadernos"), "A late review is shown beside its record")
			var other = Save.decode(Save.snapshot(map.state)).state
			panel.review_notes.clear()
			panel.review = {"id": id, "world": other, "answer": recorded, "serial": panel.feedback_serial}
			panel._on_review(language)
			check(panel.review_notes.is_empty() and panel.feedback.text == moved_on, "A review from another game is dropped")
			panel.review = {"id": id, "world": map.state, "answer": "Otra frase.", "serial": panel.feedback_serial}
			panel._on_review(language)
			check(panel.review_notes.is_empty(), "A review of another sentence is dropped")
		check(Save.read_save(map.save_path).state.campaign.records.has(id), "Task autosaved: " + id)
		if id == "ines_arrival":
			check(not map.hero_buttons.smuggler.disabled, "Ines portrait enabled immediately")
		if id == "elias_arrival":
			check(not map.hero_buttons.survivor.disabled, "Elias portrait enabled immediately")
		if id == "council_resolution":
			check(panel.body.text.contains("El archivo destruido"), "Derived ending and consequences displayed")
			if DisplayServer.get_name() != "headless":
				await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("user://council-preview.png")
		if id == "archive_bias" and DisplayServer.get_name() != "headless":
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("user://campaign-preview.png")
		panel.close_button.pressed.emit()
	map._load_game()
	check(map.state.campaign.records.size() == map.state.campaign.definitions.size() and not panel.visible, "Loading replaces ledger and closes old panel")
	map.campaign_button.pressed.emit()
	panel.active_id = "sealed_order"
	panel.refresh()
	check(panel.body.text.contains("Anotación") and panel.submit_button.disabled, "Completed proofs remain readable without replay")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape,true)
	check(not panel.visible, "Escape closes campaign journal")
	var path: String = map.save_path
	map.queue_free()
	await process_frame
	DirAccess.remove_absolute(path)
	print("Campaign panel checks: %d, failures: %d" % [checks, failures])
	quit(1 if failures else 0)