extends Node2D
## Turn-based room exploration and question-driven combat for Paper Glide.

signal question_changed(question: Dictionary)
signal scored(total: int)
signal hearts_changed(hearts: int)
signal room_changed(room_number: int, rooms_cleared: int, boss_room: bool)
signal run_ended(total: int, won: bool, rooms_cleared: int)

const MathQuestion = preload("res://scripts/flight/math_question.gd")
const LearningQuestion = preload("res://scripts/flight/learning_question.gd")

const VIEW_SIZE := Vector2(1280.0, 720.0)
const GRID_COLUMNS := 9
const GRID_ROWS := 5
const TILE_SIZE := 72.0
const GRID_ORIGIN := Vector2(316.0, 132.0)
const PLAYER_START := Vector2i(1, 2)
const EXIT_CELL := Vector2i(7, 2)
const TOTAL_CHAMBERS := 3
const TOTAL_ROOMS := 4
const STARTING_HEARTS := 3
const PAPER := Color(0.965, 0.945, 0.885)
const GRAPHITE := Color(0.16, 0.17, 0.2)
const BLUE_PENCIL := Color(0.3, 0.5, 0.8)
const RED_PENCIL := Color(0.82, 0.25, 0.22)
const FLOOR := Color(0.99, 0.976, 0.93)
const WALL := Color(0.84, 0.82, 0.76)

const ROOM_LAYOUTS := [
	{"enemy_kind": "slime", "enemy_pos": Vector2i(4, 2), "enemy_hp": 1, "blocked": []},
	{"enemy_kind": "bat", "enemy_pos": Vector2i(5, 1), "enemy_hp": 1, "blocked": [Vector2i(3, 2), Vector2i(4, 1)]},
	{"enemy_kind": "slime", "enemy_pos": Vector2i(5, 3), "enemy_hp": 1, "blocked": [Vector2i(3, 1), Vector2i(4, 1)]},
	{"enemy_kind": "dragon", "enemy_pos": Vector2i(5, 2), "enemy_hp": 2, "blocked": [Vector2i(3, 1), Vector2i(3, 3)]},
]

const HERO_TEXTURE_PATH := "res://assets/dungeon/hero_paper_scholar_runtime.png"
const SLIME_TEXTURE_PATH := "res://assets/dungeon/enemy_ink_slime_runtime.png"
const BAT_TEXTURE_PATH := "res://assets/dungeon/enemy_pencil_bat_runtime.png"
const BOSS_TEXTURE_PATH := "res://assets/dungeon/boss_paper_dragon_runtime.png"

## Public run state is read by the controller and the focused integration tests.
var state := "ready" # ready, exploring, combat, feedback, won, defeated
var practice_area := "math"
var math_track_id := "math_1"
var difficulty_level := 1
var difficulty := "easy"
var selected_topic_groups: Array[String] = []
var selected_style_id := "paper"
var hero_pos := PLAYER_START
var enemy_pos := Vector2i(4, 2)
var exit_pos := EXIT_CELL
var room_index := 0
var rooms_cleared := 0
var hearts := STARTING_HEARTS
var enemy_hp := 0
var enemy_max_hp := 0
var enemy_kind := "slime"
var enemy_alive := false
var exit_unlocked := false
var score := 0
var current_question: Dictionary = {}
var answer_history: Array[Dictionary] = []
var failure_reason := ""
var failure_answer := ""
var failure_question := ""
var failure_hint_key := ""

var _rng := RandomNumberGenerator.new()
var _room_blocked: Array[Vector2i] = []
var _math_prompt_history: Dictionary = {}
var _math_topic_bag: Array[String] = []
var _math_topic_bag_key := ""
var _last_math_topic := ""
var _learning_prompt_history: Dictionary = {}
var _last_learning_category_by_key: Dictionary = {}
var _learning_category_alternates_by_key: Dictionary = {}
var _run_finalized := false
var _run_started := false
var _hero_texture: Texture2D
var _slime_texture: Texture2D
var _bat_texture: Texture2D
var _boss_texture: Texture2D


