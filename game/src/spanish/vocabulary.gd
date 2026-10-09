extends RefCounted
## B1 vocabulary practice, Mexican Spanish first: the player types the word for a
## Spanish clue (or the connector missing from a sentence). Leitner boxes over game
## days decide what comes back. Practice never gives campaign or lesson credit.
const Curriculum = preload("res://src/spanish/curriculum.gd")
const PATH := "res://content/spanish/vocabulary.json"
## Days until an item returns, by box (0 = today).
const INTERVALS := [0, 1, 2, 4, 7, 14]
const ARTICLES := ["el ", "la ", "los ", "las ", "un ", "una "]
static var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
static var cities: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/spanish/city_vocabulary.json"))
## English glosses for the built-in words, by item id (shown in the dictionary).
static var english: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/spanish/vocabulary_en.json"))
const OWN_THEME := "mias"
const OWN_LIMIT := 300
var items: Dictionary = {}
## The player's own words, in the order added: {id, word, en, clue, example}.
var own: Array = []
## id -> {"box": 0-5, "due": day}
var progress: Dictionary = {}
# Order of the last attempts this session, so a missed word does not come back at once.
var _stamp := 0
var _seen: Dictionary = {}

func _init() -> void:
	for theme: Dictionary in catalog.themes + cities.themes:
		for item: Dictionary in theme.items:
			var entry := item.duplicate(true)
			entry["theme"] = theme.id
			entry["en"] = str(english.get(item.id, ""))
			items[item.id] = entry

func themes() -> Array:
	return (catalog.themes + cities.themes).map(func(theme: Dictionary) -> Dictionary: return {"id": theme.id, "name": theme.name}) + [{"id": OWN_THEME, "name": "Mis palabras"}]

func city_theme(location: String) -> String:
	for theme: Dictionary in cities.themes:
		if location in theme.locations:
			return str(theme.id)
	return ""

## Items due on a day (all themes when theme is empty): due ones first, then new ones,
## least recently tried first.
func due(day: int, theme := "") -> Array:
	var result: Array = []
	for id: String in items:
		if not theme.is_empty() and items[id].theme != theme:
			continue
		if int(progress.get(id, {}).get("due", 0)) <= day:
			result.append(id)
	result.sort_custom(func(a: String, b: String) -> bool:
		var seen_a: int = int(_seen.get(a, -1))
		var seen_b: int = int(_seen.get(b, -1))
		if seen_a != seen_b:
			return seen_a < seen_b
		var started_a := progress.has(a)
		var started_b := progress.has(b)
		if started_a != started_b:
			return started_a
		return a < b)
	return result

func next_item(day: int, theme := "") -> String:
	var list := due(day, theme)
	return "" if list.is_empty() else str(list[0])

func _normal(text: String, strict: bool) -> String:
	var clean := text.strip_edges().to_lower()
	if not strict:
		clean = Curriculum.fold(clean)
	for mark in [".", ",", ";", ":", "!", "¡", "?", "¿", "«", "»", "\""]:
		clean = clean.replace(mark, " ")
	return " ".join(clean.split(" ", false))

static func _bare(text: String) -> String:
	for article in ARTICLES:
		if text.begins_with(article):
			return text.substr(article.length())
	return text

## Checks a typed answer, moves the item between boxes and explains the result.
## strict: accents count (the last curriculum block, master spec 1.3).
func check(id: String, answer: String, day: int, strict := false) -> Dictionary:
	if not items.has(id) or answer.strip_edges().is_empty() or answer.length() > 120:
		return {"ok": false, "message": "Escribe una palabra o una expresión."}
	if int(progress.get(id, {}).get("due", 0)) > day:
		return {"ok": false, "message": "Esta palabra ya está practicada. Vuelve el día %d para recordarla." % int(progress[id].due)}
	var item: Dictionary = items[id]
	var typed := _normal(answer, strict)
	var matched := ""
	var with_article := false
	for candidate: String in [item.word] + item.alt:
		var form := _normal(candidate, strict)
		if typed == form:
			matched = candidate
			with_article = true
			break
		if matched.is_empty() and typed == _bare(typed) and typed == _bare(form):
			matched = candidate
	_stamp += 1
	_seen[id] = _stamp
	var record: Dictionary = progress.get(id, {"box": 0, "due": day})
	if matched.is_empty():
		record = {"box": 0, "due": day}
		progress[id] = record
		return {"ok": false, "message": "Era «%s». %s%s" % [item.word, item.example, _gloss(item)]}
	var box := mini(int(record.box) + 1, INTERVALS.size() - 1)
	progress[id] = {"box": box, "due": day + int(INTERVALS[box])}
	var article_missing: bool = not with_article and _bare(_normal(item.word, false)) != _normal(item.word, false)
	var lines: Array[String] = ["Correcto. Con artículo: «%s»." % item.word if article_missing else "Correcto: «%s»." % item.word]
	if matched != item.word and not str(item.note).is_empty():
		lines.append(str(item.note))
	lines.append(str(item.example) + _gloss(item))
	return {"ok": true, "message": " ".join(lines)}

