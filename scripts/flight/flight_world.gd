extends Node2D
## One-tap flight simulation plus its notebook / pencil-sketch presentation.
## Simulation (physics, pipes, scoring, collision) is authoritative; drawing is cosmetic.

signal flapped
signal scored(total: int)
signal crashed(total: int, hit_ground: bool)
signal question_changed(question: Dictionary)

const VIEW_SIZE := Vector2(1280.0, 720.0)
const GROUND_Y := 650.0
const PLANE_X := 340.0
const PLANE_SIZE := Vector2(122.0, 56.5)
const HIT_SCALE := 1.15
const READY_Y := 390.0
const LANE_SEPARATION := 250.0

const PIPE_BODY_HALF := 59.0
const PIPE_CAP_HALF := 71.0
const PIPE_CAP_HEIGHT := 52.0
const PIPE_BODY_WIDTH := 120.7
const PIPE_MARGIN := 78.0
const MAX_FALL_SPEED := 760.0
const MAX_STEP := 1.0 / 30.0
const FIRST_PIPE_DISTANCE := 620.0
const GROUND_PERIOD := 1400.0

const PAPER := Color(0.965, 0.945, 0.885)
const GRAPHITE := Color(0.16, 0.17, 0.2)
const BLUE_PENCIL := Color(0.36, 0.55, 0.82)
const YELLOW_PENCIL := Color(0.93, 0.78, 0.25)

const T_PAPER: Texture2D = preload("res://assets/paperglide/notebook.jpg")
const T_PLANE: Texture2D = preload("res://assets/paperglide/plane.png")
const PLANE_TINTS := {
	"paper": Color(1.0, 1.0, 1.0, 1.0),
	"sky": Color(0.72, 0.88, 1.0, 1.0),
	"coral": Color(1.0, 0.79, 0.72, 1.0),
	"gold": Color(1.0, 0.87, 0.5, 1.0),
}
const T_PIPE_CAP: Texture2D = preload("res://assets/paperglide/pipe_cap.png")
const T_PIPE_BODY: Texture2D = preload("res://assets/paperglide/pipe_body.png")
const T_CLOUDS: Array[Texture2D] = [
	preload("res://assets/paperglide/cloud0.png"),
	preload("res://assets/paperglide/cloud1.png"),
	preload("res://assets/paperglide/cloud2.png"),
	preload("res://assets/paperglide/cloud3.png"),
]
const T_DOODLES: Array[Texture2D] = [
	preload("res://assets/paperglide/doodle0.png"),
	preload("res://assets/paperglide/doodle1.png"),
	preload("res://assets/paperglide/doodle2.png"),
	preload("res://assets/paperglide/doodle3.png"),
	preload("res://assets/paperglide/doodle5.png"),
]
const MathQuestion = preload("res://scripts/flight/math_question.gd")
const LearningQuestion = preload("res://scripts/flight/learning_question.gd")

## "ready" (waiting for the first tap), "playing" or "dead".
var state := "ready"
var score := 0
var selected_plane_id := "paper"
var plane_y := READY_Y
var plane_vy := 0.0
var plane_rot := 0.0
var pipes: Array[Dictionary] = []
var spawned := 0
var difficulty := "easy"
var difficulty_level := 1
var speed_level := 1
var selected_topic_groups: Array[String] = ["addition", "subtraction", "multiplication", "division", "fractions", "number_sense"]
var practice_area := "math"
var current_question: Dictionary = {}
var failure_reason := ""
var failure_answer := ""
var failure_question := ""
var failure_hint_key := ""
var _learning_prompt_history: Dictionary = {}
var _last_learning_category_by_key: Dictionary = {}
var _learning_category_alternates_by_key: Dictionary = {}
var _math_prompt_history: Dictionary = {}
var _math_topic_bag: Array[String] = []
var _math_topic_bag_key := ""
var _last_math_topic := ""

var gravity := 1500.0
var flap_speed := 430.0
var base_speed := 230.0
var base_gap := 180.0
var pipe_spacing := 420.0
var visual_scale := 1.0
var reduced_motion := false

