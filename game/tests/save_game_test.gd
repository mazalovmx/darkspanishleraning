extends SceneTree
const Save = preload("res://src/save/save_game.gd")
const World = preload("res://src/world/world_state.gd")
var checks := 0
var failures := 0
var test_dir := "user://save_test_%d" % OS.get_process_id()
var path := test_dir + "/save.json"
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func same(a: Variant, b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float):
		return abs(a - b) <= 1e-12
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size():
			return false
		for key in a:
			if not b.has(key) or not same(a[key], b[key]):
				return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not same(a[i], b[i]):
				return false
		return true
	return a == b
func put(text: String, target := "") -> void:
	var file := FileAccess.open(path if target.is_empty() else target, FileAccess.WRITE)
	file.store_string(text)
	file.close()
func evaluation() -> Dictionary:
	return {"meaning_understood": true, "confidence": 0.9, "errors": [],
		"successful_grammar": ["present", "verb:tener"], "new_vocabulary": ["pan"]}
func run() -> void:
	DirAccess.make_dir_absolute(test_dir)
	var state := World.new()
	state.move_to(Vector2i(6, 11), true)
	state.end_turn()
	state.move_to(Vector2i(7, 10), true)
	state.move_to(Vector2i(12, 10), true)
	state.learner.observe(evaluation(), "Tengo pan", "innkeeper_prototype", 1)
	state.learner.observe(evaluation(), "Tengo agua", "lucio_salcedo", 2)
	var error := evaluation()
	error.errors = [{"type": "present|verb:tener", "original": "Yo tiene", "better": "Yo tengo", "severity": "important"}]
	state.learner.observe(error, "Yo tiene", "lucio_salcedo", 2)
	var original := Save.snapshot(state)
	check(Save.read_save(path).error == "missing", "Missing save is a normal state")
	check(Save.write_save(state, path).is_empty(), "First save succeeds")
	check(not FileAccess.file_exists(path + ".tmp"), "Successful replacement consumes temporary file")
	var loaded: Dictionary = Save.read_save(path)
	check(loaded.has("state"), "File loads into separate state")
	if not loaded.has("state"):
		quit(1)
		return
	check(same(Save.snapshot(loaded.state), original), "All implemented world and learner fields round-trip")
	for y in 20:
		for x in 20:
			var cell := Vector2i(x, y)
			check(loaded.state.fog_at(cell) == state.fog_at(cell), "Exploration and current visibility reconstructed")
	check(loaded.state.path_to(Vector2i(6, 11), true) == state.path_to(Vector2i(6, 11), true), "Known weighted pathfinding rebuilt")
	var mastery: float = loaded.state.learner.grammar.present
	loaded.state.learner.observe(evaluation(), "TENGO PAN", "innkeeper_prototype", 2)
	check(loaded.state.learner.grammar.present == mastery, "Reload cannot farm repeated message")
	loaded.state.learner.grammar.present = 0.75
	check(state.learner.grammar.present != 0.75, "Load does not alias original learner")
	state.end_turn()
	check(Save.write_save(state, path).is_empty(), "Existing file can be replaced on this platform")
	check(Save.read_save(path).state.day == 3, "Replacement has newer state")
	var bytes := FileAccess.get_file_as_string(path)
	state.learner.grammar.present = 8
	check(Save.write_save(state, path) == "invalid_state", "Invalid live state not serialized")
	check(FileAccess.get_file_as_string(path) == bytes, "Failed validation preserves previous save")
	state.learner.grammar.present = original.learner.grammar.present
	check(Save.write_save(state, test_dir + "/missing/save.json") == "write", "Unwritable/missing parent fails without truncation")
	DirAccess.make_dir_absolute(test_dir + "/blocked")
	check(Save.write_save(state, test_dir + "/blocked") == "replace", "Replacement failure reported")
	check(DirAccess.dir_exists_absolute(test_dir + "/blocked"), "Failed replace preserves destination")
	for value in [null, [], {}, true, 3]:
		check(not Save.decode(value).has("state"), "Non-snapshot rejected")
	for field: String in original:
		var bad := original.duplicate(true)
		bad.erase(field)
		check(not Save.decode(bad).has("state"), "Missing field rejected")
	var remembered := original.duplicate(true)
	remembered.npc_memory = {"lucio_salcedo": {"count": 2, "last_day": 1, "topics": ["ask_identity"]}}
	var recalled := Save.decode(JSON.parse_string(JSON.stringify(remembered)))
	check(recalled.has("state") and recalled.state.npc_memory.lucio_salcedo.count == 2 and typeof(recalled.state.npc_memory.lucio_salcedo.count) == TYPE_INT and Save.snapshot(recalled.state).npc_memory == remembered.npc_memory, "NPC memory survives a JSON round trip")
	for forged: Variant in [null, [], {"stranger": {"count": 1, "last_day": 1, "topics": []}}, {"lucio_salcedo": {"count": 0, "last_day": 1, "topics": []}}, {"lucio_salcedo": {"count": 1, "last_day": 99, "topics": []}}, {"lucio_salcedo": {"count": 1, "last_day": 1, "topics": ["invented_topic"]}}, {"lucio_salcedo": {"count": 1, "last_day": 1, "topics": [], "summary": "x"}}]:
		var bad := original.duplicate(true)
		bad.npc_memory = forged
		check(not Save.decode(bad).has("state"), "Forged NPC memory rejected")
	for value in [true, "1", 0, Save.VERSION + 1, 1.5]:
		var bad := original.duplicate(true)
		bad.version = value
		check(not Save.decode(bad).has("state"), "Unknown or malformed version rejected")
	for value in [true, null, -1, 0, 1.5, 1000001]:
		var bad := original.duplicate(true)
		bad.day = value
		check(not Save.decode(bad).has("state"), "Invalid day rejected")
	for value in [null, true, [], [1], [1, 2, 3], [-1, 0], [20, 0], [true, 10], [1.5, 10], [13, 6]]:
		var bad := original.duplicate(true)
		bad.hero.cell = value
		check(not Save.decode(bad).has("state"), "Invalid/undiscovered hero cell rejected")
	for value in [null, true, -1, 19, 1.5]:
		var bad := original.duplicate(true)
		bad.hero.movement = value
		check(not Save.decode(bad).has("state"), "Invalid movement rejected")
	for value in [[], [[21, 1]], [[true, 1]], [null], original.explored + [original.explored[0]]]:
		var bad := original.duplicate(true)
		bad.explored = value
		check(not Save.decode(bad).has("state"), "Invalid fog rejected")
	for field in ["grammar", "verbs"]:
		for value in [null, {}, true]:
			var bad := original.duplicate(true)
			bad.learner[field] = value
			check(not Save.decode(bad).has("state"), "Missing mastery categories rejected")
		for value in [true, "0.5", -0.1, 1.1, INF, NAN]:
			var bad := original.duplicate(true)
			bad.learner[field][bad.learner[field].keys()[0]] = value
			check(not Save.decode(bad).has("state"), "Invalid mastery rejected")
	for field in ["errors", "successful_contexts"]:
		var bad := original.duplicate(true)
		bad.learner[field]["invented"] = {}
		check(not Save.decode(bad).has("state"), "Unknown learner tags rejected")
	for value in [true, {}, {"count": 1, "last_seen_day": 999, "examples": ["error"]},
			{"count": 0, "last_seen_day": 1, "examples": ["error"]},
			{"count": 1, "last_seen_day": 1, "examples": []}]:
		var bad := original.duplicate(true)
		bad.learner.errors.present = value
		check(not Save.decode(bad).has("state"), "Malformed error history rejected")
	for value in [[], ["unknown_npc"], ["lucio_salcedo", "lucio_salcedo"], true]:
		var bad := original.duplicate(true)
		bad.learner.successful_contexts.present = value
		check(not Save.decode(bad).has("state"), "Malformed learner context rejected")
	for field in ["vocabulary", "recent_messages"]:
		for value in [true, [1], [""], ["repeat", "repeat"], ["x".repeat(301)]]:
			var bad := original.duplicate(true)
			bad.learner[field] = value
			check(not Save.decode(bad).has("state"), "Invalid bounded text memory rejected")
	var bad := original.duplicate(true)
	bad.learner.block = "subjunctive"
	check(not Save.decode(bad).has("state"), "Save cannot introduce an unlocked curriculum block")
	bad = original.duplicate(true)
	bad.map_id = "other_map"
	check(not Save.decode(bad).has("state"), "Incompatible map rejected")
	bad = original.duplicate(true)
	bad.api_key = "test-not-a-credential"
	check(not Save.decode(bad).has("state"), "Unexpected payload fields rejected")
	for raw in ["", "{", "null", "[]", "x".repeat(Save.MAX_BYTES + 1)]:
		put(raw)
		check(not Save.read_save(path).has("state"), "Corrupt or oversized file rejected")
		check(FileAccess.get_file_as_string(path) == raw, "Rejected file unchanged")
	Save.write_save(state, path)

	# Scene recreation emulates restart, using only this test's private save path.
	var map = load("res://src/world/world_map.tscn").instantiate()
	map.save_path = path
	root.add_child(map)
	await process_frame
	check(same(Save.snapshot(map.state), Save.snapshot(state)), "Startup resumes saved state")
	check(map.dialogue.world_state == map.state, "Dialogue bound to restored learner")
	check(map.save_button.text == "Guardar" and map.load_button.text == "Cargar", "Manual controls available")
	map._end_turn()
	check(Save.read_save(path).state.day == 4, "End day autosaves")
	map._open_poi(map.state.hero_cell)
	map.dialogue.client.config.dev_flags.offline_mode = true
	map.dialogue.submit("Hola")
	check(Save.read_save(path).state.hero_cell == map.state.hero_cell, "Completed location conversation autosaves")
	map._close_poi()
	var disk := FileAccess.get_file_as_string(path)
	map.dialogue.client.busy = true
	map.state.end_turn()
	map._save_game()
	map._load_game()
	check(FileAccess.get_file_as_string(path) == disk and map.state.day == 5, "In-flight reply blocks save/load")
	map.dialogue.client.busy = false
	var kept = map.state
	put("{broken")
	map._load_game()
	check(map.state == kept and map.save_locked, "Corruption leaves running state intact and blocks autosave")
	map._end_turn()
	check(FileAccess.get_file_as_string(path) == "{broken", "Autosave does not overwrite corrupt file")
	map._save_game()
	check(map.save_confirm.visible, "Replacing unreadable save needs explicit UI choice")
	check(FileAccess.get_file_as_string(path) == "{broken", "Prompt alone does not overwrite")
	map.save_confirm.hide()
	map._save_game(false, true)
	check(not map.save_locked and Save.read_save(path).state.day == 6, "Explicit replacement restores normal persistence")
	map.dialogue.histories.LOC01 = [{"player": "private turn", "reply": "private reply"}]
	map.dialogue.last_feedback.LOC01 = "stale"
	map._load_game()
	check(not JSON.stringify(map.dialogue.histories).contains("private turn") and map.dialogue.last_feedback.is_empty(), "Load drops the transcript said after the save and stale feedback")
	check(not FileAccess.get_file_as_string(path).contains("private turn"), "Raw dialogue not saved")
	disk = FileAccess.get_file_as_string(path)
	kept = map.state
	map.new_button.pressed.emit()
	check(map.new_confirm.visible and map.state == kept and FileAccess.get_file_as_string(path) == disk, "New game asks before replacing progress")
	map.new_confirm.hide()
	map.dialogue.client.busy = true
	map._new_game()
	check(map.state == kept, "In-flight reply blocks new game")
	map.dialogue.client.busy = false
	map.new_confirm.confirmed.emit()
	check(map.state != kept and map.state.day == 1 and map.state.evidence.progress().is_empty() and map.dialogue.world_state == map.state, "Confirmed new game starts from the beginning")
	check(Save.read_save(path).state.day == 1 and FileAccess.get_file_as_string(path + ".bak") == disk, "New game saves itself and keeps the previous file")
	kept = map.state
	map.queue_free()
	await process_frame
	var restarted = load("res://src/world/world_map.tscn").instantiate()
	restarted.save_path = path
	root.add_child(restarted)
	await process_frame
	check(same(Save.snapshot(restarted.state), Save.snapshot(kept)), "Second scene restores same snapshot after first is destroyed")
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://save-preview.png")
	restarted.queue_free()
	await process_frame
	# Remove only explicitly owned test files, never the user's save slot.
	for target in [path, path + ".tmp", path + ".bak", test_dir + "/blocked.tmp"]:
		if FileAccess.file_exists(target):
			DirAccess.remove_absolute(target)
	DirAccess.remove_absolute(test_dir + "/blocked")
	DirAccess.remove_absolute(test_dir)
	print("Save/load checks: %d, failures: %d" % [checks, failures])
	quit(1 if failures else 0)
