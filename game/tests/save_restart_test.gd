extends SceneTree
const Save = preload("res://src/save/save_game.gd")
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or not args[1].begins_with("user://save_restart_") or "/" in args[1].trim_prefix("user://"):
		quit(1)
		return
	var path: String = args[1]
	if args[0] == "--write":
		var state = preload("res://src/world/world_state.gd").new()
		state.move_to(Vector2i(6, 11), true)
		state.end_turn()
		state.learner.observe({"meaning_understood": true, "confidence": 0.9, "errors": [],
			"successful_grammar": ["present"], "new_vocabulary": ["sueño"]},
			"Tengo sueño", "innkeeper_prototype", 2)
		var error: String = Save.write_save(state, path)
		print("Restart write: ", "PASS" if error.is_empty() else "FAIL")
		quit(0 if error.is_empty() else 1)
	elif args[0] == "--read":
		var result := Save.read_save(path)
		var ok := result.has("state")
		if ok:
			var state = result.state
			ok = state.day == 2 and state.hero_cell == Vector2i(6, 11)
			ok = ok and is_equal_approx(state.learner.grammar.present, 0.05)
			ok = ok and state.learner.vocabulary == ["sueño"] and state.learner.recent_messages == ["tengo sueño"]
		print("Restart read: ", "PASS" if ok else "FAIL")
		DirAccess.remove_absolute(path)
		quit(0 if ok else 1)
	else:
		quit(1)
