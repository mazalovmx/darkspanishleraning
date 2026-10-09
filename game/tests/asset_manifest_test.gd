extends SceneTree
## Every third-party asset folder has one licence record, and attribution licences are credited.
var checks := 0
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	var root_path := "res://assets/third_party/"
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(root_path + "manifest.json"))
	check(manifest is Dictionary and manifest.get("assets") is Array, "Manifest parses")
	var credits := FileAccess.get_file_as_string("res://CREDITS.md")
	var recorded := {}
	for entry: Dictionary in manifest.assets:
		check(not recorded.has(entry.asset_id), "One record per folder: " + str(entry.asset_id))
		recorded[entry.asset_id] = true
		for field: String in ["asset_id", "source_url", "author", "license", "attribution_text", "modified", "download_date", "used_in"]:
			check(entry.get(field) is String, "Field %s present: %s" % [field, entry.asset_id])
		check(str(entry.source_url).begins_with("https://") and not str(entry.author).is_empty() and not str(entry.license).is_empty(), "Source, author and licence named: " + str(entry.asset_id))
		check(DirAccess.dir_exists_absolute(root_path + str(entry.asset_id)), "Record points at an existing folder: " + str(entry.asset_id))
		if not str(entry.license).begins_with("CC0"):
			check(not str(entry.attribution_text).is_empty(), "A licence that asks for credit has its attribution text: " + str(entry.asset_id))
			check(credits.contains(str(entry.author).get_slice(";", 0).strip_edges()), "CREDITS.md names the author: " + str(entry.asset_id))
	for folder: String in DirAccess.get_directories_at(root_path):
		if not DirAccess.get_files_at(root_path + folder).is_empty() or not DirAccess.get_directories_at(root_path + folder).is_empty():
			check(recorded.has(folder), "Asset folder has a licence record: " + folder)
	print("Asset manifest checks: %d, failures: %d" % [checks, failures])
	quit(1 if failures else 0)
