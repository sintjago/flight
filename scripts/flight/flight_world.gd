extends Node2D
## One-tap flight simulation plus its notebook / pencil-sketch presentation.
## Simulation (physics, pipes, scoring, collision) is authoritative; drawing is cosmetic.

signal flapped
signal scored(total: int)
signal crashed(total: int, hit_ground: bool)

const VIEW_SIZE := Vector2(1280.0, 720.0)
const GROUND_Y := 650.0
const PLANE_X := 340.0
const PLANE_SIZE := Vector2(122.0, 56.5)
const HIT_SCALE := 1.15
const READY_Y := 390.0

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

## "ready" (waiting for the first tap), "playing" or "dead".
var state := "ready"
var score := 0
var plane_y := READY_Y
var plane_vy := 0.0
var plane_rot := 0.0
var pipes: Array[Dictionary] = []
var spawned := 0

var gravity := 1500.0
var flap_speed := 430.0
var base_speed := 230.0
var base_gap := 230.0
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
	base_speed = _tuned("gameplay.course.scroll_speed", 230.0)
	base_gap = _tuned("gameplay.course.gap_size", 230.0)
	pipe_spacing = _tuned("gameplay.course.pipe_spacing", 420.0)
	refresh_live_tuning()


func refresh_live_tuning() -> void:
	visual_scale = _tuned("player.visual.scale", 1.0)
	var store := _store()
	reduced_motion = bool(store.call("get_active_value", "ui.reduced_motion", false)) if store != null else false


func reset_ready() -> void:
	state = "ready"
	score = 0
	spawned = 0
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
	_speed = base_speed
	_spawn_pipe(PLANE_X + FIRST_PIPE_DISTANCE)


func current_speed() -> float:
	return base_speed + minf(float(score) * 4.0, base_speed * 0.4)


func current_gap(index: int) -> float:
	return maxf(base_gap - float(index) * 2.5, base_gap * 0.76)


func _spawn_pipe(x: float) -> void:
	var gap := current_gap(spawned)
	var low := PIPE_MARGIN + gap * 0.5
	var high := GROUND_Y - PIPE_MARGIN - gap * 0.5
	var gap_y := 330.0
	if not pipes.is_empty():
		var previous: float = pipes.back().gap_y
		gap_y = clampf(rng.randf_range(low, high), previous - 190.0, previous + 250.0)
	gap_y = clampf(gap_y, low, high)
	pipes.append({"x": x, "gap_y": gap_y, "gap": gap, "passed": false})
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
	for pipe: Dictionary in pipes:
		pipe.x -= _speed * delta
	while pipes.is_empty() or pipes.back().x < VIEW_SIZE.x + 120.0:
		var last_x: float = pipes.back().x if not pipes.is_empty() else VIEW_SIZE.x
		_spawn_pipe(last_x + pipe_spacing)
	while not pipes.is_empty() and pipes[0].x < -120.0:
		pipes.remove_at(0)
	_update_trail(delta)
	for pipe: Dictionary in pipes:
		if not pipe.passed and pipe.x < PLANE_X - 24.0:
			pipe.passed = true
			score += 1
			_emit_score_ticks()
			scored.emit(score)
	if plane_hits_pipe():
		_die(false)
	elif plane_y + 14.0 >= GROUND_Y:
		plane_y = GROUND_Y - 14.0
		_die(true)


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


func _die(hit_ground: bool) -> void:
	if state != "playing":
		return
	state = "dead"
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


static func pipe_rects(pipe_x: float, gap_y: float, gap: float) -> Array[Rect2]:
	var top_edge := gap_y - gap * 0.5
	var bottom_edge := gap_y + gap * 0.5
	var inset := 3.0
	return [
		Rect2(pipe_x - PIPE_BODY_HALF + inset, -3000.0, (PIPE_BODY_HALF - inset) * 2.0, 3000.0 + top_edge - PIPE_CAP_HEIGHT),
		Rect2(pipe_x - PIPE_CAP_HALF + inset, top_edge - PIPE_CAP_HEIGHT + inset, (PIPE_CAP_HALF - inset) * 2.0, PIPE_CAP_HEIGHT - inset),
		Rect2(pipe_x - PIPE_CAP_HALF + inset, bottom_edge, (PIPE_CAP_HALF - inset) * 2.0, PIPE_CAP_HEIGHT - inset),
		Rect2(pipe_x - PIPE_BODY_HALF + inset, bottom_edge + PIPE_CAP_HEIGHT, (PIPE_BODY_HALF - inset) * 2.0, 3000.0),
	]


static func circle_hits_rect(center: Vector2, radius: float, rect: Rect2) -> bool:
	var nearest := Vector2(clampf(center.x, rect.position.x, rect.end.x), clampf(center.y, rect.position.y, rect.end.y))
	return center.distance_squared_to(nearest) < radius * radius


func plane_hits_pipe() -> bool:
	var circles := hit_circles()
	for pipe: Dictionary in pipes:
		if absf(pipe.x - PLANE_X) > PIPE_CAP_HALF + 60.0:
			continue
		for rect: Rect2 in pipe_rects(pipe.x, pipe.gap_y, pipe.gap):
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


func _draw_pipe_pair(pipe: Dictionary) -> void:
	var top_edge: float = pipe.gap_y - pipe.gap * 0.5
	var bottom_edge: float = pipe.gap_y + pipe.gap * 0.5
	draw_set_transform(Vector2(pipe.x, top_edge) + _boil, 0.0, Vector2.ONE)
	_draw_pipe_arm()
	draw_set_transform(Vector2(pipe.x, bottom_edge) + _boil, PI, Vector2.ONE)
	_draw_pipe_arm()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Draws a pipe whose open end (the cap) sits on local y = 0 and whose body extends upward.
func _draw_pipe_arm() -> void:
	var cap_size := Vector2(T_PIPE_CAP.get_width(), T_PIPE_CAP.get_height()) * 0.667
	draw_texture_rect(T_PIPE_CAP, Rect2(-cap_size.x * 0.5, -cap_size.y, cap_size.x, cap_size.y), false)
	var tile_height := T_PIPE_BODY.get_height() * 0.667
	var y := -cap_size.y + 5.0
	for i in 4:
		draw_texture_rect(T_PIPE_BODY, Rect2(-PIPE_BODY_WIDTH * 0.5, y - tile_height, PIPE_BODY_WIDTH, tile_height), false)
		y -= tile_height - 1.0


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
	draw_set_transform(at + Vector2(5.0, 9.0), plane_rot, squash)
	draw_texture_rect(T_PLANE, Rect2(-size * 0.5, size), false, Color(0.14, 0.15, 0.22, 0.2))
	draw_set_transform(at, plane_rot, squash)
	draw_texture_rect(T_PLANE, Rect2(-size * 0.5, size), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
