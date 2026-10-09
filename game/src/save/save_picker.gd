extends FileDialog
## The operating system's own save/open window where available (Windows), opened in
## the saves folder with a proposed name. Headless runs fall back to Godot's dialog.
signal chosen(path: String, saving: bool)
const Log = preload("res://src/common/play_log.gd")
var saving := true
var directory := "user://saves"
var autosave_path := ""
var name_seed := ""
var automatic_name := Button.new()
var load_autosave := Button.new()

func _ready() -> void:
	access = FileDialog.ACCESS_FILESYSTEM
	use_native_dialog = DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE)
	display_mode = FileDialog.DISPLAY_LIST
	get_cancel_button().text = "Cancelar"
	theme = Theme.new()
	theme.default_font = ThemeDB.fallback_font
	theme.default_font_size = 16
	# The two buttons exist only in the fallback dialog; the system window has none.
	automatic_name.text = "Usar nombre automático"
	automatic_name.pressed.connect(func(): current_file = fresh_name())
	get_vbox().add_child(automatic_name)
	load_autosave.text = "Cargar autoguardado"
	load_autosave.pressed.connect(func():
		hide()
		chosen.emit(autosave_path, false))
	get_vbox().add_child(load_autosave)
	file_selected.connect(func(path: String):
		hide()
		chosen.emit(resolved(path), saving))
	canceled.connect(func(): Log.write("save_picker_cancelled", {"saving":saving}))

func open(world: RefCounted, autosave: String, folder: String, for_save: bool) -> void:
	saving = for_save
	directory = folder
	autosave_path = autosave
	DirAccess.make_dir_recursive_absolute(directory)
	file_mode = FileDialog.FILE_MODE_SAVE_FILE if saving else FileDialog.FILE_MODE_OPEN_FILE
	# Loading also lists plain .json so the autosave, one folder up, can be chosen.
	filters = PackedStringArray(["*.save.json ; Partidas guardadas"] if saving else ["*.save.json ; Partidas guardadas", "*.json ; Autoguardado y otras"])
	current_dir = ProjectSettings.globalize_path(directory)
	title = "Guardar partida" if saving else "Cargar partida"
	get_ok_button().text = "Guardar" if saving else "Cargar"
	automatic_name.visible = saving
	load_autosave.visible = not saving
	load_autosave.disabled = not FileAccess.file_exists(autosave_path)
	name_seed = "Dia_%03d_%s" % [world.day, str(world.party.active().definition.short_name).validate_filename()]
	current_file = fresh_name() if saving else ""
	Log.write("save_picker_open", {"saving":saving, "native":use_native_dialog})
	popup_centered(Vector2i(780, 520))

func fresh_name() -> String:
	var stem := name_seed + "_" + Time.get_datetime_string_from_system().replace(":", "-")
	var filename := stem + ".save.json"
	var index := 2
	while FileAccess.file_exists(directory.path_join(filename)):
		filename = stem + "_%d.save.json" % index
		index += 1
	return filename

## The path the game will use: a typed name always gets the .save.json ending, so a
## checkpoint can never replace the autosave, a transcript or an unrelated file.
func resolved(path: String) -> String:
	path = path.replace("\\", "/")
	if not saving:
		return autosave_path if path == ProjectSettings.globalize_path(autosave_path) else path
	for ending: String in [".save.json", ".json", ".save"]:
		if path.to_lower().ends_with(ending):
			path = path.left(-ending.length())
			break
	return path + ".save.json"

func accepts(path: String) -> bool:
	return path.ends_with(".save.json") and not path.get_file().trim_suffix(".save.json").is_empty()