var rng := RandomNumberGenerator.new()
var _vis := RandomNumberGenerator.new()
var _time := 0.0
var _scroll := 0.0
var _speed := 0.0
var _bg_offset := 0.0
var _trail: Array[Dictionary] = []
var _trail_clock := 0.0
var _particles: Array[Dictionary] = []
var _clouds: Array[Dictionary] = []
var _doodles: Array[Dictionary] = []
var _shake := 0.0
var _flash := 0.0
var _boil_clock := 0.0
var _boil := Vector2.ZERO
var _ground_line := PackedVector2Array()
var _ground_line2 := PackedVector2Array()
var _ground_hatch := PackedVector2Array()
var _ground_wash := PackedVector2Array()
var _plane_squash := 0.0


func _ready() -> void:
	_vis.randomize()
	rng.randomize()
	_build_ground()
	_seed_ambient()
	reset_ready()


# ---------------------------------------------------------------- simulation

func _store() -> Node:
	return get_node_or_null("/root/TuningStore")


func _tuned(id: String, fallback: float) -> float:
	var store := _store()
	return float(store.call("get_active_value", id, fallback)) if store != null else fallback


## Reads the tuned values. Gameplay values apply at run boundaries; cosmetics are live.
func load_tuning() -> void:
	gravity = _tuned("gameplay.physics.gravity", 1500.0)
	flap_speed = _tuned("gameplay.physics.flap_speed", 430.0)
	var challenge_intensity := float(difficulty_level - 1) / 4.0
	var pace_intensity := float(speed_level - 1) / 4.0
	base_speed = _tuned("gameplay.course.scroll_speed", 230.0) * lerpf(0.6, 1.2, pace_intensity)
	base_gap = _tuned("gameplay.course.gap_size", 180.0) + lerpf(18.0, -18.0, challenge_intensity)
	pipe_spacing = _tuned("gameplay.course.pipe_spacing", 420.0) + lerpf(220.0, -20.0, pace_intensity)
	refresh_live_tuning()


func refresh_live_tuning() -> void:
	visual_scale = _tuned("player.visual.scale", 1.0)
	var store := _store()
	reduced_motion = bool(store.call("get_active_value", "ui.reduced_motion", false)) if store != null else false


func reset_ready() -> void:
	state = "ready"
	score = 0
	spawned = 0
	current_question.clear()
	failure_reason = ""
	failure_answer = ""
	failure_question = ""
	failure_hint_key = ""
	plane_y = READY_Y
	plane_vy = 0.0
	plane_rot = 0.0
	pipes.clear()
	_trail.clear()
	_particles.clear()
	_shake = 0.0
	_flash = 0.0
	_speed = 0.0
	load_tuning()
	queue_redraw()


func set_difficulty(value: Variant) -> void:
	difficulty_level = MathQuestion.difficulty_level_for(value)
	difficulty = MathQuestion.band_for_level(difficulty_level)
	load_tuning()
	queue_redraw()


func set_selected_topics(groups: Array) -> void:
	selected_topic_groups.clear()
	for group: Variant in groups:
		if str(group) in MathQuestion.TOPIC_GROUPS and str(group) not in selected_topic_groups:
			selected_topic_groups.append(str(group))
	if selected_topic_groups.is_empty():
		selected_topic_groups = MathQuestion.available_topic_groups(difficulty_level)


func set_practice_area(value: String) -> void:
	practice_area = value if value == "math" or value in LearningQuestion.PRACTICE_AREAS else "math"


func set_selected_plane(value: String) -> void:
	selected_plane_id = value if PLANE_TINTS.has(value) else "paper"
	queue_redraw()


func set_speed_level(value: Variant) -> void:
	speed_level = clampi(roundi(float(value)), 1, 5)
	load_tuning()
	queue_redraw()


## Flap input. The first flap of a fresh run starts it.
func flap() -> void:
	if state == "ready":
		_start_run()
	if state != "playing":
		return
	plane_vy = -flap_speed
	_plane_squash = 1.0
	_emit_flap_dashes()
	flapped.emit()


