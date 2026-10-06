extends RefCounted
## Canonical prototype state, independent of the map's visual nodes.

const COSTS := {"road": 1, "grass": 1, "field": 1, "forest": 2, "marsh": 3,
	"ruins": 2, "snow": 2, "mountain": 0, "water": 0}
enum Fog { UNKNOWN, EXPLORED, VISIBLE }
const MAPS := {"prototype_20x20_v1": "res://content/world/prototype.json",
	"province_160x120_v1": "res://content/world/province.json"}
var map_id := "prototype_20x20_v1"
var map_data: Dictionary = {}
const VIEW_RADIUS := 5
const MOVEMENT_MAX := 18
var party = preload("res://src/world/party_state.gd").new()
var learner = preload("res://src/spanish/learner_profile.gd").new()
var trade = preload("res://src/economy/trade_state.gd").new()
var evidence = preload("res://src/evidence/evidence_graph.gd").new()
const StackBattle = preload("res://src/combat/stack_battle.gd")
var army: Array:
	get:
		return party.active().army
	set(value):
		party.active().army = value
var resources := {"gold": 300, "wood": 5, "ore": 5, "mercury": 0, "sulfur": 0, "crystal": 0, "gems": 0}
var encounters: Dictionary = {}
var active_battle: RefCounted
var active_encounter := ""
var day := 1
var hero_cell: Vector2i:
	get:
		return party.active().cell
	set(value):
		party.active().cell = value
var movement_remaining: int:
	get:
		return party.active().movement_remaining
	set(value):
		party.active().movement_remaining = value
var terrain: Array = []
var grid := AStarGrid2D.new()
var known_grid := AStarGrid2D.new()
var fog: Dictionary = {}
var locations: Array = []

func _init(selected_map := "prototype_20x20_v1") -> void:
	assert(MAPS.has(selected_map), "Unknown authored map")
	map_id = selected_map
	trade.inventory = party.active().inventory
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MAPS[map_id]))
	map_data = data
	if data.has("hero_starts"):
		for id in party.heroes:
			var position: Array = data.hero_starts[id]
			party.heroes[id].cell = Vector2i(position[0], position[1])
			party.heroes[id].unlocked = id == "inquisitor"
	locations = data.get("locations", [])
	for row: String in data.rows:
		var cells: Array[String] = []
		for symbol in row:
			cells.append(data.legend[symbol])
		terrain.append(cells)
	grid.region = Rect2i(0, 0, terrain[0].size(), terrain.size())
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	grid.update()
	for y in grid.region.size.y:
		for x in grid.region.size.x:
			var cell := Vector2i(x, y)
			var cost := terrain_cost(cell)
			grid.set_point_solid(cell, cost == 0)
			grid.set_point_weight_scale(cell, maxi(1, cost))

	known_grid.region = grid.region
	known_grid.diagonal_mode = grid.diagonal_mode
	known_grid.default_compute_heuristic = grid.default_compute_heuristic
	known_grid.default_estimate_heuristic = grid.default_estimate_heuristic
	known_grid.update()
	for y in grid.region.size.y:
		for x in grid.region.size.x:
			known_grid.set_point_solid(Vector2i(x, y), true)
	_sync_gates()
	_reveal_from(hero_cell)

func fog_at(cell: Vector2i) -> int:
	return fog.get(cell, Fog.UNKNOWN)

func _reveal_from(center: Vector2i) -> void:
	for cell in fog:
		fog[cell] = Fog.EXPLORED
	var centers: Array[Vector2i] = [center]
	for id in party.heroes:
		if id != party.active_id and party.heroes[id].unlocked:
			centers.append(party.heroes[id].cell)
	for origin: Vector2i in centers:
		for y in range(origin.y - VIEW_RADIUS, origin.y + VIEW_RADIUS + 1):
			for x in range(origin.x - VIEW_RADIUS, origin.x + VIEW_RADIUS + 1):
				var cell := Vector2i(x, y)
				if grid.region.has_point(cell) and origin.distance_squared_to(cell) <= VIEW_RADIUS * VIEW_RADIUS:
					fog[cell] = Fog.VISIBLE
					known_grid.set_point_solid(cell, terrain_cost(cell) == 0 or gate_at(cell).get("closed", false))
					known_grid.set_point_weight_scale(cell, maxi(1, terrain_cost(cell)))

