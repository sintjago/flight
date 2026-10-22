extends Node
## Local persistence: best score by learning area and challenge band, plus the overall best.

const SAVE_PATH := "user://paper_glide_save.json"
const TEMP_PATH := "user://paper_glide_save.tmp"
const SAVE_VERSION := 7
const MAX_SCORE := 999999
const MAX_COINS := 999999
const DIFFICULTIES: Array[String] = ["easy", "medium", "hard"]
const PRACTICE_AREAS: Array[String] = ["math", "reading", "russian", "spanish", "science"]
const PLANE_IDS: Array[String] = ["paper", "kite_glider", "sailwing", "comet_cruiser", "sky", "coral", "gold"]
const PLANE_COSTS := {"paper": 0, "sky": 10, "coral": 20, "gold": 35, "kite_glider": 15, "sailwing": 30, "comet_cruiser": 50}
const CHEER_IDS: Array[String] = ["nice_work", "banzai", "excelente"]
const CHEER_COSTS := {"nice_work": 0, "banzai": 10, "excelente": 15}

var _data: Dictionary = {}


func _ready() -> void:
	_load()


func _empty_area_scores() -> Dictionary:
	var all_scores: Dictionary = {}
	for area: String in PRACTICE_AREAS:
		all_scores[area] = {"easy": 0, "medium": 0, "hard": 0}
	return all_scores


func _default_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"locale": "en",
		"best_score": 0,
		"best_scores": {"easy": 0, "medium": 0, "hard": 0},
		"best_scores_by_area": _empty_area_scores(),
		"games_played": 0,
		"coins": 0,
		"owned_planes": ["paper"],
		"selected_plane": "paper",
		"owned_cheers": ["nice_work"],
		"selected_cheer": "nice_work",
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

	var saved_by_area: Variant = candidate.get("best_scores_by_area", {})
	var has_saved_math_scores := false
	if saved_by_area is Dictionary:
		for area: String in PRACTICE_AREAS:
			var area_values: Variant = saved_by_area.get(area, {})
			if not area_values is Dictionary:
				continue
			if area == "math":
				has_saved_math_scores = true
			for mode: String in DIFFICULTIES:
				var value := clampi(int(area_values.get(mode, 0)), 0, MAX_SCORE)
				_data.best_scores_by_area[area][mode] = value
		if has_saved_math_scores:
			_data.best_scores = _data.best_scores_by_area.math.duplicate(true)
		else:
			_data.best_scores_by_area.math = _data.best_scores.duplicate(true)
	else:
		_data.best_scores_by_area.math = _data.best_scores.duplicate(true)

	var highest := legacy_best
	for area: String in PRACTICE_AREAS:
		for mode: String in DIFFICULTIES:
			highest = maxi(highest, int(_data.best_scores_by_area[area][mode]))
	_data.best_score = highest
	_data.games_played = clampi(int(candidate.get("games_played", 0)), 0, 99999999)
	_data.coins = clampi(int(candidate.get("coins", 0)), 0, MAX_COINS)
	var owned_planes: Array[String] = ["paper"]
	var saved_planes: Variant = candidate.get("owned_planes", [])
	if saved_planes is Array:
		for value: Variant in saved_planes:
			var plane_id := str(value)
			if plane_id in PLANE_IDS and plane_id not in owned_planes:
				owned_planes.append(plane_id)
	_data.owned_planes = owned_planes
	var saved_selected_plane := str(candidate.get("selected_plane", "paper"))
	_data.selected_plane = saved_selected_plane if saved_selected_plane in owned_planes else "paper"
	var owned_cheers: Array[String] = ["nice_work"]
	var saved_cheers: Variant = candidate.get("owned_cheers", [])
	if saved_cheers is Array:
		for value: Variant in saved_cheers:
			var cheer_id := str(value)
			if cheer_id in CHEER_IDS and cheer_id not in owned_cheers:
				owned_cheers.append(cheer_id)
	_data.owned_cheers = owned_cheers
	var saved_selected_cheer := str(candidate.get("selected_cheer", "nice_work"))
	_data.selected_cheer = saved_selected_cheer if saved_selected_cheer in owned_cheers else "nice_work"
	_data.version = SAVE_VERSION


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


func get_best_score(difficulty: String = "", practice_area: String = "math") -> int:
	if difficulty.is_empty():
		return int(_data.get("best_score", 0))
	if practice_area not in PRACTICE_AREAS:
		practice_area = "math"
	var area_scores: Dictionary = _data.get("best_scores_by_area", {}).get(practice_area, {})
	return int(area_scores.get(difficulty, 0))


func get_games_played() -> int:
	return int(_data.get("games_played", 0))


func get_coins() -> int:
	return clampi(int(_data.get("coins", 0)), 0, MAX_COINS)


## Add gameplay-earned coins and persist the new wallet balance.
func add_coins(amount: int) -> int:
	var previous := get_coins()
	if amount <= 0:
		return previous
	var updated := mini(MAX_COINS, previous + amount)
	if updated == previous:
		return previous
	_data.coins = updated
	if not save():
		_data.coins = previous
	return get_coins()


