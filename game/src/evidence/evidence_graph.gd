extends RefCounted
## Canonical evidence nodes. Model text and saves cannot redefine its meaning.
const Curriculum = preload("res://src/spanish/curriculum.gd")
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

## Reading scenes and free-wording keys (opening_practice.json), by clue id.
static var practice: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
	"res://content/evidence/opening_practice.json")).clues
const KIND_NAMES := {"observation": "una observación", "interpretation": "una interpretación",
	"accusation": "una acusación", "institutional_declaration": "una declaración institucional"}
## Present-tense verbs of the opening block that state what is there or what is done.
const PRESENT := ["hay", "veo", "ves", "ve", "vemos", "tiene", "tienen", "tengo", "esta", "estan", "es", "son", "falta", "faltan",
	"encuentro", "observo", "noto", "lleva", "llevan", "presenta", "aparece", "aparecen", "queda", "quedan", "muestra", "contiene",
	"guarda", "ordena", "exige", "manda", "dice", "obliga", "pide", "indica", "demuestra", "prueba", "identifica", "explica",
	"significa", "precede", "ocurre", "sucede", "cae", "oye", "oigo"]
const SUPPOSING := ["creo", "pienso", "supongo", "quiza", "quizas", "tal vez", "parece", "probablemente", "seguramente", "seguro",
	"debe de", "a lo mejor", "porque", "puede que", "opino", "imagino"]
const BLAMING := ["asesino", "asesina", "culpable", "culpables", "mato", "mata", "asesinato", "asesinan", "criminal", "lo matan", "es el responsable"]
const ORDERING := ["ordena", "exige", "manda", "obliga", "prohibe", "decreta", "declara", "autoriza"]
const ASKING := ["que", "quien", "quienes", "como", "cuando", "donde", "cual", "cuanto", "por que", "digame", "cuenteme", "expliqueme", "hableme"]

static func _plain(note: String) -> String:
	var text := Curriculum.fold(note)
	return " " + " ".join(RegEx.create_from_string("[^a-zñ0-9]+").sub(text, " ", true).split(" ", false)) + " "

static func _has(plain: String, words: Array) -> bool:
	for word: String in words:
		if plain.contains(" " + word + " "):
			return true
	return false

## What kind of statement a sentence is, by its own words: an order from an authority,
## a blame, a supposition, or else an observation.
static func kind_of(note: String) -> String:
	var plain := _plain(note)
	if _has(plain, BLAMING):
		return "accusation"
	if _has(plain, SUPPOSING):
		return "interpretation"
	if _has(plain, ORDERING):
		return "institutional_declaration"
	return "observation"

## What a free sentence still needs to count as this piece of evidence; empty when it is
## enough. The authored notes always pass. Needs are Spanish phrases for the player.
func missing_note(id: String, note: String) -> Array[String]:
	var needs: Array[String] = []
	if not definitions.has(id) or note.length() > 300 or note.strip_edges().is_empty():
		return ["una frase en español (máximo 300 letras)"]
	var exact := Curriculum.fold(note).trim_prefix("¿").trim_suffix("?").trim_suffix(".").strip_edges()
	if exact in definitions[id].language.accepted_notes:
		return needs
	var clue: Dictionary = definitions[id]
	var plain := _plain(note)
	var keys: Array = practice.get(id, {}).get("keys", [])
	if keys.is_empty():
		return ["la frase del ejemplo"]
	for group: Array in keys:
		if not _has(plain, group):
			needs.append("nombrar: " + " / ".join(group.slice(0, 3)))
	if clue.source_type == "testimony":
		if not note.contains("?") and not _has(plain, ASKING):
			needs.append("forma de pregunta (¿qué…?, ¿quién…?, ¿por qué…?)")
		return needs
	if not _has(plain, PRESENT):
		needs.append("un verbo en presente (hay, veo, tiene, está, falta…)")
	var kind := kind_of(note)
	if clue.source_type == "reasoning":
		if kind == "accusation":
			needs.append("no acusar a nadie: las pruebas todavía no nombran a un culpable")
	elif clue.classification == "observation" and kind != "observation":
		needs.append("decir solo lo que ves, sin suponer ni acusar (quita «%s»)" % _marker(plain))
	elif clue.classification == "institutional_declaration" and kind == "accusation":
		needs.append("citar lo que ordena el documento, sin acusar")
	for problem: String in preload("res://src/spanish/grammar_checks.gd").missing(note):
		needs.append(problem)
	return needs

