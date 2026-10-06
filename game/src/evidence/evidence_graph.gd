extends RefCounted
## First canonical evidence node. Model text and saves cannot redefine its meaning.
var definitions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
	"res://content/evidence/opening.json"))
var _progress: Dictionary = {}
var grounding = preload("res://src/dialogue/npc_grounding.gd").new()

func progress() -> Dictionary:
	return _progress.duplicate(true)

func has_evidence(id: String) -> bool:
	return _progress.has(id)

func node(id: String) -> Dictionary:
	return definitions.get(id, {}).duplicate(true)

func valid_note(id: String, note: String) -> bool:
	if not definitions.has(id) or note.length() > 300:
		return false
	var text := note.strip_edges().to_lower()
	for pair in [["á", "a"], ["é", "e"], ["í", "i"], ["ó", "o"], ["ú", "u"]]:
		text = text.replace(pair[0], pair[1])
	text = text.trim_prefix("¿").trim_suffix("?").trim_suffix(".").strip_edges()
	return text in definitions[id].language.accepted_notes

func record(id: String, location_id: String, note: String, classification: String, day: int) -> bool:
	if not definitions.has(id) or _progress.has(id) or day < 1:
		return false
	if definitions[id].source_type != "physical":
		return false
	if definitions[id].location_id != location_id or classification != definitions[id].classification:
		return false
	if not valid_note(id, note):
		return false
	_progress[id] = {"found_day": day, "classification": classification, "spanish_note": note.strip_edges()}
	return true

func restore(data: Variant, day: int) -> bool:
	if not data is Dictionary or data.size() > definitions.size():
		return false
	var validated := {}
	for id in data:
		if not id is String or not definitions.has(id):
			return false
		var entry: Variant = data[id]
		if not entry is Dictionary or entry.size() != 3:
			return false
		var found: Variant = entry.get("found_day")
		if not (found is int or found is float) or not is_finite(found) or found != floor(found) or found < 1 or found > day:
			return false
		if not entry.get("classification") is String or entry.classification != definitions[id].classification:
			return false
		if not entry.get("spanish_note") is String or not valid_note(id, entry.spanish_note):
			return false
		validated[id] = {"found_day": int(found), "classification": entry.classification, "spanish_note": entry.spanish_note}
	if validated.has("monastery_claim"):
		if not validated.has("travel_food") or validated.monastery_claim.found_day < validated.travel_food.found_day:
			return false
	_progress = validated
	return true
func context_flags() -> Dictionary:
	return {"food_recorded": "yes"} if has_evidence("travel_food") else {}

func record_dialogue(id: String, npc_id: String, location_id: String, message: String, day: int) -> bool:
	if not definitions.has(id) or definitions[id].source_type != "testimony":
		return false
	if definitions[id].npc_id != npc_id or definitions[id].location_id != location_id:
		return false
	if not grounding.allows_unlock(id, npc_id, grounding.intent_for(message), context_flags(), _progress.keys()):
		return false
	if not valid_note(id, message) or day < _progress.travel_food.found_day:
		return false
	_progress[id] = {"found_day": day, "classification": "claim", "spanish_note": message.strip_edges()}
	return true