func _start_run() -> void:
	var store := _store()
	if store != null:
		store.call("begin_run")
	load_tuning()
	state = "playing"
	score = 0
	spawned = 0
	pipes.clear()
	current_question.clear()
	_learning_prompt_history.clear()
	_last_learning_category_by_key.clear()
	_learning_category_alternates_by_key.clear()
	_math_prompt_history.clear()
	_math_topic_bag.clear()
	_math_topic_bag_key = ""
	_last_math_topic = ""
	failure_reason = ""
	failure_answer = ""
	failure_question = ""
	failure_hint_key = ""
	_speed = base_speed
	_spawn_gate(PLANE_X + FIRST_PIPE_DISTANCE)


func current_speed() -> float:
	return base_speed


func current_gap(index: int) -> float:
	return maxf(base_gap - float(index) * 1.2, base_gap * 0.84)


func _next_math_topic_group() -> String:
	var eligible: Array[String] = []
	for group: String in MathQuestion.available_topic_groups(difficulty_level):
		if selected_topic_groups.is_empty() or group in selected_topic_groups:
			eligible.append(group)
	if eligible.is_empty():
		eligible = MathQuestion.available_topic_groups(difficulty_level)
	var key_parts := PackedStringArray([str(difficulty_level)])
	for group: String in eligible:
		key_parts.append(group)
	var bag_key := "|".join(key_parts)
	if _math_topic_bag_key != bag_key or _math_topic_bag.is_empty():
		_math_topic_bag = eligible.duplicate()
		for index: int in range(_math_topic_bag.size() - 1, 0, -1):
			var swap_index := rng.randi_range(0, index)
			var held := _math_topic_bag[index]
			_math_topic_bag[index] = _math_topic_bag[swap_index]
			_math_topic_bag[swap_index] = held
		if _math_topic_bag.size() > 1 and _math_topic_bag[0] == _last_math_topic:
			var different_index := rng.randi_range(1, _math_topic_bag.size() - 1)
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
	for _attempt in attempt_limit:
		var attempt_history: Array = history.duplicate()
		var candidate: Dictionary = LearningQuestion.generate_with_history(rng, practice_area, difficulty_level, attempt_history)
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
		return LearningQuestion.generate_with_history(rng, practice_area, difficulty_level, history)
	_learning_prompt_history[history_key] = chosen_history
	_last_learning_category_by_key[history_key] = _learning_rotation_category(chosen_question)
	return chosen_question


func _spawn_gate(x: float) -> void:
	var gap := current_gap(spawned)
	var upper_y := rng.randf_range(235.0, 250.0)
	var lower_y := upper_y + LANE_SEPARATION
	var question: Dictionary
	if practice_area == "math":
		var group := _next_math_topic_group()
		var history_key := "%d:%s" % [difficulty_level, group]
		var used_prompts: Array = _math_prompt_history.get(history_key, [])
		question = MathQuestion.generate_with_history(rng, difficulty_level, [group], used_prompts)
		_math_prompt_history[history_key] = used_prompts
	else:
		question = _next_learning_question()
	pipes.append({
		"x": x,
		"upper_y": upper_y,
		"lower_y": lower_y,
		"gap": gap,
		"expression": question.expression,
		"answer": question.answer,
		"distractor": question.distractor,
		"topic": question.topic,
		"hint_key": question.hint_key,
		"upper_answer": question.upper_answer,
		"lower_answer": question.lower_answer,
		"correct_lane": question.correct_lane,
		"passed": false,
	})
	current_question = question.duplicate()
	question_changed.emit(current_question.duplicate(true))
	spawned += 1


## Advance the simulation by `delta` seconds.
func step(delta: float) -> void:
	delta = clampf(delta, 0.0, MAX_STEP)
	_time += delta
	match state:
		"ready":
			plane_y = READY_Y + sin(_time * 3.2) * 12.0
			plane_rot = sin(_time * 3.2 + 1.0) * 0.07
			_advance_background(delta, base_speed * 0.35)
		"playing":
			_step_playing(delta)
		"dead":
			_step_dead(delta)
	_step_ambient(delta)
	_plane_squash = maxf(0.0, _plane_squash - delta * 6.0)
	_flash = maxf(0.0, _flash - delta * 2.2)
	_shake = maxf(0.0, _shake - delta * 28.0)
	_boil_clock += delta
	if _boil_clock > 0.14:
		_boil_clock = 0.0
		_boil = Vector2.ZERO if reduced_motion else Vector2(_vis.randf_range(-1.1, 1.1), _vis.randf_range(-1.1, 1.1))


