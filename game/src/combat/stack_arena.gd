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
var finish_button := Button.new()
var result_panel := PanelContainer.new()
var result_title := Label.new()
var result_text := Label.new()
var selected_target := -1
var settled := false
var tokens: Array = []
var homes: Array = []
var animation: Tween
var sound := AudioStreamPlayer.new()

# Kenney Medieval RTS units (CC0): a figure per role, coloured by side.
const UNIT_ART := "res://assets/third_party/kenney_medieval_rts/Unit/medievalUnit_%02d.png"
const ROLE := {"militia": 3, "veteran_guard": 3, "ghost_guard": 3, "enforcer": 3, "inquisitorial_guard": 3,
	"archers": 2, "bandits": 2, "hired_blade": 2, "crossbow_guard": 2, "knife_fighter": 2, "crossbow_mercenary": 2,
	"relic_sentinel": 1, "hospitaller": 1, "relay_automaton": 4, "watchman": 6, "novice": 6, "thief": 6}
const GREY := ["ghost_guard", "relic_sentinel", "relay_automaton"]
var icons := {}

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
	rows.add_child(queue_line)
	var lower := HBoxContainer.new()
	lower.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lower.add_theme_constant_override("separation", 12)
	rows.add_child(lower)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 4)
	lower.add_child(grid)
	for pair in [[attack_button, "Atacar", "sword.png"], [defend_button, "Defender", "shield.png"],
			[ability_button, "Habilidad", "fire.png"], [retreat_button, "Retirarse", "flag_triangle.png"]]:
		var button: Button = pair[0]
		button.text = pair[1]
		button.icon = _texture(ICONS + pair[2])
		_style_button(button)
		button.custom_minimum_size = Vector2(230, 46)
		grid.add_child(button)
	attack_button.tooltip_text = "Ataca al objetivo marcado en rojo (clic en un enemigo para cambiarlo)."
	defend_button.tooltip_text = "Recibe menos daño hasta su próximo turno."
	retreat_button.tooltip_text = "Termina la batalla y conserva los supervivientes."
	attack_button.pressed.connect(func(): command("attack"))
	defend_button.pressed.connect(func(): command("defend"))
	ability_button.pressed.connect(func(): command("ability"))
	retreat_button.pressed.connect(func(): command("retreat"))
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
	field.setup(terrain, hash(title))
	for row in [allies, enemies]:
		for child in row.get_children():
			row.remove_child(child)
			child.queue_free()
	tokens.clear()
	for i in battle.stacks.size():
		var stack: Dictionary = battle.stacks[i]
		var token := Token.new()
		token.side = int(stack.side)
		token.figure = unit_icon(str(stack.type), token.side)
		if stack.side == 1:
			token.pressed.connect(func():
				if battle.count_at(i) > 0 and battle.outcome.is_empty():
					selected_target = i
					refresh())
			enemies.add_child(token)
		else:
			allies.add_child(token)
		tokens.append(token)
	show()
	_layout()
	refresh()

## Places each stack on its hex: the player in the second column, the enemy in the tenth.
func _layout() -> void:
	if tokens.is_empty():
		return
	homes.clear()
	homes.resize(tokens.size())
	var hex := field.hex_size()
	for side in [0, 1]:
		var members: Array = []
		for i in battle.stacks.size():
			if int(battle.stacks[i].side) == side:
				members.append(i)
		var rows: Array = Battlefield.rows_for(members.size())
		for n in members.size():
			var token: Control = tokens[members[n]]
			token.hex = hex
			var center := field.cell_center(1 if side == 0 else Battlefield.COLUMNS - 2, rows[n])
			homes[members[n]] = center - token.foot()
			token.position = homes[members[n]]
	result_panel.size = Vector2.ZERO
	result_panel.reset_size()
	result_panel.position = ((size - result_panel.size) / 2.0 - Vector2(0, 60)).floor()

