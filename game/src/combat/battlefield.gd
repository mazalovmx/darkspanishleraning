extends Control
## Battle ground in the manner of Heroes III: terrain tiles from the map's terrain, trees
## and rocks along the edges, the 11×7 hex grid of stack_battle.gd with its rocks, the
## hexes the acting stack can reach and the hex under the mouse. Clicks on a hex go to
## the arena through hex_clicked.
signal hex_clicked(cell: Vector2i, point: Vector2)
signal hex_hovered(cell: Vector2i)
const Battle = preload("res://src/combat/stack_battle.gd")
const TILE := "res://assets/third_party/kenney_medieval_rts/Tile/medievalTile_%02d.png"
const ENV := "res://assets/third_party/kenney_medieval_rts/Environment/medievalEnvironment_%02d.png"
# Ground tile, decoration pieces and tint by map terrain.
const GROUND := {
	"grass": [57, [1, 2, 3, 4, 13, 20, 7, 8], Color.WHITE],
	"road": [57, [1, 2, 13, 20, 7, 6], Color.WHITE],
	"field": [58, [13, 20, 1, 6, 7], Color(1.0, 0.95, 0.8)],
	"forest": [57, [2, 4, 4, 2, 1, 3, 13, 20], Color(0.85, 0.95, 0.85)],
	"marsh": [57, [13, 20, 1, 6, 7], Color(0.62, 0.76, 0.68)],
	"mountain": [15, [8, 9, 10, 7, 14, 15], Color.WHITE],
	"ruins": [16, [9, 8, 6, 7, 14], Color(0.86, 0.8, 0.74)],
	"snow": [29, [3, 4, 11, 7], Color.WHITE],
	"water": [1, [7, 14, 13], Color.WHITE]}
const COLUMNS := Battle.COLUMNS
const ROWS := Battle.ROWS
# Piece drawn on a rock hex, by terrain.
const OBSTACLE := {"grass": [9, 4], "road": [9, 2], "field": [15, 6], "forest": [4, 2], "marsh": [6, 13],
	"mountain": [10, 9], "ruins": [9, 8], "snow": [11, 4], "water": [9, 8]}
var terrain := "grass"
var obstacles: Array[Vector2i] = []
var reachable: Array = []
var hovered := Battle.NOWHERE
## Text for the tooltip over a hex (the arena describes stacks); empty for none.
var describe: Callable
var seed_value := 1
var textures := {}

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var cell := cell_at(event.position)
		if cell != hovered:
			hovered = cell
			hex_hovered.emit(cell)
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell := cell_at(event.position)
		if cell != Battle.NOWHERE:
			hex_clicked.emit(cell, event.position)

func _get_tooltip(at_position: Vector2) -> String:
	var cell := cell_at(at_position)
	return describe.call(cell) if cell != Battle.NOWHERE and describe.is_valid() else ""

## The hex under a point of this control, or NOWHERE.
func cell_at(point: Vector2) -> Vector2i:
	var hex := hex_size()
	var best := Battle.NOWHERE
	var nearest := hex.x * 0.55
	for row in ROWS:
		for column in COLUMNS:
			var gap := point.distance_to(cell_center(column, row))
			if gap < nearest:
				nearest = gap
				best = Vector2i(column, row)
	return best

func center_of(cell: Vector2i) -> Vector2:
	return cell_center(cell.x, cell.y)

func setup(kind: String, value: int, rocks: Array[Vector2i] = []) -> void:
	terrain = kind if GROUND.has(kind) else "grass"
	seed_value = value
	obstacles = rocks.duplicate()
	queue_redraw()

func show_reach(cells: Array) -> void:
	reachable = cells
	queue_redraw()

func _texture(path: String) -> Texture2D:
	if not textures.has(path):
		textures[path] = load(path) if ResourceLoader.exists(path) else null
	return textures[path]

## Hex size and the top-left of the grid, fitted between the top bar and the command bar.
func hex_size() -> Vector2:
	var height := minf(88.0, (field_rect().size.y) / (ROWS * 0.75 + 0.25))
	return Vector2(height * sqrt(3.0) / 2.0, height)

func field_rect() -> Rect2:
	# Below the top bar (60 px) with room for the tallest figures, above the command bar.
	return Rect2(Vector2(0, 100), Vector2(size.x, maxf(200.0, size.y - 100 - 182)))