func _step_playing(delta: float) -> void:
	_speed = current_speed()
	plane_vy = minf(plane_vy + gravity * delta, MAX_FALL_SPEED)
	plane_y += plane_vy * delta
	if plane_y < 20.0:
		plane_y = 20.0
		plane_vy = maxf(plane_vy, 0.0)
	plane_rot = lerpf(plane_rot, clampf(plane_vy / 620.0, -0.55, 1.0) * 0.8, minf(1.0, delta * 9.0))
	_advance_background(delta, _speed)
	for gate: Dictionary in pipes:
		gate.x -= _speed * delta
	while not pipes.is_empty() and pipes[0].x < -120.0:
		pipes.remove_at(0)
	if pipes.is_empty() or bool(pipes.back().passed):
		_spawn_gate(PLANE_X + pipe_spacing)
	_update_trail(delta)
	if plane_hits_pipe():
		_die(false, "collision")
		return
	if plane_y + 14.0 >= GROUND_Y:
		plane_y = GROUND_Y - 14.0
		_die(true, "ground")
		return
	for gate: Dictionary in pipes:
		if not gate.passed and gate.x < PLANE_X - 24.0:
			gate.passed = true
			var chosen_lane := _lane_for_y(plane_y, gate)
			if chosen_lane != str(gate.correct_lane):
				failure_answer = str(gate.answer)
				failure_question = str(gate.expression)
				failure_hint_key = str(gate.hint_key)
				_die(false, "wrong_answer")
				return
			score += 1
			_emit_score_ticks()
			scored.emit(score)


func _step_dead(delta: float) -> void:
	_speed = lerpf(_speed, 0.0, minf(1.0, delta * 7.0))
	_advance_background(delta, _speed)
	for pipe: Dictionary in pipes:
		pipe.x -= _speed * delta
	if plane_y < GROUND_Y - 14.0:
		plane_vy = minf(plane_vy + gravity * delta, MAX_FALL_SPEED)
		plane_y = minf(plane_y + plane_vy * delta, GROUND_Y - 14.0)
		plane_rot += 5.5 * delta
	else:
		plane_vy = 0.0
		plane_rot = lerpf(plane_rot, 1.25, minf(1.0, delta * 8.0))
	_update_trail(delta)


func _die(hit_ground: bool, reason: String = "collision") -> void:
	if state != "playing":
		return
	state = "dead"
	failure_reason = reason
	plane_vy = 0.0 if hit_ground else -260.0
	_shake = 0.0 if reduced_motion else 9.0
	_flash = 0.25 if reduced_motion else 0.6
	_emit_crash()
	var store := _store()
	if store != null:
		store.call("end_run")
	crashed.emit(score, hit_ground)


func _advance_background(delta: float, speed: float) -> void:
	_scroll += speed * delta
	_bg_offset += speed * delta * 0.2


## Circles approximating the plane silhouette (local x, local y, radius).
func hit_circles() -> Array[Vector3]:
	var local: Array[Vector3] = [
		Vector3(34.0, 1.0, 8.0), Vector3(15.0, 0.0, 11.0),
		Vector3(-8.0, 0.0, 12.0), Vector3(-30.0, -3.0, 9.0),
	]
	var out: Array[Vector3] = []
	var rotation_basis := Transform2D(plane_rot, Vector2.ZERO)
	for c: Vector3 in local:
		var p := rotation_basis * (Vector2(c.x, c.y) * HIT_SCALE) + Vector2(PLANE_X, plane_y)
		out.append(Vector3(p.x, p.y, c.z * HIT_SCALE))
	return out


static func gate_rects(gate_x: float, upper_y: float, lower_y: float, gap: float) -> Array[Rect2]:
	var upper_top := upper_y - gap * 0.5
	var upper_bottom := upper_y + gap * 0.5
	var lower_top := lower_y - gap * 0.5
	var lower_bottom := lower_y + gap * 0.5
	var inset := 3.0
	var left := gate_x - PIPE_CAP_HALF + inset
	var width := (PIPE_CAP_HALF - inset) * 2.0
	return [
		Rect2(left, -3000.0, width, 3000.0 + upper_top),
		Rect2(left, upper_bottom, width, lower_top - upper_bottom),
		Rect2(left, lower_bottom, width, 3000.0),
	]


