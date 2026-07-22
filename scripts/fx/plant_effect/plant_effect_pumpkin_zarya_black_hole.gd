extends Node2D
class_name PumpkinZaryaBlackHoleEffect

const PORTAL_SFX := preload("res://assets/audio/sounds/portal.ogg")
const CYAN := Color(0.20, 0.72, 1.0, 1.0)
const BLUE := Color(0.20, 0.34, 1.0, 1.0)
const VIOLET := Color(0.67, 0.28, 1.0, 1.0)
const CORE := Color(0.015, 0.006, 0.035, 1.0)

var _start_position := Vector2.ZERO
var _target_position := Vector2.ZERO
var _current_position := Vector2.ZERO
var _travel_duration := 0.55
var _pull_duration := 0.45
var _hold_duration := 3.0
var _elapsed := 0.0
var _arrival_started := false
var _trail_positions:PackedVector2Array = []
var _trail_sample_elapsed := 0.0


func _ready() -> void:
	top_level = true
	z_as_relative = false
	z_index = 120
	global_position = Vector2.ZERO
	set_process(false)


func play(
	start_position:Vector2,
	target_position:Vector2,
	travel_duration:float,
	pull_duration:float,
	hold_duration:float
) -> void:
	_start_position = start_position
	_target_position = target_position
	_current_position = start_position
	_travel_duration = maxf(0.01, travel_duration)
	_pull_duration = maxf(0.01, pull_duration)
	_hold_duration = maxf(0.01, hold_duration)
	_elapsed = 0.0
	_arrival_started = false
	_trail_positions = PackedVector2Array([start_position])
	SoundManager.play_sfx_with_pool(PORTAL_SFX, -4.0)
	set_process(true)
	queue_redraw()


func _process(delta:float) -> void:
	_elapsed += delta
	if _elapsed < _travel_duration:
		_update_projectile(delta)
	elif not _arrival_started:
		_arrival_started = true
		_current_position = _target_position
	if _elapsed >= _travel_duration + _pull_duration + _hold_duration:
		queue_free()
		return
	queue_redraw()


func _update_projectile(delta:float) -> void:
	var progress:float = clampf(_elapsed / _travel_duration, 0.0, 1.0)
	var eased_progress:float = smoothstep(0.0, 1.0, progress)
	var straight_position:Vector2 = _start_position.lerp(_target_position, eased_progress)
	var arc_height:float = -22.0 * sin(progress * PI)
	_current_position = straight_position + Vector2(0.0, arc_height)
	_trail_sample_elapsed += delta
	if _trail_sample_elapsed >= 0.025:
		_trail_sample_elapsed = 0.0
		_trail_positions.append(_current_position)
		if _trail_positions.size() > 24:
			_trail_positions.remove_at(0)


func _draw() -> void:
	if _elapsed < _travel_duration:
		_draw_projectile()
	else:
		_draw_active_vortex()


func _draw_projectile() -> void:
	var trail_size:int = _trail_positions.size()
	for index:int in range(1, trail_size):
		var strength:float = float(index) / float(maxi(1, trail_size - 1))
		var wave:float = sin(_elapsed * 18.0 + float(index) * 0.9)
		var color:= Color(0.30 + strength * 0.20, 0.34, 1.0, 0.08 + strength * 0.46)
		draw_line(
			_trail_positions[index - 1] + Vector2(0.0, wave * 3.0),
			_trail_positions[index],
			color,
			1.0 + strength * 4.0,
			true
		)
		if index % 3 == 0:
			draw_arc(
				_trail_positions[index],
				5.0 + strength * 9.0,
				_elapsed * 5.0 + float(index),
				_elapsed * 5.0 + float(index) + PI * 1.35,
				12,
				Color(0.30, 0.68, 1.0, 0.08 + strength * 0.30),
				1.2,
				true
			)

	var pulse:float = 1.0 + sin(_elapsed * 20.0) * 0.08
	_draw_black_hole(_current_position, 9.0 * pulse, 1.0)
	for spark_index:int in range(7):
		var angle:float = float(spark_index) * TAU / 7.0 + _elapsed * 4.0
		var spark_position:= _current_position + Vector2(cos(angle), sin(angle)) * 15.0
		draw_circle(spark_position, 1.2, Color(0.60, 0.82, 1.0, 0.75), true, -1.0, true)


