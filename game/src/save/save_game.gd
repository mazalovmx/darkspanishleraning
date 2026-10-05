extends RefCounted
## Versioned snapshot of implemented state only. No HTTP context or credentials.
const WorldState = preload("res://src/world/world_state.gd")
const Learner = preload("res://src/spanish/learner_profile.gd")
const PATH := "user://savegame.json"
const VERSION := 1
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
	return {"version": VERSION, "map_id": MAP_ID, "day": state.day,
		"hero": {"cell": [state.hero_cell.x, state.hero_cell.y], "movement": state.movement_remaining},
		"explored": explored, "learner": {"block": learner.current_block,
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

static func _learner_valid(data: Variant, day: int) -> bool:
	if not data is Dictionary or data.size() != 7:
		return false
	if not data.get("block") is String or data.block != "present_and_basic_requests":
		return false
	if not _scores(data.get("grammar"), Learner.GRAMMAR) or not _scores(data.get("verbs"), Learner.VERBS):
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
		if not _strings(contexts, 2, 100) or contexts.is_empty():
			return false
		for npc_id: String in contexts:
			if npc_id not in ["innkeeper_prototype", "lucio_salcedo"]:
				return false
	for message: String in data.recent_messages:
		if message != message.strip_edges().to_lower():
			return false
	return true

static func decode(data: Variant) -> Dictionary:
	if not data is Dictionary or data.size() != 6:
		return {"error": "invalid"}
	if not _integer(data.get("version"), VERSION, VERSION):
		return {"error": "version"}
	if not data.get("map_id") is String or data.map_id != MAP_ID:
		return {"error": "map"}
	if not _integer(data.get("day"), 1, 1000000) or not data.get("hero") is Dictionary or data.hero.size() != 2:
		return {"error": "invalid"}
	var cell: Variant = data.hero.get("cell")
	if not cell is Array or cell.size() != 2 or not _integer(cell[0], 0, 19) or not _integer(cell[1], 0, 19):
		return {"error": "invalid"}
	if not _integer(data.hero.get("movement"), 0, WorldState.MOVEMENT_MAX):
		return {"error": "invalid"}
	if not data.get("explored") is Array or data.explored.size() > 400:
		return {"error": "invalid"}
	if not _learner_valid(data.get("learner"), int(data.day)):
		return {"error": "invalid"}
	var state := WorldState.new()
	state.hero_cell = Vector2i(cell[0], cell[1])
	if state.terrain_cost(state.hero_cell) == 0:
		return {"error": "invalid"}
	var explored := {}
	for pair: Variant in data.explored:
		if not pair is Array or pair.size() != 2 or not _integer(pair[0], 0, 19) or not _integer(pair[1], 0, 19):
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
	state.learner.current_block = learner.block
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