func _ready() -> void:
	_hero_texture = load(HERO_TEXTURE_PATH) as Texture2D
	_slime_texture = load(SLIME_TEXTURE_PATH) as Texture2D
	_bat_texture = load(BAT_TEXTURE_PATH) as Texture2D
	_boss_texture = load(BOSS_TEXTURE_PATH) as Texture2D
	_rng.randomize()
	reset_ready()


func set_difficulty(value: Variant) -> void:
	difficulty_level = MathQuestion.difficulty_level_for(value)
	difficulty = MathQuestion.band_for_level(difficulty_level)


func set_practice_area(value: String) -> void:
	if value == "math" or value in LearningQuestion.PRACTICE_AREAS:
		practice_area = value


func set_math_track(value: String) -> void:
	if value in MathQuestion.TRACK_IDS:
		math_track_id = value


func set_selected_topics(groups: Array) -> void:
	selected_topic_groups.clear()
	for value: Variant in groups:
		var group := str(value)
		if group not in selected_topic_groups:
			selected_topic_groups.append(group)


func set_selected_plane(value: String) -> void:
	selected_style_id = value
	queue_redraw()


func refresh_live_tuning() -> void:
	queue_redraw()


func reset_ready() -> void:
	if _run_started:
		var tuning := get_node_or_null("/root/TuningStore")
		if tuning != null:
			tuning.call("end_run")
		_run_started = false
	state = "ready"
	room_index = 0
	rooms_cleared = 0
	hero_pos = PLAYER_START
	enemy_alive = false
	exit_unlocked = false
	current_question.clear()
	_run_finalized = false
	queue_redraw()


func start_run() -> void:
	state = "exploring"
	room_index = 0
	rooms_cleared = 0
	hearts = STARTING_HEARTS
	score = 0
	hero_pos = PLAYER_START
	exit_pos = EXIT_CELL
	answer_history.clear()
	current_question.clear()
	failure_reason = ""
	failure_answer = ""
	failure_question = ""
	failure_hint_key = ""
	_math_prompt_history.clear()
	_math_topic_bag.clear()
	_math_topic_bag_key = ""
	_last_math_topic = ""
	_learning_prompt_history.clear()
	_last_learning_category_by_key.clear()
	_learning_category_alternates_by_key.clear()
	_run_finalized = false
	_run_started = true
	_rng.randomize()
	_setup_room()
	var tuning := get_node_or_null("/root/TuningStore")
	if tuning != null:
		tuning.call("begin_run")
	hearts_changed.emit(hearts)
	question_changed.emit(_exploration_state("dungeon.explore"))
	queue_redraw()


func move_player(direction: Vector2i) -> bool:
	if state != "exploring" or abs(direction.x) + abs(direction.y) != 1:
		return false
	var target := hero_pos + direction
	if not _is_walkable(target):
		return false
	if target == exit_pos and not exit_unlocked:
		question_changed.emit(_exploration_state("dungeon.exit_locked"))
		return false
	hero_pos = target
	if hero_pos == exit_pos and exit_unlocked:
		_advance_room()
		queue_redraw()
		return true
	if enemy_alive and _manhattan(hero_pos, enemy_pos) == 1:
		_begin_encounter()
	queue_redraw()
	return true


