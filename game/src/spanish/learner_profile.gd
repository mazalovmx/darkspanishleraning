extends RefCounted
## Free-language observations and separately verified ordered lesson progression.
const GRAMMAR := ["ser_estar", "hay", "gender_articles", "object_pronouns", "gustar", "present", "perfect", "preterite", "imperfect", "preterite_vs_imperfect", "por_para", "ir_a_future", "imperative", "se", "reflexive", "relative_clauses", "subjunctive_basic", "conditional", "reported_speech", "future_simple"]
const VERBS := ["ser", "ir", "estar", "tener", "venir", "decir", "hacer", "poder", "poner", "querer", "saber", "dar", "ver", "traer", "conducir", "andar", "caber", "haber", "oir", "caer", "pedir", "dormir", "sentir", "morir", "seguir"]
const MIN_CONFIDENCE := 0.7
var grammar: Dictionary = {}
var verbs: Dictionary = {}
var errors: Dictionary = {}
var vocabulary: Array[String] = []
var recent_messages: Array[String] = []
var successful_contexts: Dictionary = {}
var curriculum = preload("res://src/spanish/curriculum.gd").new()
## B1 vocabulary practice (Leitner boxes), saved as "word_practice".
var word_practice = preload("res://src/spanish/vocabulary.gd").new()
var current_block: String:
	get:
		return curriculum.block_id()

func _init() -> void:
	for tag in GRAMMAR:
		grammar[tag] = 0.0
	for verb in VERBS:
		verbs[verb] = 0.0

func context() -> Dictionary:
	return {"block": current_block, "grammar_mastery": grammar.duplicate(),
		"verb_mastery": verbs.duplicate(), "allowed_grammar_tags": curriculum.allowed_grammar(), "curriculum": curriculum.context(),
		"allowed_verb_tags": VERBS, "focus_verbs": focus_verbs(), "recent_errors": recent_errors()}

# Only verbs in the current or earlier course blocks are proposed for practice.
# Scores and recorded errors rank candidates; selection never awards mastery.
func focus_verbs() -> Array:
	var candidates: Array = []
	for block: Dictionary in curriculum.blocks.slice(0, curriculum.index() + 1):
		for verb: String in block.verbs:
			if verb in VERBS and verb not in candidates:
				candidates.append(verb)
	candidates.sort_custom(func(a: String, b: String):
		var a_score: float = float(verbs[a]) - mini(int(errors.get("verb:" + a, {}).get("count", 0)), 10) * 0.01
		var b_score: float = float(verbs[b]) - mini(int(errors.get("verb:" + b, {}).get("count", 0)), 10) * 0.01
		return a_score < b_score if not is_equal_approx(a_score, b_score) else a < b)
	return candidates.slice(0, 3)

# Existing error records contain original examples, not verified corrected forms.
func recent_errors() -> Array:
	var tags: Array = []
	for tag: String in errors:
		if _taught(tag):
			tags.append(tag)
	tags.sort_custom(func(a: String, b: String):
		var a_day: int = int(errors[a].last_seen_day)
		var b_day: int = int(errors[b].last_seen_day)
		return a_day > b_day if a_day != b_day else a < b)
	var result: Array = []
	for tag: String in tags.slice(0, 4):
		var examples: Array = []
		for example: String in errors[tag].examples.slice(-2):
			examples.append(example.left(300))
		result.append({"tag": tag, "count": int(errors[tag].count),
			"last_seen_day": int(errors[tag].last_seen_day), "examples": examples,
			"mastery_after": snappedf(float(errors[tag].get("mastery_after", mastery(tag))), 0.01)})
	return result

func observe(language: Dictionary, message: String, npc_id: String, day: int) -> void:
	if language.confidence < MIN_CONFIDENCE:
		return
	var fingerprint := message.strip_edges().to_lower()
	if fingerprint in recent_messages:
		return
	curriculum.observe_difficulty(language.meaning_understood, language.confidence)
	recent_messages.append(fingerprint)
	if recent_messages.size() > 40:
		recent_messages.pop_front()
	var failed: Array[String] = []
	for error: Dictionary in language.errors:
		for tag in str(error.type).split("|"):
			if not _taught(tag) or tag in failed:
				continue
			failed.append(tag)
			_adjust(tag, -0.08)
			if error.severity == "important":
				if not errors.has(tag):
					errors[tag] = {"count": 0, "last_seen_day": day, "examples": []}
				errors[tag].count += 1
				errors[tag].last_seen_day = day
				# Section 28: the mastery the tag is left with after this error.
				errors[tag]["mastery_after"] = mastery(tag)
				var examples: Array = errors[tag].examples
				if not error.original in examples:
					examples.append(error.original)
					if examples.size() > 3:
						examples.pop_front()
	if language.meaning_understood:
		var credited: Array[String] = []
		for tag: String in language.successful_grammar:
			if not _taught(tag) or tag in failed or tag in credited:
				continue
			credited.append(tag)
			_adjust(tag, 0.05)
			if not successful_contexts.has(tag):
				successful_contexts[tag] = []
			if not npc_id in successful_contexts[tag]:
				successful_contexts[tag].append(npc_id)
	for word: String in language.new_vocabulary:
		if not word in vocabulary:
			vocabulary.append(word)
			if vocabulary.size() > 100:
				vocabulary.pop_front()

func mastery(tag: String) -> float:
	if tag.begins_with("verb:"):
		return float(verbs.get(tag.trim_prefix("verb:"), 0.0))
	return float(grammar.get(tag, 0.0))

func _known(tag: String) -> bool:
	return tag in GRAMMAR or (tag.begins_with("verb:") and tag.trim_prefix("verb:") in VERBS)

func _adjust(tag: String, amount: float) -> void:
	if tag.begins_with("verb:"):
		var verb := tag.trim_prefix("verb:")
		verbs[verb] = clampf(verbs[verb] + amount, 0.0, 1.0)
	else:
		grammar[tag] = clampf(grammar[tag] + amount, 0.0, 1.0)

func _taught(tag: String) -> bool:
	return _known(tag) and (tag.begins_with("verb:") or tag in curriculum.allowed_grammar())
