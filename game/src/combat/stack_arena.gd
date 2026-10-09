extends CombatArena
## Battle screen in the manner of a hex battlefield: the two armies face each other on
## ground drawn from the map's terrain, with count plates, a turn queue and animated
## strikes. The rules stay in stack_battle.gd and have no positions (master spec 13):
## the field and its hexes are presentation only.
signal finished(outcome: String, survivors: Array)
const Battle = preload("res://src/combat/stack_battle.gd")
const Battlefield = preload("res://src/combat/battlefield.gd")
const Token = preload("res://src/combat/stack_token.gd")
const ParchmentTheme = preload("res://src/common/parchment_theme.gd")
const ICONS := "res://assets/third_party/kenney_board_game_icons/"
const UI := "res://assets/third_party/kenney_ui_rpg/PNG/"
const SFX := "res://assets/sfx/"
const INK_LIGHT := Color("f6e7c1")
var battle = Battle.new()
## Map terrain under the battle; the map sets it before present().
var terrain := "grass"
var field := Battlefield.new()
var heading := Label.new()
var turn_label := Label.new()
var allies := Control.new()
var enemies := Control.new()
var effects := Control.new()
var queue_row := HBoxContainer.new()
var transcript := RichTextLabel.new()
var attack_button := Button.new()
var defend_button := Button.new()
var ability_button := Button.new()
var retreat_button := Button.new()
var wait_button := Button.new()
var finish_button := Button.new()
var result_panel := PanelContainer.new()
var result_title := Label.new()
var result_text := Label.new()
var selected_target := -1
## One line under the turn order: what an attack on the marked or hovered enemy would do.
var hint := Label.new()
const HINT := "Casilla iluminada: mover · Enemigo: atacar desde ese lado"
var settled := false
var tokens: Array = []
var animation: Tween
var sound := AudioStreamPlayer.new()

# Kenney Medieval RTS units (CC0): a figure per role, coloured by side.
const UNIT_ART := "res://assets/third_party/kenney_medieval_rts/Unit/medievalUnit_%02d.png"
const ROLE := {"militia": 3, "veteran_guard": 3, "ghost_guard": 3, "enforcer": 3, "inquisitorial_guard": 3,
	"archers": 2, "bandits": 2, "hired_blade": 2, "crossbow_guard": 2, "knife_fighter": 2, "crossbow_mercenary": 2,
	"relic_sentinel": 1, "hospitaller": 1, "relay_automaton": 4, "watchman": 6, "novice": 6, "thief": 6, "wolves": 6, "boars": 6}
const GREY := ["ghost_guard", "relic_sentinel", "relay_automaton"]
var icons := {}
# Battle for Wesnoth art (GPL v2+, assets/third_party/wesnoth): a painted portrait and a
# field sprite per unit type, both named after the unit. The Kenney figure is the fallback.
const WESNOTH := "res://assets/third_party/wesnoth/"
## Wesnoth marks team-coloured parts with this magenta ramp, darkest to lightest.
const TEAM_RAMP := ["3f0016", "55002a", "690039", "7b0045", "8c0051", "9e005d", "b10069", "c30074", "d6007f", "ec008c",
	"ee3d96", "ef5ba1", "f172ac", "f287b6", "f49ac1", "f6adcd", "f8c1d9", "fad5e5", "fde9f1"]
const TEAM_COLORS := [Color("3f74d1"), Color("cf3b32"), Color("a9b0b8")]
var sprites := {}
var portraits := {}
var portrait_view := TextureRect.new()
var portrait_name := Label.new()

## The unit's field sprite with its team parts in the side's colour, or null if absent.
func unit_sprite(type: String, side: int) -> Texture2D:
	var tone := 2 if type in GREY else side
	var key := "%s|%d" % [type, tone]
	if not sprites.has(key):
		sprites[key] = null
		var path := WESNOTH + "units/" + type + ".png"
		if ResourceLoader.exists(path):
			var image: Image = load(path).get_image()
			image.convert(Image.FORMAT_RGBA8)
			image = image.get_region(image.get_used_rect())
			var ramp := {}
			for index in TEAM_RAMP.size():
				ramp[Color(TEAM_RAMP[index]).to_rgba32()] = TEAM_COLORS[tone].darkened(0.6).lerp(TEAM_COLORS[tone].lightened(0.6), float(index) / float(TEAM_RAMP.size() - 1))
			for y in image.get_height():
				for x in image.get_width():
					var pixel := image.get_pixel(x, y)
					if pixel.a > 0.9 and ramp.has(pixel.to_rgba32()):
						image.set_pixel(x, y, ramp[pixel.to_rgba32()])
			sprites[key] = ImageTexture.create_from_image(image)
	return sprites[key]

