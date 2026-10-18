extends Node

const FlightWorld = preload("res://scripts/flight/flight_world.gd")

var _failures := PackedStringArray()
var _checks := 0
var _saved_user_files: Dictionary = {}
var _crash_events := 0
var _score_events := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	for path: String in [SaveStore.SAVE_PATH]:
		_saved_user_files[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	SaveStore.set("_data", SaveStore.call("_default_data"))
	_test_autoloads_and_schema()
	_test_geometry()
	await _test_simulation()
	_test_fairness_bot()
	_test_save_store()
	await _test_runtime_scene()
	_restore_user_files()
	if _failures.is_empty():
		print("[game-generic-tests] PASS: %d checks" % _checks)
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error("[game-generic-tests] " + failure)
	get_tree().quit(1)


func _test_autoloads_and_schema() -> void:
	for node_name: String in ["I18n", "TuningStore", "SaveStore", "AudioDirector"]:
		_check(get_tree().root.get_node_or_null(node_name) != null, "%s autoload must exist" % node_name)
	var tuning := get_tree().root.get_node("TuningStore")
	tuning.call("reset_defaults")
	_check(is_equal_approx(float(tuning.call("get_active_value", "gameplay.physics.gravity")), 1500.0), "default gravity")
	_check(is_equal_approx(float(tuning.call("get_active_value", "gameplay.course.gap_size")), 230.0), "default gap size")
	_check(get_tree().root.get_node("I18n").call("t", "over.restart") == "FLY AGAIN", "English strings resolve")
	for setting: Dictionary in tuning.call("get_settings"):
		_check(get_tree().root.get_node("I18n").call("t", str(setting.label_key)) != str(setting.label_key), "label for %s" % setting.id)


func _test_geometry() -> void:
	var rect := Rect2(100.0, 100.0, 50.0, 50.0)
	_check(FlightWorld.circle_hits_rect(Vector2(95.0, 125.0), 8.0, rect), "circle overlapping a rect edge hits")
	_check(not FlightWorld.circle_hits_rect(Vector2(80.0, 125.0), 8.0, rect), "circle clear of a rect misses")
	var rects := FlightWorld.pipe_rects(500.0, 300.0, 220.0)
	_check(rects.size() == 4, "a pipe pair has body and cap rectangles on both sides")
	_check(rects[0].end.y <= 300.0 - 110.0, "top pipe never intrudes into the gap")
	_check(rects[3].position.y >= 300.0 + 110.0, "bottom pipe never intrudes into the gap")


func _make_world() -> Node2D:
	var world: Node2D = FlightWorld.new()
	add_child(world)
	_crash_events = 0
	_score_events = 0
	world.connect("crashed", func(_total: int, _ground: bool) -> void: _crash_events += 1)
	world.connect("scored", func(_total: int) -> void: _score_events += 1)
	return world


func _set_pipes(world: Node2D, items: Array) -> void:
	var pipes: Array = world.get("pipes")
	pipes.clear()
	for item in items:
		pipes.append(item)


func _test_simulation() -> void:
	var world := _make_world()
	_check(world.get("state") == "ready", "world starts waiting for the first tap")
	world.call("flap")
	_check(world.get("state") == "playing", "first flap starts the run")
	_check(is_equal_approx(float(world.get("plane_vy")), -float(world.get("flap_speed"))), "flap sets upward speed")
	var start_y: float = world.get("plane_y")
	for i in 10:
		world.call("step", 1.0 / 60.0)
	_check(float(world.get("plane_y")) < start_y, "a flap carries the plane upward against gravity")
	for i in 400:
		world.call("step", 1.0 / 60.0)
	_check(world.get("state") == "dead", "an untouched plane falls to the ground and crashes")
	_check(_crash_events == 1, "crash is reported exactly once")
	for i in 60:
		world.call("step", 1.0 / 60.0)
	_check(_crash_events == 1, "dead world does not re-report crashes")
	world.queue_free()

	world = _make_world()
	world.call("flap")
	world.set("gravity", 0.0)
	world.set("plane_vy", 0.0)
	var level_y: float = world.get("plane_y")
	_set_pipes(world, [{"x": FlightWorld.PLANE_X + 120.0, "gap_y": level_y, "gap": 230.0, "passed": false}])
	for i in 90:
		world.call("step", 1.0 / 60.0)
	_check(world.get("state") == "playing", "flying straight through a gap is safe")
	_check(int(world.get("score")) == 1 and _score_events == 1, "passing a pipe pair scores exactly once")
	world.queue_free()

	world = _make_world()
	world.call("flap")
	world.set("gravity", 0.0)
	world.set("plane_vy", 0.0)
	level_y = world.get("plane_y")
	_set_pipes(world, [{"x": FlightWorld.PLANE_X + 120.0, "gap_y": level_y + 220.0, "gap": 200.0, "passed": false}])
	for i in 90:
		world.call("step", 1.0 / 60.0)
	_check(world.get("state") == "dead" and _crash_events == 1, "hitting a pipe ends the run")
	_check(int(world.get("score")) == 0, "a pipe hit does not score")
	world.queue_free()

	world = _make_world()
	_check(world.call("current_gap", 0) > world.call("current_gap", 12), "gaps tighten as the run goes on")
	_check(world.call("current_gap", 500) >= float(world.get("base_gap")) * 0.76 - 0.01, "gap shrink has a floor")
	world.queue_free()
	await get_tree().process_frame


## A simple tap-when-below-target bot must be able to clear a long stretch of generated pipes.
func _test_fairness_bot() -> void:
	for seed_value in [1, 2, 3]:
		var world := _make_world()
		world.rng.seed = seed_value
		world.call("flap")
		var steps := 0
		while world.get("state") == "playing" and steps < 60 * 90:
			var target := 330.0
			for pipe: Dictionary in world.get("pipes"):
				if pipe.x > FlightWorld.PLANE_X - 70.0:
					target = pipe.gap_y + 18.0
					break
			if float(world.get("plane_y")) > target and float(world.get("plane_vy")) > -50.0:
				world.call("flap")
			world.call("step", 1.0 / 60.0)
			steps += 1
		_check(int(world.get("score")) >= 15, "generated courses are passable (seed %d scored %d)" % [seed_value, int(world.get("score"))])
		world.queue_free()


func _test_save_store() -> void:
	SaveStore.set("_data", SaveStore.call("_default_data"))
	_check(SaveStore.record_run(7, true), "first scoring run sets a best")
	_check(SaveStore.get_best_score() == 7, "best score persists in memory")
	_check(not SaveStore.record_run(5, true), "a lower score is not a new best")
	_check(not SaveStore.record_run(99, false), "practice runs never set the best")
	_check(SaveStore.get_best_score() == 7, "practice score left the best untouched")
	_check(SaveStore.get_games_played() == 3, "every run is counted")


func _test_runtime_scene() -> void:
	var tuning := get_tree().root.get_node("TuningStore")
	tuning.call("reset_defaults")
	var packed: PackedScene = load("res://scenes/main.tscn")
	_check(packed != null, "main scene must load")
	if packed == null:
		return
	var main: Control = packed.instantiate()
	get_tree().root.add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(bool((main.get("_title_screen") as Control).visible), "title screen shows on boot")
	_check(main.get("_state") == "title", "game boots into the title state")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	main.call("_unhandled_input", click)
	await get_tree().process_frame
	_check(main.get("_state") == "playing", "a tap on the title starts flying")
	_check(not bool((main.get("_title_screen") as Control).visible), "title hides once flying")
	_check((main.get("_world") as Node2D).get("state") == "playing", "world is running after the first tap")
	main.call("_set_paused", true)
	_check(get_tree().paused and main.get("_state") == "paused", "pause freezes the tree")
	main.call("_set_paused", false)
	_check(not get_tree().paused and main.get("_state") == "playing", "resume continues the run")
	var world: Node2D = main.get("_world")
	world.set("plane_y", FlightWorld.GROUND_Y)
	world.call("step", 1.0 / 60.0)
	_check(main.get("_state") == "over", "crash moves the game to the over state")
	main.set("_over_unlock_ms", 0)
	main.call("_unhandled_input", click)
	await get_tree().process_frame
	_check(main.get("_state") == "playing" and int(world.get("score")) == 0, "one tap restarts a fresh run")
	get_tree().paused = false
	main.queue_free()
	await get_tree().process_frame


func _restore_user_files() -> void:
	for path: String in _saved_user_files:
		var content: Variant = _saved_user_files[path]
		if content == null:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		else:
			var file := FileAccess.open(path, FileAccess.WRITE)
			if file != null:
				file.store_buffer(content)
				file.close()


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
