extends Control
## Clickable body slots and a layered preview of the actually equipped items.
signal slot_selected(slot: String)
var buttons: Dictionary = {}
var overlays: Dictionary = {}
var equipped: Dictionary = {}
var portrait := TextureRect.new()
const POSITIONS := {"head":Vector2(4,38), "neck":Vector2(4,111), "cloak":Vector2(4,184), "ring_1":Vector2(4,257), "torso":Vector2(284,38), "weapon":Vector2(284,111), "shield":Vector2(284,184), "ring_2":Vector2(284,257), "feet":Vector2(144,310), "misc_1":Vector2(4,380), "misc_2":Vector2(80,380), "misc_3":Vector2(156,380), "misc_4":Vector2(232,380), "misc_5":Vector2(308,380)}
const LAYERS := {"cloak":Rect2(136,121,110,168), "torso":Rect2(148,126,85,91), "feet":Rect2(163,270,55,42), "weapon":Rect2(121,198,48,74), "shield":Rect2(218,196,45,58), "head":Rect2(165,68,52,52), "neck":Rect2(178,116,26,30), "ring_1":Rect2(135,257,22,22), "ring_2":Rect2(226,257,22,22)}
func _ready() -> void:
	custom_minimum_size = Vector2(388,442)
	clip_contents = true
	var background := StyleBoxFlat.new()
	background.bg_color = Color("263331")
	background.set_corner_radius_all(6)
	var panel := Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel",background)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var label := Label.new()
	label.text = "EN EL HÉROE"
	label.position = Vector2(12,8)
	label.add_theme_font_size_override("font_size",16)
	label.add_theme_color_override("font_color",Color("f5dfaf"))
	add_child(label)
	var body := TextureRect.new()
	var cropped := AtlasTexture.new()
	cropped.atlas = load("res://assets/third_party/game_icons/person.svg")
	cropped.region = Rect2(145,15,220,480)
	body.position = Vector2(132,48)
	body.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	body.texture = cropped
	body.size = Vector2(118,266)
	body.modulate = Color("88958b")
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(body)
	portrait.position = Vector2(162,53)
	portrait.size = Vector2(58,66)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(portrait)
	for key: String in LAYERS:
		var layer := TextureRect.new()
		layer.position = LAYERS[key].position
		layer.size = LAYERS[key].size
		layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlays[key] = layer
		add_child(layer)
	for key: String in POSITIONS:
		var button := Button.new()
		button.name = key
		button.position = POSITIONS[key]
		button.size = Vector2(72 if key.begins_with("misc") else 100,60)
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width",32)
		button.add_theme_font_size_override("font_size",13)
		button.clip_text = true
		button.pressed.connect(func(): slot_selected.emit(key))
		buttons[key] = button
		add_child(button)
func refresh(world: RefCounted, names: Dictionary, icon: Callable, selected_slot := "") -> void:
	var gear = world.equipment
	var owner: String = world.party.active_id
	var path := "res://assets/third_party/claw_and_blade/portraits/%s.png" % owner
	portrait.texture = load(path) if ResourceLoader.exists(path) else null
	equipped.clear()
	for key: String in buttons:
		var id: String = gear.at_slot(owner,key)
		var texture: Texture2D = null
		var item_name := "Vacío"
		if not id.is_empty():
			equipped[key] = id
			var item: Dictionary = gear.items[gear.instances[id].item]
			texture = icon.call(item)
			item_name = item.name
		var button: Button = buttons[key]
		button.text = "Acc. " + key.right(1) if key.begins_with("misc") else names[key]
		button.icon = texture
		button.tooltip_text = "%s · %s" % [names[key],item_name]
		button.modulate = Color("ffe3a0") if key == selected_slot else Color.WHITE
		if overlays.has(key):
			overlays[key].texture = texture
			overlays[key].visible = texture != null
