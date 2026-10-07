extends SceneTree
const World = preload("res://src/world/world_state.gd")
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
	var state := World.new("province_160x120_v1")
	check(state.grid.region.size == Vector2i(160, 120), "Full map dimensions")
	check(state.hero_cell == Vector2i(52, 39), "Canonical monastery start")
	check(not state.select_hero("smuggler") and not state.select_hero("survivor"), "Campaign heroes await story introduction")
	check(state.fog_at(Vector2i(126, 105)) == World.Fog.UNKNOWN, "Locked hero reveals no distant port")
	check(state.locations.size() == 18, "All canonical map nodes present")
	for row: String in state.map_data.rows:
		check(row.length() == 160, "Every row has canonical width")
		for symbol in row:
			check(state.map_data.legend.has(symbol), "Every terrain symbol defined")
	for y in 120:
		for x in 160:
			check(not state.region_at(Vector2i(x,y)).is_empty(), "All cells belong to a region")
	var gate := Vector2i(49, 14)
	check(state.gate_at(gate).closed, "Northern pass starts closed")
	check(state.path_to(Vector2i(48, 8)).is_empty(), "No bypass around closed mountain pass")
	var ids := {}
	for location: Dictionary in state.locations:
		check(not ids.has(location.id), "Unique location id")
		ids[location.id] = true
		var cell := Vector2i(location.position[0], location.position[1])
		check(state.terrain_cost(cell) > 0, "Every POI stands on walkable terrain")
		if location.id not in ["LOC09", "LOC18"]:
			check(not state.path_to(cell).is_empty(), "Southern POIs reachable: " + location.id)
	var proof := {}
	for id in state.evidence.definitions:
		var node: Dictionary = state.evidence.definitions[id]
		proof[id] = {"found_day": 1, "classification": node.classification, "spanish_note": node.language.sample}
	check(state.evidence.restore(proof, 1), "Valid completed-case fixture")
	for location: Dictionary in state.locations:
		check(not state.path_to(Vector2i(location.position[0], location.position[1])).is_empty(), "Completed case opens route to every POI")
	check(not state.gate_at(gate).closed, "Pass derives access from evidence")
	var resources := {}
	for site: Dictionary in state.map_data.resource_sites:
		resources[site.resource] = true
		check(not state.path_to(Vector2i(site.position[0], site.position[1])).is_empty(), "Resource site reachable")
	check(resources.size() == 7, "All seven strategic resources have sites")
	# Actually walk the discovered route to the port, spending daily movement.
	var route := state.path_to(Vector2i(126, 105))
	var index := 0
	while index < route.size()-1:
		var next := index
		var cost := 0
		while next+1 < route.size() and state.fog_at(route[next+1]) != World.Fog.UNKNOWN:
			cost += state.terrain_cost(route[next+1])
			if cost > state.movement_remaining:
				break
			next += 1
		check(next > index and state.move_to(route[next],true), "Queue discovered travel to Cardena")
		if next == index:
			break
		state.end_turn()
		check(state.hero_cell == route[next], "Daily orders move to planned destination")
		index = next
	check(state.hero_cell == Vector2i(126, 105) and state.day > 1, "Long travel consumes world days")
	var result := Save.decode(Save.snapshot(state))
	check(result.has("state"), "Province snapshot restores")
	if result.has("state"):
		check(result.state.map_id == state.map_id and result.state.hero_cell == state.hero_cell, "Map identity and large coordinates persist")
		check(result.state.fog == state.fog and result.state.day == state.day, "Exploration and travel time persist")
		check(not result.state.gate_at(gate).closed, "Gate restored from verified evidence")
	var bad := Save.snapshot(state)
	bad.map_id = "invented"
	check(not Save.decode(bad).has("state"), "Unknown map rejected")
	print("Province map checks: %d, failures: %d" % [checks, failures])
	quit(1 if failures else 0)