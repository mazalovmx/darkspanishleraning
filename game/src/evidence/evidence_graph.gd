extends RefCounted
## First canonical evidence node. Model text and saves cannot redefine its meaning.
var definitions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
	"res://content/evidence/opening.json"))
var _progress: Dictionary = {}

func progress() -> Dictionary:
	return _progress.duplicate(true)

func has_evidence(id: String) -> bool:
	return _progress.has(id)

func node(id: String) -> Dictionary:
	return definitions.get(id, {}).duplicate(true)

func valid_note(id: String, note: String) -> bool:
	if not definitions.has(id) or note.length() > 300:
		return false
	var text := note.strip_edges().to_lower().replace("á", "a")
	text = text.trim_suffix(".").strip_edges()
	return text in definitions[id].language.accepted_notes

func record(id: String, location_id: String, note: String, classification: String, day: int) -> bool:
	if not definitions.has(id) or _progress.has(id) or day < 1:
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
	_progress = validated
	return true
