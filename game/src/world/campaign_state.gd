extends RefCounted
## Authored campaign claims. No model response can advance this ledger.
const Institutions = preload("res://src/world/institutions.gd")
var definitions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/scenario/campaign.json")).nodes
var records: Dictionary = {}
const CLASSIFICATIONS := ["observed", "reported", "inferred", "declared", "unresolved"]

func _proof_day(world: RefCounted, id: String, progress: Dictionary) -> int:
	if id.begins_with("e:"):
		return int(world.evidence.progress().get(id.trim_prefix("e:"), {}).get("found_day", 0))
	return int(progress.get(id, {}).get("day", 0))

func prerequisites(world: RefCounted, node: Dictionary, progress: Dictionary, day: int) -> bool:
	for id: String in node.requires + node.get("supports", []):
		var found := _proof_day(world, id, progress)
		if found < 1 or found > day:
			return false
	return true

func language_ready(world: RefCounted, node: Dictionary, day: int) -> bool:
	var course = world.learner.curriculum
	for index in int(node.min_block):
		for card: Dictionary in course.blocks[index].cards:
			var recalled: int = int(course.records.get(card.id, {}).get("recall", {}).get("day", 0))
			if recalled < 1 or recalled > day:
				return false
	for tag: String in node.grammar:
		var practiced := false
		for block: Dictionary in course.blocks:
			for card: Dictionary in block.cards:
				if card.tag == tag:
					var applied: int = int(course.records.get(card.id, {}).get("second", {}).get("day", 0))
					practiced = applied > 0 and applied <= day
		if not practiced:
			return false
	return true

func available(world: RefCounted) -> Array:
	var result := []
	for id in definitions:
		if not records.has(id) and prerequisites(world, definitions[id], records, world.day):
			result.append(id)
	return result

func chapter(world: RefCounted) -> int:
	if not world.evidence.has_evidence("opening_conclusion"):
		return 1
	for id in definitions:
		if not records.has(id) and not definitions[id].get("optional", false):
			return int(definitions[id].act)
	return 7

## Needs a free answer still lacks. Authored answers and variants always pass; a node
## without keys (the council's choice) accepts only them.
func missing(world: RefCounted, node: Dictionary, answer: String) -> Array[String]:
	var result: Array[String] = []
	var course = world.learner.curriculum
	for accepted: String in node.answers + node.get("variants", []):
		if course.normalized(answer) == course.normalized(accepted):
			return result
	if not node.has("keys"):
		result.append("una de las propuestas, tal como está escrita")
		return result
	var text: String = course.words(answer)
	# One claim per conclusion: a second sentence or a long addition is not a paraphrase.
	var longest := 0
	for accepted: String in node.answers + node.get("variants", []):
		longest = maxi(longest, course.words(accepted).split(" ", false).size())
	if RegEx.create_from_string("[.;!?]\\s*\\S").search(answer.strip_edges()) != null:
		result.append("una sola frase")
	elif text.split(" ", false).size() > longest + 8:
		result.append("una frase más breve, con una sola afirmación")
	for group: Dictionary in node.keys:
		if not group.any.any(func(form: String) -> bool: return text.contains(" %s " % form)):
			result.append(str(group.need))
	var negative: bool = course.words(node.answers[0]).contains(" no ")
	if negative != (text.contains(" no ") or text.contains(" nunca ")):
		var mixed: bool = node.get("variants", []).any(func(v: String) -> bool: return course.words(v).contains(" no ") != negative)
		if not mixed:
			result.append("una negación (no…)" if negative else "una afirmación, sin negación")
	return result

