extends RefCounted
## Paper look for document panels, built from Pixel UI Fantasy Free (CC BY 4.0, see
## game/CREDITS.md). The art is 1x pixel art, so it is enlarged with nearest filtering.
## If the art is missing the panel keeps whatever style it already had.
const ART := "res://assets/third_party/pixel_ui_fantasy/parchment/"
const INK := Color("33241a")
const FADED := Color("33241a99")
const PAPER := Color("d6b684")
const LIGHT := Color("f4e6c8")

static func _box(file: String, margins: Array, scale := 2, flat_centre := false) -> StyleBoxTexture:
	if not ResourceLoader.exists(ART + file):
		return null
	var image: Image = load(ART + file).get_image()
	if image == null or image.is_empty():
		return null
	image.convert(Image.FORMAT_RGBA8)
	if flat_centre:
		# The mottled centre would be stretched into blotches; keep the frame, flatten the paper.
		image.fill_rect(Rect2i(margins[0], margins[1], image.get_width() - margins[0] - margins[2], image.get_height() - margins[1] - margins[3]), PAPER)
	image.resize(image.get_width() * scale, image.get_height() * scale, Image.INTERPOLATE_NEAREST)
	var box := StyleBoxTexture.new()
	box.texture = ImageTexture.create_from_image(image)
	var sides := [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]
	for index in 4:
		box.set_texture_margin(sides[index], margins[index] * scale)
		box.set_content_margin(sides[index], margins[index] * scale + (4 if flat_centre else 0))
	return box

## Gives the panel a parchment page and its controls dark ink and matching frames.
static func apply(panel: PanelContainer) -> bool:
	var page := _box("parchment.png", [6, 9, 6, 9], 3, true)
	if page == null:
		return false
	panel.add_theme_stylebox_override("panel", page)
	var theme := Theme.new()
	for type in ["Label", "Button", "OptionButton", "LineEdit", "ItemList", "CheckBox", "SpinBox"]:
		theme.set_color("font_color", type, INK)
	for type in ["Button", "OptionButton"]:
		for state in ["font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			theme.set_color(state, type, INK)
		theme.set_color("font_disabled_color", type, FADED)
		for pair in [["normal", "button_normal.png"], ["hover", "button_hover.png"], ["pressed", "button_pressed.png"], ["disabled", "button_disabled.png"]]:
			var frame := _box(pair[1], [5, 5, 5, 5])
			if frame != null:
				theme.set_stylebox(pair[0], type, frame)
		theme.set_stylebox("focus", type, preload("res://src/common/ui_tokens.gd").focus_box(preload("res://src/common/ui_tokens.gd").FOCUS))
	theme.set_color("default_color", "RichTextLabel", INK)
	# The field art is dark wood, so its text is light.
	theme.set_color("font_color", "LineEdit", LIGHT)
	theme.set_color("font_placeholder_color", "LineEdit", Color(LIGHT, 0.55))
	theme.set_color("caret_color", "LineEdit", LIGHT)
	theme.set_color("font_selected_color", "ItemList", INK)
	theme.set_color("font_hovered_color", "ItemList", INK)
	var field := _box("line_edit.png", [4, 4, 4, 4])
	if field != null:
		theme.set_stylebox("normal", "LineEdit", field)
		theme.set_stylebox("focus", "LineEdit", field)
	theme.set_stylebox("focus", "ItemList", preload("res://src/common/ui_tokens.gd").focus_box(preload("res://src/common/ui_tokens.gd").FOCUS))
	var inset := _box("panel_inset.png", [5, 5, 5, 5])
	if inset != null:
		theme.set_stylebox("panel", "ItemList", inset)
	# Tabs (equipment panel): paper page with button-frame tabs instead of the dark default.
	var sheet := StyleBoxFlat.new()
	sheet.bg_color = Color("e2c99a")
	sheet.set_content_margin_all(6)
	theme.set_stylebox("panel", "TabContainer", sheet)
	for pair in [["tab_selected", "button_pressed.png"], ["tab_unselected", "button_normal.png"], ["tab_hovered", "button_hover.png"], ["tab_disabled", "button_disabled.png"]]:
		var tab := _box(pair[1], [5, 5, 5, 5])
		if tab != null:
			theme.set_stylebox(pair[0], "TabContainer", tab)
	theme.set_stylebox("tab_focus", "TabContainer", StyleBoxEmpty.new())
	for state in ["font_selected_color", "font_unselected_color", "font_hovered_color"]:
		theme.set_color(state, "TabContainer", INK)
	theme.set_color("font_disabled_color", "TabContainer", FADED)
	var chosen := StyleBoxFlat.new()
	chosen.bg_color = Color("c9a56a")
	for state in ["selected", "selected_focus", "hovered"]:
		theme.set_stylebox(state, "ItemList", chosen)
	panel.theme = theme
	return true
