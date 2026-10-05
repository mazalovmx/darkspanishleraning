extends RefCounted
## Deterministic observations, not an automatic curriculum unlocker.
const GRAMMAR := ["ser_estar", "hay", "gender_articles", "object_pronouns", "gustar", "present", "perfect", "preterite", "imperfect", "preterite_vs_imperfect", "por_para", "ir_a_future", "imperative", "se", "reflexive", "relative_clauses", "subjunctive_basic", "conditional", "reported_speech"]
const VERBS := ["ser", "ir", "estar", "tener", "venir", "decir", "hacer", "poder", "poner", "querer", "saber", "dar", "ver", "traer", "conducir", "andar", "caber", "haber", "oir", "caer", "pedir", "dormir", "sentir", "morir", "seguir"]
const MIN_CONFIDENCE := 0.7
var grammar: Dictionary = {}
var verbs: Dictionary = {}
var errors: Dictionary = {}
var vocabulary: Array[String] = []
var recent_messages: Array[String] = []
var successful_contexts: Dictionary = {}
var current_block := "present_and_basic_requests"

func _init() -> void:
	for tag in GRAMMAR:
		grammar[tag] = 0.0
	for verb in VERBS:
		verbs[verb] = 0.0

func context() -> Dictionary:
	return {"block": current_block, "grammar_mastery": grammar.duplicate(),
		"verb_mastery": verbs.duplicate(), "allowed_grammar_tags": GRAMMAR,
		"allowed_verb_tags": VERBS}

func observe(language: Dictionary, message: String, npc_id: String, day: int) -> void:
	if language.confidence < MIN_CONFIDENCE:
		return
	var fingerprint := message.strip_edges().to_lower()
	if fingerprint in recent_messages:
		return
	recent_messages.append(fingerprint)
	if recent_messages.size() > 40:
		recent_messages.pop_front()
	var failed: Array[String] = []
	for error: Dictionary in language.errors:
		for tag in str(error.type).split("|"):
			if not _known(tag) or tag in failed:
				continue
			failed.append(tag)
			_adjust(tag, -0.08)
			if error.severity == "important":
				if not errors.has(tag):
					errors[tag] = {"count": 0, "last_seen_day": day, "examples": []}
				errors[tag].count += 1
				errors[tag].last_seen_day = day
				var examples: Array = errors[tag].examples
				if not error.original in examples:
					examples.append(error.original)
					if examples.size() > 3:
						examples.pop_front()
	if language.meaning_understood:
		var credited: Array[String] = []
		for tag: String in language.successful_grammar:
			if not _known(tag) or tag in failed or tag in credited:
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

func _known(tag: String) -> bool:
	return tag in GRAMMAR or (tag.begins_with("verb:") and tag.trim_prefix("verb:") in VERBS)

func _adjust(tag: String, amount: float) -> void:
	if tag.begins_with("verb:"):
		var verb := tag.trim_prefix("verb:")
		verbs[verb] = clampf(verbs[verb] + amount, 0.0, 1.0)
	else:
		grammar[tag] = clampf(grammar[tag] + amount, 0.0, 1.0)