## The unit's painted portrait, or null if absent.
func unit_portrait(type: String) -> Texture2D:
	if not portraits.has(type):
		var path := WESNOTH + "portraits/" + type + ".webp"
		portraits[type] = load(path) if ResourceLoader.exists(path) else null
	return portraits[type]

## Head and shoulders of the portrait, for the small tiles of the turn order.
func unit_face(type: String) -> Texture2D:
	var full := unit_portrait(type)
	if full == null:
		return null
	var face := AtlasTexture.new()
	face.atlas = full
	var side := full.get_size().x
	face.region = Rect2(side * 0.14, 0, side * 0.72, side * 0.72)
	return face

## Shows a stack in the card of the command bar: portrait, name, numbers.
func show_card(index: int) -> void:
	if index < 0 or index >= battle.stacks.size() or battle.count_at(index) == 0:
		return
	var stack: Dictionary = battle.stacks[index]
	var unit: Dictionary = battle.data.units[stack.type]
	portrait_view.texture = unit_portrait(str(stack.type))
	portrait_view.flip_h = int(stack.side) == 1
	portrait_name.text = "%s · %d\nSalud %d · Ataque %d · Defensa %d\nDaño %d–%d · Mov. %d" % [unit.name, battle.count_at(index), stack.stats.health,
		stack.stats.attack, stack.stats.defense, unit.damage_min, unit.damage_max, stack.speed]

## Blue for the player, red for the enemy, grey for spectral and relic units.
## The figure is cropped to its drawn pixels; callers scale it.
func unit_icon(type: String, side: int) -> Texture2D:
	var number: int = ROLE.get(type, 6) + (18 if type in GREY else 0 if side == 0 else 6)
	if not icons.has(number):
		var path := UNIT_ART % number
		icons[number] = null
		if ResourceLoader.exists(path):
			var image: Image = load(path).get_image()
			icons[number] = ImageTexture.create_from_image(image.get_region(image.get_used_rect()))
	return icons[number]

func _texture(path: String) -> Texture2D:
	return load(path) if ResourceLoader.exists(path) else null

func _frame(file: String, margin: int) -> StyleBox:
	var texture := _texture(UI + file)
	if texture == null:
		var flat := StyleBoxFlat.new()
		flat.bg_color = Color("4a3322")
		return flat
	var box := StyleBoxTexture.new()
	box.texture = texture
	box.set_texture_margin_all(margin)
	box.set_content_margin_all(margin)
	return box

func _ready() -> void:
	theme = Theme.new()
	theme.default_font = ThemeDB.fallback_font
	theme.default_font_size = 18
	custom_minimum_size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	field.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	field.hex_clicked.connect(_on_hex)
	field.hex_hovered.connect(_on_hover)
	field.describe = _describe
	field.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_child(field)
	for layer in [allies, enemies, effects]:
		layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(layer)
	resized.connect(_layout)
	sound.bus = &"SFX"
	add_child(sound)
	_build_top_bar()
	_build_command_bar()
	_build_result()
	hide()

