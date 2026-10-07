extends SceneTree
const Save = preload("res://src/save/save_game.gd")
const World = preload("res://src/world/world_state.gd")
const Client = preload("res://src/claude/claude_client.gd")
class FakeClient extends Client:
	func _api_key() -> String:
		return "test-only"
	func _send() -> void:
		attempts += 1
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
	var path := "user://curriculum_ui_%d.json" % OS.get_process_id()
	var map = load("res://src/world/world_map.tscn").instantiate()
	map.save_path = path
	root.add_child(map)
	await process_frame
	map.language_button.pressed.emit()
	var panel = map.lessons
	check(panel.visible and panel.task.stage == "introduce", "Map opens first lesson")
	var day: int = map.state.day
	map._end_turn()
	check(map.state.day == day, "Learning screen blocks hostile day progression")
	panel.advance.pressed.emit()
	check(panel.task.stage == "guided" and panel.explanation.text.contains("Soy médico."), "Introduction leads to supported production")
	panel.answer.text = "sí"
	panel.advance.pressed.emit()
	check(panel.task.stage == "guided", "Wrong answer cannot progress")
	panel.answer.text = "Soy médico."
	panel.advance.pressed.emit()
	check(panel.task.stage == "first" and not panel.explanation.text.contains("Soy investigador."), "Transfer hides answer model")
	panel.answer.text = "Soy investigador."
	panel.advance.pressed.emit()
	check(panel.task.stage == "second", "Second independent context required")
	panel.answer.text = "Estoy en la torre."
	panel.advance.pressed.emit()
	check(panel.task.stage == "introduce" and panel.task.card.id == "existence", "Next topic while recall waits")
	check(Save.read_save(path).state.learner.curriculum.records.identity.second.answer == "Estoy en la torre.", "Independent production autosaves")
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/dev/game/tools/local/curriculum-preview.png")
	# Complete the rest of the current block through actual lesson controls.
	var attempts := 0
	while panel.task.stage != "wait" and attempts < 40:
		attempts += 1
		if panel.task.stage == "introduce":
			panel.advance.pressed.emit()
		else:
			var task: Dictionary = panel.task
			panel.answer.text = task.card.model if task.stage == "guided" else task.card.exercises[["first", "second", "recall"].find(task.stage)].answers[0]
			panel.advance.pressed.emit()
	check(panel.task.stage == "wait", "Same-day practice ends at recall gate")
	check(map.state.learner.current_block == "present_and_basic_requests", "Guided and transfer successes do not skip delayed recall")
	panel.close_button.pressed.emit()
	map._end_turn()
	map.language_button.pressed.emit()
	check(panel.task.stage == "recall", "Following day offers recall")
	for i in 4:
		var task: Dictionary = panel.task
		panel.answer.text = task.card.exercises[2].answers[0]
		panel.advance.pressed.emit()
	check(map.state.learner.current_block == "requests_and_prices", "All recalled topics unlock exactly the next block")
	check(map.state.learner.grammar.present == 0, "Lesson completion is separate from free-language mastery")
	panel.close_button.pressed.emit()
	map._save_game()
	map._load_game()
	check(map.state.learner.current_block == "requests_and_prices", "Reload preserves derived curriculum stage")
	var bad := Save.snapshot(map.state)
	bad.learner.block = "completed_past"
	check(not Save.decode(bad).has("state"), "Claimed block cannot override lesson proof")
	bad = Save.snapshot(map.state)
	bad.learner.curriculum.records.identity.recall.day = 1
	check(not Save.decode(bad).has("state"), "Saved recall must occur on later day")
	var old := Save.snapshot(World.new())
	old.version = 4
	old.erase("party")
	old.erase("campaign")
	old.strategy.erase("economy")
	old.strategy.erase("equipment")
	old.strategy.erase("side_cases")
	old.strategy.erase("ghosts")
	old.learner.erase("curriculum")
	old.learner.grammar.erase("future_simple")
	var migrated := Save.decode(old)
	check(migrated.has("state") and migrated.state.learner.grammar.future_simple == 0, "V4 migration adds future category and no invented lessons")
	map.state.move_to(Vector2i(6, 11), true)
	map._open_poi(map.state.hero_cell)
	check(map.dialogue.hint.text.contains("Peticiones"), "Conversation objective follows curriculum")
	var dialogue = map.dialogue
	dialogue.client.queue_free()
	var fake := FakeClient.new()
	dialogue.client = fake
	dialogue.add_child(fake)
	fake.config.dev_flags.offline_mode = false
	fake.completed.connect(dialogue._on_reply)
	dialogue.submit("Hola")
	var sent: Dictionary = JSON.parse_string(JSON.parse_string(fake.payload).messages[0].content)
	check(sent.language_profile.curriculum.block_index == 2, "Claude receives actual current block")
	check(not sent.language_profile.allowed_grammar_tags.has("preterite"), "Future-block tense withheld from prompt")
	check(sent.language_profile.has("focus") and sent.language_profile.curriculum.has("dimensions"), "Prompt includes schedule and dimensions")
	fake._finish({})
	map.state.learner.observe({"meaning_understood":true,"confidence":0.9,"errors":[],"successful_grammar":["preterite"],"new_vocabulary":[]}, "Ayer fui", "innkeeper_prototype", map.state.day)
	check(map.state.learner.grammar.preterite == 0, "Model cannot credit an untaught tense")
	map.queue_free()
	await process_frame
	DirAccess.remove_absolute(path)
	print("Curriculum integration checks: %d, failures: %d" % [checks, failures])
	quit(1 if failures else 0)
