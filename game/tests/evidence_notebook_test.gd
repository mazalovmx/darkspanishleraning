extends SceneTree
const World = preload("res://src/world/world_state.gd")
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
	var state := World.new()
	check(state.evidence.progress().is_empty(), "No evidence awarded at start")
	check(not state.evidence.record("invented", "LOC01", "Hay comida", "observation", 1), "Unknown evidence ID denied")
	check(not state.evidence.record("travel_food", "LOC11", "Hay comida", "observation", 1), "Wrong location denied")
	check(not state.evidence.record("travel_food", "LOC01", "Hay comida", "interpretation", 1), "Wrong classification denied")
	for text in ["", "food", "suicidio", "Hay comida porque es un asesino", "x".repeat(301)]:
		check(not state.evidence.valid_note("travel_food", text), "Unsupported guided answer denied")
	for text in ["Hay comida.", "Veo comida para un viaje.", "  TOMÁS TIENE COMIDA.  "]:
		check(state.evidence.valid_note("travel_food", text), "Supported present-tense description")
	check(state.evidence.record("travel_food", "LOC01", "Hay comida.", "observation", 1), "Physical observation recorded")
	check(not state.evidence.record("travel_food", "LOC01", "Veo comida", "observation", 1), "Repeated record not awarded")
	var canonical := state.evidence.node("travel_food")
	check(canonical.interpretations.size() == 4 and canonical.causal_link.begins_with("No establecido"), "Four hypotheses remain open")
	canonical.observation = "forged"
	check(state.evidence.node("travel_food").observation != "forged", "Canonical text returned by copy")
	var saved := Save.snapshot(state)
	var loaded := Save.decode(saved)
	check(loaded.has("state") and loaded.state.evidence.progress() == state.evidence.progress(), "Evidence snapshot restored")
	for value in [null, [], {"invented": {}}, {"travel_food": {"found_day": 1, "classification": "observation", "spanish_note": "Hay comida", "observation": "forged"}}]:
		var bad := saved.duplicate(true)
		bad.evidence = value
		check(not Save.decode(bad).has("state"), "Invalid evidence save rejected")
	for value in [true, 0, -1, 2, 1.5, "1"]:
		var bad := saved.duplicate(true)
		bad.evidence.travel_food.found_day = value
		check(not Save.decode(bad).has("state"), "Invalid evidence day denied")
	var bad := saved.duplicate(true)
	bad.evidence.travel_food.classification = "proven_murder"
	check(not Save.decode(bad).has("state"), "Save cannot turn observation into proven cause")
	bad = saved.duplicate(true)
	bad.evidence.travel_food.spanish_note = "password"
	check(not Save.decode(bad).has("state"), "Save must preserve a valid production")
	var progress := state.evidence.progress()
	check(not state.evidence.restore({"unknown": {}}, 1) and state.evidence.progress() == progress, "Invalid restore is transactional")
	var old := saved.duplicate(true)
	old.version = 1
	old.erase("party")
	old.erase("campaign")
	old.learner.erase("curriculum")
	old.learner.grammar.erase("future_simple")
	old.erase("evidence")
	old.erase("strategy")
	var migrated := Save.decode(old)
	check(migrated.has("state") and migrated.state.evidence.progress().is_empty(), "V1 migrates without inventing evidence")
	check(migrated.state.hero_cell == state.hero_cell, "V1 keeps world state")
	check(Save.snapshot(migrated.state).version == Save.VERSION, "Next save uses current version")

	var path := "user://evidence_test_%d.json" % OS.get_process_id()
	var map = load("res://src/world/world_map.tscn").instantiate()
	map.save_path = path
	root.add_child(map)
	await process_frame
	map.notebook_button.pressed.emit()
	check(map.notebook.visible and map.notebook.active_id.is_empty(), "Empty journal accessible from map")
	var day: int = map.state.day
	map._end_turn()
	check(map.state.day == day, "Notebook blocks day advancement")
	var escape := InputEventKey.new()
	escape.pressed = true
	escape.keycode = KEY_ESCAPE
	map._input(escape)
	check(not map.notebook.visible, "Escape closes journal")
	check(not map.notebook.inspect(map.state), "Remote inspection denied")
	map.state.move_to(Vector2i(6, 11), true)
	map._open_poi(Vector2i(6, 11))
	check(not map.inspect_button.visible, "Inn has no monastery inspection action")
	map._close_poi()
	map.state.end_turn()
	map.state.move_to(Vector2i(7, 10), true)
	map.state.move_to(Vector2i(12, 10), true)
	map._open_poi(Vector2i(12, 10))
	check(map.inspect_button.visible, "Monastery exposes physical inspection")
	map.inspect_button.pressed.emit()
	var notebook = map.notebook
	check(notebook.visible and notebook.exercise.visible, "Inspection opens guided notebook")
	for section in ["OBSERVACIÓN", "AFIRMACIÓN", "INTERPRETACIONES POSIBLES", "ESTADO INSTITUCIONAL", "VÍNCULO CAUSAL"]:
		check(notebook.body.text.contains(section), "Semiotic categories visible separately")
	notebook.record_button.pressed.emit()
	check(map.state.evidence.progress().is_empty(), "Button alone cannot grant evidence")
	notebook.note.text = "Hay comida para un viaje."
	notebook.category.select(2)
	notebook.record_button.pressed.emit()
	check(map.state.evidence.progress().is_empty(), "Correct Spanish alone is insufficient")
	notebook.category.select(1)
	notebook.record_button.pressed.emit()
	check(map.state.evidence.has_evidence("travel_food"), "Spanish description plus classification records observation")
	check(not notebook.exercise.visible and notebook.feedback.text.contains("siguen abiertas"), "Recorded evidence does not settle interpretation")
	check(map.state.learner.grammar.hay == 0, "Guided matching does not fake free-language mastery")
	check(Save.read_save(path).state.evidence.has_evidence("travel_food"), "Recording autosaves")
	map._input(escape)
	check(not notebook.visible and map.poi_modal.visible, "Escape returns to underlying location")
	map._close_poi()
	map._load_game()
	map.notebook_button.pressed.emit()
	check(notebook.active_id == "travel_food" and notebook.feedback.text.contains("Hay comida"), "Journal restores after loading")
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/dev/game/tools/local/evidence-preview.png")
	map.queue_free()
	await process_frame
	DirAccess.remove_absolute(path)
	print("Evidence notebook checks: %d, failures: %d" % [checks, failures])
	quit(1 if failures else 0)
