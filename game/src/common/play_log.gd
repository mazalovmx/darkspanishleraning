extends RefCounted
## Append-only JSONL sessions. Player messages are intentional diagnostic data;
## credentials and model prompts are never recorded. No network upload occurs.
const DIRECTORY := "user://logs"
const MAX_BYTES := 5000000
static var test_path := "" # Explicit isolated opt-in for headless regression tests.
static var output_path := ""
static var session := ""
static var sequence := 0
static var part := 0
static var base_path := ""
static var owner: WeakRef
static var warned := false

static func attach(root: Node) -> void:
	if DisplayServer.get_name() == "headless" and test_path.is_empty():
		return
	if not output_path.is_empty():
		write("session_end", {"reason":"map_replaced"})
	session = Time.get_datetime_string_from_system(true).replace(":", "-") + "_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	base_path = test_path if not test_path.is_empty() else DIRECTORY + "/session_" + session + ".jsonl"
	output_path = base_path
	sequence = 0
	part = 0
	warned = false
	owner = weakref(root)
	_watch_tree(root)
	if not root.get_tree().node_added.is_connected(_watch_node):
		root.get_tree().node_added.connect(_watch_node)
	write("session_start", {"engine":Engine.get_version_info().string, "format":1})

static func snapshot(world: RefCounted) -> Dictionary:
	var heroes := {}
	for id: String in world.party.heroes:
		var member = world.party.heroes[id]
		heroes[id] = {"cell":[member.cell.x, member.cell.y], "health":member.health, "unlocked":member.unlocked}
	return {"map":world.map_id, "day":world.day, "hero":world.party.active_id,
		"cell":[world.hero_cell.x, world.hero_cell.y], "movement":world.movement_remaining,
		"heroes":heroes, "resources":world.resources.duplicate(true), "army":world.army.duplicate(true),
		"buildings":world.economy.buildings.duplicate(true), "mines":world.economy.mines.duplicate(true),
		"planned_orders":world.ghosts.plan.orders.duplicate(true) if world.ghosts.plan != null else {}, "order_phase":world.economy.phase, "evidence":world.evidence.progress().keys()}

static func _context() -> Dictionary:
	var root = owner.get_ref() if owner != null else null
	return snapshot(root.state) if is_instance_valid(root) else {}

static func write(event: String, data: Dictionary = {}) -> bool:
	if DisplayServer.get_name() == "headless" and test_path.is_empty():
		return false
	if output_path.is_empty():
		return false
	DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	var file := FileAccess.open(output_path, FileAccess.READ_WRITE) if FileAccess.file_exists(output_path) else FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		if not warned:
			push_warning("Session log could not be opened: " + str(FileAccess.get_open_error()))
			warned = true
		return false
	if file.get_length() >= MAX_BYTES:
		file.close()
		part += 1
		output_path = base_path.get_basename() + "_%03d.jsonl" % part
		return write(event, data)
	sequence += 1
	file.seek_end()
	file.store_line(JSON.stringify({"schema":1, "session":session, "seq":sequence,
		"utc":Time.get_datetime_string_from_system(true), "ticks_ms":Time.get_ticks_msec(),
		"event":event, "context":_context(), "data":_safe(data)}))
	var ok := file.get_error() == OK
	file.close()
	return ok

static func _safe(value: Variant) -> Variant:
	if value is Dictionary:
		var clean := {}
		for key in value:
			var name := str(key).to_lower()
			clean[key] = "[redacted]" if name in ["authorization", "api_key", "password", "secret", "access_token", "system_prompt", "prompt", "headers"] or name.ends_with("_api_key") else _safe(value[key])
		return clean
	if value is Array:
		return value.map(_safe)
	return value

static func _watch_tree(node: Node) -> void:
	_watch_node(node)
	for child in node.get_children():
		_watch_tree(child)

static func _watch_node(node: Node) -> void:
	var root = owner.get_ref() if owner != null else null
	if not is_instance_valid(root) or not root.is_ancestor_of(node) or node.has_meta("play_log_watched"):
		return
	node.set_meta("play_log_watched", true)
	var control_path := str(root.get_path_to(node))
	if node is BaseButton:
		node.button_down.connect(func(): write("ui_attempt", {"control":control_path, "label":node.text if node is Button else "", "fields":_fields(root)}))
		node.pressed.connect(func(): write("ui_action", {"control":control_path, "label":node.text if node is Button else ""}))
	if node is OptionButton:
		node.item_selected.connect(func(index: int): write("ui_choice", {"control":control_path, "index":index, "label":node.get_item_text(index), "value":node.get_item_metadata(index)}))
	if node is LineEdit:
		node.text_submitted.connect(func(text: String): write("ui_submit", {"control":control_path, "text":text}))
	if node is SpinBox:
		node.value_changed.connect(func(value: float): write("ui_quantity", {"control":control_path, "value":value}))

static func _fields(root: Node) -> Dictionary:
	var fields := {}
	for node in root.find_children("*", "LineEdit", true, false):
		if node.is_visible_in_tree() and not node.secret:
			fields[str(root.get_path_to(node))] = node.text
	return fields