func cell_center(column: int, row: int) -> Vector2:
	var hex := hex_size()
	var width := hex.x * (COLUMNS + 0.5)
	var height := hex.y * (ROWS * 0.75 + 0.25)
	var origin := field_rect().get_center() - Vector2(width, height) / 2.0
	return origin + Vector2(hex.x * (column + 0.5 + (0.5 if row % 2 == 1 else 0.0)), hex.y * (0.5 + row * 0.75))

## Pointy-top hex outline (closed: seven points).
static func hex_points(center: Vector2, hex: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for k in 7:
		var angle := deg_to_rad(60.0 * k - 90.0)
		points.append(center + Vector2(cos(angle) * hex.x / sqrt(3.0), sin(angle) * hex.y / 2.0))
	return points

func _draw() -> void:
	var setting: Array = GROUND[terrain]
	var ground := _texture(TILE % setting[0])
	if ground != null:
		var step := 64.0
		for x in range(0, int(size.x / step) + 1):
			for y in range(0, int(size.y / step) + 1):
				draw_texture_rect(ground, Rect2(Vector2(x, y) * step, Vector2(step, step)), false, setting[2])
	else:
		draw_rect(Rect2(Vector2.ZERO, size), Color("4f7a3a"))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var field := field_rect()
	var hex := hex_size()
	var grid_top := cell_center(0, 0).y - hex.y / 2.0
	var grid_bottom := cell_center(0, ROWS - 1).y + hex.y / 2.0
	# Trees and rocks in the bands above and below the grid, and a few at the far sides.
	var pieces: Array = setting[1]
	var spots: Array = []
	# Decoration stays off the grid so it is never mistaken for a rock that blocks a hex:
	# a band above the grid (pieces grow upwards from their foot) and the far sides.
	for i in 24:
		spots.append(Vector2(rng.randf_range(0, size.x), rng.randf_range(field.position.y - 40, grid_top - 2)))
	for i in 10:
		var left := rng.randf() < 0.5
		spots.append(Vector2(rng.randf_range(0, cell_center(0, 0).x - hex.x * 0.8) if left else rng.randf_range(cell_center(COLUMNS - 1, 1).x + hex.x * 0.8, size.x), rng.randf_range(grid_top, grid_bottom)))
	spots.sort_custom(func(a: Vector2, b: Vector2): return a.y < b.y)
	for spot: Vector2 in spots:
		var piece := _texture(ENV % int(pieces[rng.randi() % pieces.size()]))
		if piece == null:
			continue
		var scale := rng.randf_range(1.6, 2.3)
		var drawn := piece.get_size() * scale
		draw_texture_rect(piece, Rect2(spot - Vector2(drawn.x / 2.0, drawn.y * 0.85), drawn), false, setting[2])
	# Hex grid: faint outlines, slightly darker field.
	for row in ROWS:
		for column in COLUMNS:
			var points := hex_points(cell_center(column, row), hex)
			draw_colored_polygon(points.slice(0, 6), Color(0, 0, 0, 0.06))
			draw_polyline(points, Color(0.1, 0.08, 0.04, 0.32), 1.5)
	for cell in reachable:
		var points := hex_points(center_of(cell), hex)
		draw_colored_polygon(points.slice(0, 6), Color(1.0, 0.93, 0.6, 0.22))
		draw_polyline(points, Color(1.0, 0.9, 0.5, 0.55), 1.5)
	if hovered != Battle.NOWHERE and hovered not in obstacles:
		draw_polyline(hex_points(center_of(hovered), hex), Color(1, 1, 1, 0.85), 2.5)
	# Rocks (or trees) that block hexes.
	for cell in obstacles:
		var piece := _texture(ENV % int(OBSTACLE.get(terrain, [9, 4])[(cell.x + cell.y) % 2]))
		draw_colored_polygon(hex_points(center_of(cell), hex).slice(0, 6), Color(0, 0, 0, 0.18))
		if piece != null:
			var drawn := piece.get_size() * 2.4
			draw_texture_rect(piece, Rect2(center_of(cell) - Vector2(drawn.x / 2.0, drawn.y * 0.72), drawn), false, setting[2])
	# Soft shade at the top and the bottom so the bars read well.
	for i in 12:
		var alpha := 0.045 * (12 - i)
		draw_rect(Rect2(0, field.position.y + i * 4, size.x, 4), Color(0, 0, 0, alpha * 0.6))
		draw_rect(Rect2(0, field.end.y - (i + 1) * 4, size.x, 4), Color(0, 0, 0, alpha * 0.6))
