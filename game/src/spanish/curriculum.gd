extends RefCounted
## Lesson progression is proven by authored transfer and delayed recall, not model praise.
var blocks: Array = JSON.parse_string(FileAccess.get_file_as_string("res://content/spanish/curriculum.json")).blocks
var records: Dictionary = {}
var cursor := 0
var recent_focus: Array = []
var dimensions := {"grammar": 0.10, "lexicon": 0.10, "sentence_length": 0.10, "implicit_meaning": 0.05, "interaction_pressure": 0.05}
var success_streak := 0
var failure_streak := 0
var session_change := 0.0

func index() -> int:
	for i in blocks.size():
		for card: Dictionary in blocks[i].cards:
			if records.get(card.id, {}).get("recall", {}).is_empty():
				return i
	return blocks.size() - 1

func block_id() -> String:
	return str(blocks[index()].id)

func completed() -> bool:
	for block: Dictionary in blocks:
		for card: Dictionary in block.cards:
			if records.get(card.id, {}).get("recall", {}).is_empty():
				return false
	return true

func card_for(id: String) -> Dictionary:
	for block: Dictionary in blocks:
		for card: Dictionary in block.cards:
			if card.id == id:
				return card.duplicate(true)
	return {}

const FOLD := [["á","a"],["é","e"],["í","i"],["ó","o"],["ú","u"],["ü","u"],["'",""],["’",""],["´",""],["`",""]]

## Lower case without tildes, diaeresis or apostrophes: outside the last block these
## are not errors (master spec 1.3, user clarification 2026-10-07).
static func fold(message: String) -> String:
	var result := message.strip_edges().to_lower()
	for pair in FOLD:
		result = result.replace(pair[0], pair[1])
	return result

func normalized(message: String) -> String:
	return fold(message).trim_prefix("¿").trim_suffix("?").trim_suffix(".").strip_edges()

## Last block only: each typed word that differs from an authored word only by a tilde,
## a diaeresis or an apostrophe, as "querria → querría". Unknown words are not judged.
static func orthography_errors(message: String, authored: Array) -> PackedStringArray:
	var split := RegEx.create_from_string("[^\\p{L}'’´`]+")
	var exact := {}
	var folded := {}
	for sentence: String in authored:
		for word in split.sub(sentence.to_lower(), " ", true).split(" ", false):
			exact[word] = true
			if not folded.has(fold(word)):
				folded[fold(word)] = word
	var result: PackedStringArray = []
	for word in split.sub(message.to_lower(), " ", true).split(" ", false):
		if not exact.has(word) and folded.has(fold(word)) and str(folded[fold(word)]) not in result:
			result.append("%s → %s" % [word, folded[fold(word)]])
	return result

func is_last_block(block: int) -> bool:
	return block >= blocks.size() - 1

func block_of(card_id: String) -> int:
	for i in blocks.size():
		for card: Dictionary in blocks[i].cards:
			if card.id == card_id:
				return i
	return -1

## Lower case, accents dropped, punctuation as spaces, padded: " a b c ".
func words(message: String) -> String:
	var text := normalized(message)
	for mark in [",", ".", ";", ":", "!", "¡", "?", "¿", "\"", "«", "»", "(", ")"]:
		text = text.replace(mark, " ")
	return " " + " ".join(text.split(" ", false)) + " "

func _answer_ok(card: Dictionary, stage: String, message: String) -> bool:
	if message.length() > 300:
		return false
	if stage == "guided":
		return normalized(message) == normalized(card.model)
	var exercise_index: int = ["first", "second", "recall"].find(stage)
	if exercise_index < 0:
		return false
	for answer: String in card.exercises[exercise_index].answers:
		if normalized(message) == normalized(answer):
			return true
	return false

func next_task(day: int) -> Dictionary:
	if completed():
		return {"stage": "complete", "title": blocks.back().title}
	for card: Dictionary in blocks[index()].cards:
		if not records.has(card.id):
			return {"stage": "introduce", "card": card.duplicate(true)}
		var record: Dictionary = records[card.id]
		if record.guided == 0:
			return {"stage": "guided", "card": card.duplicate(true)}
		for stage in ["first", "second"]:
			if record[stage].is_empty():
				return {"stage": stage, "card": card.duplicate(true)}
		if record.recall.is_empty() and day > int(record.second.day):
			return {"stage": "recall", "card": card.duplicate(true)}
	return {"stage": "wait", "title": blocks[index()].title}