func get_owned_planes() -> Array[String]:
	var owned: Array[String] = []
	var saved_planes: Variant = _data.get("owned_planes", ["paper"])
	if saved_planes is Array:
		for value: Variant in saved_planes:
			var plane_id := str(value)
			if plane_id in PLANE_IDS and plane_id not in owned:
				owned.append(plane_id)
	if "paper" not in owned:
		owned.push_front("paper")
	return owned


func owns_plane(plane_id: String) -> bool:
	return plane_id in PLANE_IDS and plane_id in get_owned_planes()


func get_plane_cost(plane_id: String) -> int:
	return int(PLANE_COSTS.get(plane_id, -1))


func get_selected_plane() -> String:
	var selected := str(_data.get("selected_plane", "paper"))
	return selected if owns_plane(selected) else "paper"


func select_plane(plane_id: String) -> bool:
	if not owns_plane(plane_id):
		return false
	var previous := get_selected_plane()
	if previous == plane_id:
		return true
	_data.selected_plane = plane_id
	if not save():
		_data.selected_plane = previous
		return false
	return true


## Buying a skin immediately equips it; all plane variants remain cosmetic.
func purchase_plane(plane_id: String) -> bool:
	if plane_id not in PLANE_IDS or owns_plane(plane_id):
		return false
	var cost := get_plane_cost(plane_id)
	var previous_coins := get_coins()
	if cost < 0 or previous_coins < cost:
		return false
	var previous_owned := get_owned_planes()
	var previous_selected := get_selected_plane()
	_data.coins = previous_coins - cost
	var owned := previous_owned.duplicate()
	owned.append(plane_id)
	_data.owned_planes = owned
	_data.selected_plane = plane_id
	if not save():
		_data.coins = previous_coins
		_data.owned_planes = previous_owned
		_data.selected_plane = previous_selected
		return false
	return true


func get_owned_cheers() -> Array[String]:
	var owned: Array[String] = []
	var saved_cheers: Variant = _data.get("owned_cheers", ["nice_work"])
	if saved_cheers is Array:
		for value: Variant in saved_cheers:
			var cheer_id := str(value)
			if cheer_id in CHEER_IDS and cheer_id not in owned:
				owned.append(cheer_id)
	if "nice_work" not in owned:
		owned.push_front("nice_work")
	return owned


func owns_cheer(cheer_id: String) -> bool:
	return cheer_id in CHEER_IDS and cheer_id in get_owned_cheers()


func get_cheer_cost(cheer_id: String) -> int:
	return int(CHEER_COSTS.get(cheer_id, -1))


func get_selected_cheer() -> String:
	var selected := str(_data.get("selected_cheer", "nice_work"))
	return selected if owns_cheer(selected) else "nice_work"


func select_cheer(cheer_id: String) -> bool:
	if not owns_cheer(cheer_id):
		return false
	var previous := get_selected_cheer()
	if previous == cheer_id:
		return true
	_data.selected_cheer = cheer_id
	if not save():
		_data.selected_cheer = previous
		return false
	return true


func purchase_cheer(cheer_id: String) -> bool:
	if cheer_id not in CHEER_IDS or owns_cheer(cheer_id):
		return false
	var cost := get_cheer_cost(cheer_id)
	var previous_coins := get_coins()
	if cost < 0 or previous_coins < cost:
		return false
	var previous_owned := get_owned_cheers()
	var previous_selected := get_selected_cheer()
	_data.coins = previous_coins - cost
	var owned := previous_owned.duplicate()
	owned.append(cheer_id)
	_data.owned_cheers = owned
	_data.selected_cheer = cheer_id
	if not save():
		_data.coins = previous_coins
		_data.owned_cheers = previous_owned
		_data.selected_cheer = previous_selected
		return false
	return true


## Records a finished run. Practice runs count as played but never set any best score.
func record_run(score: int, ranked: bool, difficulty: String = "medium", practice_area: String = "math") -> bool:
	if difficulty not in DIFFICULTIES:
		difficulty = "medium"
	if practice_area not in PRACTICE_AREAS:
		practice_area = "math"
	_data.games_played = clampi(get_games_played() + 1, 0, 99999999)
	var all_scores: Dictionary = _data.get("best_scores_by_area", _empty_area_scores())
	var area_scores: Dictionary = all_scores.get(practice_area, {"easy": 0, "medium": 0, "hard": 0})
	var is_mode_best := ranked and score > int(area_scores.get(difficulty, 0))
	if is_mode_best:
		area_scores[difficulty] = clampi(score, 0, MAX_SCORE)
	all_scores[practice_area] = area_scores
	_data.best_scores_by_area = all_scores
	if practice_area == "math":
		_data.best_scores = area_scores.duplicate(true)
	if ranked and score > int(_data.get("best_score", 0)):
		_data.best_score = clampi(score, 0, MAX_SCORE)
	save()
	return is_mode_best
