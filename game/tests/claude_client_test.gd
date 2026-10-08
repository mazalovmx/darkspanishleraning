extends SceneTree
const Client = preload("res://src/claude/claude_client.gd")
class FakeClient extends Client:
	var key := "test-only"
	func _api_key() -> String:
		return key
	func _send() -> void:
		attempts += 1

# Every provider has a key; the balance check is answered by the test.
class ChainClient extends Client:
	var keys := {"anthropic": "a-test", "deepseek": "d-test", "nvidia": "n-test"}
	var balance_requests := 0
	func _key(name: String) -> String:
		return keys.get(name, "")
	func _send() -> void:
		attempts += 1
	func _request_balance() -> void:
		balance_requests += 1

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
	return wrapped(JSON.stringify(data), stop)

func wrapped(text: String, stop := "end_turn", tokens: Variant = 40) -> PackedByteArray:
	return JSON.stringify({"content": [{"type": "text", "text": text}],
		"stop_reason": stop, "usage": {"input_tokens": 900, "output_tokens": tokens}}).to_utf8_buffer()

func fail(client: Node, result: int, code: int) -> void:
	client.http.request_completed.emit(result, code, PackedStringArray(), PackedByteArray())

# Stands in for the retry delay elapsing.
func elapse(client: Node) -> void:
	client.retry_timer.stop()
	client.retry_timer.timeout.emit()

