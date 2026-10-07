extends RefCounted
## Institutional speech acts (master spec 15, Epic 18): an act changes the world only
## with a speaker who holds that power, the procedure's seal and a witness.
static var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/scenario/institutions.json"))

static func valid(act: Variant) -> bool:
	if not act is Dictionary:
		return false
	var authority: Dictionary = rules.authorities.get(act.get("authority", ""), {})
	var procedure: Dictionary = rules.procedures.get(act.get("procedure", ""), {})
	if authority.is_empty() or procedure.is_empty() or act.get("kind", "") not in authority.kinds:
		return false
	if act.get("seal", "") != procedure.seal or (procedure.witness and str(act.get("witness", "")).is_empty()):
		return false
	for field in ["target", "effect", "text"]:
		if not act.get(field) is String or act[field].is_empty():
			return false
	return true

static func describe(act: Dictionary) -> String:
	return "%s · %s: %s" % [rules.kinds.get(act.kind, act.kind), rules.authorities[act.authority].name, act.text]
