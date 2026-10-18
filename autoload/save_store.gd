extends Node
## Local persistence: best score and games played. One language (English).

const SAVE_PATH := "user://paper_glide_save.json"
const TEMP_PATH := "user://paper_glide_save.tmp"
const SAVE_VERSION := 3
const MAX_SCORE := 999999

var _data: Dictionary = {}


func _ready() -> void:
	_load()


func _default_data() -> Dictionary:
	return {"version": SAVE_VERSION, "locale": "en", "best_score": 0, "games_played": 0}


func _load() -> void:
	_data = _default_data()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return
	var candidate: Dictionary = parsed
	_data.best_score = clampi(int(candidate.get("best_score", 0)), 0, MAX_SCORE)
	_data.games_played = clampi(int(candidate.get("games_played", 0)), 0, 99999999)


func save() -> bool:
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(_data, "  "))
	file.close()
	var temporary := ProjectSettings.globalize_path(TEMP_PATH)
	var destination := ProjectSettings.globalize_path(SAVE_PATH)
	if FileAccess.file_exists(SAVE_PATH):
		if DirAccess.remove_absolute(destination) != OK:
			return false
	return DirAccess.rename_absolute(temporary, destination) == OK


func get_locale() -> String:
	return "en"


func set_locale(_locale: String) -> void:
	pass


func get_best_score() -> int:
	return int(_data.get("best_score", 0))


func get_games_played() -> int:
	return int(_data.get("games_played", 0))


## Records a finished run. Returns true when it set a new best score.
## Practice runs (tuned gameplay values) count as played but never set the best.
func record_run(score: int, ranked: bool) -> bool:
	_data.games_played = clampi(get_games_played() + 1, 0, 99999999)
	var is_best := ranked and score > get_best_score()
	if is_best:
		_data.best_score = clampi(score, 0, MAX_SCORE)
	save()
	return is_best