func run() -> void:
	check(not Client.parse_response(envelope(valid())).is_empty(), "Valid Messages response accepted")
	for raw in ["garbage", "null", "[]", "{}", "{\"content\":42}", "x".repeat(65537)]:
		check(Client.parse_response(raw.to_utf8_buffer()).is_empty(), "Malformed envelope rejected")
	check(Client.parse_response(envelope(valid(), "max_tokens")).is_empty(), "Truncated completion rejected")
	var json := JSON.stringify(valid())
	var fenced := "```json\n" + json + "\n```"
	for text in ["\n  " + json + " \n", fenced, "```\n" + json + "\n```", " ```JSON \n" + json + "```\n"]:
		check(Client.parse_response(wrapped(text)).get("npc_reply") == valid().npc_reply, "Whitespace or one whole-text fence is tolerated")
	for text in ["Claro: " + json, json + " Espero que ayude.", json + json, json + "\n" + json, json.left(json.length() - 1),
			"```json\n" + json, json + "\n```", fenced + "\nListo.", "Aquí:\n" + fenced, fenced + "\n" + fenced,
			"```python\n" + json + "\n```", "```json " + json + "```", "```json\n" + json.left(json.length() - 1) + "\n```",
			"```json\n[" + json + "]\n```", "```\n```", "``````", "```", ""]:
		check(Client.parse_response(wrapped(text)).is_empty(), "Prose, extra objects, truncation and broken fences rejected")
	check(Client.parse_response(wrapped(fenced, "max_tokens")).is_empty(), "Fence does not excuse a truncated completion")
	check(Client.parse_response(wrapped("```json\n{\"npc_reply\":\"Hola.\"}\n```")).is_empty(), "Fenced object still needs the strict schema")
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
	check(client.usage_stats() == {"requests": 1, "output_tokens": 40}, "Usage counts the answered request and its output tokens")
	client.usage_stats().requests = 99
	check(client.usage_stats().requests == 1, "Usage is handed out as a copy")
	check(client.retry_timer.one_shot and client.retry_timer.wait_time > 0.0 and client.retry_timer.wait_time <= 3.0, "Retry delay is short and bounded")
	for failure in [[HTTPRequest.RESULT_TIMEOUT, 0], [HTTPRequest.RESULT_CANT_CONNECT, 0], [HTTPRequest.RESULT_SUCCESS, 429],
			[HTTPRequest.RESULT_SUCCESS, 500], [HTTPRequest.RESULT_SUCCESS, 503], [HTTPRequest.RESULT_SUCCESS, 529]]:
		var before := results.size()
		client.request_reply({})
		fail(client, failure[0], failure[1])
		await process_frame
		check(client.attempts == 1 and client.busy and not client.retry_timer.is_stopped() and results.size() == before, "Retry waits for the delay and stays busy")
		client.request_reply({"player_message": "Duplicate"})
		check(client.attempts == 1, "No second turn starts during the delay")
		elapse(client)
		check(client.attempts == 2 and client.busy, "Transport/server failure retries once")
		fail(client, failure[0], failure[1])
		check(not client.busy and results.size() == before + 1 and results.back().is_empty(), "Second failure returns fallback")
		check(client.retry_timer.is_stopped() and client.attempts == 2, "No third attempt is scheduled")
	for code in [400, 401, 403, 404, 413]:
		var before := results.size()
		client.request_reply({})
		fail(client, HTTPRequest.RESULT_SUCCESS, code)
		check(not client.busy and client.attempts == 1 and client.retry_timer.is_stopped(), "Client error is not retried")
		check(results.size() == before + 1 and results.back().is_empty(), "Client error returns fallback at once")
		# A refused key or model is not asked again this session.
		check(client.exhausted.has("anthropic") == (code in [401, 403, 404]), "Key and model refusals skip the provider for the session")
		client.exhausted.clear()
	check(client.usage_stats() == {"requests": 1, "output_tokens": 40}, "Failed requests add no usage")
	client.request_reply({})
	client.http.request_completed.emit(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), "not JSON".to_utf8_buffer())
	check(client.attempts == 1 and client.busy, "Invalid schema waits before its retry")
	elapse(client)
	check(client.attempts == 2, "Invalid schema retries once")
	client.http.request_completed.emit(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), wrapped(fenced, "end_turn", 55))
	check(results.back().get("npc_reply") == valid().npc_reply, "Valid fenced retry recovers")
	check(client.usage_stats() == {"requests": 2, "output_tokens": 95}, "Unparseable reply is not counted; the retry is")
	for tokens in [null, "12", -5, 1e12, true]:
		client.request_reply({})
		client.http.request_completed.emit(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), wrapped(json, "end_turn", tokens))
	check(client.usage_stats() == {"requests": 7, "output_tokens": 95}, "Implausible token counts are ignored")
	check(client.usage_stats().keys() == ["requests", "output_tokens"], "Usage holds two numbers and nothing else")
	client.retry_timer.wait_time = 0.05
	client.request_reply({})
	fail(client, HTTPRequest.RESULT_TIMEOUT, 0)
	await create_timer(0.5).timeout
	check(client.attempts == 2 and client.busy, "Real timer fires the retry")
	fail(client, HTTPRequest.RESULT_TIMEOUT, 0)
	check(not client.busy, "Timed retry ends the turn")
	client.queue_free()
	await process_frame

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
	map.state.move_to(Vector2i(6, 11), true)
	map._open_poi(Vector2i(6, 11))
	var course = map.state.learner.curriculum
	var slot: int = course.cursor
	var recent: Array = course.recent_focus.duplicate()
	fake.key = ""
	panel.submit("Hola")
	check(panel.histories.LOC11.size() == 1 and course.cursor == slot and course.recent_focus == recent, "Offline turn keeps its focus slot")
	fake.key = "test-only"
	panel.submit("Hola")
	check(course.cursor == slot + 1, "Sent turn reserves a focus slot")
	fail(fake, HTTPRequest.RESULT_SUCCESS, 401)
	check(panel.histories.LOC11.size() == 2 and course.cursor == slot and course.recent_focus == recent, "Failed turn returns its focus slot")
	# A refused key skips the provider for the session; the fake's key is fine again.
	fake.exhausted.clear()
	var invented := valid()
	invented.conversation.suggested_unlock = "invented_clue"
	panel.submit("Hola")
	fake.http.request_completed.emit(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), envelope(invented))
	check(panel.histories.LOC11.size() == 3 and course.cursor == slot and course.recent_focus == recent, "Refused proposal returns its focus slot")
	panel.histories.LOC11.clear()
	panel.submit("Hola")
	check(fake.busy and not panel.input.editable, "UI locks submit while waiting")
	map._close_poi()
	map.state.move_to(Vector2i(7, 10), true)
	map.state.move_to(Vector2i(12, 10), true)
	map._open_poi(Vector2i(12, 10))
	fake.http.request_completed.emit(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), envelope(valid()))
	check(panel.histories.LOC11.size() == 1 and panel.histories.LOC01.is_empty(), "Late reply remains with original NPC")
	check(not panel.transcript.text.contains("Qué necesita"), "Late reply does not replace current conversation")
	check(course.cursor == slot + 1 and course.recent_focus.size() == recent.size() + 1, "Applied proposal consumes exactly one focus slot")
	panel.submit("No sé")
	fail(fake, HTTPRequest.RESULT_TIMEOUT, 0)
	check(fake.busy and not panel.input.editable, "UI stays locked during the retry delay")
	elapse(fake)
	fail(fake, HTTPRequest.RESULT_TIMEOUT, 0)
	check(course.cursor == slot + 1, "Two failed attempts return the focus slot")
	check(panel.histories.LOC01.back().reply == panel.conversations.LOC01.fallback, "UI recovers with authored fallback")
	check(panel.input.editable and not fake.busy, "Fallback restores input")
	# Review mode: one gated sentence, language part only, feedback never state.
	var language: Dictionary = valid().language
	language.errors = [{"type": "present", "original": "los cuaderno", "better": "los cuadernos", "severity": "minor"},
		{"type": "present", "original": "Tomas", "better": "Tomás", "severity": "minor"}]
	check(not Client.parse_review(envelope(language)).is_empty(), "Valid review accepted")
	check(Client.parse_review(envelope(valid())).is_empty(), "A full NPC proposal is not a review")
	var bad_review: Dictionary = language.duplicate(true)
	bad_review.errors[0].severity = "fatal"
	check(Client.parse_review(envelope(bad_review)).is_empty(), "Invalid review rejected")
	var lenient: String = Client.review_text(language, false)
	check(lenient.contains("los cuaderno → los cuadernos") and not lenient.contains("Tomás"), "Tilde-only correction dropped outside the last block")
	check(Client.review_text(language, true).contains("Tomas → Tomás"), "Tilde correction kept in the last block")
	check(Client.review_text({}, false).is_empty(), "No review, no feedback line")
	var reviewer := FakeClient.new()
	root.add_child(reviewer)
	await process_frame
	reviewer.config.dev_flags.offline_mode = false
	reviewer.config["claude_model"] = "test-model"
	var reviews: Array = []
	reviewer.reviewed.connect(func(data: Dictionary): reviews.append(data))
	reviewer.completed.connect(func(_data: Dictionary): reviews.append("wrong signal"))
	reviewer.request_review("Los cuaderno son ilícitos.", "Explica qué cambia el documento.", {})
	var sent: Dictionary = JSON.parse_string(reviewer.payload)
	check(reviewer.busy and sent.system == Client.REVIEW_PROMPT and sent.messages[0].content.contains("learner_sentence"), "Review uses its own prompt")
	reviewer.http.request_completed.emit(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), envelope(language))
	check(reviews.size() == 1 and reviews[0] is Dictionary and reviews[0].errors.size() == 2 and not reviewer.busy, "Review answered on its own signal")
	reviewer.key = ""
	reviewer.request_review("Hola.", "Saluda.", {})
	check(reviews.size() == 2 and reviews[1].is_empty() and not reviewer.busy, "Offline review returns nothing at once")
	reviewer.queue_free()
	# Provider chain: Anthropic, then DeepSeek (balance checked first), then NVIDIA.
	var chain := ChainClient.new()
	root.add_child(chain)
	await process_frame
	chain.config.dev_flags.offline_mode = false
	chain.config["claude_model"] = "claude-test"
	chain.config["provider_order"] = ["anthropic", "deepseek", "nvidia"]
	var answers: Array = []
	chain.completed.connect(func(data: Dictionary): answers.append(data))
	chain.request_reply({"player_message": "Hola"})
	check(chain.provider == "anthropic" and JSON.parse_string(chain.payload).system == Client.SYSTEM_PROMPT, "Anthropic is tried first")
	chain.http.request_completed.emit(HTTPRequest.RESULT_SUCCESS, 402, PackedStringArray(), JSON.stringify({"type": "error", "error": {"type": "billing_error"}}).to_utf8_buffer())
	check(chain.exhausted.has("anthropic") and chain.balance_requests == 1 and chain.busy, "No Anthropic budget: DeepSeek's balance is checked")
	chain._on_balance(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify({"is_available": true, "balance_infos": []}).to_utf8_buffer())
	var chained: Dictionary = JSON.parse_string(chain.payload)
	check(chain.provider == "deepseek" and chained.model == "deepseek-flash" and chained.thinking == {"type": "disabled"} and chained.response_format == {"type": "json_object"} and chained.messages[0].role == "system" and chained.messages[1].content.contains("Hola"), "DeepSeek gets an OpenAI-format request")
	var chat := JSON.stringify({"choices": [{"finish_reason": "stop", "message": {"role": "assistant", "content": JSON.stringify(valid())}}], "usage": {"completion_tokens": 30}})
	chain.http.request_completed.emit(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), chat.to_utf8_buffer())
	check(answers.size() == 1 and answers[0].get("npc_reply", "") == valid().npc_reply, "A DeepSeek chat answer goes through the same validation")
	chain.request_reply({"player_message": "Otra vez"})
	check(chain.provider == "deepseek" and chain.balance_requests == 1, "Anthropic stays skipped and the balance is checked once")
	chain.http.request_completed.emit(HTTPRequest.RESULT_SUCCESS, 402, PackedStringArray(), PackedByteArray())
	check(chain.provider == "nvidia" and JSON.parse_string(chain.payload).model == "deepseek-ai/deepseek-v4-flash", "DeepSeek out of balance: NVIDIA answers")
	chain.http.request_completed.emit(HTTPRequest.RESULT_SUCCESS, 402, PackedStringArray(), PackedByteArray())
	check(answers.size() == 2 and answers[1].is_empty() and not chain.busy, "With no provider left the turn falls back offline")
	chain.request_reply({"player_message": "¿Hay alguien?"})
	check(answers.size() == 3 and answers[2].is_empty() and chain.attempts == 0, "Later turns stay offline without a request")
	var empty := ChainClient.new()
	root.add_child(empty)
	await process_frame
	empty.config.dev_flags.offline_mode = false
	empty.config["claude_model"] = "claude-test"
	empty.config["provider_order"] = ["anthropic", "deepseek", "nvidia"]
	empty.exhausted["anthropic"] = true
	empty.busy = false
	empty.balance_checked = false
	var skipped: Array = []
	empty.completed.connect(func(data: Dictionary): skipped.append(data))
	empty.request_reply({"player_message": "Hola"})
	empty._on_balance(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify({"is_available": false}).to_utf8_buffer())
	check(empty.exhausted.has("deepseek") and empty.provider == "nvidia", "An empty DeepSeek balance skips straight to NVIDIA")
	check(Client._out_of_budget("anthropic", 400, "Your credit balance is too low to access the Anthropic API.".to_utf8_buffer()) and not Client._out_of_budget("deepseek", 400, "credit balance".to_utf8_buffer()), "Anthropic's low-credit 400 counts as no budget")
	# Default order: DeepSeek, then Claude; NVIDIA only when listed.
	var plain := ChainClient.new()
	root.add_child(plain)
	await process_frame
	plain.config.dev_flags.offline_mode = false
	plain.config["claude_model"] = "claude-test"
	plain.balance_checked = true
	check(plain.order() == ["deepseek", "anthropic"], "DeepSeek first, Claude second, no NVIDIA by default")
	var turns: Array = []
	plain.completed.connect(func(data: Dictionary): turns.append(data))
	plain.request_reply({"player_message": "Hola"})
	check(plain.provider == "deepseek" and plain.turn_attempts == 1, "DeepSeek answers first")
	fail(plain, HTTPRequest.RESULT_SUCCESS, 503)
	elapse(plain)
	fail(plain, HTTPRequest.RESULT_SUCCESS, 503)
	check(plain.provider == "anthropic" and plain.busy and plain.turn_attempts == 3 and not plain.exhausted.has("deepseek"), "Two temporary failures move the turn to Claude")
	fail(plain, HTTPRequest.RESULT_SUCCESS, 503)
	check(not plain.busy and turns.size() == 1 and turns[0].is_empty() and plain.turn_attempts == 3 and plain.last_turn.reason == "limit", "Three requests per turn at most, then offline")
	plain.request_reply({"player_message": "Hola"})
	check(plain.provider == "deepseek", "A temporary failure skips a provider for one turn only")
	fail(plain, HTTPRequest.RESULT_SUCCESS, 401)
	check(plain.provider == "anthropic" and plain.exhausted.has("deepseek") and plain.busy, "A refused key moves to Claude at once")
	plain.http.request_completed.emit(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), envelope(valid()))
	check(turns.size() == 2 and turns[1].get("npc_reply", "") == valid().npc_reply, "Claude's answer is used once")
	check(plain.last_turn.provider == "anthropic" and plain.last_turn.model == "claude-test" and plain.last_turn.reason == "ok" and plain.last_turn.output_tokens == 40 and plain.last_turn.request_id == 2, "The turn's provider, model and tokens are noted")
	check(not JSON.stringify(plain.last_turn).contains("a-test") and not JSON.stringify(plain.last_turn).contains("Hola"), "No key or player text in the turn notes")
	plain.http.request_completed.emit(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), envelope(valid()))
	check(turns.size() == 2, "A late answer starts nothing")
	plain.exhausted.clear()
	plain.request_reply({"player_message": "Hola"})
	plain.turn_started -= int((Client.TURN_SECONDS + 1.0) * 1000.0)
	fail(plain, HTTPRequest.RESULT_SUCCESS, 503)
	check(not plain.busy and turns.size() == 3 and turns[2].is_empty() and plain.last_turn.reason == "limit", "The turn ends offline after its time limit")
	var nvidia_listed := ChainClient.new()
	nvidia_listed.config = {"provider_order": ["nvidia", "bogus", "nvidia"]}
	check(nvidia_listed.order() == ["nvidia"], "NVIDIA only when listed; unknown and repeated names ignored")
	nvidia_listed.free()
	plain.queue_free()
	chain.queue_free()
	empty.queue_free()
	map.queue_free()
	await process_frame
	print("Claude client checks: %d, failures: %d" % [checks, failures])
	quit(1 if failures else 0)
