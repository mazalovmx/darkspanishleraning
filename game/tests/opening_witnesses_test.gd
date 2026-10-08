extends SceneTree
const Save = preload("res://src/save/save_game.gd")
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
	var map = load("res://src/world/world_map.tscn").instantiate()
	map.persistence_enabled = false
	root.add_child(map)
	await process_frame
	map.state.move_to(Vector2i(6, 11), true)
	map.state.end_turn()
	map.state.move_to(Vector2i(7, 10), true)
	map.state.move_to(Vector2i(12, 10), true)
	map._open_poi(Vector2i(12, 10))
	var panel = map.dialogue
	panel.client.config.dev_flags.offline_mode = true
	var evidence = map.state.evidence
	check(panel.speaker.item_count == 3, "Three monastery speakers")
	panel.speaker.item_selected.emit(1)
	check(panel.location_id == "LOC01_GABRIEL", "Selector opens Gabriel")
	panel.submit("¿Qué oye por la noche?")
	check(not evidence.has_evidence("gabriel_denial"), "No testimony before first observation")
	evidence.record("travel_food", "LOC01", "Hay comida.", "observation", 2)
	panel.open_conversation("LOC01_GABRIEL")
	check(panel.hint.text.contains("noche"), "First question scaffold")
	var hidden: Dictionary = panel.grounding.context_for("hermano_gabriel", "ask_night", evidence.context_flags(), [])
	check(not str(hidden).contains("Robo vino"), "Secret withheld from model")
	panel.submit("noche")
	check(not evidence.has_evidence("gabriel_denial"), "Keyword cannot replace question")
	panel.submit("¿Qué oye por la noche?")
	check(evidence.has_evidence("gabriel_denial"), "Initial authored testimony")
	check(panel.histories.LOC01_GABRIEL.back().reply.contains("capilla"), "Authored denial displayed")
	check(not panel.transcript.text.contains("deliberate_lie"), "Author classification remains hidden")
	panel.submit("¿Oye un caballo?")
	check(not evidence.has_evidence("horse_sound"), "Physical prerequisite required")
	evidence.record("brass_tube", "LOC01", "Hay un tubo roto.", "observation", 2)
	panel.open_conversation("LOC01_GABRIEL")
	check(panel.hint.text.contains("caballo"), "Next eligible question scaffold")
	panel.submit("¿Oye un caballo?")
	check(evidence.has_evidence("horse_sound"), "Witness observation obtained")
	check(evidence.node("horse_sound").claim.contains("Creo"), "Inference remains attributed belief")
	panel.submit("¿Por qué cambia su relato?")
	check(evidence.has_evidence("wine_secret"), "Irrelevant secret follows contradiction")
	check(panel.histories.LOC01_GABRIEL.back().reply.contains("Robo vino"), "Canonical confession")
	panel.open_conversation("LOC01_LEONOR")
	panel.submit("¿Qué indica la herida?")
	check(not evidence.has_evidence("medical_report"), "Incomplete examination cannot grant report")
	for id in ["tower_blood", "scraped_boot", "missing_notebook"]:
		evidence.record(id, "LOC01", evidence.node(id).language.sample, "observation", 2)
	panel.open_conversation("LOC01_LEONOR")
	check(panel.hint.text.contains("herida"), "Clinical question scaffold")
	panel.submit("¿Qué indica la herida?")
	check(evidence.has_evidence("medical_report"), "Report follows physical comparison")
	check(panel.histories.LOC01_LEONOR.size() == 2, "NPC histories separate")
	check(not evidence.record_dialogue("medical_report", "hermano_gabriel", "LOC01", "¿Qué indica la herida?", 2), "Wrong witness rejected")
	panel.open_conversation("LOC01")
	panel.submit("¿Qué dice la comunidad?")
	check(evidence.has_evidence("monastery_claim"), "Abbot still available")
	map.state.learner.successful_contexts["present"] = ["innkeeper_prototype", "lucio_salcedo", "hermano_gabriel", "leonor_valera"]
	var decoded := Save.decode(Save.snapshot(map.state))
	check(decoded.has("state"), "Four NPC learner contexts save")
	check(decoded.has("state") and decoded.state.evidence.progress() == evidence.progress(), "New testimony persists")
	map.notebook.open_journal(map.state)
	check(not map.notebook.body.text.contains("deliberate_lie"), "Journal does not expose author tags")
	map.notebook.close()
	# In-flight response keeps the original witness and uses request-time eligibility.
	panel.client.queue_free()
	var fake := FakeClient.new()
	panel.client = fake
	panel.add_child(fake)
	fake.config.dev_flags.offline_mode = false
	fake.completed.connect(panel._on_reply)
	panel.open_conversation("LOC01_LEONOR")
	panel.submit("Hola")
	check(panel.speaker.disabled, "Speaker selector locked during request")
	panel.open_conversation("LOC01_GABRIEL")
	fake._finish({})
	check(panel.histories.LOC01_LEONOR.back().player == "Hola", "Late reply stays with source NPC")
	check(not panel.speaker.disabled, "Selector restored after response")
	panel.open_conversation("LOC01_GABRIEL")
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://opening-witnesses-preview.png")
	map.queue_free()
	await process_frame
	print("Opening witnesses checks: %d, failures: %d" % [checks, failures])
	quit(1 if failures else 0)