func introduce(id: String, day: int) -> bool:
	var task := next_task(day)
	if day < 1 or task.stage != "introduce" or task.card.id != id:
		return false
	records[id] = {"introduced": day, "guided": 0, "first": {}, "second": {}, "recall": {}}
	return true

func submit(id: String, message: String, day: int) -> Dictionary:
	var task := next_task(day)
	if day < 1 or task.stage not in ["guided", "first", "second", "recall"] or task.card.id != id:
		return {"ok": false, "message": "Sigue la tarea actual."}
	if not _answer_ok(task.card, task.stage, message):
		return {"ok": false, "message": "Revisa la forma y el sentido. Regla: " + str(task.card.rule)}
	if is_last_block(block_of(id)):
		var authored: Array = [task.card.model]
		for exercise: Dictionary in task.card.exercises:
			authored.append_array(exercise.answers)
		var spelling := orthography_errors(message, authored)
		if not spelling.is_empty():
			return {"ok": false, "message": "En este nivel cuentan las tildes: " + ", ".join(spelling) + "."}
	var record: Dictionary = records[id]
	var earliest: int = int(record.introduced) if task.stage == "guided" else int(record.guided) if task.stage == "first" else int(record.first.day) if task.stage == "second" else int(record.second.day) + 1
	if day < earliest:
		return {"ok": false, "message": "La práctica no puede preceder a sus requisitos."}
	if task.stage == "guided":
		record.guided = day
	else:
		record[task.stage] = {"day": day, "answer": message.strip_edges()}
	return {"ok": true, "message": "Práctica registrada. " + ("Ahora usa la forma sin copiar el modelo." if task.stage == "guided" else "La siguiente tarea cambia el contexto.")}

func allowed_grammar() -> Array:
	var result: Array = []
	for i in index():
		for tag in blocks[i].grammar:
			if tag not in result:
				result.append(tag)
	if index() == 0:
		result.append_array(blocks[0].grammar)
	else:
		for card: Dictionary in blocks[index()].cards:
			if card.tag not in result:
				result.append(card.tag)
			if not records.has(card.id):
				break
	return result

func _consolidating() -> bool:
	for card: Dictionary in blocks[index()].cards:
		if records.get(card.id, {}).get("guided", 0) == 0:
			return true
	return false

func select_focus(scores: Dictionary, errors: Dictionary) -> Dictionary:
	var slot := cursor % 20
	cursor = (cursor + 1) % 1000000
	var mode := "weak_review" if slot < 12 else "current" if slot < 17 else "stretch"
	if mode == "stretch" and _consolidating():
		mode = "current"
	var taught: Array = allowed_grammar()
	var current_tags: Array = []
	for tag in blocks[index()].grammar:
		if tag in taught:
			current_tags.append(tag)
	var candidates: Array = taught if mode == "weak_review" else current_tags
	var filtered: Array = []
	for tag in candidates:
		if tag not in recent_focus.slice(-2):
			filtered.append(tag)
	if not filtered.is_empty():
		candidates = filtered
	candidates.sort_custom(func(a: String, b: String):
		var a_score: float = float(scores.get(a, 0.0)) - mini(int(errors.get(a, {}).get("count", 0)), 10) * 0.01
		var b_score: float = float(scores.get(b, 0.0)) - mini(int(errors.get(b, {}).get("count", 0)), 10) * 0.01
		return a_score < b_score if not is_equal_approx(a_score, b_score) else a < b)
	var tag: String = str(candidates[0])
	recent_focus.append(tag)
	if recent_focus.size() > 3:
		recent_focus.pop_front()
	return {"tag": tag, "mode": mode, "block": block_id(),
		"constraint": "Only taught/current-block grammar. Stretch adds vocabulary or a longer sentence, never an untaught tense."}

func begin_conversation() -> void:
	session_change = 0.0

