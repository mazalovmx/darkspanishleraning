extends RefCounted
## Conservative offline checks for known forms, not a general Spanish parser.
## Unknown vocabulary, omitted subjects and quoted testimony are not guessed at.
const Course = preload("res://src/spanish/curriculum.gd")
static var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/spanish/grammar_checks.json"))
const ARTICLES := {"el": ["m", 1], "la": ["f", 1], "los": ["m", 2], "las": ["f", 2],
	"un": ["m", 1], "una": ["f", 1], "unos": ["m", 2], "unas": ["f", 2]}
const SUBJECTS := {"yo": 0, "tu": 1, "el": 2, "ella": 2, "usted": 2,
	"nosotros": 3, "nosotras": 3, "vosotros": 4, "vosotras": 4, "ellos": 5, "ellas": 5, "ustedes": 5}
const MODALS := ["quiero", "quieres", "quiere", "queremos", "quereis", "quieren",
	"puedo", "puedes", "puede", "podemos", "podeis", "pueden"]
const NOUN_VERBS := ["documento", "archivo", "camino", "registro", "recuerdo", "informe",
	"precio", "prueba", "pruebas", "firma", "firmas", "copia", "copias", "sello"]
const PREDICATES := ["es", "son", "esta", "estan", "cambia", "cambian", "muestra", "muestran",
	"contiene", "contienen", "dice", "dicen", "confirma", "confirman", "tiene", "tienen"]

static func missing(answer: String) -> Array[String]:
	var result: Array[String] = []
	# A quoted error is evidence, not the player's assertion. Keep clause boundaries.
	var text := RegEx.create_from_string('"[^"\\n]*"|«[^»\\n]*»|“[^”\\n]*”').sub(answer, ".", true)
	text = Course.fold(text)
	var nouns := {}
	for row: Array in rules.nouns:
		nouns[row[0]] = [row[2], 1]
		if row[0] != row[1]:
			nouns[row[1]] = [row[2], 2]
		else:
			nouns[row[0]][1] = 0 # Invariant number, e.g. hipótesis.
	for clause in RegEx.create_from_string("[.,;:!?¿¡\\n]").sub(text, "|", true).split("|", false):
		var tokens := RegEx.create_from_string("[^a-zñ0-9]+").sub(clause, " ", true).split(" ", false)
		for i in range(tokens.size() - 1):
			var first: String = tokens[i]
			var next: String = tokens[i + 1]
			if ARTICLES.has(first) and nouns.has(next):
				var expected: Array = nouns[next]
				var could_be_clitic: bool = first in ["la", "los", "las"] and next in NOUN_VERBS and (i + 2 >= tokens.size() or tokens[i + 2] not in PREDICATES)
				if not could_be_clitic and (ARTICLES[first][0] != expected[0] or (expected[1] != 0 and ARTICLES[first][1] != expected[1])):
					_add(result, "concordancia de artículo y nombre en «%s %s»" % [first, next])
			if (first.is_valid_int() and int(first) > 1 or first in ["dos", "tres", "cuatro", "cinco", "seis", "siete", "ocho", "nueve", "diez"]) and nouns.has(next) and nouns[next][1] == 1:
				_add(result, "el nombre en plural después de «%s»" % first)
			# El/tu can be articles/possessives: never treat a known noun as their verb.
			if SUBJECTS.has(first):
				var j := i + 1
				if tokens[j] in ["no", "nunca", "tampoco"] and j + 1 < tokens.size():
					j += 1
				if tokens[j] in ["lo", "la", "los", "las", "le", "les", "me", "te", "nos"] and j + 1 < tokens.size():
					j += 1
				var form: String = tokens[j]
				if first in ["el", "tu"] and (nouns.has(form) or form in ["compra", "compras", "estas", "esta", "cuesta", "cuestas"]):
					continue
				for infinitive: String in rules.verbs:
					var forms: Array = rules.verbs[infinitive]
					# Unaccented se is also a clitic, so leave it to context/model feedback.
					if form != "se" and form in forms and form != forms[SUBJECTS[first]]:
						_add(result, "concordancia: «%s» con «%s»" % [first, str(forms[SUBJECTS[first]])])
			if first in MODALS:
				for infinitive: String in rules.verbs:
					if next in rules.verbs[infinitive] and next not in ["se", "compra", "compras", "cuesta", "cuestas"]:
						_add(result, "un infinitivo después de «%s»: «%s»" % [first, infinitive])
	return result

static func _add(result: Array[String], message: String) -> void:
	if result.size() < 2 and message not in result:
		result.append(message)