static func circle_hits_rect(center: Vector2, radius: float, rect: Rect2) -> bool:
	var nearest := Vector2(clampf(center.x, rect.position.x, rect.end.x), clampf(center.y, rect.position.y, rect.end.y))
	return center.distance_squared_to(nearest) < radius * radius


func _lane_for_y(y: float, gate: Dictionary) -> String:
	var clearance: float = maxf(float(gate.gap) * 0.5 - 16.0, 0.0)
	if absf(y - float(gate.upper_y)) <= clearance:
		return "upper"
	if absf(y - float(gate.lower_y)) <= clearance:
		return "lower"
	return ""


func plane_hits_pipe() -> bool:
	var circles := hit_circles()
	for gate: Dictionary in pipes:
		if gate.passed or absf(gate.x - PLANE_X) > PIPE_CAP_HALF + 60.0:
			continue
		for rect: Rect2 in gate_rects(gate.x, gate.upper_y, gate.lower_y, gate.gap):
			for c: Vector3 in circles:
				if circle_hits_rect(Vector2(c.x, c.y), c.z, rect):
					return true
	return false


# ------------------------------------------------------------ ambient / fx

func _seed_ambient() -> void:
	_clouds.clear()
	for i in 7:
		_clouds.append(_make_cloud(120.0 + i * 230.0))
	_doodles.clear()
	for i in 3:
		var doodle := _make_doodle(200.0 + i * 480.0)
		doodle.tex = (i * 2 + _vis.randi_range(0, 1)) % T_DOODLES.size()
		_doodles.append(doodle)


func _make_cloud(x: float) -> Dictionary:
	var index := _vis.randi_range(0, T_CLOUDS.size() - 1)
	return {"x": x, "y": _vis.randf_range(30.0, 400.0), "tex": index,
		"scale": _vis.randf_range(0.34, 0.55), "par": _vis.randf_range(0.12, 0.3),
		"alpha": _vis.randf_range(0.7, 0.92)}


func _make_doodle(x: float) -> Dictionary:
	return {"x": x, "y": _vis.randf_range(70.0, 560.0), "tex": _vis.randi_range(0, T_DOODLES.size() - 1),
		"scale": _vis.randf_range(0.5, 0.7), "par": 0.55, "rot": _vis.randf_range(-0.4, 0.4)}


func _step_ambient(delta: float) -> void:
	var speed := _speed if state != "ready" else base_speed * 0.35
	for cloud: Dictionary in _clouds:
		cloud.x -= speed * cloud.par * delta
		var tex: Texture2D = T_CLOUDS[cloud.tex]
		if cloud.x + tex.get_width() * cloud.scale < -20.0:
			cloud.merge(_make_cloud(VIEW_SIZE.x + _vis.randf_range(20.0, 320.0)), true)
	for doodle: Dictionary in _doodles:
		doodle.x -= speed * doodle.par * delta
		var tex: Texture2D = T_DOODLES[doodle.tex]
		if doodle.x + tex.get_width() * doodle.scale < -20.0:
			var previous_tex: int = doodle.tex
			doodle.merge(_make_doodle(VIEW_SIZE.x + _vis.randf_range(60.0, 700.0)), true)
			if doodle.tex == previous_tex:
				doodle.tex = (previous_tex + 1) % T_DOODLES.size()
	var index := _particles.size() - 1
	while index >= 0:
		var particle: Dictionary = _particles[index]
		particle.life -= delta
		if particle.life <= 0.0:
			_particles.remove_at(index)
		else:
			particle.pos += particle.vel * delta
			particle.vel.y += particle.grav * delta
			particle.rot += particle.spin * delta
		index -= 1


func _update_trail(delta: float) -> void:
	_trail_clock += delta
	if _trail_clock > 0.055 and state == "playing":
		_trail_clock = 0.0
		_trail.append({"pos": Vector2(PLANE_X - 34.0, plane_y), "age": 0.0})
	var index := _trail.size() - 1
	while index >= 0:
		var point: Dictionary = _trail[index]
		point.age += delta
		point.pos.x -= _speed * delta
		if point.age > 1.1:
			_trail.remove_at(index)
		index -= 1


