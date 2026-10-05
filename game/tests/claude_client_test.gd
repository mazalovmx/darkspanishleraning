extends SceneTree
const Client = preload("res://src/claude/claude_client.gd")
class FakeClient extends Client:
	var key := "test-only"
	func _api_key() -> String:
		return key
	func _send() -> void:
		attempts += 1

var checks := 0
var failures := 0
var results: Array = []

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func valid() -> Dictionary:
	return {"npc_reply": "Buenos días. ¿Qué necesita?", "language": {
		"meaning_understood": true, "confidence": 0.8, "errors": [],
		"successful_grammar": ["present"], "new_vocabulary": ["pan"]},
		"conversation": {"player_intent": "greeting", "npc_attitude_delta": 0,
		"suggested_unlock": null, "difficulty_observation": "comfortable"}}

func envelope(data: Variant, stop := "end_turn") -> PackedByteArray:
	return JSON.stringify({"content": [{"type": "text", "text": JSON.stringify(data)}],
		"stop_reason": stop}).to_utf8_buffer()

func run() -> void:
	check(not Client.parse_response(envelope(valid())).is_empty(), "Valid Messages response accepted")
	for raw in ["garbage", "null", "[]", "{}", "{\"content\":42}", "x".repeat(65537)]:
		check(Client.parse_response(raw.to_utf8_buffer()).is_empty(), "Malformed envelope rejected")
	check(Client.parse_response(envelope(valid(), "max_tokens")).is_empty(), "Truncated completion rejected")
	for field in valid():
		var proposal := valid()
		proposal.erase(field)
		check(not Client.valid_proposal(proposal), "Missing top field rejected")
	for group in ["language", "conversation"]:
		for field in valid()[group]:
			var proposal := valid()
			proposal[group].erase(field)
			check(not Client.valid_proposal(proposal), "Missing nested field rejected")
	for value in [null, false, 7, "", " ", "x".repeat(2001)]:
		var proposal := valid()
		proposal.npc_reply = value
		check(not Client.valid_proposal(proposal), "Invalid reply rejected")
	for value in [-0.1, 1.1, "0.5", true, null, INF, NAN]:
		var proposal := valid()
		proposal.language.confidence = value
		check(not Client.valid_proposal(proposal), "Invalid confidence rejected")
	for value in ["true", 1, null]:
		var proposal := valid()
		proposal.language.meaning_understood = value
		check(not Client.valid_proposal(proposal), "Meaning flag must be boolean")
	for value in ["present", [1], [null], [""], {}]:
		var proposal := valid()
		proposal.language.successful_grammar = value
		check(not Client.valid_proposal(proposal), "Invalid tags rejected")
	for value in [null, {}, [1], [{}], [{"type": "present", "original": "yo es", "better": "yo soy", "severity": "invalid"}]]:
		var proposal := valid()
		proposal.language.errors = value
		check(not Client.valid_proposal(proposal), "Invalid errors rejected")
	var corrected := valid()
	corrected.language.errors = [{"type": "ser", "original": "yo es", "better": "yo soy", "severity": "important"}]
	check(Client.valid_proposal(corrected), "Structured correction accepted")
	var malicious := valid()
	malicious.conversation.suggested_unlock = "invented_clue"
	check(Client.valid_proposal(malicious), "Unlock string passes syntax; canonical verifier checks authorization")
	malicious = valid()
	malicious.conversation.npc_attitude_delta = true
	check(not Client.valid_proposal(malicious), "Boolean attitude rejected")
	malicious.conversation.npc_attitude_delta = 5
	check(not Client.valid_proposal(malicious), "Relationship mutation proposal rejected")
	malicious = valid()
	malicious["gold"] = 100
	check(not Client.valid_proposal(malicious), "Unexpected top-level state fields rejected")

	var client := FakeClient.new()
	root.add_child(client)
	client.completed.connect(func(data: Dictionary): results.append(data))
	check(client.http.timeout == 20.0 and client.http.max_redirects == 0, "Timeout and no redirects configured")
	client.key = ""
	client.request_reply({})
	check(results.size() == 1 and results.back().is_empty() and client.attempts == 0, "Missing key falls back without HTTP")
	client.key = "test-only"
	client.config.dev_flags.offline_mode = true
	client.request_reply({})
	check(results.size() == 2 and client.attempts == 0, "Explicit offline mode bypasses HTTP")
	client.config.dev_flags.offline_mode = false
	client.request_reply({"player_message": "Hola"})
	client.request_reply({"player_message": "Duplicate"})
	check(client.busy and client.attempts == 1, "One in-flight request")
	var request: Dictionary = JSON.parse_string(client.payload)
	check(request.messages.size() == 1 and not request.has("temperature"), "One messages call with no legacy sampling fields")
	check(not client.payload.contains("test-only"), "Key is not in prompt payload")
	client.http.request_completed.emit(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), envelope(valid()))
	check(results.size() == 3 and not results.back().is_empty() and client.attempts == 1, "Success uses one attempt")
	check(not client.busy and client.payload.is_empty(), "Success clears busy and prompt")
	for result in [HTTPRequest.RESULT_TIMEOUT, HTTPRequest.RESULT_CANT_CONNECT, HTTPRequest.RESULT_SUCCESS]:
		client.request_reply({})
		client.http.request_completed.emit(result, 503, PackedStringArray(), PackedByteArray())
		await process_frame
		check(client.attempts == 2 and client.busy, "Transport/server failure retries once")
		client.http.request_completed.emit(result, 503, PackedStringArray(), PackedByteArray())
		check(not client.busy and results.back().is_empty(), "Second failure returns fallback")
	client.request_reply({})
	client.http.request_completed.emit(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), "not JSON".to_utf8_buffer())
	await process_frame
	check(client.attempts == 2, "Invalid schema retries once")
	client.http.request_completed.emit(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), envelope(valid()))
	check(not results.back().is_empty(), "Valid retry recovers")
	client.queue_free()
	await process_frame

	var map = load("res://src/world/world_map.tscn").instantiate()
	root.add_child(map)
	await process_frame
	var panel = map.dialogue
	panel.client.queue_free()
	var fake := FakeClient.new()
	panel.client = fake
	panel.add_child(fake)
	fake.completed.connect(panel._on_reply)
	map.state.move_to(Vector2i(6, 11), true)
	map._open_poi(Vector2i(6, 11))
	panel.submit("Hola")
	check(fake.busy and not panel.input.editable, "UI locks submit while waiting")
	map._close_poi()
	map.state.move_to(Vector2i(7, 10), true)
	map.state.move_to(Vector2i(12, 10), true)
	map._open_poi(Vector2i(12, 10))
	fake.http.request_completed.emit(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), envelope(valid()))
	check(panel.histories.LOC11.size() == 1 and panel.histories.LOC01.is_empty(), "Late reply remains with original NPC")
	check(not panel.transcript.text.contains("Qué necesita"), "Late reply does not replace current conversation")
	panel.submit("No sé")
	fake.http.request_completed.emit(HTTPRequest.RESULT_TIMEOUT, 0, PackedStringArray(), PackedByteArray())
	await process_frame
	fake.http.request_completed.emit(HTTPRequest.RESULT_TIMEOUT, 0, PackedStringArray(), PackedByteArray())
	check(panel.histories.LOC01.back().reply == panel.conversations.LOC01.fallback, "UI recovers with authored fallback")
	check(panel.input.editable and not fake.busy, "Fallback restores input")
	map.queue_free()
	await process_frame
	print("Claude client checks: %d, failures: %d" % [checks, failures])
	quit(1 if failures else 0)
