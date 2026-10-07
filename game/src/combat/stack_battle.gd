extends RefCounted
## Stack adapter using the retained Open RPG health/stat resource.
const Stats = preload("res://src/combat/battlers/battler_stats.gd")
const DATA_PATH := "res://content/combat/stacks.json"
const MAX_STACKS := 7
const BONUS_CAPS := {"army_attack":20,"army_defense":20,"army_hp_percent":50,"army_initiative":5,
	"army_luck":3,"army_morale":3,"world_movement":6,"ranged_damage_percent":50}
var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
var stacks: Array = []
var queue: Array = []
var round_number := 0
var outcome := ""
var log: Array[String] = []
var rng := RandomNumberGenerator.new()
var enemy_script: Dictionary = {}

func valid_army(army: Variant) -> bool:
	if not army is Array or army.is_empty() or army.size() > MAX_STACKS:
		return false
	for item in army:
		if not item is Dictionary or item.size() != 2 or not item.get("type") is String:
			return false
		if not data.units.has(item.type):
			return false
		var count_value: Variant = item.get("count")
		if not (count_value is int or count_value is float) or not is_finite(count_value):
			return false
		if count_value != floor(count_value) or count_value < 1 or count_value > 100000:
			return false
	return true

func start(allies: Array, enemies: Array, seed_value: int = 1, bonuses: Dictionary = {}, script: Dictionary = {}) -> bool:
	if not valid_army(allies) or not valid_army(enemies) or not _valid_script(script):
		return false
	for key in bonuses:
		var value: Variant = bonuses[key]
		if not BONUS_CAPS.has(key) or not (value is int or value is float) or not is_finite(value) or value != floor(value) or value < 0 or value > BONUS_CAPS[key]:
			return false
	enemy_script = script.duplicate(true)
	stacks.clear()
	queue.clear()
	log.clear()
	outcome = ""
	round_number = 0
	rng.seed = seed_value
	for side in [0, 1]:
		var army: Array = allies if side == 0 else enemies
		var effects: Dictionary = bonuses if side == 0 else {}
		for item: Dictionary in army:
			var definition: Dictionary = data.units[item.type]
			var stats := Stats.new()
			var unit_hp := maxi(1,roundi(int(definition.hp) * (1.0 + float(effects.get("army_hp_percent",0)) / 100.0)))
			stats.base_max_health = int(item.count) * unit_hp
			stats.max_health = stats.base_max_health
			stats.initialize()
			stats.base_attack = int(definition.attack) + int(effects.get("army_attack",0))
			stats.base_defense = int(definition.defense) + int(effects.get("army_defense",0))
			stats.base_speed = int(definition.initiative) + int(effects.get("army_initiative",0))
			stacks.append({"type": item.type, "side": side, "stats": stats,
				"unit_hp":unit_hp,"luck":int(effects.get("army_luck",0)),"morale":int(effects.get("army_morale",0)),"morale_round":0,"ranged_bonus":int(effects.get("ranged_damage_percent",0)), "defending": false, "brace_active":false, "last_attacker":-1, "ability_used": false, "retaliated": false})
	_new_round()
	_run_enemies()
	return true

func count_at(index: int) -> int:
	if index < 0 or index >= stacks.size():
		return 0
	return ceili(float(stacks[index].stats.health) / float(stacks[index].unit_hp))

func current() -> int:
	return int(queue.front()) if not queue.is_empty() and outcome.is_empty() else -1

func surviving_army(side: int = 0) -> Array:
	var result: Array = []
	for i in stacks.size():
		if stacks[i].side == side and count_at(i) > 0:
			result.append({"type": str(stacks[i].type), "count": count_at(i)})
	return result

func act(command: String, target: int = -1) -> bool:
	var actor := current()
	if actor < 0 or stacks[actor].side != 0:
		return false
	if command == "retreat":
		outcome = "retreated"
		log.append("Tu ejército se retira. Conservas los supervivientes.")
		return true
	if not _execute(actor, command, target):
		return false
	if command in ["attack","ability"] and stacks[actor].morale > 0 and count_at(actor) > 0 and not surviving_army(1).is_empty() and stacks[actor].morale_round != round_number:
		if rng.randf() < float(stacks[actor].morale) * 0.05:
			stacks[actor].morale_round = round_number
			queue.insert(1,actor)
			log.append(str(data.units[stacks[actor].type].name) + " gana una acción por moral.")
	_advance()
	_run_enemies()
	return true

