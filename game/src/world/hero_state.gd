extends RefCounted
var id := ""
var definition: Dictionary = {}
var cell := Vector2i.ZERO
var movement_remaining := 18
var health := 100
var unlocked := true
var army: Array = []
var inventory: Dictionary = {}

func _init(hero_id: String = "", data: Dictionary = {}) -> void:
	id = hero_id
	definition = data.duplicate(true)
	if data.is_empty():
		return
	cell = Vector2i(data.prototype_position[0], data.prototype_position[1])
	movement_remaining = int(data.movement_max)
	army = data.army.duplicate(true)
	var goods: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/economy/market.json"))
	for item in goods:
		inventory[item] = 0

func snapshot() -> Dictionary:
	return {"position": [cell.x, cell.y], "movement": movement_remaining, "health": health,
		"unlocked": unlocked, "army": army.duplicate(true), "inventory": inventory.duplicate()}
