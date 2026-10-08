extends SceneTree
const Client = preload("res://src/claude/claude_client.gd")
const Save = preload("res://src/save/save_game.gd")
const World = preload("res://src/world/world_state.gd")
class FakeClient extends Client:
	func _api_key() -> String:
		return "test-only"
	func _send() -> void:
		attempts += 1
var checks := 0
var failures := 0
const QUESTION := "¿Qué dice la comunidad sobre la muerte de Tomás?"
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func proposal(id: Variant = "monastery_claim", intent := "ask_death") -> Dictionary:
	return {"npc_reply": "Texto del modelo que no es prueba canónica.", "language": {
		"meaning_understood": true, "confidence": 0.9, "errors": [],
		"successful_grammar": ["present"], "new_vocabulary": []},
		"conversation": {"player_intent": intent, "npc_attitude_delta": 0,
		"suggested_unlock": id, "difficulty_observation": "comfortable"}}
func add_food(state: RefCounted) -> void:
	state.evidence.record("travel_food", "LOC01", "Hay comida.", "observation", state.day)
func run() -> void:
	var state := World.new()
	check(not state.evidence.record_dialogue("monastery_claim", "lucio_salcedo", "LOC01", QUESTION, 1), "Earlier physical evidence required")
	add_food(state)
	check(not state.evidence.record("monastery_claim", "LOC01", QUESTION, "claim", 1), "Physical recorder cannot award testimony")
	check(not state.evidence.record_dialogue("invented", "lucio_salcedo", "LOC01", QUESTION, 1), "Unknown clue denied")
	check(not state.evidence.record_dialogue("monastery_claim", "innkeeper_prototype", "LOC01", QUESTION, 1), "Wrong NPC denied")
	check(not state.evidence.record_dialogue("monastery_claim", "lucio_salcedo", "LOC11", QUESTION, 1), "Wrong conversation location denied")
	check(not state.evidence.record_dialogue("monastery_claim", "lucio_salcedo", "LOC01", "suicidio", 1), "Single keyword not enough language production")
	check(not state.evidence.record_dialogue("monastery_claim", "lucio_salcedo", "LOC01", "Hola", 1), "Unrelated intent denied")
	check(state.evidence.record_dialogue("monastery_claim", "lucio_salcedo", "LOC01", QUESTION, 1), "Grounded question records attributed claim")
	check(not state.evidence.record_dialogue("monastery_claim", "lucio_salcedo", "LOC01", QUESTION, 1), "Repeated unlock denied")
	check(state.evidence.progress().monastery_claim.classification == "claim", "Not classified as proven truth")
	check(state.evidence.node("monastery_claim").causal_link.begins_with("No establecido"), "Cause remains unknown")
	var saved := Save.snapshot(state)
	var restored := Save.decode(saved)
	check(restored.has("state") and restored.state.evidence.has_evidence("monastery_claim"), "Dialogue evidence survives restore")
	var bad := saved.duplicate(true)
	bad.evidence.erase("travel_food")
	check(not Save.decode(bad).has("state"), "Forged prerequisite-free save denied")
	bad = saved.duplicate(true)
	bad.day = 2
	bad.evidence.travel_food.found_day = 2
	check(not Save.decode(bad).has("state"), "Evidence chronology enforced")

	var path := "user://clue_test_%d.json" % OS.get_process_id()
	var map = load("res://src/world/world_map.tscn").instantiate()
	map.save_path = path
	root.add_child(map)
	await process_frame
	map.state.move_to(Vector2i(6, 11), true)
	map.state.end_turn()
	map.state.move_to(Vector2i(7, 10), true)
	map.state.move_to(Vector2i(12, 10), true)
	map._open_poi(Vector2i(12, 10))
	var panel = map.dialogue
	panel.client.queue_free()
	var fake := FakeClient.new()
	panel.client = fake
	panel.add_child(fake)
	fake.completed.connect(panel._on_reply)

	panel.submit(QUESTION)
	var sent: Dictionary = JSON.parse_string(JSON.parse_string(fake.payload).messages[0].content)
	check(sent.eligible_unlock_ids.is_empty() and not sent.npc_knowledge.has("monastery_claim"), "Before inspection prompt withholds clue")
	fake._finish(proposal())
	check(not map.state.evidence.has_evidence("monastery_claim"), "Model cannot skip prerequisite")
	check(map.state.learner.grammar.present == 0, "Rejected unlock cannot award learner progress")
	add_food(map.state)
	panel.open_conversation("LOC01")
	check(panel.hint.text.contains("comunidad"), "Question scaffold appears after food observation")
	for proposed in ["invented", "travel_food"]:
		panel.submit(QUESTION)
		fake._finish(proposal(proposed))
		check(not map.state.evidence.has_evidence("monastery_claim"), "Invalid ID cannot fall through to offline unlock")
	panel.submit(QUESTION)
	fake._finish(proposal("monastery_claim", "greeting"))
	check(not map.state.evidence.has_evidence("monastery_claim"), "Claimed intent cannot override local intent")
	panel.submit("suicidio")
	fake._finish(proposal())
	check(not map.state.evidence.has_evidence("monastery_claim"), "Model cannot waive full Spanish question")
	panel.submit(QUESTION)
	sent = JSON.parse_string(JSON.parse_string(fake.payload).messages[0].content)
	check(sent.eligible_unlock_ids == ["monastery_claim"], "Actual prompt contains only eligible clue")
	check(sent.npc_memory.conversation_count >= 1 and sent.npc_memory.revealed.is_empty() and sent.npc_memory.size() == 4, "Prompt carries bounded memory of earlier talks")
	check(sent.npc_knowledge.monastery_claim.contains("afirmación"), "Prompt keeps claim attributed")
	# Late response belongs to the abbot even after the player returns to the inn.
	map._close_poi()
	map.state.end_turn()
	map.state.move_to(Vector2i(6, 11), true)
	map._open_poi(Vector2i(6, 11))
	fake._finish(proposal())
	check(map.state.evidence.has_evidence("monastery_claim"), "Verified late response records original NPC claim")
	check(panel.histories.LOC11.is_empty(), "Late disclosure does not enter the wrong NPC history")
	check(panel.histories.LOC01.back().reply.contains("La comunidad"), "Critical statement rendered from canonical text")
	check(not panel.histories.LOC01.back().reply.contains("Texto del modelo"), "Generated prose cannot replace canonical evidence")
	check(map.state.evidence.progress().monastery_claim.found_day == 2, "Original conversation day retained")
	check(Save.read_save(path).state.evidence.has_evidence("monastery_claim"), "Accepted disclosure autosaves")
	var mastery: float = map.state.learner.grammar.present
	map._close_poi()
	map.notebook_button.pressed.emit()
	check(map.notebook.entries.item_count == 2 and map.notebook.active_id == "monastery_claim", "Notebook lists both evidence nodes")
	check(map.notebook.body.text.contains("DECLARACIÓN") or map.notebook.body.text.contains("Declaración atribuida"), "Journal shows institutional claim status")
	map.notebook.entries.item_selected.emit(0)
	check(map.notebook.active_id == "travel_food", "Player can return to physical observation")
	map.notebook.close()

	# Exercise the authored offline route in a fresh logical session.
	map.state = World.new()
	panel.world_state = map.state
	map.state.move_to(Vector2i(6, 11), true)
	map._open_poi(Vector2i(6, 11))
	add_food(map.state)
	fake.config.dev_flags.offline_mode = true
	panel.submit(QUESTION)
	check(not map.state.evidence.has_evidence("monastery_claim"), "Offline innkeeper cannot reveal abbot testimony")
	map._close_poi()
	map.state.end_turn()
	map.state.move_to(Vector2i(7, 10), true)
	map.state.move_to(Vector2i(12, 10), true)
	map._open_poi(Vector2i(12, 10))
	panel.submit(QUESTION)
	check(map.state.evidence.has_evidence("monastery_claim"), "Offline mode completes the same canonical unlock")
	check(map.state.learner.grammar.present == 0, "Offline clue matching does not fake language evaluation")
	check(panel.feedback.text.contains("Nueva afirmación"), "UI confirms notebook update")
	var first_record: Dictionary = map.state.evidence.progress()
	panel.submit(QUESTION)
	check(map.state.evidence.progress() == first_record, "Repeated question does not duplicate evidence")
	map._close_poi()
	map.notebook_button.pressed.emit()
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://dialogue-clue-preview.png")
	check(mastery > 0, "Valid evaluated dialogue still updates Spanish observations")
	map.queue_free()
	await process_frame
	DirAccess.remove_absolute(path)
	print("Dialogue clue checks: %d, failures: %d" % [checks, failures])
	quit(1 if failures else 0)
