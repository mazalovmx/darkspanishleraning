extends RefCounted
## Canonical prototype state, independent of the map's visual nodes.

const COSTS := {"road": 1, "grass": 1, "field": 1, "forest": 2, "marsh": 3,
	"ruins": 2, "snow": 2, "mountain": 0, "water": 0}
enum Fog { UNKNOWN, EXPLORED, VISIBLE }
const VIEW_RADIUS := 5
const MOVEMENT_MAX := 18
var learner = preload("res://src/spanish/learner_profile.gd").new()
var day := 1
var hero_cell := Vector2i(2, 10)
var movement_remaining := MOVEMENT_MAX
var terrain: Array = []
var grid := AStarGrid2D.new()
var known_grid := AStarGrid2D.new()
var fog: Dictionary = {}
var locations: Array = []

func _init() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://content/world/prototype.json"))
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
	_reveal_from(hero_cell)

func fog_at(cell: Vector2i) -> int:
	return fog.get(cell, Fog.UNKNOWN)

func _reveal_from(center: Vector2i) -> void:
	for cell in fog:
		fog[cell] = Fog.EXPLORED
	for y in range(center.y - VIEW_RADIUS, center.y + VIEW_RADIUS + 1):
		for x in range(center.x - VIEW_RADIUS, center.x + VIEW_RADIUS + 1):
			var cell := Vector2i(x, y)
			if grid.region.has_point(cell) and center.distance_squared_to(cell) <= VIEW_RADIUS * VIEW_RADIUS:
				fog[cell] = Fog.VISIBLE
				known_grid.set_point_solid(cell, terrain_cost(cell) == 0)
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
	if terrain_cost(destination) == 0:
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
	day += 1
	movement_remaining = MOVEMENT_MAX