func observe_difficulty(understood: bool, confidence: float) -> void:
	if confidence < 0.7:
		return
	if understood:
		success_streak = mini(success_streak + 1, 1000000)
		failure_streak = 0
	else:
		failure_streak = mini(failure_streak + 1, 1000000)
		success_streak = 0
	if session_change >= 0.1:
		return
	if success_streak >= 3:
		var axis := "lexicon"
		for key in ["sentence_length", "implicit_meaning", "interaction_pressure"]:
			if dimensions[key] < dimensions[axis]:
				axis = key
		var change: float = minf(0.05, 0.1 - session_change)
		dimensions[axis] = minf(0.20 + index() * 0.10, float(dimensions[axis]) + change)
		session_change += change
		success_streak = 0
	elif failure_streak >= 2:
		var axis := "interaction_pressure" if dimensions.interaction_pressure >= dimensions.sentence_length else "sentence_length"
		var change: float = minf(0.04, 0.1 - session_change)
		dimensions[axis] = maxf(0.0, float(dimensions[axis]) - change)
		session_change += change
		failure_streak = 0

func context() -> Dictionary:
	return {"block": block_id(), "block_index": index() + 1, "title": blocks[index()].title,
		"allowed_grammar": allowed_grammar(), "dimensions": dimensions.duplicate(),
		"lesson_cards_completed": records.values().filter(func(record: Dictionary): return not record.recall.is_empty()).size(),
		"policy": "Use the current block or earlier material. Ask one short production at a time. Do not jump to a later tense.",
		"orthography": "check" if is_last_block(index()) else "ignore"}

func snapshot() -> Dictionary:
	return {"records": records.duplicate(true), "cursor": cursor, "recent_focus": recent_focus.duplicate(),
		"dimensions": dimensions.duplicate(), "success_streak": success_streak, "failure_streak": failure_streak}

func _integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(value) and value == floor(value) and value >= low and value <= high

func restore(data: Variant, day: int) -> bool:
	if not data is Dictionary or data.size() != 6 or not data.get("records") is Dictionary:
		return false
	if not _integer(data.get("cursor"), 0, 999999) or not _integer(data.get("success_streak"), 0, 1000000) or not _integer(data.get("failure_streak"), 0, 1000000):
		return false
	if not data.get("dimensions") is Dictionary or data.dimensions.size() != dimensions.size():
		return false
	for axis in dimensions:
		var value: Variant = data.dimensions.get(axis)
		if not (value is int or value is float) or not is_finite(value) or value < 0 or value > 1:
			return false
	var known: Array = []
	var previous_complete := true
	var previous_end := 0
	for block: Dictionary in blocks:
		var block_complete := true
		var block_end := 0
		var previous_card_ready := true
		var previous_card_day := previous_end
		for card: Dictionary in block.cards:
			known.append(card.id)
			if not data.records.has(card.id):
				block_complete = false
				previous_card_ready = false
				continue
			if not previous_complete or not previous_card_ready:
				return false
			var record: Variant = data.records[card.id]
			if not record is Dictionary or record.size() != 5 or not _integer(record.get("introduced"), maxi(1, previous_card_day), day):
				return false
			if not _integer(record.get("guided"), 0, day) or (record.guided > 0 and record.guided < record.introduced):
				return false
			var last_day: int = int(record.guided)
			var missing: bool = record.guided == 0
			for stage in ["first", "second", "recall"]:
				var proof: Variant = record.get(stage)
				if not proof is Dictionary:
					return false
				if proof.is_empty():
					missing = true
					continue
				if missing or proof.size() != 2 or not _integer(proof.get("day"), last_day + (1 if stage == "recall" else 0), day):
					return false
				if not proof.get("answer") is String or not _answer_ok(card, stage, proof.answer):
					return false
				last_day = int(proof.day)
			previous_card_ready = not record.second.is_empty()
			previous_card_day = int(record.second.get("day", previous_card_day))
			if record.recall.is_empty():
				block_complete = false
			else:
				block_end = maxi(block_end, int(record.recall.day))
		previous_complete = block_complete
		previous_end = block_end
	for id in data.records:
		if not id is String or id not in known:
			return false
	if not data.get("recent_focus") is Array or data.recent_focus.size() > 3:
		return false
	var all_tags: Array = []
	for block: Dictionary in blocks:
		all_tags.append_array(block.grammar)
	for tag in data.recent_focus:
		if not tag is String or tag not in all_tags:
			return false
	records = data.records.duplicate(true)
	cursor = int(data.cursor)
	recent_focus = data.recent_focus.duplicate()
	dimensions = data.dimensions.duplicate()
	success_streak = int(data.success_streak)
	failure_streak = int(data.failure_streak)
	session_change = 0.0
	return true
