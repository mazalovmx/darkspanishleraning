extends RefCounted
## Dark wood look for the map's side panel and resource bar, built from Kenney UI Pack
## RPG Expansion (CC0, game/CREDITS.md). Missing art leaves the default style.
const UI := "res://assets/third_party/kenney_ui_rpg/PNG/"
const ICONS := "res://assets/third_party/kenney_board_game_icons/"
const LIGHT := Color("f6e7c1")
const DIM := Color("cdb88f")

static func frame(file: String, margin: int, content := -1) -> StyleBox:
	if not ResourceLoader.exists(UI + file):
		return null
	var box := StyleBoxTexture.new()
	box.texture = load(UI + file)
	box.set_texture_margin_all(margin)
	box.set_content_margin_all(margin if content < 0 else content)
	return box

static func icon(name: String) -> Texture2D:
	return load(ICONS + name + ".png") if ResourceLoader.exists(ICONS + name + ".png") else null

## Theme for a wooden panel: light text, brown buttons with a pressed and a grey state.
static func build(font_size := 16) -> Theme:
	var theme := Theme.new()
	theme.default_font = ThemeDB.fallback_font
	theme.default_font_size = font_size
	theme.set_color("font_color", "Label", LIGHT)
	var normal := frame("buttonLong_brown.png", 10, 6)
	if normal == null:
		return theme
	var hover := frame("buttonLong_brown.png", 10, 6)
	hover.modulate_color = Color(1.25, 1.18, 1.05)
	var pressed := frame("buttonLong_brown_pressed.png", 10, 6)
	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_stylebox("hover_pressed", "Button", pressed)
	theme.set_stylebox("disabled", "Button", frame("buttonLong_grey.png", 10, 6))
	theme.set_stylebox("focus", "Button", preload("res://src/common/ui_tokens.gd").focus_box(preload("res://src/common/ui_tokens.gd").FOCUS_ON_WOOD))
	for state in ["font_color", "font_hover_color", "font_focus_color", "font_hover_pressed_color"]:
		theme.set_color(state, "Button", LIGHT)
	theme.set_color("font_pressed_color", "Button", Color("ffe08a"))
	theme.set_color("font_disabled_color", "Button", Color("5a5148"))
	theme.set_color("icon_normal_color", "Button", LIGHT)
	theme.set_color("icon_hover_color", "Button", Color.WHITE)
	theme.set_color("icon_pressed_color", "Button", Color("ffe08a"))
	theme.set_color("icon_disabled_color", "Button", Color("5a5148"))
	theme.set_constant("icon_max_width", "Button", 20)
	theme.set_constant("h_separation", "Button", 6)
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color("8a6a43")
	theme.set_stylebox("grabber", "VScrollBar", grabber)
	theme.set_stylebox("grabber_highlight", "VScrollBar", grabber)
	theme.set_stylebox("grabber_pressed", "VScrollBar", grabber)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0, 0, 0, 0.25)
	theme.set_stylebox("scroll", "VScrollBar", track)
	return theme