func _draw_active_vortex() -> void:
	var active_elapsed:float = _elapsed - _travel_duration
	var appear:float = smoothstep(0.0, 0.28, active_elapsed)
	var stable_elapsed:float = maxf(0.0, active_elapsed - _pull_duration)
	var hold_remaining:float = _hold_duration - stable_elapsed
	var fade:float = smoothstep(0.0, 0.38, hold_remaining)
	var strength:float = appear * fade
	var end_shrink:float = clampf(hold_remaining / 0.38, 0.18, 1.0)
	var vortex_radius:float = 108.0 * appear
	var rotation_phase:float = active_elapsed * 2.2

	if active_elapsed < 0.38:
		var burst_progress:float = active_elapsed / 0.38
		var burst_radius:float = lerpf(12.0, 92.0, burst_progress)
		draw_arc(
			_target_position,
			burst_radius,
			0.0,
			TAU,
			64,
			Color(0.35, 0.65, 1.0, (1.0 - burst_progress) * 0.72),
			3.0,
			true
		)
		for ray_index:int in range(12):
			var ray_angle:float = float(ray_index) * TAU / 12.0
			var ray_direction:= Vector2(cos(ray_angle), sin(ray_angle) * 0.55)
			draw_line(
				_target_position + ray_direction * (14.0 + burst_progress * 10.0),
				_target_position + ray_direction * (30.0 + burst_progress * 70.0),
				Color(0.58, 0.80, 1.0, (1.0 - burst_progress) * 0.62),
				1.5,
				true
			)

	_draw_vortex_dome(vortex_radius, rotation_phase, strength)
	_draw_vortex_arms(vortex_radius, rotation_phase, strength)
	_draw_vortex_particles(vortex_radius, rotation_phase, strength)
	_draw_black_hole(_target_position, 13.0 * appear * end_shrink, strength)


func _draw_vortex_dome(radius:float, phase:float, strength:float) -> void:
	if radius <= 0.1:
		return
	var dome_fill:= PackedVector2Array([_target_position - Vector2(radius, 0.0)])
	for fill_index:int in range(49):
		var fill_ratio:float = float(fill_index) / 48.0
		var fill_angle:float = PI + fill_ratio * PI
		dome_fill.append(_target_position + Vector2(
			cos(fill_angle) * radius,
			sin(fill_angle) * radius * 0.72
		))
	dome_fill.append(_target_position + Vector2(radius, 0.0))
	draw_colored_polygon(dome_fill, Color(0.12, 0.32, 0.90, 0.055 * strength))
	var ground_ellipse:= _ellipse_points(_target_position, Vector2(radius, radius * 0.34), 0.0, TAU, 64)
	draw_polyline(ground_ellipse, Color(0.20, 0.45, 1.0, 0.26 * strength), 2.5, true)
	for dome_index:int in range(3):
		var dome_radius:float = radius * (1.0 - float(dome_index) * 0.16)
		var dome_points:= PackedVector2Array()
		for point_index:int in range(41):
			var ratio:float = float(point_index) / 40.0
			var angle:float = PI + ratio * PI
			var point:= _target_position + Vector2(
				cos(angle) * dome_radius,
				sin(angle) * radius * (0.72 - float(dome_index) * 0.09)
			)
			point += Vector2(0.0, sin(ratio * TAU * 2.0 + phase + dome_index) * 3.0)
			dome_points.append(point)
		var dome_color:= CYAN.lerp(VIOLET, float(dome_index) / 2.0)
		dome_color.a = (0.20 + float(dome_index) * 0.07) * strength
		draw_polyline(dome_points, dome_color, 2.0 + float(dome_index), true)

	for ribbon_index:int in range(6):
		var ribbon_points:= PackedVector2Array()
		var base_x:float = lerpf(-radius * 0.72, radius * 0.72, float(ribbon_index) / 5.0)
		for point_index:int in range(13):
			var ratio:float = float(point_index) / 12.0
			ribbon_points.append(_target_position + Vector2(
				base_x + sin(phase * 1.6 + ratio * 8.0 + ribbon_index) * 7.0,
				-ratio * radius * 0.68
			))
		var ribbon_color:= BLUE.lerp(CYAN, float(ribbon_index % 2))
		ribbon_color.a = 0.22 * strength
		draw_polyline(ribbon_points, ribbon_color, 2.2, true)


