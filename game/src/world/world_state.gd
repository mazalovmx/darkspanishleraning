extends RefCounted
## Canonical prototype state, independent of the map's visual nodes.

const COSTS := {"road": 1, "grass": 1, "field": 1, "forest": 2, "marsh": 3,
	"ruins": 2, "snow": 2, "mountain": 0, "water": 0}
const MOVEMENT_MAX := 18
var day := 1
var hero_cell := Vector2i(2, 10)
var movement_remaining := MOVEMENT_MAX
var terrain: Array = []
var grid := AStarGrid2D.new()

func _init() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://content/world/prototype.json"))
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

func terrain_cost(cell: Vector2i) -> int:
	if not grid.region.has_point(cell):
		return 0
	return COSTS[terrain[cell.y][cell.x]]

func path_to(destination: Vector2i) -> Array[Vector2i]:
	if terrain_cost(destination) == 0:
		return []
	return grid.get_id_path(hero_cell, destination)

func path_cost(path: Array[Vector2i]) -> int:
	var cost := 0
	for i in range(1, path.size()):
		cost += terrain_cost(path[i])
	return cost

func move_to(destination: Vector2i) -> bool:
	var path := path_to(destination)
	if path.size() < 2:
		return false
	var cost := path_cost(path)
	if cost > movement_remaining:
		return false
	hero_cell = destination
	movement_remaining -= cost
	return true

func end_turn() -> void:
	day += 1
	movement_remaining = MOVEMENT_MAX
