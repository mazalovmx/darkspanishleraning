extends Button
## One stack on the battlefield: its hex, a group of figures, the count plate and a
## health bar. Enemies face left. A fallen stack leaves a skull on its hex.
const Battlefield = preload("res://src/combat/battlefield.gd")
const SKULL := "res://assets/third_party/kenney_board_game_icons/skull.png"
const SIDE_COLORS := [Color("2d5a9e"), Color("9e2d2d")]
const GOLD := Color("f0cf6a")
var figure: Texture2D
var count := 0
var health_ratio := 1.0
var side := 0
var active := false
var targeted := false
var selectable := false
var hex := Vector2(76, 88)

func _init() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	custom_minimum_size = Vector2(120, 130)
	size = custom_minimum_size
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)

## The point where the stack stands (the hex centre) in local coordinates.
func foot() -> Vector2:
	return Vector2(size.x / 2.0, size.y - hex.y / 2.0 - 4.0)

func _draw() -> void:
	var center := foot()
	var outline := Battlefield.hex_points(center, hex)
	if active:
		draw_colored_polygon(outline.slice(0, 6), Color(GOLD, 0.38))
		draw_polyline(outline, GOLD, 3.0)
	elif targeted:
		draw_colored_polygon(outline.slice(0, 6), Color(0.85, 0.2, 0.15, 0.32))
		draw_polyline(outline, Color("e0533f"), 3.0)
	elif selectable and is_hovered():
		draw_colored_polygon(outline.slice(0, 6), Color(1, 1, 1, 0.16))
	if count <= 0:
		var skull: Texture2D = load(SKULL) if ResourceLoader.exists(SKULL) else null
		if skull != null:
			draw_texture_rect(skull, Rect2(center - Vector2(18, 26), Vector2(36, 36)), false, Color(0.92, 0.9, 0.85, 0.7))
		return
	# Shadow.
	draw_set_transform(center + Vector2(0, 2), 0.0, Vector2(1.0, 0.32))
	draw_circle(Vector2.ZERO, hex.x * 0.42, Color(0, 0, 0, 0.32))
	draw_set_transform(Vector2.ZERO)
	if figure != null:
		var facing := 1.0 if side == 0 else -1.0
		var main := figure.get_size() * 3.0
		# Two comrades behind the leader for a larger stack.
		var rear: Array = []
		if count >= 4:
			rear.append(Vector2(-16, -12))
		if count >= 12:
			rear.append(Vector2(14, -16))
		for offset: Vector2 in rear:
			var drawn := main * 0.78
			_figure(center + Vector2(offset.x * facing, offset.y), drawn, facing, Color(0.82, 0.82, 0.82))
		_figure(center + Vector2(0, 4), main, facing, Color.WHITE)
	# Count plate and health bar, Heroes-style, at the stack's front corner.
	var font := get_theme_default_font()
	var text := str(count)
	var plate := Rect2(center + Vector2(4 if side == 0 else -50, 8), Vector2(46, 22))
	draw_rect(plate, SIDE_COLORS[side])
	draw_rect(plate, GOLD, false, 2.0)
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	draw_string(font, plate.position + Vector2((plate.size.x - width) / 2.0, 17), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	var bar := Rect2(center + Vector2(-34, 34), Vector2(68, 6))
	draw_rect(bar, Color(0, 0, 0, 0.6))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(health_ratio, 0.0, 1.0), bar.size.y)), Color("d94b3d").lerp(Color("5fc44f"), health_ratio))

func _figure(foot_point: Vector2, drawn: Vector2, facing: float, tint: Color) -> void:
	draw_set_transform(foot_point, 0.0, Vector2(facing, 1.0))
	draw_texture_rect(figure, Rect2(Vector2(-drawn.x / 2.0, -drawn.y), drawn), false, tint)
	draw_set_transform(Vector2.ZERO)