static func _marker(plain: String) -> String:
	for word: String in BLAMING + SUPPOSING + ORDERING:
		if plain.contains(" " + word + " "):
			return word
	return ""

func valid_note(id: String, note: String) -> bool:
	if not definitions.has(id) or note.length() > 300:
		return false
	if practice.has(id):
		return missing_note(id, note).is_empty()
	var text := Curriculum.fold(note)
	text = text.trim_prefix("¿").trim_suffix("?").trim_suffix(".").strip_edges()
	return text in definitions[id].language.accepted_notes

func record(id: String, location_id: String, note: String, classification: String, day: int) -> bool:
	if not definitions.has(id) or _progress.has(id) or day < 1:
		return false
	if definitions[id].source_type not in ["physical", "document"]:
		return false
	if definitions[id].location_id != location_id or classification != definitions[id].classification:
		return false
	if not valid_note(id, note) or not prerequisites_met(id, _progress, day):
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
	for id in validated:
		if not prerequisites_met(id, validated, validated[id].found_day):
			return false
	_progress = validated
	return true
func context_flags() -> Dictionary:
	var flags := {"food_recorded": "yes"} if has_evidence("travel_food") else {}
	for id in _progress:
		flags[id + "_recorded"] = "yes"
	return flags

func record_dialogue(id: String, npc_id: String, location_id: String, message: String, day: int) -> bool:
	if not definitions.has(id) or definitions[id].source_type != "testimony":
		return false
	if definitions[id].npc_id != npc_id or definitions[id].location_id != location_id:
		return false
	if not grounding.allows_unlock(id, npc_id, grounding.intent_for(message), context_flags(), _progress.keys()):
		return false
	if day < 1 or not valid_note(id, message) or not prerequisites_met(id, _progress, day):
		return false
	_progress[id] = {"found_day": day, "classification": "claim", "spanish_note": message.strip_edges()}
	return true

func prerequisites_met(id: String, records: Dictionary, day: int) -> bool:
	if not definitions.has(id):
		return false
	for required in definitions[id].get("requires", []):
		if not records.has(required) or records[required].found_day > day:
			return false
	return true

func inspectable_ids(location_id: String) -> Array:
	var result: Array = []
	for id in definitions:
		var clue: Dictionary = definitions[id]
		if clue.location_id == location_id and clue.source_type in ["physical", "document"]:
			if prerequisites_met(id, _progress, 2147483647):
				result.append(id)
	return result

func reviewable_ids(day: int) -> Array:
	var result: Array = []
	for id in definitions:
		if definitions[id].source_type == "reasoning" and prerequisites_met(id, _progress, day):
			result.append(id)
	return result

func record_reasoning(id: String, note: String, choice: String, supports: Array, day: int) -> bool:
	if not definitions.has(id) or definitions[id].source_type != "reasoning" or has_evidence(id) or day < 1:
		return false
	var clue: Dictionary = definitions[id]
	if not prerequisites_met(id, _progress, day) or not valid_note(id, note):
		return false
	if choice != clue.assessment.answer or supports.size() != clue.assessment.supports.size():
		return false
	var seen := {}
	for supporting in supports:
		if not supporting is String or seen.has(supporting) or not has_evidence(supporting):
			return false
		if supporting not in clue.assessment.supports:
			return false
		seen[supporting] = true
	_progress[id] = {"found_day": day, "classification": clue.classification, "spanish_note": note.strip_edges()}
	return true