func location_at(cell: Vector2i) -> Dictionary:
	if fog_at(cell) == Fog.UNKNOWN:
		return {}
	for location: Dictionary in locations:
		if Vector2i(location.position[0], location.position[1]) == cell:
			return location
	return {}

func terrain_cost(cell: Vector2i) -> int:
	if not grid.region.has_point(cell):
		return 0
	return COSTS[terrain[cell.y][cell.x]]

func path_to(destination: Vector2i, discovered_only := false) -> Array[Vector2i]:
	_sync_gates()
	if terrain_cost(destination) == 0 or gate_at(destination).get("closed", false):
		return []
	if discovered_only:
		if fog_at(destination) == Fog.UNKNOWN:
			return []
		return known_grid.get_id_path(hero_cell, destination)
	return grid.get_id_path(hero_cell, destination)

func path_cost(path: Array[Vector2i]) -> int:
	var cost := 0
	for i in range(1, path.size()):
		cost += terrain_cost(path[i])
	return cost

func move_to(destination: Vector2i, discovered_only := false) -> bool:
	if active_battle != null:
		return false
	var path := path_to(destination, discovered_only)
	if path.size() < 2:
		return false
	var cost := path_cost(path)
	if cost > movement_remaining:
		return false
	for cell in path:
		_reveal_from(cell)
	hero_cell = destination
	movement_remaining -= cost
	return true

func end_turn() -> void:
	if active_battle != null:
		return
	day += 1
	party.end_day()

func begin_encounter(id: String) -> bool:
	if active_battle != null or army.is_empty() or movement_remaining < 2:
		return false
	var model := StackBattle.new()
	var encounter: Dictionary = model.data.opening
	if id != encounter.id or location_at(hero_cell).get("id", "") != encounter.location_id:
		return false
	if not evidence.has_evidence(encounter.requires) or encounters.get(id, {}).get("outcome", "") == "victory":
		return false
	if not model.start(army, encounter.enemies, day * 1009 + hero_cell.x * 31 + hero_cell.y):
		return false
	active_battle = model
	active_encounter = id
	movement_remaining -= 2
	return true

func settle_encounter() -> bool:
	if active_battle == null or active_battle.outcome.is_empty():
		return false
	var result: String = active_battle.outcome
	army = active_battle.surviving_army()
	if result == "victory":
		for resource in active_battle.data.opening.reward:
			resources[resource] += int(active_battle.data.opening.reward[resource])
	elif result in ["defeat", "retreated"]:
		movement_remaining = 0
	encounters[active_encounter] = {"outcome": result, "day": day}
	active_battle = null
	active_encounter = ""
	return true

func select_hero(id: String) -> bool:
	if active_battle != null or not trade.pending.is_empty() or not party.select(id):
		return false
	trade.inventory = party.active().inventory
	_reveal_from(hero_cell)
	return true

func gate_at(cell: Vector2i) -> Dictionary:
	for gate: Dictionary in map_data.get("gates", []):
		if cell == Vector2i(gate.position[0], gate.position[1]):
			var result := gate.duplicate()
			result["closed"] = not evidence.has_evidence(gate.requires)
			return result
	return {}

func _sync_gates() -> void:
	for gate: Dictionary in map_data.get("gates", []):
		var cell := Vector2i(gate.position[0], gate.position[1])
		var closed := not evidence.has_evidence(gate.requires)
		grid.set_point_solid(cell, closed)
		if known_grid.is_in_boundsv(cell):
			known_grid.set_point_solid(cell, closed or fog_at(cell) == Fog.UNKNOWN)

func region_at(cell: Vector2i) -> String:
	for region: Dictionary in map_data.get("regions", []):
		var b: Array = region.bounds
		if Rect2i(b[0], b[1], b[2], b[3]).has_point(cell):
			return region.name
	return ""