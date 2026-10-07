extends SceneTree
## Data-driven golden conversations (master spec section 39). Each case feeds a fake
## model reply through the real parser, verifier, learner and dialogue panel.
const Client = preload("res://src/claude/claude_client.gd")
const World = preload("res://src/world/world_state.gd")
const BASELINE := 0.5
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

func proposal(fields: Dictionary) -> Dictionary:
	return {"npc_reply": fields.get("reply", "Texto del modelo que no es prueba canónica."), "language": {
		"meaning_understood": fields.get("understood", true), "confidence": fields.get("confidence", 0.9),
		"errors": fields.get("errors", []), "successful_grammar": fields.get("success", []), "new_vocabulary": []},
		"conversation": {"player_intent": fields.get("intent", "unknown"), "npc_attitude_delta": fields.get("attitude", 0),
		"suggested_unlock": fields.get("unlock"), "difficulty_observation": "comfortable"}}

# Wraps model text in the API envelope so the production parser decides what survives.
func parsed(model: Variant) -> Dictionary:
	if model == null:
		return {}
	var text: String = model if model is String else JSON.stringify(proposal(model))
	return Client.parse_response(JSON.stringify({"stop_reason": "end_turn", "content": [{"type": "text", "text": text}]}).to_utf8_buffer())

func score(state: RefCounted, tag: String) -> float:
	return state.learner.verbs[tag.trim_prefix("verb:")] if tag.begins_with("verb:") else state.learner.grammar[tag]

func run() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/dialogue_golden.json"))
	check(data.cases.size() >= 30, "At least thirty golden conversations")
	var map = load("res://src/world/world_map.tscn").instantiate()
	map.persistence_enabled = false
	root.add_child(map)
	await process_frame
	var panel = map.dialogue
	panel.client.queue_free()
	var fake := FakeClient.new()
	panel.client = fake
	panel.add_child(fake)
	fake.completed.connect(panel._on_reply)
	var names := {}
	for case: Dictionary in data.cases:
		var label: String = case.name
		check(not names.has(label), "Unique case name: " + label)
		names[label] = true
		map._adopt(World.new())
		panel.histories.clear()
		var state = map.state
		var proof := {}
		for id: String in case.evidence:
			var node: Dictionary = state.evidence.definitions[id]
			proof[id] = {"found_day": 1, "classification": node.classification, "spanish_note": node.language.sample}
		check(state.evidence.restore(proof, state.day), "Fixture evidence is canonical: " + label)
		var expect: Dictionary = case.expect
		for tag: String in expect.get("delta", {}):
			if tag.begins_with("verb:"):
				state.learner.verbs[tag.trim_prefix("verb:")] = BASELINE
			else:
				state.learner.grammar[tag] = BASELINE
		var scene: String = panel.scene_for(case.conversation)
		for location: Dictionary in state.locations:
			if location.id == scene:
				state.hero_cell = Vector2i(location.position[0], location.position[1])
		state._reveal_from(state.hero_cell)
		map._open_poi(state.hero_cell)
		panel.open_conversation(case.conversation)
		var before: Array = state.evidence.progress().keys()
		var resources: Dictionary = state.resources.duplicate()
		var day: int = state.day
		var fallback: String = panel.reply_for(case.conversation, str(case.player).strip_edges().left(300))
		for turn in int(case.get("times", 1)):
			panel.submit(case.player)
			check(fake.busy, "Request reaches the transport: " + label)
			fake._finish(parsed(case.model))
		var history: Array = panel.histories[case.conversation]
		check(history.size() == int(case.get("times", 1)) and not fake.busy, "Every turn completes: " + label)
		var reply: String = history.back().reply
		var gained: Array = state.evidence.progress().keys().filter(func(id): return id not in before)
		check(gained == ([] if expect.unlock == null else [expect.unlock]), "Evidence change is exactly the expected one: " + label)
		check(reply.contains("queda anotada") == (expect.unlock != null), "The reply announces a record only when one was made: " + label)
		check(state.resources == resources and state.day == day and state.campaign.records.is_empty(), "No other canonical state changes: " + label)
		for text: String in expect.get("reply_contains", []):
			check(reply.contains(text), "Reply contains '%s': %s" % [text, label])
		for text: String in expect.get("reply_excludes", []):
			check(not reply.contains(text), "Reply excludes '%s': %s" % [text, label])
		if expect.get("fallback", false):
			check(reply == fallback, "Authored fallback used: " + label)
		if expect.has("feedback_contains"):
			check(panel.feedback.text.contains(expect.feedback_contains), "Feedback shows '%s': %s" % [expect.feedback_contains, label])
		for tag: String in expect.get("delta", {}):
			check(is_equal_approx(score(state, tag), BASELINE + float(expect.delta[tag])), "Mastery change for %s: %s" % [tag, label])
		if expect.has("player_max"):
			check(str(history.back().player).length() <= int(expect.player_max), "Stored message is bounded: " + label)
		map._close_poi()
	print("Golden conversation checks: %d, failures: %d" % [checks, failures])
	quit(1 if failures else 0)
