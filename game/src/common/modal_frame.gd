extends RefCounted
## One way to build a full-screen modal: dimmed backdrop, parchment page, title, a guide
## line saying what to do, a content box and a close button (docs/UI_PLAN.md, stage 1).
const Tokens = preload("res://src/common/ui_tokens.gd")

## Fills `backdrop` and returns {"panel", "title", "guide", "content", "close"}.
static func build(backdrop: ColorRect, title_text: String, size: Vector2, close_text := "Volver (Esc)") -> Dictionary:
	backdrop.color = Color(0, 0, 0, 0.85)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.size = size
	panel.position = ((Vector2(1280, 720) - size) / 2).floor()
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color("22252a")
	panel.add_theme_stylebox_override("panel", flat)
	preload("res://src/common/parchment_theme.gd").apply(panel)
	backdrop.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, Tokens.PAD)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", Tokens.GAP)
	margin.add_child(box)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", Tokens.H2)
	box.add_child(title)
	var guide := Label.new()
	guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide.add_theme_font_size_override("font_size", Tokens.CAPTION)
	guide.visible = false
	box.add_child(guide)
	var content := VBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", Tokens.GAP)
	box.add_child(content)
	var close := Button.new()
	close.text = close_text
	close.add_theme_font_size_override("font_size", Tokens.BODY)
	box.add_child(close)
	return {"panel": panel, "title": title, "guide": guide, "content": content, "close": close}
