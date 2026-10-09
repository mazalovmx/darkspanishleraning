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
	# Every battle unit has its portrait and its field sprite, credited per file.
	var units: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/combat/stacks.json")).units
	var readme := FileAccess.get_file_as_string(root_path + "wesnoth/README.md")
	for type: String in units:
		check(ResourceLoader.exists(root_path + "wesnoth/portraits/%s.webp" % type) and ResourceLoader.exists(root_path + "wesnoth/units/%s.png" % type), "Unit has a portrait and a sprite: " + type)
		check(readme.contains("| portraits/%s.webp | " % type) and readme.contains("| units/%s.png | " % type), "Unit art is credited per file: " + type)
	check(FileAccess.get_file_as_string(root_path + "wesnoth/COPYING").contains("GNU GENERAL PUBLIC LICENSE"), "The licence text ships with the art")
	var arena = load("res://src/combat/stack_arena.gd").new()
	var sprite: Texture2D = arena.unit_sprite("militia", 0)
	var enemy: Texture2D = arena.unit_sprite("militia", 1)
	check(sprite != null and enemy != null and sprite.get_image().get_data() != enemy.get_image().get_data(), "The same unit is coloured differently for each side")
	var magenta := 0
	var image: Image = sprite.get_image()
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			magenta += int(pixel.a > 0.9 and pixel.r > 0.8 and pixel.g < 0.45 and pixel.b > 0.4 and pixel.b < 0.85)
	check(magenta == 0, "No team-colour placeholder is left on a coloured sprite: %d" % magenta)
	check(arena.unit_portrait("wolves") != null and arena.unit_face("wolves").region.size.x < arena.unit_portrait("wolves").get_size().x and arena.unit_sprite("invented", 0) == null, "Portraits load, faces are cropped, an unknown unit falls back")
	arena.free()
	print("Asset manifest checks: %d, failures: %d" % [checks, failures])
	quit(1 if failures else 0)
