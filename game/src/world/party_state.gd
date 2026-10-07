extends RefCounted
const Hero = preload("res://src/world/hero_state.gd")
const Battle = preload("res://src/combat/stack_battle.gd")
var definitions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/world/heroes.json"))
var heroes: Dictionary = {}
var active_id := "inquisitor"

func _init() -> void:
	for id in definitions:
		heroes[id] = Hero.new(id, definitions[id])

func active() -> RefCounted:
	return heroes[active_id]

func select(id: String) -> bool:
	if not heroes.has(id) or not heroes[id].unlocked:
		return false
	active_id = id
	return true

func end_day() -> void:
	for hero in heroes.values():
		hero.movement_remaining = int(hero.definition.movement_max)

func transfer_stack(from_id: String, to_id: String, index: int, quantity: int) -> bool:
	if from_id == to_id or not heroes.has(from_id) or not heroes.has(to_id) or quantity < 1:
		return false
	var source = heroes[from_id]
	var target = heroes[to_id]
	if not source.unlocked or not target.unlocked or source.cell != target.cell or index < 0 or index >= source.army.size():
		return false
	var stack: Dictionary = source.army[index]
	if quantity > stack.count:
		return false
	var merge := -1
	for i in target.army.size():
		if target.army[i].type == stack.type:
			merge = i
			break
	if (merge == -1 and target.army.size() >= 7) or (merge >= 0 and target.army[merge].count + quantity > 100000):
		return false
	if merge == -1:
		target.army.append({"type": str(stack.type), "count": quantity})
	else:
		target.army[merge].count += quantity
	stack.count -= quantity
	if stack.count == 0:
		source.army.remove_at(index)
	return true

func transfer_supply(from_id: String, to_id: String, item: String, quantity: int) -> bool:
	if from_id == to_id or not heroes.has(from_id) or not heroes.has(to_id) or quantity < 1:
		return false
	var source = heroes[from_id]
	var target = heroes[to_id]
	if not source.unlocked or not target.unlocked or source.cell != target.cell:
		return false
	if not source.inventory.has(item) or not target.inventory.has(item) or source.inventory[item] < quantity:
		return false
	if target.inventory[item] + quantity > 1000000:
		return false
	source.inventory[item] -= quantity
	target.inventory[item] += quantity
	return true

func snapshot() -> Dictionary:
	var result := {}
	for id in heroes:
		result[id] = heroes[id].snapshot()
	return {"active": active_id, "heroes": result}

func _integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(value) and value == floor(value) and value >= low and value <= high

func restore(data: Variant, bounds: Rect2i, passable: Callable, movement_bonus_cap := 0) -> bool:
	if not data is Dictionary or data.size() != 2 or not data.get("active") is String or not definitions.has(data.active):
		return false
	if not data.get("heroes") is Dictionary or data.heroes.size() != definitions.size():
		return false
	var validated := {}
	var battle := Battle.new()
	for id in definitions:
		var entry: Variant = data.heroes.get(id)
		if not entry is Dictionary or entry.size() != 6 or not entry.get("unlocked") is bool:
			return false
		if not entry.get("position") is Array or entry.position.size() != 2:
			return false
		if not _integer(entry.position[0], bounds.position.x, bounds.end.x - 1) or not _integer(entry.position[1], bounds.position.y, bounds.end.y - 1):
			return false
		var cell := Vector2i(entry.position[0], entry.position[1])
		if not passable.call(cell):
			return false
		if not _integer(entry.get("movement"), 0, int(definitions[id].movement_max) + movement_bonus_cap) or not _integer(entry.get("health"), 0, 100):
			return false
		if not entry.get("army") is Array or (not entry.army.is_empty() and not battle.valid_army(entry.army)):
			return false
		var hero := Hero.new(id, definitions[id])
		if not entry.get("inventory") is Dictionary or entry.inventory.size() != hero.inventory.size():
			return false
		for item in hero.inventory:
			if not _integer(entry.inventory.get(item), 0, 1000000):
				return false
		hero.cell = cell
		hero.movement_remaining = int(entry.movement)
		hero.health = int(entry.health)
		hero.unlocked = entry.unlocked
		hero.army = entry.army.duplicate(true)
		hero.inventory = entry.inventory.duplicate()
		validated[id] = hero
	if not validated[data.active].unlocked:
		return false
	heroes = validated
	active_id = data.active
	return true
