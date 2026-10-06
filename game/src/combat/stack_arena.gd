extends CombatArena
signal finished(outcome: String, survivors: Array)
const Battle = preload("res://src/combat/stack_battle.gd")
var battle = Battle.new()
var heading := Label.new()
var turn_label := Label.new()
var allies := HBoxContainer.new()
var enemies := HBoxContainer.new()
var transcript := RichTextLabel.new()
var attack_button := Button.new()
var defend_button := Button.new()
var ability_button := Button.new()
var retreat_button := Button.new()
var finish_button := Button.new()
var selected_target := -1
var settled := false

func _ready() -> void:
	custom_minimum_size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop := ColorRect.new()
	backdrop.color = Color("#161b24")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 35)
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)
	heading.add_theme_font_size_override("font_size", 24)
	box.add_child(heading)
	box.add_child(turn_label)
	var enemy_title := Label.new()
	enemy_title.text = "ENEMIGOS · selecciona un objetivo"
	box.add_child(enemy_title)
	box.add_child(enemies)
	var ally_title := Label.new()
	ally_title.text = "TU EJÉRCITO · actúa el destacamento resaltado"
	box.add_child(ally_title)
	box.add_child(allies)
	transcript.bbcode_enabled = false
	transcript.scroll_following = true
	transcript.size_flags_vertical = Control.SIZE_EXPAND_FILL
	transcript.custom_minimum_size.y = 160
	box.add_child(transcript)
	var actions := HBoxContainer.new()
	for button in [attack_button, defend_button, ability_button, retreat_button, finish_button]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(button)
	box.add_child(actions)
	attack_button.text = "Atacar"
	defend_button.text = "Defender"
	retreat_button.text = "Retirarse"
	finish_button.text = "Volver al mapa"
	attack_button.pressed.connect(func(): command("attack"))
	defend_button.pressed.connect(func(): command("defend"))
	ability_button.pressed.connect(func(): command("ability"))
	retreat_button.pressed.connect(func(): command("retreat"))
	finish_button.pressed.connect(func():
		if not settled and not battle.outcome.is_empty():
			settled = true
			finished.emit(battle.outcome, battle.surviving_army()))
	hide()

func launch(army: Array, opposing: Array, seed_value: int, title: String) -> bool:
	if not battle.start(army, opposing, seed_value):
		return false
	heading.text = title
	settled = false
	selected_target = -1
	show()
	refresh()
	return true

func command(action: String) -> void:
	if battle.act(action, selected_target):
		refresh()

func refresh() -> void:
	for row in [allies, enemies]:
		for child in row.get_children():
			row.remove_child(child)
			child.queue_free()
	if selected_target < 0 or battle.count_at(selected_target) == 0:
		selected_target = -1
		for i in battle.stacks.size():
			if battle.stacks[i].side == 1 and battle.count_at(i) > 0:
				selected_target = i
				break
	for i in battle.stacks.size():
		var stack: Dictionary = battle.stacks[i]
		var unit: Dictionary = battle.data.units[stack.type]
		var card := Button.new()
		card.custom_minimum_size = Vector2(148, 95)
		card.text = "%s\n%d unidades\nSalud: %d" % [unit.name, battle.count_at(i), stack.stats.health]
		card.disabled = stack.side == 0 or battle.count_at(i) == 0 or not battle.outcome.is_empty()
		if i == battle.current():
			card.add_theme_color_override("font_disabled_color", Color("#ffdf87"))
		if i == selected_target:
			card.text = "▸ " + card.text
		if stack.side == 1:
			card.pressed.connect(func(): selected_target = i; refresh())
			enemies.add_child(card)
		else:
			allies.add_child(card)
	var actor: int = battle.current()
	var complete: bool = not battle.outcome.is_empty()
	turn_label.text = "Ronda %d · %s" % [battle.round_number,
		{"victory": "Victoria", "defeat": "Derrota", "retreated": "Retirada"}.get(battle.outcome, "Elige una acción")]
	attack_button.disabled = complete
	defend_button.disabled = complete
	retreat_button.disabled = complete
	ability_button.disabled = complete or actor < 0 or battle.stacks[actor].ability_used
	ability_button.text = str(battle.data.units[battle.stacks[actor].type].ability_name) if actor >= 0 else "Habilidad"
	finish_button.visible = complete
	transcript.text = "\n".join(battle.log)
