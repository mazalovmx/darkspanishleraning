extends RefCounted
## Versioned snapshot of implemented state only. No HTTP context or credentials.
const WorldState = preload("res://src/world/world_state.gd")
const Learner = preload("res://src/spanish/learner_profile.gd")
const PATH := "user://savegame.json"
const VERSION := 6
const MAP_ID := "prototype_20x20_v1"
const MAX_BYTES := 1048576

static func snapshot(state: WorldState) -> Dictionary:
	var explored: Array = []
	for y in state.grid.region.size.y:
		for x in state.grid.region.size.x:
			var cell := Vector2i(x, y)
			if state.fog_at(cell) != WorldState.Fog.UNKNOWN:
				explored.append([x, y])
	var learner = state.learner
	return {"version": VERSION, "map_id": state.map_id, "day": state.day,
		"party": state.party.snapshot(), "hero": {"cell": [state.hero_cell.x, state.hero_cell.y], "movement": state.movement_remaining},
		"strategy": {"trade": state.trade.snapshot(), "army": state.army.duplicate(true), "resources": state.resources.duplicate(true), "encounters": state.encounters.duplicate(true)}, "explored": explored, "evidence": state.evidence.progress(), "learner": {"block": learner.current_block, "curriculum": learner.curriculum.snapshot(),
		"grammar": learner.grammar.duplicate(true), "verbs": learner.verbs.duplicate(true),
		"errors": learner.errors.duplicate(true), "vocabulary": learner.vocabulary.duplicate(),
		"recent_messages": learner.recent_messages.duplicate(),
		"successful_contexts": learner.successful_contexts.duplicate(true)}}

static func _integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(value) and value == floor(value) and value >= low and value <= high

static func _strings(value: Variant, count_limit: int, length_limit: int) -> bool:
	if not value is Array or value.size() > count_limit:
		return false
	var seen := {}
	for item in value:
		if not item is String or item.strip_edges().is_empty() or item.length() > length_limit:
			return false
		if seen.has(item):
			return false
		seen[item] = true
	return true

static func _scores(values: Variant, keys: Array) -> bool:
	if not values is Dictionary or values.size() != keys.size():
		return false
	for key in keys:
		var value: Variant = values.get(key)
		if not (value is float or value is int) or not is_finite(value) or value < 0 or value > 1:
			return false
	return true

static func _learner_valid(data: Variant, day: int, version: int) -> bool:
	if not data is Dictionary or data.size() != (8 if version >= 5 else 7):
		return false
	var course = preload("res://src/spanish/curriculum.gd").new()
	if version >= 5 and not course.restore(data.get("curriculum"), day):
		return false
	if not data.get("block") is String or data.block != course.block_id():
		return false
	var grammar_keys: Array = Learner.GRAMMAR.duplicate()
	if version < 5:
		grammar_keys.erase("future_simple")
	if not _scores(data.get("grammar"), grammar_keys) or not _scores(data.get("verbs"), Learner.VERBS):
		return false
	if not _strings(data.get("vocabulary"), 100, 100) or not _strings(data.get("recent_messages"), 40, 300):
		return false
	if not data.get("errors") is Dictionary or not data.get("successful_contexts") is Dictionary:
		return false
	var profile := Learner.new()
	for tag in data.errors:
		if not tag is String or not profile._known(tag):
			return false
		var error: Variant = data.errors[tag]
		if not error is Dictionary or error.size() != 3:
			return false
		if not _integer(error.get("count"), 1, 1000000000) or not _integer(error.get("last_seen_day"), 1, day):
			return false
		if not _strings(error.get("examples"), 3, 300) or error.examples.is_empty():
			return false
	for tag in data.successful_contexts:
		if not tag is String or not profile._known(tag):
			return false
		var contexts: Variant = data.successful_contexts[tag]
		if not _strings(contexts, 4, 100) or contexts.is_empty():
			return false
		for npc_id: String in contexts:
			if npc_id not in ["innkeeper_prototype", "lucio_salcedo", "hermano_gabriel", "leonor_valera"]:
				return false
	for message: String in data.recent_messages:
		if message != message.strip_edges().to_lower():
			return false
	return true

