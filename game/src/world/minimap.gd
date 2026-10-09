extends Control
## The explored province in one corner: terrain, known places, heroes and the part the
## camera shows. A click or drag on it moves the camera (docs/UI_PLAN.md, stage 3).
signal picked(cell: Vector2i)
const SCALE := 1.5
const UNKNOWN := Color("14171c")
var image: Image
var texture := ImageTexture.new()
## What the image was last built from: the world and how much of it was explored.
var built_for := 0
var built_cells := -1
var state: RefCounted
## The cells the camera currently shows.
var view := Rect2()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "Mapa de lo explorado. Clic o arrastre: llevar la vista allí. Tecla M: mostrar u ocultar.\nExplored map. Click or drag to move the view. M shows or hides it."

## Called a few times a second by the map. The image is rebuilt only when another world
## is shown or more of it has been explored, away from the map's own repaint.
func refresh(world: RefCounted, shown: Rect2, colors: Dictionary) -> void:
	state = world
	view = shown
	if world.get_instance_id() != built_for or world.fog.size() != built_cells:
		built_for = world.get_instance_id()
		built_cells = world.fog.size()
		var cells: Vector2i = world.grid.region.size
		image = Image.create(maxi(1, cells.x), maxi(1, cells.y), false, Image.FORMAT_RGB8)
		image.fill(UNKNOWN)
		for cell: Vector2i in world.fog:
			if world.fog[cell] != 0:
				image.set_pixelv(cell, colors.get(world.terrain[cell.y][cell.x], Color.GRAY))
		texture.set_image(image)
	queue_redraw()

func _draw() -> void:
	if image == null or state == null:
		return
	var area := Rect2(Vector2.ZERO, Vector2(image.get_size()) * SCALE)
	draw_texture_rect(texture, area, false)
	for location: Dictionary in state.locations:
		var cell := Vector2i(location.position[0], location.position[1])
		if state.fog_at(cell) != 0:
			draw_rect(Rect2(Vector2(cell) * SCALE - Vector2(2, 2), Vector2(5, 5)), Color("f4e6c8"))
			draw_rect(Rect2(Vector2(cell) * SCALE - Vector2(2, 2), Vector2(5, 5)), Color("33241a"), false, 1.0)
	for id: String in state.party.heroes:
		var member = state.party.heroes[id]
		if member.unlocked:
			var active: bool = id == state.party.active_id
			draw_circle(Vector2(member.cell) * SCALE + Vector2(0.75, 0.75), 4.0 if active else 3.0, Color("ffd24a") if active else Color("e9e2d0"))
			draw_arc(Vector2(member.cell) * SCALE + Vector2(0.75, 0.75), 4.0 if active else 3.0, 0, TAU, 12, Color("1a1410"), 1.0)
	draw_rect(Rect2(view.position * SCALE, view.size * SCALE).intersection(area), Color.WHITE, false, 1.0)
	draw_rect(area, Color("b8913f"), false, 2.0)

func _gui_input(event: InputEvent) -> void:
	var pressed: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	var dragged: bool = event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT
	if (pressed or dragged) and image != null:
		var cell := Vector2i(event.position / SCALE)
		picked.emit(cell.clamp(Vector2i.ZERO, image.get_size() - Vector2i.ONE))
		accept_event()