func submit_answer(option_index: int) -> bool:
	if state != "combat" or current_question.is_empty():
		return false
	var options: Array = current_question.get("answer_options", [])
	if option_index < 0 or option_index >= options.size():
		return false
	var selected_answer := str(options[option_index])
	var correct_answer := str(current_question.get("answer", ""))
	var is_correct := option_index == int(current_question.get("correct_index", -1))
	_record_answer(current_question, selected_answer, is_correct)
	var resolved_question := current_question.duplicate(true)
	current_question.clear()
	if is_correct:
		score += 1
		enemy_hp = maxi(0, enemy_hp - 1)
		scored.emit(score)
		if enemy_hp <= 0:
			enemy_alive = false
			exit_unlocked = not _is_boss_room()
			if _is_boss_room():
				_finish_run(true)
			else:
				state = "exploring"
				question_changed.emit(_exploration_state("dungeon.exit_open"))
		else:
			state = "combat"
			_issue_question()
	else:
		hearts = maxi(0, hearts - 1)
		hearts_changed.emit(hearts)
		failure_reason = "wrong_answer"
		failure_answer = correct_answer
		failure_question = str(resolved_question.get("expression", ""))
		failure_hint_key = str(resolved_question.get("hint_key", ""))
		if hearts <= 0:
			_finish_run(false)
		else:
			state = "feedback"
			resolved_question["phase"] = "feedback"
			resolved_question["selected_answer"] = selected_answer
			question_changed.emit(resolved_question)
	queue_redraw()
	return true


func continue_after_wrong() -> void:
	if state != "feedback":
		return
	state = "combat"
	_issue_question()


func get_current_room_number() -> int:
	return room_index + 1


func is_boss_room() -> bool:
	return _is_boss_room()


static func hero_texture_for(_style_id: String = "paper") -> Texture2D:
	return load(HERO_TEXTURE_PATH) as Texture2D


static func hero_tint_for(style_id: String) -> Color:
	match style_id:
		"sky":
			return Color(0.77, 0.87, 1.0)
		"coral":
			return Color(1.0, 0.78, 0.73)
		"gold":
			return Color(1.0, 0.9, 0.62)
		"kite_glider":
			return Color(0.75, 0.93, 0.9)
		"sailwing":
			return Color(0.9, 0.82, 1.0)
		"comet_cruiser":
			return Color(1.0, 0.79, 0.55)
		"albatross_glider":
			return Color(0.79, 0.9, 0.96)
		"double_fold":
			return Color(0.88, 0.85, 0.75)
		"boomerang_kite":
			return Color(0.94, 0.82, 0.89)
	return Color.WHITE


func _setup_room() -> void:
	var room_data: Dictionary = ROOM_LAYOUTS[clampi(room_index, 0, TOTAL_ROOMS - 1)]
	enemy_kind = str(room_data.get("enemy_kind", "slime"))
	enemy_pos = Vector2i(room_data.get("enemy_pos", Vector2i(4, 2)))
	enemy_max_hp = int(room_data.get("enemy_hp", 1))
	enemy_hp = enemy_max_hp
	enemy_alive = true
	exit_unlocked = false
	hero_pos = PLAYER_START
	_room_blocked.clear()
	for cell: Variant in room_data.get("blocked", []):
		if cell is Vector2i:
			_room_blocked.append(cell)
	room_changed.emit(room_index + 1, rooms_cleared, _is_boss_room())


func _advance_room() -> void:
	if _is_boss_room():
		return
	rooms_cleared = mini(TOTAL_CHAMBERS, rooms_cleared + 1)
	room_index = mini(TOTAL_ROOMS - 1, room_index + 1)
	_setup_room()
	state = "exploring"
	question_changed.emit(_exploration_state("dungeon.explore"))


func _begin_encounter() -> void:
	if state != "exploring" or not enemy_alive:
		return
	state = "combat"
	_issue_question()


func _issue_question() -> void:
	current_question = _build_question()
	if current_question.is_empty():
		state = "exploring"
		question_changed.emit(_exploration_state("dungeon.question_unavailable"))
		return
	current_question["phase"] = "combat"
	question_changed.emit(current_question.duplicate(true))