func _draw_vortex_arms(radius:float, phase:float, strength:float) -> void:
	for arm_index:int in range(5):
		var previous_point:= _target_position
		for point_index:int in range(1, 22):
			var ratio:float = float(point_index) / 21.0
			var arm_radius:float = radius * ratio
			var angle:float = phase + float(arm_index) * TAU / 5.0 + ratio * 4.7
			var point:= _target_position + Vector2(
				cos(angle) * arm_radius,
				sin(angle) * arm_radius * 0.42
			)
			var arm_color:= CYAN.lerp(VIOLET, ratio)
			arm_color.a = (0.12 + (1.0 - ratio) * 0.34) * strength
			draw_line(previous_point, point, arm_color, 3.2 - ratio * 1.7, true)
			previous_point = point


func _draw_vortex_particles(radius:float, phase:float, strength:float) -> void:
	for particle_index:int in range(28):
		var ratio:float = float((particle_index * 7) % 29) / 28.0
		var angle:float = float(particle_index) * 2.399963 + phase * (0.65 + float(particle_index % 4) * 0.12)
		var particle_radius:float = radius * (0.18 + ratio * 0.82)
		var particle_position:= _target_position + Vector2(
			cos(angle) * particle_radius,
			sin(angle) * particle_radius * 0.52 - sin(phase + particle_index) * 5.0
		)
		var particle_alpha:float = (0.35 + sin(_elapsed * 7.0 + particle_index) * 0.18) * strength
		draw_circle(
			particle_position,
			1.0 + float(particle_index % 3) * 0.45,
			Color(0.62, 0.84, 1.0, particle_alpha),
			true,
			-1.0,
			true
		)


func _draw_black_hole(center:Vector2, radius:float, strength:float) -> void:
	if radius <= 0.1:
		return
	draw_circle(center, radius * 1.55, Color(0.22, 0.12, 0.55, 0.30 * strength), true, -1.0, true)
	draw_circle(center, radius * 1.26, Color(0.16, 0.56, 1.0, 0.88 * strength), true, -1.0, true)
	draw_circle(center, radius, Color(CORE.r, CORE.g, CORE.b, strength), true, -1.0, true)
	draw_arc(center, radius * 1.18, 0.0, TAU, 40, Color(0.45, 0.78, 1.0, strength), 1.8, true)
	for spike_index:int in range(9):
		var angle:float = float(spike_index) * TAU / 9.0 + _elapsed * 1.7
		var direction:= Vector2(cos(angle), sin(angle))
		draw_line(
			center + direction * radius * 1.18,
			center + direction * radius * (1.45 + 0.18 * sin(_elapsed * 8.0 + spike_index)),
			Color(0.42, 0.72, 1.0, 0.72 * strength),
			1.2,
			true
		)


func _ellipse_points(
	center:Vector2,
	radii:Vector2,
	start_angle:float,
	end_angle:float,
	point_count:int
) -> PackedVector2Array:
	var points:= PackedVector2Array()
	for point_index:int in range(point_count + 1):
		var ratio:float = float(point_index) / float(point_count)
		var angle:float = lerpf(start_angle, end_angle, ratio)
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	return points
