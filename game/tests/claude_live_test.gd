extends SceneTree
## Opt-in: sends one short real conversation (with the client's bounded retry).
func _initialize() -> void:
	if not "--live" in OS.get_cmdline_user_args():
		print("Live check skipped: requires --live and an environment key.")
		quit(2)
		return
	run.call_deferred()

func run() -> void:
	if OS.get_environment("ANTHROPIC_API_KEY").strip_edges().is_empty():
		print("Live check: missing key.")
		quit(2)
		return
	var map = load("res://src/world/world_map.tscn").instantiate()
	root.add_child(map)
	await process_frame
	map.state.move_to(Vector2i(6, 11), true)
	map._refresh()
	map._open_poi(Vector2i(6, 11))
	map.state.learner.verbs.tener = 0.5 # Test baseline for measuring a correction.
	var client = map.dialogue.client
	client.http.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray):
		print("Live transport result=%d HTTP=%d" % [result, code]))
	client.completed.connect(func(proposal: Dictionary):
		var success: bool = not proposal.is_empty() and map.dialogue.histories.LOC11.size() == 1 and map.dialogue.histories.LOC11[0].reply == proposal.npc_reply
		var language_ok: bool = success and not proposal.language.errors.is_empty() and map.dialogue.feedback.text.contains("Mejor:") and map.state.learner.verbs.tener < 0.5
		print("Live Spanish feedback check: %s" % ["PASS" if language_ok else "FAIL"])
		success = success and language_ok
		print("Live Claude UI check: %s; attempts=%d" % ["PASS" if success else "FAIL (authored fallback)", client.attempts])
		map.queue_free()
		quit(0 if success else 1))
	create_timer(50).timeout.connect(func():
		print("Live check deadline exceeded.")
		quit(1))
	map.dialogue.submit("Yo tiene pan. ¿Cómo llego al monasterio?")
