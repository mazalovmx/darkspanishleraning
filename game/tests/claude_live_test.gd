extends SceneTree
## Opt-in: sends one short real conversation (with the client's bounded retry).
## --provider=deepseek|anthropic|nvidia limits the chain to that provider, --model=<id>
## overrides its model; the check passes only when that provider and model answered.
func _initialize() -> void:
	if not "--live" in OS.get_cmdline_user_args():
		print("Live check skipped: requires --live and an environment key.")
		quit(2)
		return
	run.call_deferred()

func _option(name: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % name):
			return arg.get_slice("=", 1).strip_edges()
	return ""

func run() -> void:
	var Client = preload("res://src/claude/claude_client.gd")
	var only := _option("provider")
	if not only.is_empty() and not Client.PROVIDERS.has(only):
		print("Live check: unknown provider.")
		quit(2)
		return
	var env: String = Client.PROVIDERS[only].env if not only.is_empty() else "ANTHROPIC_API_KEY"
	if OS.get_environment(env).strip_edges().is_empty():
		print("Live check: missing key.")
		quit(2)
		return
	var map = load("res://src/world/world_map.tscn").instantiate()
	map.persistence_enabled = false
	root.add_child(map)
	await process_frame
	map.state.move_to(Vector2i(6, 11), true)
	map._refresh()
	map._open_poi(Vector2i(6, 11))
	map.state.learner.verbs.tener = 0.5 # Test baseline for measuring a correction.
	var client = map.dialogue.client
	if not only.is_empty():
		client.config["provider_order"] = [only]
		if not _option("model").is_empty():
			client.config[Client.PROVIDERS[only].model] = _option("model")
	var expected_model: String = str(client.config.get(Client.PROVIDERS[only].model, "")) if not only.is_empty() else ""
	client.http.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray):
		print("Live transport result=%d HTTP=%d" % [result, code]))
	client.completed.connect(func(proposal: Dictionary):
		var success: bool = not proposal.is_empty() and map.dialogue.histories.LOC11.size() == 1 and map.dialogue.histories.LOC11[0].reply == proposal.npc_reply
		var language_ok: bool = success and not proposal.language.errors.is_empty() and map.dialogue.feedback.text.contains("Mejor:") and map.state.learner.verbs.tener < 0.5
		print("Live Spanish feedback check: %s" % ["PASS" if language_ok else "FAIL"])
		success = success and language_ok
		# A provider-specific check never passes on another provider's answer.
		var answered: Dictionary = client.last_turn
		if not only.is_empty():
			success = success and answered.get("provider") == only and answered.get("model") == expected_model
		print("Live UI check: %s; provider=%s model=%s attempts=%d ms=%d" % ["PASS" if success else "FAIL (authored fallback)",
			answered.get("provider", ""), answered.get("model", ""), client.turn_attempts, int(answered.get("ms", 0))])
		map.queue_free()
		quit(0 if success else 1))
	create_timer(50).timeout.connect(func():
		print("Live check deadline exceeded.")
		quit(1))
	map.dialogue.submit("Yo tiene pan. ¿Cómo llego al monasterio?")