func _build_question() -> Dictionary:
	var question: Dictionary = {}
	if practice_area == "math":
		var group := _next_math_topic_group()
		var history_key := "%d:%s" % [difficulty_level, group]
		var used_prompts: Array = _math_prompt_history.get(history_key, [])
		question = MathQuestion.generate_with_history(_rng, difficulty_level, [group], used_prompts)
		_math_prompt_history[history_key] = used_prompts
	else:
		question = _next_learning_question()
	if question.is_empty():
		return {}
	question = question.duplicate(true)
	question["practice_area"] = practice_area
	question["difficulty_level"] = difficulty_level
	question["difficulty"] = difficulty
	var topic := str(question.get("topic", question.get("topic_group", "")))
	question["topic"] = topic
	if practice_area == "math":
		var correct_index := 0 if str(question.get("correct_lane", "upper")) == "upper" else 1
		question["answer_options"] = [str(question.get("upper_answer", "")), str(question.get("lower_answer", ""))]
		question["correct_index"] = correct_index
		question["answer"] = str(question.get("answer", question["answer_options"][correct_index]))
	else:
		var correct := str(question.get("answer", ""))
		var distractor := str(question.get("distractor", ""))
		var options: Array[String] = [correct, distractor]
		if _rng.randi_range(0, 1) == 1:
			options.reverse()
		question["answer_options"] = options
		question["correct_index"] = options.find(correct)
	question["question_number"] = answer_history.size() + 1
	return question


func _next_math_topic_group() -> String:
	var eligible: Array[String] = MathQuestion.available_topic_groups_for_track(math_track_id, difficulty_level)
	if selected_topic_groups.is_empty():
		eligible = MathQuestion.available_topic_groups(difficulty_level)
	else:
		var selected: Array[String] = []
		for group: String in eligible:
			if group in selected_topic_groups:
				selected.append(group)
		eligible = selected
	if eligible.is_empty():
		eligible = MathQuestion.available_topic_groups(difficulty_level)
	var parts := PackedStringArray([str(difficulty_level), math_track_id])
	for group: String in eligible:
		parts.append(group)
	var bag_key := "|".join(parts)
	if _math_topic_bag_key != bag_key or _math_topic_bag.is_empty():
		_math_topic_bag = eligible.duplicate()
		for index: int in range(_math_topic_bag.size() - 1, 0, -1):
			var swap_index := _rng.randi_range(0, index)
			var held := _math_topic_bag[index]
			_math_topic_bag[index] = _math_topic_bag[swap_index]
			_math_topic_bag[swap_index] = held
		if _math_topic_bag.size() > 1 and _math_topic_bag[0] == _last_math_topic:
			var different_index := _rng.randi_range(1, _math_topic_bag.size() - 1)
			var first := _math_topic_bag[0]
			_math_topic_bag[0] = _math_topic_bag[different_index]
			_math_topic_bag[different_index] = first
		_math_topic_bag_key = bag_key
	var next_group := str(_math_topic_bag.pop_front())
	_last_math_topic = next_group
	return next_group


func _learning_rotation_category(question: Dictionary) -> String:
	var generator_kind := str(question.get("generator_kind", ""))
	if not generator_kind.is_empty() and generator_kind != "knowledge_choice":
		return generator_kind
	return str(question.get("topic", ""))