func needs(node: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for group: Dictionary in node.get("keys", []):
		result.append(str(group.need))
	return result

func _answer_valid(world: RefCounted, node: Dictionary, answer: String, classification: String, supports: Array) -> bool:
	# At the council a wrong category is recorded, not refused: it closes the Charter
	# (bible 36, "wrong classification changes available endings").
	if answer.length() > 300 or classification not in (CLASSIFICATIONS if node.get("council", false) else [node.classification]):
		return false
	if not missing(world, node, answer).is_empty():
		return false
	var required: Array = node.get("supports", [])
	if supports.size() != required.size():
		return false
	var seen := {}
	for id in supports:
		if not id is String or id not in required or seen.has(id):
			return false
		seen[id] = true
	return true

func _declaration_valid(node: Dictionary) -> bool:
	# The act carried by the node, never authority supplied by an NPC/model response.
	return not node.has("declaration") or Institutions.valid(node.declaration)

## The chosen outcome of a decision node, or {} when the answer names none.
func outcome_for(world: RefCounted, node: Dictionary, answer: String) -> Dictionary:
	for outcome: Dictionary in node.get("outcomes", []):
		if world.learner.curriculum.normalized(answer) == world.learner.curriculum.normalized(outcome.answer):
			return outcome
	return {}

## Valid institutional acts in force: those of recorded nodes and of chosen outcomes.
func acts(world: RefCounted, progress: Variant = null) -> Array:
	var ledger: Dictionary = records if progress == null else progress
	var result: Array = []
	for id: String in ledger:
		var node: Dictionary = definitions[id]
		for act: Variant in [node.get("declaration"), outcome_for(world, node, str(ledger[id].answer)).get("declaration")]:
			if Institutions.valid(act):
				result.append(act)
	return result

## World consequences of the acts in force, as effect flags.
func effects(world: RefCounted, progress: Variant = null) -> Dictionary:
	var result := {}
	for act: Dictionary in acts(world, progress):
		result[act.effect] = true
	return result

func reason(world: RefCounted, id: String) -> String:
	if world.planning_active():
		return "Resuelve primero las órdenes preparadas."
	if world.map_id != "province_160x120_v1" or not definitions.has(id):
		return "Este expediente no está disponible aquí."
	var node: Dictionary = definitions[id]
	if records.has(id):
		return "La conclusión ya está anotada."
	if not prerequisites(world, node, records, world.day):
		return "Primero reúne las pruebas anteriores."
	if not language_ready(world, node, world.day):
		return "Completa las prácticas y el repaso del curso antes de esta tarea."
	if world.active_battle != null or not world.trade.pending.is_empty():
		return "Termina la acción actual."
	if world.location_at(world.hero_cell).get("id", "") != node.location:
		return "Viaja al lugar del expediente."
	if node.hero != "any" and world.party.active_id != node.hero:
		return "Esta gestión corresponde a otro miembro del grupo."
	if node.get("reunite", false):
		for member in world.party.heroes.values():
			if not member.unlocked or member.cell != world.hero_cell:
				return "Reúne a Mateo, Inés y Elias en Santa Lucerna."
	return ""

func submit(world: RefCounted, id: String, answer: String, classification: String, supports: Array = []) -> Dictionary:
	var denied := reason(world, id)
	if not denied.is_empty():
		return {"ok":false, "message":denied}
	var node: Dictionary = definitions[id]
	var gaps := missing(world, node, answer)
	if answer.length() <= 300 and not gaps.is_empty():
		return {"ok":false, "message":"Tu frase necesita: " + "; ".join(gaps) + "."}
	if world.learner.curriculum.is_last_block(int(node.min_block)):
		var spelling: PackedStringArray = world.learner.curriculum.orthography_errors(answer, node.answers + node.get("variants", []))
		if not spelling.is_empty():
			return {"ok":false, "message":"En este nivel cuentan las tildes: " + ", ".join(spelling) + "."}
	if not _answer_valid(world, node, answer, classification, supports) or not _declaration_valid(node):
		return {"ok":false, "message":"Revisa la fuente, la categoría y las pruebas. Escribe una frase completa en español."}
	if not _outcome_ready(world, node, answer, records, world.day):
		return {"ok":false, "message":"La Carta exige revisar los expedientes del grano, la ventilación y el condensador, y un consejo sin clasificaciones erróneas."}
	records[id] = {"day":world.day, "hero":world.party.active_id, "answer":answer.strip_edges(),
		"classification":classification, "supports":supports.duplicate()}
	if node.has("unlock_hero"):
		world.party.heroes[node.unlock_hero].unlocked = true
		world._reveal_from(world.hero_cell)
	return {"ok":true, "message":"Anotado. La categoría no convierte un testimonio en un hecho observado."}

func snapshot() -> Dictionary:
	return records.duplicate(true)

func restore(data: Variant, world: RefCounted) -> bool:
	if not data is Dictionary or data.size() > definitions.size():
		return false
	if world.map_id != "province_160x120_v1" and not data.is_empty():
		return false
	var validated := {}
	for id in data:
		if not id is String or not definitions.has(id):
			return false
		var entry: Variant = data[id]
		var node: Dictionary = definitions[id]
		if not entry is Dictionary or entry.size() != 5:
			return false
		var day: Variant = entry.get("day")
		if not (day is int or day is float) or not is_finite(day) or day != floor(day) or day < 1 or day > world.day:
			return false
		if not entry.get("hero") is String or not world.party.heroes.has(entry.hero):
			return false
		if node.hero != "any" and node.hero != entry.hero:
			return false
		var intro := "ines_arrival" if entry.hero == "smuggler" else "elias_arrival" if entry.hero == "survivor" else ""
		if not intro.is_empty():
			if not data.get(intro) is Dictionary or definitions.keys().find(id) <= definitions.keys().find(intro):
				return false
			var intro_day: Variant = data[intro].get("day")
			if not (intro_day is int or intro_day is float) or intro_day > day:
				return false
		if not entry.get("answer") is String or not entry.get("classification") is String or not entry.get("supports") is Array:
			return false
		if not _answer_valid(world, node, entry.answer, entry.classification, entry.supports):
			return false
		if not language_ready(world, node, int(day)) or not _declaration_valid(node):
			return false
		validated[id] = entry.duplicate(true)
	for id in validated:
		if not prerequisites(world, definitions[id], validated, int(validated[id].day)) or not _outcome_ready(world, definitions[id], validated[id].answer, validated, int(validated[id].day)):
			return false
	if world.map_id == "province_160x120_v1":
		if world.party.heroes.smuggler.unlocked != validated.has("ines_arrival") or world.party.heroes.survivor.unlocked != validated.has("elias_arrival"):
			return false
	records = validated
	return true
func _outcome_ready(world: RefCounted, node: Dictionary, answer: String, progress: Dictionary, day: int) -> bool:
	for outcome: Dictionary in node.get("outcomes", []):
		if world.learner.curriculum.normalized(answer) == world.learner.curriculum.normalized(outcome.answer):
			for id: String in outcome.requires:
				var found := _proof_day(world,id,progress)
				if found < 1 or found > day:
					return false
			if outcome.get("clean_council", false) and misclassified(progress) > 0:
				return false
			if outcome.has("declaration") and not Institutions.valid(outcome.declaration):
				return false
			# An act already in force can close an outcome (e.g. emergency powers, the Charter).
			var other := progress.duplicate()
			other.erase(node.id)
			for effect: String in outcome.get("closed_by", []):
				if effects(world, other).has(effect):
					return false
	return true

## Council statements recorded under a category other than the authored one.
func misclassified(progress: Dictionary) -> int:
	var count := 0
	for id: String in progress:
		if definitions.has(id) and definitions[id].get("council", false) and progress[id].get("classification") != definitions[id].classification:
			count += 1
	return count

func ending(world: RefCounted) -> Dictionary:
	if not records.has("council_resolution"):
		return {}
	var answer: String = records.council_resolution.answer
	for outcome: Dictionary in definitions.council_resolution.outcomes:
		if world.learner.curriculum.normalized(answer) == world.learner.curriculum.normalized(outcome.answer):
			return outcome.duplicate(true)
	return {}