func _new_round() -> void:
	round_number += 1
	queue.clear()
	for i in stacks.size():
		if count_at(i) > 0:
			stacks[i].retaliated = false
			queue.append(i)
	queue.sort_custom(func(a: int, b: int):
		if stacks[a].stats.speed == stacks[b].stats.speed:
			return a < b
		return stacks[a].stats.speed > stacks[b].stats.speed)
	if not queue.is_empty():
		stacks[queue.front()].defending = false
		stacks[queue.front()].brace_active = false

func _damage(actor: int, target: int, roll: bool = true, ignore_defend: bool = false) -> int:
	var unit: Dictionary = data.units[stacks[actor].type]
	var base: int = rng.randi_range(int(unit.damage_min), int(unit.damage_max)) if roll else int(unit.damage_min)
	var delta: int = stacks[actor].stats.attack - stacks[target].stats.defense
	var multiplier := 1.0 + 0.05 * clampi(delta, 0, 60) if delta >= 0 else 1.0 / (1.0 + 0.05 * mini(-delta, 60))
	if unit.ranged:
		multiplier *= 1.0 + float(stacks[actor].ranged_bonus) / 100.0
	if not ignore_defend:
		if stacks[target].defending:
			multiplier *= 0.65
		if stacks[target].brace_active:
			multiplier *= 0.5
	return maxi(1, roundi(count_at(actor) * base * multiplier))

func _strike(actor: int, target: int, multiplier: float = 1.0, ignore_defend: bool = false) -> int:
	var amount := maxi(1, roundi(_damage(actor, target, true, ignore_defend) * multiplier))
	if stacks[actor].luck > 0 and rng.randf() < float(stacks[actor].luck) * 0.05:
		amount *= 2
		log.append("La fortuna duplica el daño.")
	stacks[target].last_attacker = actor
	stacks[target].stats.health -= amount
	log.append("%s → %s: %d de daño; quedan %d." % [
		data.units[stacks[actor].type].name, data.units[stacks[target].type].name,
		amount, count_at(target)])
	return amount

func _execute(actor: int, command: String, target: int) -> bool:
	var unit: Dictionary = data.units[stacks[actor].type]
	if command == "defend":
		stacks[actor].defending = true
		log.append(str(unit.name) + " defiende hasta su próximo turno.")
		return true
	if command not in ["attack", "ability"]:
		return false
	if command == "ability" and stacks[actor].ability_used:
		return false
	if command == "ability" and unit.ability == "temporary_brace":
		stacks[actor].ability_used = true
		stacks[actor].brace_active = true
		log.append(str(unit.name) + " cierra filas hasta su próximo turno.")
		return true
	if command == "ability" and unit.ability == "brace":
		stacks[actor].ability_used = true
		stacks[actor].defending = true
		stacks[actor].stats.base_defense += 3
		log.append(str(unit.name) + " forma escudos: +3 defensa durante la batalla.")
		return true
	if target < 0 or target >= stacks.size() or count_at(target) == 0 or stacks[target].side == stacks[actor].side:
		return false
	var multiplier := 1.0
	if command == "ability":
		stacks[actor].ability_used = true
		multiplier = 1.5 if unit.ability == "aim" else 2.0 if unit.ability == "charge" else 1.0
	var amount := _strike(actor, target, multiplier, command == "ability" and unit.ability == "feint")
	if command == "ability" and unit.ability == "charge":
		stacks[actor].stats.health -= maxi(1, roundi(amount * 0.2))
	if command == "ability" and unit.ability == "drain":
		var cap: int = count_at(actor) * int(stacks[actor].unit_hp)
		stacks[actor].stats.health = mini(cap, stacks[actor].stats.health + amount / 2)
	if not unit.ranged and count_at(target) > 0 and count_at(actor) > 0 and not stacks[target].retaliated:
		stacks[target].retaliated = true
		_strike(target, actor)
	return true

