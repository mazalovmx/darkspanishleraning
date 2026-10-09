extends SceneTree
const Client = preload("res://src/claude/claude_client.gd")
class CaptureClient extends Client:
	var captured: Dictionary = {}
	func request_reply(context: Dictionary) -> void:
		captured = context.duplicate(true)
		completed.emit({})
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
	var learner = preload("res://src/spanish/learner_profile.gd").new()
	var before: Dictionary = learner.curriculum.snapshot()
	check(learner.context().focus_verbs == ["estar", "haber", "ser"], "Stable initial focus follows taught course verbs")
	check(learner.context().recent_errors.is_empty(), "No invented error history")
	learner.verbs.estar = 0.8
	learner.errors["verb:tener"] = {"count": 3, "last_seen_day": 2, "examples": ["yo tiene"]}
	check(learner.context().focus_verbs[0] == "tener", "Recorded verb weakness gets priority")
	learner.errors.conditional = {"count": 99, "last_seen_day": 99, "examples": ["future block"]}
	for tag in ["ser_estar", "hay", "gender_articles", "present"]:
		learner.errors[tag] = {"count": 2, "last_seen_day": 3, "examples": ["old", "x".repeat(350), "new"]}
	var context: Dictionary = learner.context()
	check(context.recent_errors.size() == 4, "Error context is bounded")
	check(context.recent_errors[0].tag == "gender_articles", "Equal-day errors have deterministic order")
	for error: Dictionary in context.recent_errors:
		check(error.tag != "conditional", "Untaught tense excluded")
		check(error.examples.size() == 2 and error.examples[0].length() == 300 and error.examples[1] == "new", "Only latest bounded original examples")
	context.recent_errors[0].examples.clear()
	check(learner.errors.gender_articles.examples.size() == 3, "Context does not alias learner records")
	check(learner.curriculum.snapshot() == before, "Context selection never advances curriculum or awards mastery")
	var map = load("res://src/world/world_map.tscn").instantiate()
	map.persistence_enabled = false
	root.add_child(map)
	await process_frame
	check(map.state.move_to(Vector2i(6, 11), true), "Reach actual inn")
	map._open_poi(Vector2i(6, 11))
	var panel = map.dialogue
	panel.remove_child(panel.client)
	panel.client.queue_free()
	var client := CaptureClient.new()
	panel.client = client
	panel.add_child(client)
	client.completed.connect(panel._on_reply)
	for index in range(10):
		panel.histories.LOC11.append({"player": str(index), "reply": "Respuesta " + str(index)})
	var cursor: int = map.state.learner.curriculum.cursor
	panel.submit("Hola, ¿hay pan?")
	var sent: Dictionary = client.captured
	check(sent.scene.location_id == "LOC11" and sent.scene.conversation_location_id == "LOC11", "Request carries actual conversation place")
	check(sent.scene.name == map.state.location_at(map.state.hero_cell).name and sent.scene.day == map.state.day, "Name and day come from world state")
	check(sent.scene.keys().size() == 5 and not sent.scene.has("locations"), "Scene exposes no remote world catalog")
	check(sent.recent_dialogue.size() == 8 and sent.recent_dialogue[0].player == "2" and sent.recent_dialogue[7].player == "9", "Latest eight completed exchanges sent in order")
	check(sent.language_profile.has("focus_verbs") and sent.language_profile.has("recent_errors"), "Live request uses learner context additions")
	check(map.state.learner.curriculum.cursor == cursor, "Offline captured turn returns focus slot")
	check(not sent.has("relationship") and not sent.has("summary"), "No invented relationship or summary")
	map.queue_free()
	await process_frame
	print("Dialogue context checks: %s, failures: %s" % [checks, failures])
	quit(0 if failures == 0 else 1)