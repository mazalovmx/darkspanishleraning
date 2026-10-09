extends Control
## Read-only town view. Clicking a site selects an order; only Spanish confirmation builds it.
signal building_selected(id: String)
const ART := "res://assets/third_party/feudal_wars/"
const BUILDING_ART := {"council_hall":"castle", "barracks":"barracks", "archery_range":"archery", "forge":"blacksmith", "laboratory":"tower", "treasury":"houses_2", "lumber_yard":"stable", "artifact_market":"houses_1"}
const SHORT_NAMES := {"council_hall":"Administración", "barracks":"Cuartel", "archery_range":"Arquería", "forge":"Forja", "laboratory":"Reliquias", "treasury":"Tesorería", "lumber_yard":"Aserradero", "artifact_market":"Mercado"}
var summary := Label.new()
var buttons: Dictionary = {}
var income: Dictionary = {}
var built_ids: Array = []
var textures: Dictionary = {}

func _ready() -> void:
	custom_minimum_size.x = 460
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_PASS
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.add_theme_font_size_override("font_size", 16)
	summary.add_theme_color_override("font_color", Color("f9e4ad"))
	add_child(summary)
	resized.connect(_layout)
	for id: String in BUILDING_ART:
		var path: String = ART + BUILDING_ART[id] + ".png"
		if ResourceLoader.exists(path):
			textures[id] = load(path)

func refresh(world: RefCounted, selected_id := "") -> void:
	for button: Button in buttons.values():
		remove_child(button)
		button.queue_free()
	buttons.clear()
	income.clear()
	built_ids.clear()
	var economy = world.economy
	var town: String = world.location_at(world.hero_cell).get("id", "")
	var built: Dictionary = economy.buildings.get(town, {})
	for id: String in economy.catalog.town_buildings.get(town, []):
		var definition: Dictionary = economy.catalog.buildings[id]
		var exists := built.has(id)
		if exists:
			built_ids.append(id)
			for resource: String in definition.income:
				income[resource] = int(income.get(resource, 0)) + int(definition.income[resource])
		var reason: String = economy.reason(world, "build", id, 1)
		var button := Button.new()
		button.name = id
		button.disabled = not economy.pending.is_empty()
		button.clip_contents = true
		button.pressed.connect(func(): building_selected.emit(id))
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.08, 0.12, 0.11, 0.55 if exists else 0.28)
		style.border_color = Color("f2d083") if id == selected_id else Color("689984") if exists else Color("69716b")
		style.set_border_width_all(2 if id == selected_id else 1)
		style.set_corner_radius_all(5)
		button.add_theme_stylebox_override("normal", style)
		var hover := style.duplicate()
		hover.bg_color = Color("46584b")
		button.add_theme_stylebox_override("hover", hover)
		button.add_theme_stylebox_override("pressed", hover)
		button.add_theme_stylebox_override("disabled", style)
		var face := TextureRect.new()
		face.texture = textures.get(id)
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face.modulate = Color.WHITE if exists else Color(0.55, 0.59, 0.61, 0.8)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(face)
		var label := Label.new()
		label.text = SHORT_NAMES.get(id, definition.name)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 15)
		label.add_theme_color_override("font_color", Color("fff0c9"))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(label)
		var status := Label.new()
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status.add_theme_font_size_override("font_size", 14)
		status.add_theme_color_override("font_color", Color("a6e2bb") if exists else Color("ddd2b5"))
		status.text = "Construido" if exists else "Disponible" if reason.is_empty() else "Pendiente"
		if not definition.income.is_empty():
			var benefits: PackedStringArray = []
			for resource: String in definition.income:
				benefits.append("+%d %s/día" % [definition.income[resource], economy.catalog.resource_names[resource]])
			status.text += "\n" + ", ".join(benefits)
		else:
			status.text += "\nServicio · sin ingreso"
		status.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(status)
		var requirements: PackedStringArray = []
		for required: String in definition.requires:
			requirements.append(economy.catalog.buildings[required].name)
		button.tooltip_text = "%s\n%s\nCoste: %s\nRequiere: %s\n%s" % [definition.name, definition.description, economy.cost_text(definition.cost), ", ".join(requirements) if not requirements.is_empty() else "ningún edificio", "Construido" if exists else reason]
		add_child(button)
		buttons[id] = button
	summary.text = "TU CIUDAD · %d/%d edificios\nPróximo día: %s" % [built_ids.size(), buttons.size(), economy.cost_text(income) if not income.is_empty() else "sin ingreso de edificios"]
	_layout()
	queue_redraw()

func _layout() -> void:
	if not is_inside_tree():
		return
	summary.position = Vector2(12, 10)
	summary.size = Vector2(maxf(0, size.x - 24), 56)
	var tile := Vector2((size.x - 32) / 3, (size.y - 90) / 3)
	var index := 0
	for button: Button in buttons.values():
		button.position = Vector2(8 + (index % 3) * (tile.x + 8), 78 + (index / 3) * (tile.y + 4))
		button.size = tile
		button.get_child(0).position = Vector2(6, 3)
		button.get_child(0).size = Vector2(tile.x - 12, maxf(20, tile.y - 66))
		button.get_child(1).position = Vector2(2, tile.y - 63)
		button.get_child(1).size = Vector2(tile.x - 4, 20)
		button.get_child(2).position = Vector2(2, tile.y - 43)
		button.get_child(2).size = Vector2(tile.x - 4, 42)
		index += 1
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("263931"))
	var points := PackedVector2Array([Vector2(0, size.y * 0.4), Vector2(size.x * 0.3, 45), Vector2(size.x * 0.65, size.y * 0.4), Vector2(size.x, 90), size, Vector2(0, size.y)])
	draw_colored_polygon(points, Color("35493a"))
	draw_line(Vector2(size.x * 0.1, size.y), Vector2(size.x * 0.7, 75), Color("6b6145"), 24, true)
	draw_rect(Rect2(Vector2.ZERO, size), Color("987b4d"), false, 2)