func _next_learning_question() -> Dictionary:
	var history_key := "%s:%d" % [practice_area, difficulty_level]
	var previous_category := str(_last_learning_category_by_key.get(history_key, ""))
	var history: Array = _learning_prompt_history.get(history_key, []).duplicate()
	var fallback_question: Dictionary = {}
	var fallback_history: Array = []
	var chosen_question: Dictionary = {}
	var chosen_history: Array = []
	var attempt_limit := 1
	if not previous_category.is_empty() and bool(_learning_category_alternates_by_key.get(history_key, true)):
		attempt_limit = 64
	for _attempt: int in attempt_limit:
		var attempt_history: Array = history.duplicate()
		var candidate: Dictionary = LearningQuestion.generate_with_history(_rng, practice_area, difficulty_level, attempt_history)
		if candidate.is_empty():
			continue
		if fallback_question.is_empty():
			fallback_question = candidate
			fallback_history = attempt_history
		if previous_category.is_empty() or _learning_rotation_category(candidate) != previous_category:
			chosen_question = candidate
			chosen_history = attempt_history
			if not previous_category.is_empty():
				_learning_category_alternates_by_key[history_key] = true
			break
	if chosen_question.is_empty():
		chosen_question = fallback_question
		chosen_history = fallback_history
		if not previous_category.is_empty():
			_learning_category_alternates_by_key[history_key] = false
	if chosen_question.is_empty():
		return LearningQuestion.generate_with_history(_rng, practice_area, difficulty_level, history)
	_learning_prompt_history[history_key] = chosen_history
	_last_learning_category_by_key[history_key] = _learning_rotation_category(chosen_question)
	return chosen_question


func _record_answer(question: Dictionary, selected_answer: String, is_correct: bool) -> void:
	answer_history.append({
		"number": int(question.get("question_number", answer_history.size() + 1)),
		"expression": str(question.get("expression", "")),
		"selected_answer": selected_answer,
		"correct_answer": str(question.get("answer", "")),
		"topic": str(question.get("topic", "")),
		"practice_area": practice_area,
		"difficulty_level": difficulty_level,
		"status": "correct" if is_correct else "incorrect",
		"scored": is_correct,
		"hint_key": str(question.get("hint_key", "")),
	})


func _exploration_state(message_key: String) -> Dictionary:
	return {
		"phase": "explore",
		"message_key": message_key,
		"practice_area": practice_area,
		"difficulty": difficulty,
		"difficulty_level": difficulty_level,
	}


func _finish_run(won: bool) -> void:
	if _run_finalized:
		return
	_run_finalized = true
	_run_started = false
	state = "won" if won else "defeated"
	current_question.clear()
	var tuning := get_node_or_null("/root/TuningStore")
	if tuning != null:
		tuning.call("end_run")
	question_changed.emit({"phase": "ended", "won": won})
	run_ended.emit(score, won, rooms_cleared)
	queue_redraw()


func _is_boss_room() -> bool:
	return room_index >= TOTAL_CHAMBERS


func _is_walkable(cell: Vector2i) -> bool:
	if cell.x <= 0 or cell.x >= GRID_COLUMNS - 1 or cell.y <= 0 or cell.y >= GRID_ROWS - 1:
		return false
	if cell in _room_blocked:
		return false
	if enemy_alive and cell == enemy_pos:
		return false
	return true


func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(GRID_ORIGIN + Vector2(cell) * TILE_SIZE, Vector2.ONE * TILE_SIZE)


func _cell_center(cell: Vector2i) -> Vector2:
	return _cell_rect(cell).get_center()


func _draw() -> void:
	_draw_notebook()
	if state == "ready":
		return
	_draw_room()
	_draw_actors()


func _draw_notebook() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), PAPER)
	for index: int in range(0, 10):
		var y := 42.0 + float(index) * 72.0
		draw_line(Vector2(24.0, y), Vector2(1256.0, y), Color(0.34, 0.54, 0.78, 0.15), 1.0)
	draw_line(Vector2(246.0, 0.0), Vector2(246.0, VIEW_SIZE.y), Color(0.78, 0.28, 0.26, 0.22), 2.0)


func _draw_room() -> void:
	for y: int in range(GRID_ROWS):
		for x: int in range(GRID_COLUMNS):
			var cell := Vector2i(x, y)
			var rect := _cell_rect(cell)
			var is_border := x == 0 or x == GRID_COLUMNS - 1 or y == 0 or y == GRID_ROWS - 1
			var fill := WALL if is_border else FLOOR
			if not is_border and (x + y) % 2 == 0:
				fill = Color(0.975, 0.962, 0.921)
			draw_rect(rect, fill, true)
			draw_rect(rect, Color(GRAPHITE, 0.28), false, 1.0)
			if is_border:
				_draw_wall_hatching(rect)
	for cell: Vector2i in _room_blocked:
		_draw_stack_tile(_cell_rect(cell))
	_draw_door(_cell_rect(exit_pos), exit_unlocked)
	var room_frame := Rect2(GRID_ORIGIN, Vector2(GRID_COLUMNS, GRID_ROWS) * TILE_SIZE)
	draw_rect(room_frame, Color(GRAPHITE, 0.7), false, 3.0)