func _advance() -> void:
	if not queue.is_empty():
		queue.pop_front()
	while not queue.is_empty() and count_at(queue.front()) == 0:
		queue.pop_front()
	if surviving_army(0).is_empty():
		outcome = "defeat"
	elif surviving_army(1).is_empty():
		outcome = "victory"
	if not outcome.is_empty():
		log.append("Victoria." if outcome == "victory" else "Derrota.")
		return
	if queue.is_empty():
		_new_round()
	else:
		stacks[queue.front()].defending = false
		stacks[queue.front()].brace_active = false

func _run_enemies() -> void:
	while current() >= 0 and stacks[current()].side == 1:
		var actor := current()
		var target := -1
		for i in stacks.size():
			if stacks[i].side != 0 or count_at(i) == 0:
				continue
			if target == -1 or stacks[i].stats.health < stacks[target].stats.health:
				target = i
			if _damage(actor, i, false) >= stacks[i].stats.health:
				target = i
				break
		if not enemy_script.is_empty():
			target = _script_target(actor)
			if not _execute(actor,_script_command(actor,target),target):
				_execute(actor,"attack",target)
		else:
			_execute(actor, _enemy_command(actor,target), target)
		_advance()
	if log.size() > 80:
		log = log.slice(-80)

func _enemy_command(actor: int,target: int) -> String:
	if stacks[actor].ability_used or _damage(actor,target,false) >= stacks[target].stats.health:
		return "attack"
	var unit: Dictionary = data.units[stacks[actor].type]
	if unit.ability == "feint" and (stacks[target].defending or stacks[target].brace_active):
		return "ability"
	if stacks[actor].type == "crossbow_guard":
		return "ability"
	if unit.ability == "temporary_brace" and surviving_army(1).size() > 1:
		for i in stacks.size():
			if stacks[i].side == 0 and count_at(i) > 0 and _damage(i,actor,false) >= stacks[actor].stats.health / 2:
				return "ability"
	return "attack"

const SCRIPT_TARGETS := ["lowest_defense_then_stack_index","highest_attack_then_stack_index","fastest_then_stack_index","lowest_remaining_hp_then_stack_index","highest_initiative_then_stack_index","highest_ranged_damage_then_stack_index","last_attacker_else_lowest_hp","highest_expected_damage_then_stack_index"]

func _valid_script(script: Dictionary) -> bool:
	if script.is_empty():
		return true
	if script.size() != 7 or script.get("target") not in SCRIPT_TARGETS:
		return false
	for field in ["first_round","second_round","later_rounds"]:
		if script.get(field) not in ["ATTACK","DEFEND","ABILITY"]:
			return false
	return script.get("invalid_or_spent_ability") == "ATTACK" and script.get("no_legal_target") == "DEFEND" and (script.get("ability_uses") is int or script.get("ability_uses") is float) and script.ability_uses == 1

func _script_target(actor: int) -> int:
	var rule: String = enemy_script.target
	if rule == "last_attacker_else_lowest_hp":
		var previous: int = stacks[actor].last_attacker
		if previous >= 0 and count_at(previous) > 0 and stacks[previous].side == 0:
			return previous
	var best := -1
	var best_score := INF
	for i in stacks.size():
		if stacks[i].side != 0 or count_at(i) == 0:
			continue
		var score: float = stacks[i].stats.health
		match rule:
			"lowest_defense_then_stack_index": score = stacks[i].stats.defense
			"highest_attack_then_stack_index": score = -stacks[i].stats.attack
			"fastest_then_stack_index","highest_initiative_then_stack_index": score = -stacks[i].stats.speed
			"highest_ranged_damage_then_stack_index": score = -_damage(i,actor,false) if data.units[stacks[i].type].ranged else 0
			"highest_expected_damage_then_stack_index": score = -_damage(i,actor,false)
		if best == -1 or score < best_score:
			best = i
			best_score = score
	return best

func _script_command(actor: int,target: int) -> String:
	if target < 0:
		return "defend"
	var key := "first_round" if round_number == 1 else "second_round" if round_number == 2 else "later_rounds"
	var command: String = str(enemy_script[key]).to_lower()
	if command == "ability" and stacks[actor].ability_used:
		return "attack"
	return command