func _build_top_bar() -> void:
	var bar := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.09, 0.06, 0.9)
	style.border_color = Color("b8913f")
	style.border_width_bottom = 3
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	bar.add_theme_stylebox_override("panel", style)
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.custom_minimum_size.y = 60
	add_child(bar)
	var row := HBoxContainer.new()
	bar.add_child(row)
	row.add_child(_banner("TU EJÉRCITO", Color("5d8fe0"), false))
	var middle := VBoxContainer.new()
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 0)
	heading.add_theme_font_size_override("font_size", 22)
	heading.add_theme_color_override("font_color", Color("f3d27a"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.clip_text = true
	turn_label.add_theme_font_size_override("font_size", 15)
	turn_label.add_theme_color_override("font_color", INK_LIGHT)
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	middle.add_child(heading)
	middle.add_child(turn_label)
	row.add_child(middle)
	row.add_child(_banner("ENEMIGOS", Color("e05d5d"), true))

func _banner(text: String, color: Color, flag_right: bool) -> Control:
	var box := HBoxContainer.new()
	box.custom_minimum_size.x = 220
	box.alignment = BoxContainer.ALIGNMENT_END if flag_right else BoxContainer.ALIGNMENT_BEGIN
	var flag := TextureRect.new()
	flag.texture = _texture(ICONS + "flag_triangle.png")
	flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	flag.custom_minimum_size = Vector2(30, 30)
	flag.modulate = color
	flag.flip_h = flag_right
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", color.lightened(0.35))
	for control in ([label, flag] if flag_right else [flag, label]):
		box.add_child(control)
	return box

func _build_command_bar() -> void:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", _frame("panel_brown.png", 12))
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -176
	add_child(bar)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	bar.add_child(rows)
	var queue_line := HBoxContainer.new()
	var queue_title := Label.new()
	queue_title.text = "Turnos:"
	queue_title.add_theme_font_size_override("font_size", 15)
	queue_title.add_theme_color_override("font_color", INK_LIGHT)
	queue_line.add_child(queue_title)
	queue_row.add_theme_constant_override("separation", 4)
	queue_line.add_child(queue_row)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	queue_line.add_child(spacer)
	hint.text = HINT
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color("f6e7c1"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	queue_line.add_child(hint)
	rows.add_child(queue_line)
	var lower := HBoxContainer.new()
	lower.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lower.add_theme_constant_override("separation", 12)
	rows.add_child(lower)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 4)
	lower.add_child(grid)
	for pair in [[attack_button, "Atacar", "sword.png"], [defend_button, "Defender", "shield.png"],
			[wait_button, "Esperar", "hourglass.png"], [ability_button, "Habilidad", "fire.png"],
			[retreat_button, "Retirarse", "flag_triangle.png"]]:
		var button: Button = pair[0]
		button.text = pair[1]
		button.icon = _texture(ICONS + pair[2])
		_style_button(button)
		button.custom_minimum_size = Vector2(196, 46)
		grid.add_child(button)
	attack_button.tooltip_text = "Tecla A. Ataca al objetivo marcado en rojo. En el campo: clic en una casilla iluminada para mover, clic en un enemigo para atacarlo desde ese lado."
	defend_button.tooltip_text = "Tecla D. Recibe menos daño hasta su próximo turno."
	retreat_button.tooltip_text = "Tecla R. Termina la batalla y conserva los supervivientes."
	wait_button.tooltip_text = "Tecla E. El destacamento actúa al final de la ronda (una vez por ronda)."
	wait_button.pressed.connect(func(): command("wait"))
	attack_button.pressed.connect(func(): command("attack"))
	defend_button.pressed.connect(func(): command("defend"))
	ability_button.pressed.connect(func(): command("ability"))
	retreat_button.pressed.connect(func(): command("retreat"))
	# The card of the acting stack, or of the enemy under the pointer.
	portrait_view.custom_minimum_size = Vector2(88, 88)
	portrait_view.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	portrait_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	lower.add_child(portrait_view)
	portrait_name.custom_minimum_size.x = 210
	portrait_name.add_theme_font_size_override("font_size", 15)
	portrait_name.add_theme_color_override("font_color", INK_LIGHT)
	lower.add_child(portrait_name)
	var log_frame := PanelContainer.new()
	log_frame.add_theme_stylebox_override("panel", _frame("panelInset_brown.png", 10))
	log_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lower.add_child(log_frame)
	transcript.bbcode_enabled = false
	transcript.scroll_following = true
	transcript.custom_minimum_size.y = 90
	transcript.add_theme_font_size_override("normal_font_size", 14)
	transcript.add_theme_color_override("default_color", INK_LIGHT)
	log_frame.add_child(transcript)

func _style_button(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _frame("buttonLong_brown.png", 10))
	var hover := _frame("buttonLong_brown.png", 10)
	if hover is StyleBoxTexture:
		hover.modulate_color = Color(1.25, 1.18, 1.05)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", _frame("buttonLong_brown_pressed.png", 10))
	button.add_theme_stylebox_override("disabled", _frame("buttonLong_grey.png", 10))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, INK_LIGHT)
	button.add_theme_color_override("font_disabled_color", Color("5a5148"))
	button.add_theme_constant_override("icon_max_width", 24)
	button.add_theme_font_size_override("font_size", 17)

func _build_result() -> void:
	result_panel.custom_minimum_size = Vector2(480, 0)
	ParchmentTheme.apply(result_panel)
	add_child(result_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	result_panel.add_child(box)
	result_title.add_theme_font_size_override("font_size", 30)
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(result_title)
	result_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_text.custom_minimum_size.x = 420
	result_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(result_text)
	finish_button.text = "Volver al mapa"
	finish_button.custom_minimum_size.y = 44
	box.add_child(finish_button)
	finish_button.pressed.connect(func():
		if not settled and not battle.outcome.is_empty():
			settled = true
			finished.emit(battle.outcome, battle.surviving_army()))
	result_panel.hide()

func launch(army: Array, opposing: Array, seed_value: int, title: String) -> bool:
	if not battle.start(army, opposing, seed_value):
		return false
	present(battle, title)
	return true

func present(model: RefCounted, title: String) -> void:
	battle = model
	heading.text = title
	settled = false
	selected_target = -1
	if animation != null:
		animation.kill()
	for child in effects.get_children():
		child.queue_free()
	field.setup(terrain, hash(title), battle.obstacles)
	for row in [allies, enemies]:
		for child in row.get_children():
			row.remove_child(child)
			child.queue_free()
	tokens.clear()
	for i in battle.stacks.size():
		var stack: Dictionary = battle.stacks[i]
		var token := Token.new()
		token.side = int(stack.side)
		token.figure = unit_sprite(str(stack.type), token.side)
		if token.figure != null:
			token.figure_scale = 1.9
		else:
			token.figure = unit_icon(str(stack.type), token.side)
		(enemies if stack.side == 1 else allies).add_child(token)
		tokens.append(token)
	show()
	_layout()
	refresh()
	# Enemies faster than the whole player army have already moved: show it.
	_animate(battle.events)

## Places each token on its stack's hex.
func _layout() -> void:
	if tokens.is_empty():
		return
	var hex := field.hex_size()
	for i in mini(tokens.size(), battle.stacks.size()):
		tokens[i].hex = hex
		tokens[i].position = _spot(battle.stacks[i].cell, i)
	result_panel.size = Vector2.ZERO
	result_panel.reset_size()
	result_panel.position = ((size - result_panel.size) / 2.0 - Vector2(0, 60)).floor()

## Token position that puts stack i on a hex.
func _spot(cell: Vector2i, i: int) -> Vector2:
	return field.center_of(cell) - tokens[i].foot()

## Click on the field: an enemy hex attacks it from the side nearest the click, a lit
## hex moves the acting stack there.
func _on_hex(cell: Vector2i, point: Vector2) -> void:
	var actor: int = battle.current()
	if actor < 0 or not battle.outcome.is_empty():
		return
	var who: int = battle.occupant(cell)
	if who >= 0 and battle.stacks[who].side == 1:
		selected_target = who
		field.strike_from = Battle.NOWHERE
		command("attack", _side_toward(cell, point))
	elif who == -1 and cell != battle.stacks[actor].cell and battle.reachable(actor).has(cell):
		command("move", cell)

## Over an enemy, light the hex the acting stack would strike from (melee only).
func _on_hover(cell: Vector2i) -> void:
	field.strike_from = Battle.NOWHERE
	var actor: int = battle.current()
	var who: int = battle.occupant(cell) if cell != Battle.NOWHERE else -1
	hint.text = forecast_text(who if who >= 0 and battle.stacks[who].side == 1 else selected_target)
	show_card(who if who >= 0 else battle.current())
	if actor < 0 or who < 0 or battle.stacks[who].side != 1 or not battle.outcome.is_empty():
		return
	if battle.data.units[battle.stacks[actor].type].ranged and battle._adjacent_enemies(actor).is_empty():
		return
	var from: Vector2i = battle.attack_cell(actor, who, _side_toward(cell, field.get_local_mouse_position()))
	if from != battle.stacks[actor].cell:
		field.strike_from = from

## The forecast of an attack on that enemy as one line; the general hint when there is none.
func forecast_text(target: int) -> String:
	var actor: int = battle.current()
	if actor < 0 or not battle.outcome.is_empty():
		return HINT
	var forecast: Dictionary = battle.forecast(actor, target)
	if forecast.is_empty():
		return HINT
	var name := str(battle.data.units[battle.stacks[forecast.target].type].name)
	if not forecast.reach:
		return "✗ %s: fuera de alcance este turno; el destacamento solo avanzará." % name
	var damage: String = str(forecast.low) if forecast.low == forecast.high else "%d–%d" % [forecast.low, forecast.high]
	var losses: String = str(forecast.losses_low) if forecast.losses_low == forecast.losses_high else "%d–%d" % [forecast.losses_low, forecast.losses_high]
	var line := "ATACAR a %s: daño %s · bajas %s de %d" % [name, damage, losses, forecast.count]
	if forecast.far:
		line += " · disparo lejano (mitad)"
	if forecast.trapped:
		line += " · trabado: cuerpo a cuerpo (mitad)"
	line += " · responde: hasta %d" % forecast.answer if forecast.answer > 0 else " · sin respuesta"
	if forecast.lucky:
		line += " · la suerte puede duplicarlo"
	var special: Dictionary = battle.forecast(actor, target, "ability")
	if not battle.stacks[actor].ability_used and special.get("reach", false) and (special.low != forecast.low or special.high != forecast.high):
		line += "\n%s: daño %d–%d" % [battle.data.units[battle.stacks[actor].type].ability_name, special.low, special.high]
	return line

## One key per action (docs/UI_PLAN.md, stage 5). Handled here rather than with Button
## shortcuts: those kept the headless test process from exiting.
func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event is InputEventKey or not event.pressed or event.echo or event.ctrl_pressed or event.alt_pressed:
		return
	var keys := {KEY_A: attack_button, KEY_D: defend_button, KEY_E: wait_button, KEY_H: ability_button, KEY_R: retreat_button}
	if keys.has(event.keycode):
		var button: Button = keys[event.keycode]
		if button.visible and not button.disabled:
			button.pressed.emit()
		get_viewport().set_input_as_handled()

func _side_toward(cell: Vector2i, point: Vector2) -> Vector2i:
	var side := Battle.NOWHERE
	for around in Battle.neighbors(cell):
		if side == Battle.NOWHERE or point.distance_to(field.center_of(around)) < point.distance_to(field.center_of(side)):
			side = around
	return side

func _describe(cell: Vector2i) -> String:
	var i: int = battle.occupant(cell)
	if i < 0:
		return "Roca: no se puede pasar." if cell in battle.obstacles else ""
	var stack: Dictionary = battle.stacks[i]
	var unit: Dictionary = battle.data.units[stack.type]
	var actor: int = battle.current()
	var shot_note := ""
	if actor >= 0 and stack.side == 1 and battle.data.units[battle.stacks[actor].type].ranged and battle._adjacent_enemies(actor).is_empty():
		shot_note = "\nDisparo desde aquí: " + ("mitad de daño (más de %d casillas)" % Battle.FULL_RANGE if battle.far_shot(actor, i) else "daño completo")
	return "%s · %d unidades\nSalud: %d · Ataque %d · Defensa %d\nDaño %d-%d · Iniciativa %d · Movimiento %d%s%s\nHabilidad: %s" % [
		unit.name, battle.count_at(i), stack.stats.health, stack.stats.attack, stack.stats.defense,
		unit.damage_min, unit.damage_max, stack.stats.speed, stack.speed, " · dispara" if unit.ranged else "",
		" · vuela" if stack.flying else "", unit.ability_name] + shot_note

func command(action: String, cell: Vector2i = Battle.NOWHERE) -> void:
	var target := selected_target if action in ["attack", "ability"] else -1
	if battle.act(action, target, cell):
		refresh()
		_animate(battle.events)

func refresh() -> void:
	if selected_target < 0 or battle.count_at(selected_target) == 0:
		selected_target = -1
		for i in battle.stacks.size():
			if battle.stacks[i].side == 1 and battle.count_at(i) > 0:
				selected_target = i
				break
	var actor: int = battle.current()
	var complete: bool = not battle.outcome.is_empty()
	for i in mini(tokens.size(), battle.stacks.size()):
		var stack: Dictionary = battle.stacks[i]
		var unit: Dictionary = battle.data.units[stack.type]
		var token = tokens[i]
		token.count = battle.count_at(i)
		token.health_ratio = float(stack.stats.health) / maxf(1.0, float(stack.stats.max_health))
		token.active = i == actor and not complete
		token.targeted = i == selected_target and not complete
		token.selectable = stack.side == 1 and token.count > 0 and not complete
		token.queue_redraw()
	var reach: Array = []
	if actor >= 0 and not complete:
		for cell in battle.reachable(actor):
			if cell != battle.stacks[actor].cell:
				reach.append(cell)
	field.show_reach(reach)
	var acting := ""
	if actor >= 0:
		var mover: Dictionary = battle.stacks[actor]
		acting = " · Actúa: %s (%d) · Movimiento %d%s" % [battle.data.units[mover.type].name, battle.count_at(actor), mover.speed,
			("" if not battle.data.units[mover.type].ranged else (" · dispara" + (" (lejos: mitad de daño)" if selected_target >= 0 and battle.far_shot(actor, selected_target) else "")) if battle._adjacent_enemies(actor).is_empty() else " · trabado: lucha cuerpo a cuerpo")]
	turn_label.text = "Ronda %d · %s%s" % [battle.round_number,
		{"victory": "Victoria", "defeat": "Derrota", "retreated": "Retirada"}.get(battle.outcome, "Elige una acción"), acting]
	attack_button.disabled = complete
	defend_button.disabled = complete
	retreat_button.disabled = complete
	wait_button.disabled = complete or actor < 0 or battle.stacks[actor].waited or battle.queue.size() < 2
	ability_button.disabled = complete or actor < 0 or battle.stacks[actor].ability_used
	ability_button.text = str(battle.data.units[battle.stacks[actor].type].ability_name) if actor >= 0 else "Habilidad"
	finish_button.visible = complete
	result_panel.visible = complete
	if complete:
		result_title.text = {"victory": "Victoria", "defeat": "Derrota", "retreated": "Retirada"}.get(battle.outcome, "")
		var survivors: Array = []
		for item: Dictionary in battle.surviving_army():
			# Unit names mix singular and plural ("Milicia", "Arqueros"): name, then count.
			survivors.append("%s: %d" % [battle.data.units[item.type].name, item.count])
		result_text.text = ("Supervivientes · " + " · ".join(survivors)) if not survivors.is_empty() else "No queda nadie de tu ejército."
		_layout()
	transcript.text = "\n".join(battle.log)
	hint.text = forecast_text(selected_target)
	show_card(actor)
	_refresh_queue(actor)

func _refresh_queue(actor: int) -> void:
	for child in queue_row.get_children():
		queue_row.remove_child(child)
		child.queue_free()
	var order: Array = battle.queue.duplicate() if battle.outcome.is_empty() else []
	for n in mini(order.size(), 12):
		var i: int = order[n]
		if battle.count_at(i) == 0:
			continue
		var slot := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Token.SIDE_COLORS[int(battle.stacks[i].side)].darkened(0.35)
		style.border_color = Token.GOLD if i == actor else Color(0, 0, 0, 0.5)
		style.set_border_width_all(3 if i == actor else 1)
		style.set_content_margin_all(2)
		slot.add_theme_stylebox_override("panel", style)
		slot.tooltip_text = str(battle.data.units[battle.stacks[i].type].name)
		var inner := HBoxContainer.new()
		inner.add_theme_constant_override("separation", 2)
		var picture := TextureRect.new()
		var face := unit_face(str(battle.stacks[i].type))
		picture.texture = face if face != null else (tokens[i].figure if i < tokens.size() else null)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.custom_minimum_size = Vector2(46, 46) if i == actor else Vector2(38, 38)
		picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		picture.flip_h = int(battle.stacks[i].side) == 1
		inner.add_child(picture)
		var number := Label.new()
		number.text = str(battle.count_at(i))
		number.add_theme_font_size_override("font_size", 14)
		number.add_theme_color_override("font_color", Color.WHITE)
		inner.add_child(number)
		slot.add_child(inner)
		queue_row.add_child(slot)

## Plays the moves and strikes of the last command in order: stacks walk hex by hex,
## melee stacks lunge at their target, shooters loose a bolt; each hit shows the damage.
func _animate(events: Array) -> void:
	if animation != null:
		animation.kill()
	if tokens.is_empty():
		return
	var spots: Array = []
	for i in tokens.size():
		spots.append(_spot(battle.stacks[i].cell, i))
	for event: Dictionary in events:
		if event.kind == "move":
			var i: int = event.stack
			if spots[i] == _spot(battle.stacks[i].cell, i):
				spots[i] = _spot(event.path[0], i)
	for i in tokens.size():
		tokens[i].position = spots[i]
	animation = create_tween()
	for event: Dictionary in events.slice(0, 24):
		if event.kind == "move":
			var i: int = event.stack
			for k in range(1, event.path.size()):
				animation.tween_property(tokens[i], "position", _spot(event.path[k], i), 0.09 if not battle.stacks[i].flying else 0.16)
			spots[i] = _spot(event.path[-1], i)
		elif event.kind == "strike":
			var actor: int = event.actor
			var target: int = event.target
			var from: Vector2 = spots[actor]
			var at: Vector2 = spots[target] + tokens[target].foot()
			if event.shot:
				animation.tween_callback(_bolt.bind(from + tokens[actor].foot(), at))
				animation.tween_interval(0.28)
			else:
				animation.tween_property(tokens[actor], "position", from + (spots[target] - from) * 0.4, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			animation.tween_callback(_hit.bind(target, int(event.amount), bool(event.shot), at))
			if not event.shot:
				animation.tween_property(tokens[actor], "position", from, 0.18).set_trans(Tween.TRANS_QUAD)
			animation.tween_interval(0.1)
	animation.tween_callback(_layout)

func _bolt(from_foot: Vector2, to_foot: Vector2) -> void:
	var bolt := ColorRect.new()
	bolt.color = Color("f4e2b0")
	bolt.size = Vector2(18, 3)
	var start: Vector2 = from_foot - Vector2(0, 40)
	var end: Vector2 = to_foot - Vector2(0, 40)
	bolt.position = start
	bolt.rotation = (end - start).angle()
	bolt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effects.add_child(bolt)
	var flight := create_tween()
	flight.tween_property(bolt, "position", end, 0.26)
	flight.tween_callback(bolt.queue_free)

func _hit(target: int, amount: int, ranged: bool, at: Vector2) -> void:
	_play("knifeSlice.ogg" if ranged else ["impactPlate_heavy_001.ogg", "impactMetal_medium_000.ogg", "impactPunch_medium_000.ogg"][amount % 3])
	var token: Control = tokens[target]
	var flash := create_tween()
	token.modulate = Color(1.6, 0.6, 0.55)
	flash.tween_property(token, "modulate", Color.WHITE, 0.3)
	var number := Label.new()
	number.text = "-%d" % amount
	number.add_theme_font_size_override("font_size", 24)
	number.add_theme_color_override("font_color", Color("ffdf6b"))
	number.add_theme_color_override("font_outline_color", Color("3a1408"))
	number.add_theme_constant_override("outline_size", 6)
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	number.position = at - Vector2(18, 92)
	effects.add_child(number)
	var rise := create_tween()
	rise.tween_property(number, "position:y", number.position.y - 36, 0.8)
	rise.parallel().tween_property(number, "modulate:a", 0.0, 0.8).set_delay(0.3)
	rise.tween_callback(number.queue_free)

func _play(file: String) -> void:
	var stream: AudioStream = load(SFX + file) if ResourceLoader.exists(SFX + file) else null
	if stream != null:
		sound.stream = stream
		sound.play()