static func _gloss(item: Dictionary) -> String:
	return "" if str(item.get("en", "")).is_empty() else " (en inglés: %s)" % item.en

func mastered(theme := "") -> int:
	var count := 0
	for id: String in progress:
		if int(progress[id].box) >= 4 and (theme.is_empty() or items[id].theme == theme):
			count += 1
	return count

## Finds a dictionary entry by its Spanish word, with or without article.
func find(word: String) -> String:
	var wanted := _bare(_normal(word, false))
	for id: String in items:
		for candidate: String in [items[id].word] + items[id].alt:
			if _bare(_normal(candidate, false)) == wanted:
				return id
	return ""

static func _text(value: Variant, low: int, high: int) -> bool:
	return value is String and value.strip_edges().length() >= low and value.length() <= high and not value.contains("\n")

## Checks one own word (typed by the player or proposed by the model) before it is
## kept. Returns a Spanish message, empty when the entry is acceptable.
func own_error(entry: Variant) -> String:
	if not entry is Dictionary or not _text(entry.get("word"), 1, 60):
		return "Escribe la palabra en español (máximo 60 letras)."
	if not _text(entry.get("en"), 1, 80):
		return "Falta la traducción al inglés (máximo 80 letras)."
	if not _text(entry.get("clue"), 1, 200):
		return "Falta la explicación en español (máximo 200 letras)."
	if not _text(entry.get("example", ""), 0, 200):
		return "El ejemplo es demasiado largo."
	# An explanation that names the word would give the answer away in practice.
	var bare := _bare(_normal(entry.word, false))
	if (" " + _normal(entry.clue, false) + " ").contains(" " + bare + " "):
		return "La explicación no debe contener la palabra."
	return ""

## Adds a word to the player's own list; it joins the practice at once.
func add_own(entry: Dictionary, day: int) -> Dictionary:
	var error := own_error(entry)
	if not error.is_empty():
		return {"ok": false, "message": error}
	if not find(entry.word).is_empty():
		return {"ok": false, "message": "«%s» ya está en el diccionario." % items[find(entry.word)].word}
	if own.size() >= OWN_LIMIT:
		return {"ok": false, "message": "Tu lista está llena (%d palabras). Quita alguna." % OWN_LIMIT}
	var number := 1
	for saved: Dictionary in own:
		number = maxi(number, int(str(saved.id).trim_prefix("mia_")) + 1)
	var record := {"id": "mia_%04d" % number, "word": entry.word.strip_edges(), "en": entry.en.strip_edges(),
		"clue": entry.clue.strip_edges(), "example": str(entry.get("example", "")).strip_edges()}
	own.append(record)
	_index_own(record)
	progress[record.id] = {"box": 0, "due": day}
	return {"ok": true, "id": record.id, "message": "«%s» está en tus palabras. Aparecerá en la práctica." % record.word}

func remove_own(id: String) -> bool:
	for index in own.size():
		if own[index].id == id:
			own.remove_at(index)
			items.erase(id)
			progress.erase(id)
			_seen.erase(id)
			return true
	return false

func _index_own(record: Dictionary) -> void:
	items[record.id] = {"id": record.id, "word": record.word, "en": record.en, "clue": record.clue,
		"example": record.example, "alt": [], "note": "", "theme": OWN_THEME}

func snapshot_own() -> Array:
	return own.duplicate(true)

## Restores the player's own words; call before restore(). A malformed list, a
## duplicate or a foreign id rejects the save.
func restore_own(data: Variant) -> bool:
	if not data is Array or data.size() > OWN_LIMIT:
		return false
	var fresh = get_script().new()
	for entry: Variant in data:
		if not entry is Dictionary or entry.size() != 5 or not entry.get("id") is String or not entry.id.begins_with("mia_") or not entry.id.trim_prefix("mia_").is_valid_int():
			return false
		if fresh.items.has(entry.id) or not fresh.own_error(entry).is_empty() or not fresh.find(entry.word).is_empty():
			return false
		var record := {"id": entry.id, "word": entry.word, "en": entry.en, "clue": entry.clue, "example": entry.example}
		fresh.own.append(record)
		fresh._index_own(record)
	for saved: Dictionary in own:
		items.erase(saved.id)
		progress.erase(saved.id)
	own = fresh.own
	for record: Dictionary in own:
		_index_own(record)
	return true

func snapshot() -> Dictionary:
	return progress.duplicate(true)

static func _integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(value) and value == floor(value) and value >= low and value <= high

## Restores saved boxes; unknown words or impossible days reject the save.
func restore(data: Variant, day: int) -> bool:
	if not data is Dictionary:
		return false
	for id in data:
		var entry: Variant = data[id]
		if not id is String or not items.has(id) or not entry is Dictionary or entry.size() != 2:
			return false
		if not _integer(entry.get("box"), 0, INTERVALS.size() - 1) or not _integer(entry.get("due"), 0, day + int(INTERVALS.back())):
			return false
	progress.clear()
	for id: String in data:
		progress[id] = {"box": int(data[id].box), "due": int(data[id].due)}
	return true