func command(action: String) -> void:
	var before: Array = []
	for i in battle.stacks.size():
		before.append(int(battle.stacks[i].stats.health))
	var lines_before: int = battle.log.size()
	if battle.act(action, selected_target):
		refresh()
		var fresh: Array = battle.log.slice(lines_before) if battle.log.size() >= lines_before else []
		_animate(fresh, before)

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
		token.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if token.selectable else Control.CURSOR_ARROW
		token.tooltip_text = "%s · %d unidades\nSalud: %d · Ataque %d · Defensa %d\nDaño %d-%d · Iniciativa %d%s\nHabilidad: %s" % [
			unit.name, token.count, stack.stats.health, stack.stats.attack, stack.stats.defense,
			unit.damage_min, unit.damage_max, stack.stats.speed, " · a distancia" if unit.ranged else "", unit.ability_name]
		token.queue_redraw()
	var acting := ""
	if actor >= 0:
		acting = " · Actúa: %s (%d)" % [battle.data.units[battle.stacks[actor].type].name, battle.count_at(actor)]
	turn_label.text = "Ronda %d · %s%s" % [battle.round_number,
		{"victory": "Victoria", "defeat": "Derrota", "retreated": "Retirada"}.get(battle.outcome, "Elige una acción"), acting]
	attack_button.disabled = complete
	defend_button.disabled = complete
	retreat_button.disabled = complete
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
		picture.texture = tokens[i].figure if i < tokens.size() else null
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.custom_minimum_size = Vector2(30, 34)
		picture.flip_h = int(battle.stacks[i].side) == 1
		inner.add_child(picture)
		var number := Label.new()
		number.text = str(battle.count_at(i))
		number.add_theme_font_size_override("font_size", 14)
		number.add_theme_color_override("font_color", Color.WHITE)
		inner.add_child(number)
		slot.add_child(inner)
		queue_row.add_child(slot)

## Plays the strikes of the last command in order: melee stacks lunge at their target,
## ranged stacks loose a bolt; each hit shows the damage over the target.
func _animate(lines: Array, before: Array) -> void:
	if animation != null:
		animation.kill()
	for i in tokens.size():
		if i < homes.size() and homes[i] != null:
			tokens[i].position = homes[i]
	animation = create_tween()
	var steps := 0
	for line in lines:
		var parts := _strike_parts(str(line))
		if parts.is_empty() or steps >= 10:
			continue
		steps += 1
		var actor: int = parts[0]
		var target: int = parts[1]
		var amount: int = parts[2]
		var from: Vector2 = homes[actor]
		var toward: Vector2 = (homes[target] - homes[actor])
		if battle.data.units[battle.stacks[actor].type].ranged:
			animation.tween_callback(_bolt.bind(actor, target))
			animation.tween_interval(0.28)
		else:
			animation.tween_property(tokens[actor], "position", from + toward * 0.42, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		animation.tween_callback(_hit.bind(target, amount, battle.data.units[battle.stacks[actor].type].ranged))
		if not battle.data.units[battle.stacks[actor].type].ranged:
			animation.tween_property(tokens[actor], "position", from, 0.2).set_trans(Tween.TRANS_QUAD)
		animation.tween_interval(0.12)
	if steps == 0:
		animation.tween_interval(0.01)

## Reads "Actor → Target: N de daño; quedan M." back into stack indices.
func _strike_parts(line: String) -> Array:
	var arrow := line.find(" → ")
	var colon := line.find(": ", arrow)
	if arrow < 0 or colon < 0:
		return []
	var actor_name := line.substr(0, arrow)
	var target_name := line.substr(arrow + 3, colon - arrow - 3)
	var amount := int(line.substr(colon + 2).split(" ")[0])
	for actor in battle.stacks.size():
		if str(battle.data.units[battle.stacks[actor].type].name) != actor_name:
			continue
		for target in battle.stacks.size():
			if battle.stacks[target].side != battle.stacks[actor].side and str(battle.data.units[battle.stacks[target].type].name) == target_name:
				return [actor, target, amount]
	return []

func _bolt(actor: int, target: int) -> void:
	var bolt := ColorRect.new()
	bolt.color = Color("f4e2b0")
	bolt.size = Vector2(18, 3)
	var start: Vector2 = homes[actor] + tokens[actor].foot() - Vector2(0, 40)
	var end: Vector2 = homes[target] + tokens[target].foot() - Vector2(0, 40)
	bolt.position = start
	bolt.rotation = (end - start).angle()
	bolt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effects.add_child(bolt)
	var flight := create_tween()
	flight.tween_property(bolt, "position", end, 0.26)
	flight.tween_callback(bolt.queue_free)

func _hit(target: int, amount: int, ranged: bool) -> void:
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
	number.position = homes[target] + token.foot() - Vector2(18, 92)
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
