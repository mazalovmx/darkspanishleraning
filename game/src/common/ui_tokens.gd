extends RefCounted
## Shared sizes and meanings for the interface (docs/UI_PLAN.md, stage 1). Panels take
## their numbers from here instead of writing literals.
const UNIT := 8
const GAP := 8
const GAP_GROUP := 16
const PAD := 24
## Font sizes for the 1280x720 canvas. CAPTION is for secondary labels only.
const CAPTION := 16
const BODY := 18
const H2 := 24
const H1 := 30
const NUMERIC := 22
## Meanings, readable on parchment (dark ink) and on wood (light text).
const INK := Color("33241a")
const INK_FADED := Color("5c4636")
const OK := Color("21441d")
const WARN := Color("5c3700")
const ERROR := Color("8a1f14")
const FOCUS := Color("103a6b")
const FOCUS_ON_WOOD := Color("ffe08a")

## WCAG relative-luminance contrast of two opaque colours.
static func contrast(a: Color, b: Color) -> float:
	var la := _luminance(a)
	var lb := _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)

static func _luminance(color: Color) -> float:
	var parts: Array[float] = []
	for value: float in [color.r, color.g, color.b]:
		parts.append(value / 12.92 if value <= 0.03928 else pow((value + 0.055) / 1.055, 2.4))
	return 0.2126 * parts[0] + 0.7152 * parts[1] + 0.0722 * parts[2]

## A frame drawn around the control that has keyboard focus; never the "selected" look.
static func focus_box(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.draw_center = false
	box.border_color = color
	box.set_border_width_all(3)
	box.set_corner_radius_all(3)
	box.set_expand_margin_all(2)
	return box
