extends RefCounted
## Canonical, read-only boundary. No model-owned dictionaries enter these checks.
var _data: Dictionary

func _init(fixture: Dictionary = {}) -> void:
	_data = fixture.duplicate(true) if not fixture.is_empty() else JSON.parse_string(
		FileAccess.get_file_as_string("res://content/dialogue/npc_grounding.json"))

func _npc(id: String) -> Dictionary:
	var npc: Variant = _data.get("npcs", {}).get(id)
	if not npc is Dictionary or npc.get("id") != id:
		return {}
	for field in ["persona", "lie_policy"]:
		if not npc.get(field) is Dictionary:
			return {}
	for field in ["knowledge", "beliefs", "false_beliefs", "secrets"]:
		if not npc.get(field) is Array:
			return {}
	if not npc.get("language_register") is String:
		return {}
	return npc

func _requirements(requirements: Variant, states: Dictionary) -> bool:
	if not requirements is Dictionary:
		return false
	for key in requirements:
		if not requirements[key] is String or not states.has(key) or not states[key] is String or states[key] != requirements[key]:
			return false
	return true

func _known_ids(npc: Dictionary, states: Dictionary) -> Array:
	var ids: Array = npc.knowledge.duplicate()
	for secret: Variant in npc.secrets:
		# A missing/empty policy never makes a secret public.
		if secret is Dictionary and secret.get("prerequisites") is Dictionary:
			if not secret.prerequisites.is_empty() and _requirements(secret.prerequisites, states):
				if secret.get("id") is String:
					ids.append(secret.id)
	return ids

func intent_for(message: String) -> String:
	var normalized := message.to_lower()
	for pair in [["á", "a"], ["é", "e"], ["í", "i"], ["ó", "o"], ["ú", "u"], ["ü", "u"]]:
		normalized = normalized.replace(pair[0], pair[1])
	var words := RegEx.new()
	words.compile("[^a-zñ0-9]+")
	normalized = " " + words.sub(normalized, " ", true).strip_edges() + " "
	for intent: String in _data.get("intents", {}):
		for keyword: String in _data.intents[intent]:
			if normalized.contains(" " + keyword + " "):
				return intent
	return "unknown"

func allows_unlock(clue_id: Variant, npc_id: String, intent: String,
		states: Dictionary, revealed: Array) -> bool:
	var npc := _npc(npc_id)
	if npc.is_empty():
		return false
	if clue_id == null:
		return true
	if not clue_id is String or clue_id.is_empty() or clue_id in revealed:
		return false
	var clue: Variant = _data.get("clues", {}).get(clue_id)
	if not clue is Dictionary or not _data.get("facts", {}).get(clue_id) is String:
		return false
	if clue_id not in _known_ids(npc, states):
		return false
	if intent == "unknown" or clue.get("intent") != intent:
		return false
	return _requirements(clue.get("prerequisites"), states)

func context_for(npc_id: String, intent: String, states: Dictionary, revealed: Array) -> Dictionary:
	var npc := _npc(npc_id)
	if npc.is_empty():
		return {}
	var facts := {}
	var eligible: Array[String] = []
	var secret_ids: Array = []
	for secret: Variant in npc.secrets:
		if secret is Dictionary:
			secret_ids.append(secret.get("id"))
	for id: Variant in _known_ids(npc, states):
		if not id is String or not _data.get("facts", {}).get(id) is String:
			continue
		if _data.get("clues", {}).has(id):
			if id not in revealed and not allows_unlock(id, npc_id, intent, states, revealed):
				continue
			if allows_unlock(id, npc_id, intent, states, revealed):
				eligible.append(id)
		facts[id] = _data.facts[id]
	var disclosed_secrets := {}
	for id in secret_ids:
		if facts.has(id):
			disclosed_secrets[id] = facts[id]
	# Copy nested values so callers cannot mutate canonical data.
	return {"npc": {"id": npc_id, "persona": npc.persona,
		"language_register": npc.language_register, "lie_policy": npc.lie_policy},
		"world_facts": facts, "npc_knowledge": facts,
		"npc_beliefs": npc.beliefs, "npc_false_beliefs": npc.false_beliefs,
		"npc_secrets": disclosed_secrets, "eligible_unlock_ids": eligible,
		"verified_intent": intent}.duplicate(true)