func _draw_wall_hatching(rect: Rect2) -> void:
	var start_x := rect.position.x + 8.0
	var end_x := rect.end.x - 8.0
	for index: int in range(0, 4):
		var y := rect.position.y + 12.0 + float(index) * 12.0
		draw_line(Vector2(start_x, y), Vector2(end_x, y - 3.0), Color(GRAPHITE, 0.28), 1.0)


func _draw_stack_tile(rect: Rect2) -> void:
	var inset := 9.0
	for layer: int in range(3):
		var book := Rect2(rect.position + Vector2(inset + float(layer) * 2.0, 35.0 - float(layer) * 12.0), Vector2(TILE_SIZE - inset * 2.0, 15.0))
		draw_rect(book, Color(0.89, 0.84, 0.74), true)
		draw_rect(book, Color(GRAPHITE, 0.74), false, 2.0)
		draw_line(book.position + Vector2(5.0, 4.0), book.position + Vector2(book.size.x - 5.0, 4.0), Color(BLUE_PENCIL, 0.62), 1.0)


func _draw_door(rect: Rect2, open: bool) -> void:
	var door := Rect2(rect.position + Vector2(8.0, 7.0), Vector2(rect.size.x - 16.0, rect.size.y - 12.0))
	var door_color := Color(0.73, 0.83, 0.72) if open else Color(0.89, 0.84, 0.74)
	draw_rect(door, door_color, true)
	draw_rect(door, Color(GRAPHITE, 0.82), false, 2.0)
	draw_line(door.position + Vector2(6.0, 12.0), door.position + Vector2(door.size.x - 6.0, 12.0), Color(GRAPHITE, 0.35), 1.0)
	if not open:
		var lock_center := door.position + Vector2(door.size.x * 0.5, door.size.y * 0.58)
		draw_circle(lock_center, 3.0, GRAPHITE)


func _draw_actors() -> void:
	if enemy_alive:
		var texture: Texture2D = _slime_texture
		var actor_size := Vector2.ONE * TILE_SIZE
		match enemy_kind:
			"bat":
				texture = _bat_texture
			"dragon":
				texture = _boss_texture
				actor_size = Vector2(108.0, 108.0)
		if texture != null:
			var actor_rect := Rect2(_cell_center(enemy_pos) - actor_size * 0.5, actor_size)
			draw_texture_rect(texture, actor_rect, false)
		else:
			draw_circle(_cell_center(enemy_pos), 19.0, Color(0.18, 0.2, 0.24))
		if enemy_max_hp > 1:
			for pip: int in range(enemy_max_hp):
				var color := RED_PENCIL if pip < enemy_hp else Color(GRAPHITE, 0.22)
				draw_circle(_cell_center(enemy_pos) + Vector2(-9.0 + float(pip) * 18.0, -44.0), 4.0, color)
	if _hero_texture != null:
		var hero_size := Vector2.ONE * TILE_SIZE
		var hero_rect := Rect2(_cell_center(hero_pos) - hero_size * 0.5, hero_size)
		draw_texture_rect(_hero_texture, hero_rect, false, hero_tint_for(selected_style_id))
	else:
		draw_circle(_cell_center(hero_pos), 18.0, BLUE_PENCIL)
	var badge_color := hero_tint_for(selected_style_id)
	draw_circle(_cell_center(hero_pos) + Vector2(18.0, -18.0), 4.0, badge_color)
