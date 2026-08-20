extends Node
## Persists player settings under user:// with graceful storage-failure handling.
## Gameplay/save state belongs to the session, not here.

const SETTINGS_PATH: String = "user://settings.cfg"

var _settings: Dictionary = {}
var _storage_ok: bool = true


func _ready() -> void:
	load_settings()


func get_setting(key: String, default_value: Variant) -> Variant:
	return _settings.get(key, default_value)


func set_setting(key: String, value: Variant) -> void:
	_settings[key] = value
	_save()


func load_settings() -> void:
	_storage_ok = true
	var config := ConfigFile.new()
	var err := config.load(SETTINGS_PATH)
	if err != OK:
		if err != ERR_FILE_NOT_FOUND:
			_storage_ok = false
		_settings = {}
		return
	for section in config.get_sections():
		for key in config.get_section_keys(section):
			_settings["%s/%s" % [section, key]] = config.get_value(section, key)
	GameEvents.settings_changed.emit("load")


func storage_ok() -> bool:
	return _storage_ok


func _save() -> void:
	_storage_ok = true
	var config := ConfigFile.new()
	for key: String in _settings:
		var section := key.get_slice("/", 0)
		var sub_key := key.get_slice("/", 1)
		if section.is_empty() or sub_key.is_empty():
			continue
		config.set_value(section, sub_key, _settings[key])
	var err := config.save(SETTINGS_PATH)
	if err != OK:
		_storage_ok = false
		push_warning("SaveManager: settings save failed (%s)" % error_string(err))