func _add_particle(kind: String, pos: Vector2, vel: Vector2, life: float, size: float, grav: float = 0.0) -> void:
	if _particles.size() > 140:
		return
	_particles.append({"kind": kind, "pos": pos, "vel": vel, "life": life, "max": life, "size": size,
		"grav": grav, "rot": _vis.randf_range(0.0, TAU), "spin": _vis.randf_range(-8.0, 8.0)})


func _emit_flap_dashes() -> void:
	var count := 2 if reduced_motion else 4
	for i in count:
		var origin := Vector2(PLANE_X - 38.0, plane_y + 4.0 + _vis.randf_range(-12.0, 12.0))
		_add_particle("dash", origin, Vector2(-170.0 - _vis.randf_range(0.0, 90.0), _vis.randf_range(30.0, 110.0)), 0.32, _vis.randf_range(10.0, 18.0))


func _emit_score_ticks() -> void:
	if reduced_motion:
		return
	for i in 7:
		var angle := TAU * float(i) / 7.0 + _vis.randf_range(-0.2, 0.2)
		_add_particle("tick", Vector2(PLANE_X + 4.0, plane_y - 8.0), Vector2.from_angle(angle) * _vis.randf_range(110.0, 190.0), 0.45, 11.0)


func _emit_crash() -> void:
	var at := Vector2(PLANE_X + 10.0, plane_y)
	for i in (5 if reduced_motion else 16):
		_add_particle("scrap", at, Vector2.from_angle(_vis.randf_range(0.0, TAU)) * _vis.randf_range(90.0, 330.0) + Vector2(0.0, -80.0),
			_vis.randf_range(0.6, 1.1), _vis.randf_range(5.0, 10.0), 520.0)
	for i in (3 if reduced_motion else 9):
		_add_particle("tick", at, Vector2.from_angle(_vis.randf_range(0.0, TAU)) * _vis.randf_range(120.0, 260.0), 0.5, 14.0)


# ------------------------------------------------------------------ drawing

func _process(delta: float) -> void:
	step(delta)
	position = Vector2(_vis.randf_range(-1.0, 1.0), _vis.randf_range(-1.0, 1.0)) * _shake if _shake > 0.1 else Vector2.ZERO
	queue_redraw()


func _build_ground() -> void:
	var gen := RandomNumberGenerator.new()
	gen.seed = 7
	var step_x := 14.0
	var count := int(GROUND_PERIOD / step_x)
	var jitter_a: Array[float] = []
	var jitter_b: Array[float] = []
	for i in count:
		jitter_a.append(gen.randf_range(-1.6, 1.6))
		jitter_b.append(gen.randf_range(-2.2, 2.2))
	_ground_line.clear()
	_ground_line2.clear()
	_ground_wash.clear()
	for i in count + 1:
		var x := float(i) * step_x
		var wave := sin(TAU * x / GROUND_PERIOD * 5.0) * 2.4 + sin(TAU * x / GROUND_PERIOD * 11.0 + 1.3) * 1.2
		_ground_line.append(Vector2(x, GROUND_Y + wave + jitter_a[i % count]))
		_ground_line2.append(Vector2(x, GROUND_Y + 3.0 + wave * 0.8 + jitter_b[i % count]))
	_ground_wash = _ground_line.duplicate()
	_ground_wash.append(Vector2(GROUND_PERIOD, VIEW_SIZE.y + 10.0))
	_ground_wash.append(Vector2(0.0, VIEW_SIZE.y + 10.0))
	_ground_hatch.clear()
	var x_hatch := 6.0
	while x_hatch < GROUND_PERIOD:
		var row_count := gen.randi_range(1, 3)
		for row in row_count:
			var y := GROUND_Y + 14.0 + float(row) * 16.0 + gen.randf_range(-3.0, 3.0)
			var length := gen.randf_range(10.0, 20.0)
			_ground_hatch.append(Vector2(x_hatch, y))
			_ground_hatch.append(Vector2(x_hatch - length * 0.55, y + length))
		x_hatch += gen.randf_range(16.0, 30.0)


