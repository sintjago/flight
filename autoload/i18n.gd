extends Node
## Single-language (English) catalog lookup with {token} interpolation.

signal locale_changed(locale: String)

const CATALOG_PATHS := {"en": "res://localization/en.json"}

var _catalogs: Dictionary = {}
var _locale := "en"


func _ready() -> void:
	for locale: String in CATALOG_PATHS:
		_catalogs[locale] = _load_catalog(str(CATALOG_PATHS[locale]))


static func detect_locale(_os_locale: String) -> String:
	return "en"


static func resolve_locale(_saved: String, _os_locale: String) -> String:
	return "en"


func _load_catalog(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("I18n: missing catalog " + path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		push_error("I18n: invalid catalog " + path)
		return {}
	return parsed


func text(key: String, replacements: Dictionary = {}) -> String:
	var catalog: Dictionary = _catalogs.get("en", {})
	var result := str(catalog.get(key, key))
	for token: Variant in replacements:
		result = result.replace("{%s}" % str(token), str(replacements[token]))
	return result


func t(key: String, replacements: Dictionary = {}) -> String:
	return text(key, replacements)


func get_locale() -> String:
	return _locale


func set_locale(_locale_code: String) -> void:
	pass


func toggle_locale() -> void:
	pass


func catalog_keys(locale: String) -> Array:
	var catalog: Dictionary = _catalogs.get(locale, {})
	return catalog.keys()
