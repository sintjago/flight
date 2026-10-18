extends Node
## Local persistence: best score per math difficulty plus the legacy overall best.

const SAVE_PATH := "user://paper_glide_save.json"
const TEMP_PATH := "user://paper_glide_save.tmp"
const SAVE_VERSION := 4
const MAX_SCORE := 999999
const DIFFICULTIES := ["easy", "medium", "hard"]

var _data: Dictionary = {}


func _ready() -> void:
	_load()


func _default_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"locale": "en",
		"best_score": 0,
		"best_scores": {"easy": 0, "medium": 0, "hard": 0},
		"games_played": 0,
	}


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
	var legacy_best := clampi(int(candidate.get("best_score", 0)), 0, MAX_SCORE)
	var saved_scores: Variant = candidate.get("best_scores", {})
	var has_mode_score := false
	if saved_scores is Dictionary:
		for mode: String in DIFFICULTIES:
			var value := clampi(int(saved_scores.get(mode, 0)), 0, MAX_SCORE)
			_data.best_scores[mode] = value
			has_mode_score = has_mode_score or value > 0
	if not has_mode_score and legacy_best > 0:
		_data.best_scores.medium = legacy_best
	var highest := legacy_best
	for mode: String in DIFFICULTIES:
		highest = maxi(highest, int(_data.best_scores[mode]))
	_data.best_score = highest
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


func get_best_score(difficulty: String = "") -> int:
	if difficulty.is_empty():
		return int(_data.get("best_score", 0))
	var scores: Dictionary = _data.get("best_scores", {})
	return int(scores.get(difficulty, 0))


func get_games_played() -> int:
	return int(_data.get("games_played", 0))


## Records a finished run. Practice runs count as played but never set any best score.
func record_run(score: int, ranked: bool, difficulty: String = "medium") -> bool:
	if difficulty not in DIFFICULTIES:
		difficulty = "medium"
	_data.games_played = clampi(get_games_played() + 1, 0, 99999999)
	var scores: Dictionary = _data.get("best_scores", {"easy": 0, "medium": 0, "hard": 0})
	var is_mode_best := ranked and score > int(scores.get(difficulty, 0))
	if is_mode_best:
		scores[difficulty] = clampi(score, 0, MAX_SCORE)
	_data.best_scores = scores
	if ranked and score > int(_data.get("best_score", 0)):
		_data.best_score = clampi(score, 0, MAX_SCORE)
	save()
	return is_mode_best