static func decode(data: Variant) -> Dictionary:
	if not data is Dictionary:
		return {"error": "invalid"}
	if not _integer(data.get("version"), 1, VERSION):
		return {"error": "version"}
	if data.size() != (6 if data.version == 1 else 7 if data.version == 2 else 8 if data.version < 6 else 9):
		return {"error": "invalid"}
	if data.version >= 2 and not data.has("evidence"):
		return {"error": "invalid"}
	if not data.get("map_id") is String or not WorldState.MAPS.has(data.map_id):
		return {"error": "map"}
	if not _integer(data.get("day"), 1, 1000000) or not data.get("hero") is Dictionary or data.hero.size() != 2:
		return {"error": "invalid"}
	var state := WorldState.new(data.map_id)
	var bounds: Vector2i = state.grid.region.size
	var cell: Variant = data.hero.get("cell")
	if not cell is Array or cell.size() != 2 or not _integer(cell[0], 0, bounds.x - 1) or not _integer(cell[1], 0, bounds.y - 1):
		return {"error": "invalid"}
	if not _integer(data.hero.get("movement"), 0, WorldState.MOVEMENT_MAX):
		return {"error": "invalid"}
	if not data.get("explored") is Array or data.explored.size() > bounds.x * bounds.y:
		return {"error": "invalid"}
	if not _learner_valid(data.get("learner"), int(data.day), int(data.version)):
		return {"error": "invalid"}
	if data.version >= 3 and not _restore_strategy(state, data.get("strategy"), int(data.day), int(data.version)):
		return {"error": "invalid"}
	if not state.evidence.restore(data.get("evidence", {}), int(data.day)):
		return {"error": "invalid"}
	state.hero_cell = Vector2i(cell[0], cell[1])
	if state.terrain_cost(state.hero_cell) == 0:
		return {"error": "invalid"}
	var explored := {}
	for pair: Variant in data.explored:
		if not pair is Array or pair.size() != 2 or not _integer(pair[0], 0, bounds.x - 1) or not _integer(pair[1], 0, bounds.y - 1):
			return {"error": "invalid"}
		var position := Vector2i(pair[0], pair[1])
		if explored.has(position):
			return {"error": "invalid"}
		explored[position] = WorldState.Fog.EXPLORED
	if not explored.has(state.hero_cell):
		return {"error": "invalid"}
	state.day = int(data.day)
	state.movement_remaining = int(data.hero.movement)
	state.fog = explored
	for y in state.grid.region.size.y:
		for x in state.grid.region.size.x:
			var position := Vector2i(x, y)
			state.known_grid.set_point_solid(position, not explored.has(position) or state.terrain_cost(position) == 0)
			state.known_grid.set_point_weight_scale(position, maxi(1, state.terrain_cost(position)))
	if data.version >= 6:
		if not state.party.restore(data.get("party"), state.grid.region, func(position: Vector2i): return state.terrain_cost(position) > 0):
			return {"error": "invalid"}
		if state.hero_cell != Vector2i(cell[0], cell[1]) or state.movement_remaining != int(data.hero.movement):
			return {"error": "invalid"}
		if state.army != data.strategy.army or state.party.active().inventory != data.strategy.trade.inventory:
			return {"error": "invalid"}
		for member in state.party.heroes.values():
			if member.unlocked and not explored.has(member.cell):
				return {"error": "invalid"}
	else:
		state.party.active().inventory = state.trade.inventory
	state.trade.inventory = state.party.active().inventory
	state._sync_gates()
	state._reveal_from(state.hero_cell)
	var learner: Dictionary = data.learner
	for tag in learner.grammar:
		state.learner.grammar[tag] = float(learner.grammar[tag])
	for verb in learner.verbs:
		state.learner.verbs[verb] = float(learner.verbs[verb])
	for tag in learner.errors:
		var record: Dictionary = learner.errors[tag]
		state.learner.errors[tag] = {"count": int(record.count), "last_seen_day": int(record.last_seen_day),
			"examples": record.examples.duplicate()}
	state.learner.vocabulary.assign(learner.vocabulary)
	state.learner.recent_messages.assign(learner.recent_messages)
	state.learner.successful_contexts = learner.successful_contexts.duplicate(true)
	if data.version >= 5:
		state.learner.curriculum.restore(learner.curriculum, int(data.day))
	return {"state": state, "error": ""}

static func read_save(path := PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"error": "missing"}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"error": "read"}
	if file.get_length() > MAX_BYTES:
		return {"error": "invalid"}
	var text := file.get_as_text()
	file.close()
	# Parse errors are returned without logging private learner text.
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return {"error": "invalid"}
	return decode(parser.data)

static func write_save(state: WorldState, path := PATH) -> String:
	if state.active_battle != null:
		return "battle_active"
	var data := snapshot(state)
	if not decode(data).has("state"):
		return "invalid_state"
	var text := JSON.stringify(data, "", true, true)
	if text.to_utf8_buffer().size() > MAX_BYTES:
		return "invalid_state"
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return "write"
	file.store_string(text)
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK or not read_save(temporary).has("state"):
		return "write"
	# Same-directory replacement, never truncate the existing save in place.
	if DirAccess.rename_absolute(temporary, path) != OK:
		return "replace"
	return ""

static func _restore_strategy(state: WorldState, data: Variant, day: int, version: int) -> bool:
	if not data is Dictionary or data.size() != (4 if version >= 4 else 3):
		return false
	if version >= 4 and not state.trade.restore(data.get("trade"), day):
		return false
	if not data.get("army") is Array or (not data.army.is_empty() and not WorldState.StackBattle.new().valid_army(data.army)):
		return false
	if not data.get("resources") is Dictionary or data.resources.size() != state.resources.size():
		return false
	for resource in state.resources:
		if not _integer(data.resources.get(resource), 0, 1000000000):
			return false
	if not data.get("encounters") is Dictionary or data.encounters.size() > 1:
		return false
	for id in data.encounters:
		if id != "opening_road":
			return false
		var entry: Variant = data.encounters[id]
		if not entry is Dictionary or entry.size() != 2 or entry.get("outcome") not in ["victory", "defeat", "retreated"]:
			return false
		if not _integer(entry.get("day"), 1, day):
			return false
	state.army = data.army.duplicate(true)
	state.resources = data.resources.duplicate(true)
	state.encounters = data.encounters.duplicate(true)
	return true
