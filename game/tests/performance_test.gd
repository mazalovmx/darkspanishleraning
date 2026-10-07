extends SceneTree
## Benchmark of map refresh, route preview, a day of travel and saving on the province.
## Headless timings of game logic only: nothing is drawn, so these are not FPS.
const Save = preload("res://src/save/save_game.gd")
const World = preload("res://src/world/world_state.gd")
# Budgets in milliseconds for the worst sample: three to five times the worst value measured on the
# (busy) development PC with the province fully explored. They catch regressions, not slow frames.
const BUDGETS := {"refresh": 5.0, "refresh_reveal": 60.0, "rebuild": 250.0, "preview": 30.0,
	"move_day": 2000.0, "write_save": 1200.0, "read_save": 1000.0}
var checks := 0
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func report(label: String, samples: Array, budget_key: String) -> void:
	var total := 0.0
	var worst := 0.0
	for sample: float in samples:
		total += sample
		worst = maxf(worst, sample)
	var budget: float = BUDGETS[budget_key]
	print("%-34s avg %8.3f ms  worst %8.3f ms  budget %6.1f ms  (n=%d)" % [label, total / samples.size(), worst, budget, samples.size()])
	check(worst <= budget, "%s worst %.3f ms exceeds %.1f ms" % [label, worst, budget])

func timed(action: Callable) -> float:
	var start := Time.get_ticks_usec()
	action.call()
	return (Time.get_ticks_usec() - start) / 1000.0

func run() -> void:
	root.size = Vector2i(1280, 720)
	var map = load("res://src/world/province_map.tscn").instantiate()
	map.persistence_enabled = false
	root.add_child(map)
	await process_frame
	var state: World = map.state
	var home: Vector2i = state.hero_cell
	# Fixture: walk the reveal radius over the province so most of it is explored.
	# Each band of the map is refreshed as it appears, like exploration during play.
	var samples: Array = []
	for y in range(3, 120, 6):
		for x in range(3, 160, 6):
			state._reveal_from(Vector2i(x, y))
		samples.append(timed(map._refresh))
	state._reveal_from(home)
	check(state.fog.size() > 15000, "Fixture explores most of the province")
	print("Explored cells: %d of %d" % [state.fog.size(), 160 * 120])
	report("_refresh, new band of ~960 cells", samples, "refresh_reveal")
	check(map.tiles.get_used_cells().size() == state.fog.size(), "Refresh paints every explored cell")
	samples.clear()
	for index in 50:
		samples.append(timed(map._refresh))
	report("_refresh, nothing new", samples, "refresh")
	check(map.tiles.get_used_cells().size() == state.fog.size(), "Repeated refresh keeps the painted tiles")

	samples.clear()
	for index in 5:
		samples.append(timed(map._adopt.bind(state)))
	report("_adopt full rebuild", samples, "rebuild")
	check(map.tiles.get_used_cells().size() == state.fog.size(), "Rebuild paints every explored cell")
	var names: Array = map.COLORS.keys()
	var correct := true
	for cell: Vector2i in state.fog:
		if map.tiles.get_cell_atlas_coords(cell) != Vector2i(names.find(state.terrain[cell.y][cell.x]), 0):
			correct = false
	check(correct, "Each painted tile matches its terrain")

	# Route preview towards explored cells near and far from the hero.
	map.selected = true
	var targets: Array[Vector2i] = []
	for cell: Vector2i in state.fog:
		if state.terrain_cost(cell) > 0 and (cell.x * 7 + cell.y * 13) % 311 == 0:
			targets.append(cell)
	samples.clear()
	var routed := 0
	for cell in targets:
		map.pointer = map.tiles.get_global_transform_with_canvas() * map.tiles.map_to_local(cell)
		samples.append(timed(map._update_preview))
		if map.preview.size() > 1:
			routed += 1
	check(routed > 10, "Preview fixture finds real routes")
	print("Preview targets: %d, with a route: %d" % [targets.size(), routed])
	report("_update_preview", samples, "preview")

	# A planned move, the end of the day and the refresh that follows, without saving.
	var near: Array[Vector2i] = []
	for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if state.terrain_cost(home + offset) > 0:
			near.append(home + offset)
	check(not near.is_empty(), "Hero has a walkable neighbour")
	samples.clear()
	var refresh_samples: Array = []
	var moved := 0
	for index in 12:
		if near.is_empty() or not state.ghosts.pending_encounter.is_empty():
			break
		var before: Vector2i = state.hero_cell
		var destination: Vector2i = home if before != home else near[0]
		var day: int = state.day
		samples.append(timed(func():
			state.move_to(destination, true)
			map._end_turn()))
		refresh_samples.append(timed(map._refresh))
		if state.day == day + 1 and state.hero_cell == destination:
			moved += 1
	check(moved >= 6, "Hero travels and days end during the benchmark (%d)" % moved)
	report("move + end of day (with refresh)", samples, "move_day")
	report("_refresh after a move", refresh_samples, "refresh")
	check(map.tiles.get_used_cells().size() == state.fog.size(), "Tiles follow exploration after moves")

	var path := "user://performance_test_%d.json" % OS.get_process_id()
	samples.clear()
	var read_samples: Array = []
	var saved := true
	for index in 5:
		var start := Time.get_ticks_usec()
		var error: String = Save.write_save(state, path)
		samples.append((Time.get_ticks_usec() - start) / 1000.0)
		start = Time.get_ticks_usec()
		var result: Dictionary = Save.read_save(path)
		read_samples.append((Time.get_ticks_usec() - start) / 1000.0)
		if not error.is_empty() or not result.has("state") or result.state.fog.size() != state.fog.size():
			saved = false
	check(saved, "Explored province saves and loads")
	if FileAccess.file_exists(path):
		print("Save size: %d bytes" % FileAccess.get_file_as_bytes(path).size())
	report("SaveGame.write_save", samples, "write_save")
	report("SaveGame.read_save", read_samples, "read_save")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".tmp"))
	check(not FileAccess.file_exists(path), "Benchmark save removed")

	if DisplayServer.get_name() != "headless":
		# Optional windowed sample; informative only, no budget.
		var frames := 0
		var start := Time.get_ticks_usec()
		while frames < 120:
			map.queue_redraw()
			await process_frame
			frames += 1
		print("Windowed: %d frames, avg %.2f ms per frame (vsync may cap this)" % [frames, (Time.get_ticks_usec() - start) / 1000.0 / frames])
	map.queue_free()
	await process_frame
	print("Headless timings are not FPS; budgets only catch regressions.")
	print("Performance checks: %d, failures: %d" % [checks, failures])
	quit(1 if failures else 0)
