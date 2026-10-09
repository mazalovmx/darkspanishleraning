extends SceneTree
## The played game multiplies daily movement (config "movement_scale"); worlds built
## directly keep the base value, which the other suites rely on.
const World = preload("res://src/world/world_state.gd")
const Party = preload("res://src/world/party_state.gd")
const Save = preload("res://src/save/save_game.gd")
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
	check(Party.movement_scale == 1 and World.movement_max() == 18, "A world built directly keeps the base movement")
	var base := World.new("province_160x120_v1")
	check(base.movement_remaining == 18, "Base hero starts with 18 points")
	var base_save: Dictionary = Save.snapshot(base)
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/game.json"))
	check(config.get("movement_scale") == 10.0, "The configuration asks for ten times the movement")
	var menu = load("res://src/ui/title_menu.tscn").instantiate()
	menu.save_path = "user://none_movement_scale.json"
	root.add_child(menu)
	await process_frame
	check(Party.movement_scale == 10 and World.movement_max() == 180, "Starting from the title menu applies the scale")
	menu.queue_free()
	var state := World.new("province_160x120_v1")
	check(state.movement_remaining == 180 and int(state.party.active().definition.movement_max) == 180, "Heroes of the played game have 180 points")
	# A route far beyond the old allowance is accepted in one day.
	var origin: Vector2i = state.hero_cell
	for step in range(0, 60, 2):
		for side in [-4, 0, 4]:
			if state.grid.region.has_point(origin + Vector2i(side, step)):
				state._reveal_from(origin + Vector2i(side, step))
	var far := Vector2i(-1, -1)
	for step in range(25, 60):
		var cell := origin + Vector2i(0, step)
		var path: Array[Vector2i] = state.path_to(cell, true)
		if path.size() >= 2 and state.path_cost(path) > 18 and state.path_cost(path) <= 180:
			far = cell
			break
	check(far.x >= 0 and state.move_to(far, true), "A route costing more than 18 and at most 180 is planned")
	state.end_turn()
	check(state.hero_cell == far and state.movement_remaining == 180 and state.day == 2, "The day resolves the long route and restores 180 points")
	var loaded: Dictionary = Save.decode(Save.snapshot(state))
	check(loaded.has("state") and loaded.state.movement_remaining == 180, "A save with 180 points is valid and restores them")
	check(Save.decode(base_save).has("state"), "A save written with the base movement still loads")
	var forged: Dictionary = Save.snapshot(state).duplicate(true)
	forged.hero.movement = 187
	check(not Save.decode(forged).has("state"), "Movement above the scaled allowance plus equipment is still rejected")
	Party.movement_scale = 1
	await process_frame
	print("Movement scale checks: %d, failures: %d" % [checks, failures])
	quit(1 if failures else 0)