func _draw() -> void:
	_draw_paper()
	_draw_ambient()
	for pipe: Dictionary in pipes:
		if not pipe.passed:
			_draw_pipe_pair(pipe)
	_draw_ground()
	_draw_trail()
	_draw_particles()
	_draw_plane()
	if _flash > 0.0:
		draw_rect(Rect2(-20.0, -20.0, VIEW_SIZE.x + 40.0, VIEW_SIZE.y + 40.0), Color(1.0, 0.99, 0.95, clampf(_flash, 0.0, 1.0)))


func _draw_paper() -> void:
	var offset := -fposmod(_bg_offset, VIEW_SIZE.x)
	draw_texture_rect(T_PAPER, Rect2(offset - 24.0, -24.0, VIEW_SIZE.x + 1.0, VIEW_SIZE.y + 48.0), false)
	draw_texture_rect(T_PAPER, Rect2(offset + VIEW_SIZE.x - 24.0, -24.0, VIEW_SIZE.x + 1.0, VIEW_SIZE.y + 48.0), false)
	draw_texture_rect(T_PAPER, Rect2(offset + VIEW_SIZE.x * 2.0 - 24.0, -24.0, VIEW_SIZE.x + 1.0, VIEW_SIZE.y + 48.0), false)


func _draw_ambient() -> void:
	for cloud: Dictionary in _clouds:
		var tex: Texture2D = T_CLOUDS[cloud.tex]
		var size: Vector2 = tex.get_size() * float(cloud.scale)
		draw_texture_rect(tex, Rect2(Vector2(cloud.x, cloud.y) + _boil * 0.8, size), false, Color(1, 1, 1, cloud.alpha))
	for doodle: Dictionary in _doodles:
		var tex: Texture2D = T_DOODLES[doodle.tex]
		var size: Vector2 = tex.get_size() * float(doodle.scale)
		draw_set_transform(Vector2(doodle.x, doodle.y) + size * 0.5 + _boil, doodle.rot, Vector2.ONE)
		draw_texture_rect(tex, Rect2(-size * 0.5, size), false, Color(1, 1, 1, 0.8))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_pipe_pair(gate: Dictionary) -> void:
	var upper_top: float = gate.upper_y - gate.gap * 0.5
	var upper_bottom: float = gate.upper_y + gate.gap * 0.5
	var lower_top: float = gate.lower_y - gate.gap * 0.5
	var lower_bottom: float = gate.lower_y + gate.gap * 0.5
	var center_arm_length := (lower_top - upper_bottom) * 0.5 + PIPE_CAP_HEIGHT * 0.667 + 8.0
	_draw_pipe_edge(gate.x, upper_top, false, upper_top + 180.0)
	_draw_pipe_edge(gate.x, upper_bottom, true, center_arm_length)
	_draw_pipe_edge(gate.x, lower_top, false, center_arm_length)
	_draw_pipe_edge(gate.x, lower_bottom, true, GROUND_Y - lower_bottom + 100.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var answer_label_x: float = float(gate.x) + 128.0
	_draw_answer_label(answer_label_x, float(gate.upper_y), gate.upper_answer)
	_draw_answer_label(answer_label_x, float(gate.lower_y), gate.lower_answer)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_pipe_edge(x: float, edge_y: float, points_down: bool, length: float) -> void:
	draw_set_transform(Vector2(x, edge_y) + _boil, PI if points_down else 0.0, Vector2.ONE)
	_draw_pipe_arm(length)


## Draws a pencil-textured pipe arm with its open end at local y = 0.
func _draw_pipe_arm(length: float) -> void:
	var cap_size := Vector2(T_PIPE_CAP.get_width(), T_PIPE_CAP.get_height()) * 0.667
	draw_texture_rect(T_PIPE_CAP, Rect2(-cap_size.x * 0.5, -cap_size.y, cap_size.x, cap_size.y), false)
	var tile_height := T_PIPE_BODY.get_height() * 0.667
	var y := -cap_size.y + 5.0
	var remaining := maxf(length - cap_size.y, 0.0)
	while remaining > 0.0:
		var segment := minf(tile_height, remaining)
		draw_texture_rect(T_PIPE_BODY, Rect2(-PIPE_BODY_WIDTH * 0.5, y - segment, PIPE_BODY_WIDTH, segment), false)
		y -= segment - 1.0
		remaining -= segment


static func fit_answer_font_size(answer_text: String, max_width: float) -> int:
	var safe_width := maxf(max_width, 1.0)
	for candidate_size: int in range(28, 11, -1):
		var text_width := ThemeDB.fallback_font.get_string_size(answer_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, candidate_size).x
		if text_width <= safe_width:
			return candidate_size
	return 12


func _draw_answer_label(center_x: float, center_y: float, answer: Variant) -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var plate := Rect2(center_x - 58.0, center_y - 21.0, 116.0, 42.0)
	var shadow := Rect2(plate.position + Vector2(3.0, 3.0), plate.size)
	var answer_text := str(answer)
	var font_size := fit_answer_font_size(answer_text, plate.size.x - 12.0)
	draw_rect(shadow, Color(GRAPHITE, 0.18), true)
	draw_rect(plate, PAPER, true)
	draw_rect(plate, Color(BLUE_PENCIL, 0.95), false, 2.5)
	draw_string(ThemeDB.fallback_font, Vector2(plate.position.x + 6.0, center_y + float(font_size) * 0.35), answer_text, HORIZONTAL_ALIGNMENT_CENTER, plate.size.x - 12.0, font_size, GRAPHITE)

func _draw_ground() -> void:
	var offset := -fposmod(_scroll, GROUND_PERIOD)
	for tile in 2:
		draw_set_transform(Vector2(offset + float(tile) * GROUND_PERIOD, 0.0), 0.0, Vector2.ONE)
		draw_colored_polygon(_ground_wash, Color(0.915, 0.905, 0.875, 1.0))
		draw_multiline(_ground_hatch, Color(0.2, 0.22, 0.28, 0.55), 1.8, true)
		draw_polyline(_ground_line2, Color(0.2, 0.22, 0.28, 0.4), 1.7, true)
		draw_polyline(_ground_line, Color(GRAPHITE, 0.9), 2.8, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_trail() -> void:
	for point: Dictionary in _trail:
		var fade := 1.0 - float(point.age) / 1.1
		draw_circle(point.pos, 2.6 * fade + 0.6, Color(GRAPHITE, 0.55 * fade))


func _draw_particles() -> void:
	for particle: Dictionary in _particles:
		var life_ratio: float = particle.life / particle.max
		var alpha := clampf(life_ratio * 1.5, 0.0, 1.0)
		match particle.kind:
			"dash":
				var direction: Vector2 = (particle.vel as Vector2).normalized()
				draw_line(particle.pos, particle.pos - direction * particle.size, Color(GRAPHITE, 0.6 * alpha), 2.2, true)
			"tick":
				var direction: Vector2 = (particle.vel as Vector2).normalized()
				var color := YELLOW_PENCIL if int(particle.size) % 2 == 1 else BLUE_PENCIL
				draw_line(particle.pos, particle.pos + direction * particle.size, Color(color, alpha), 3.0, true)
			"scrap":
				var s: float = particle.size
				var points := PackedVector2Array([Vector2(-s, -s * 0.6), Vector2(s, -s * 0.2), Vector2(-s * 0.2, s)])
				var transform := Transform2D(particle.rot, particle.pos)
				var moved := PackedVector2Array()
				for p in points:
					moved.append(transform * p)
				draw_colored_polygon(moved, Color(0.99, 0.98, 0.94, alpha))
				moved.append(moved[0])
				draw_polyline(moved, Color(GRAPHITE, 0.8 * alpha), 1.6, true)


func _draw_plane() -> void:
	var size := PLANE_SIZE * visual_scale
	var squash := Vector2(1.0 + _plane_squash * 0.06, 1.0 - _plane_squash * 0.1)
	var at := Vector2(PLANE_X, plane_y)
	var plane_tint: Color = PLANE_TINTS.get(selected_plane_id, Color.WHITE)
	draw_set_transform(at + Vector2(5.0, 9.0), plane_rot, squash)
	draw_texture_rect(T_PLANE, Rect2(-size * 0.5, size), false, Color(0.14, 0.15, 0.22, 0.2))
	draw_set_transform(at, plane_rot, squash)
	draw_texture_rect(T_PLANE, Rect2(-size * 0.5, size), false, plane_tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
