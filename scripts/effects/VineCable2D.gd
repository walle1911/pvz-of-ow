extends Node2D
class_name VineCable2D

@export var rest_length: float = 160.0
@export var tight_length: float = 420.0
@export var point_count: int = 36
@export var loose_amplitude: float = 22.0
@export var tight_amplitude: float = 0.8
@export var loose_turns: float = 3.2
@export var tight_turns: float = 0.15
@export var base_width: float = 5.0
@export var twist_speed: float = 3.0
@export var follow_speed: float = 10.0
@export_range(0.0, 1.0, 0.01) var alpha_multiplier: float = 1.0:
	set(value):
		alpha_multiplier = clamp(value, 0.0, 1.0)
		queue_redraw()
@export var end_bulge_strength: float = 0.0
@export var end_bulge_position: float = 0.82
@export var end_bulge_width: float = 0.18
@export var middle_bulge_ratio: float = 0.4
@export var start_bulge_ratio: float = 0.03
@export var tight_bulge_ratio: float = 0.0
@export var tight_strand_separation: float = 0.0
@export var strand_colors: Array[Color] = [
	Color(1.0, 0.72, 0.84, 0.42),
	Color(1.0, 0.72, 0.84, 0.42),
	Color(1.0, 0.72, 0.84, 0.42),
]

var visual_tension: float = 0.0

var _target_start: Vector2 = Vector2.ZERO
var _target_end: Vector2 = Vector2(160.0, 0.0)
var _visual_start: Vector2 = Vector2.ZERO
var _visual_end: Vector2 = Vector2(160.0, 0.0)
var _target_tension: float = 0.0
var _twist_phase: float = 0.0
var _has_points := false
var _is_tension_overridden := false
var _override_tension: float = 0.0


func set_points(start_pos: Vector2, end_pos: Vector2) -> void:
	_target_start = to_local(start_pos)
	_target_end = to_local(end_pos)
	if _is_tension_overridden:
		_target_tension = _override_tension
	else:
		_target_tension = _calculate_tension(_target_start.distance_to(_target_end))

	if not _has_points:
		_visual_start = _target_start
		_visual_end = _target_end
		visual_tension = _target_tension
		_has_points = true

	queue_redraw()


func snap_points(start_pos: Vector2, end_pos: Vector2) -> void:
	_target_start = to_local(start_pos)
	_target_end = to_local(end_pos)
	_visual_start = _target_start
	_visual_end = _target_end
	_has_points = true
	if _is_tension_overridden:
		_target_tension = _override_tension
	else:
		_target_tension = _calculate_tension(_target_start.distance_to(_target_end))
	visual_tension = _target_tension
	queue_redraw()


func set_tension_override(tension: float, snap_visual: bool = false) -> void:
	_is_tension_overridden = true
	_override_tension = clamp(tension, 0.0, 1.0)
	_target_tension = _override_tension
	if snap_visual:
		visual_tension = _override_tension
	queue_redraw()


func clear_tension_override() -> void:
	_is_tension_overridden = false
	_target_tension = _calculate_tension(_target_start.distance_to(_target_end))
	queue_redraw()


func _process(delta: float) -> void:
	var follow_alpha := _get_follow_alpha(delta)
	_visual_start = _visual_start.lerp(_target_start, follow_alpha)
	_visual_end = _visual_end.lerp(_target_end, follow_alpha)
	visual_tension = lerp(visual_tension, _target_tension, follow_alpha)
	_twist_phase = wrapf(_twist_phase + twist_speed * delta, 0.0, TAU)
	queue_redraw()


func _draw() -> void:
	var cable_vector := _visual_end - _visual_start
	var cable_length := cable_vector.length()
	if cable_length <= 0.001:
		return

	var direction := cable_vector / cable_length
	var normal := Vector2(-direction.y, direction.x)
	var amplitude: float = lerp(loose_amplitude, tight_amplitude, visual_tension)
	var turns: float = lerp(loose_turns, tight_turns, visual_tension)
	var sample_count: int = max(point_count, 2)
	var segment_draws: Array[Dictionary] = []

	for strand_index in range(3):
		var phase := TAU * float(strand_index) / 3.0
		var color := _get_strand_color(strand_index)
		var strand_points: Array[Vector2] = []
		var strand_depths: Array[float] = []
		strand_points.resize(sample_count)
		strand_depths.resize(sample_count)

		for point_index in range(sample_count):
			var u := float(point_index) / float(sample_count - 1)
			var angle: float = TAU * turns * u + phase + _twist_phase
			var endpoint_falloff: float = sin(PI * u)
			var bulge_tension_scale: float = lerp(1.0, tight_bulge_ratio, visual_tension)
			var end_bulge: float = _get_end_bulge(u) * bulge_tension_scale
			var center_point := _visual_start.lerp(_visual_end, u)
			var loose_offset: float = sin(angle) * amplitude * endpoint_falloff * (1.0 + end_bulge)
			var tight_offset: float = _get_tight_strand_offset(strand_index, endpoint_falloff)
			var offset: Vector2 = normal * (loose_offset + tight_offset)

			strand_points[point_index] = center_point + offset
			strand_depths[point_index] = cos(angle)

		for point_index in range(sample_count - 1):
			var depth := (strand_depths[point_index] + strand_depths[point_index + 1]) * 0.5
			segment_draws.append({
				"from": strand_points[point_index],
				"to": strand_points[point_index + 1],
				"color": _shade_color(color, depth),
				"width": _shade_width(depth),
				"depth": depth,
			})

	segment_draws.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["depth"] < b["depth"]
	)

	for segment in segment_draws:
		_draw_rounded_segment(segment["from"], segment["to"], segment["color"], segment["width"])


func _calculate_tension(distance: float) -> float:
	var length_range: float = max(tight_length - rest_length, 0.001)
	return clamp((distance - rest_length) / length_range, 0.0, 1.0)


func _get_follow_alpha(delta: float) -> float:
	if follow_speed <= 0.0:
		return 1.0

	return clamp(1.0 - exp(-follow_speed * delta), 0.0, 1.0)


func _get_strand_color(strand_index: int) -> Color:
	if strand_colors.is_empty():
		return Color.WHITE

	return strand_colors[strand_index % strand_colors.size()]


func _get_end_bulge(u: float) -> float:
	if end_bulge_strength <= 0.0:
		return 0.0

	var middle_u := 0.5
	var front_start: float = max(clamp(end_bulge_position - end_bulge_width, 0.0, 1.0), middle_u + 0.001)

	if u < middle_u:
		var middle_blend: float = smoothstep(0.0, middle_u, u)
		return end_bulge_strength * lerp(start_bulge_ratio, middle_bulge_ratio, middle_blend)

	if u < front_start:
		var front_blend: float = smoothstep(middle_u, front_start, u)
		return end_bulge_strength * lerp(middle_bulge_ratio, 1.0, front_blend)

	return end_bulge_strength


func _get_tight_strand_offset(strand_index: int, endpoint_falloff: float) -> float:
	if tight_strand_separation <= 0.0:
		return 0.0

	var strand_lane := float(strand_index) - 1.0
	return strand_lane * tight_strand_separation * visual_tension * endpoint_falloff


func _draw_rounded_segment(from_point: Vector2, to_point: Vector2, color: Color, width: float) -> void:
	draw_line(from_point, to_point, color, width, true)
	var radius: float = width * 0.5
	if radius > 0.25:
		draw_circle(from_point, radius, color)
		draw_circle(to_point, radius, color)


func _shade_color(base_color: Color, depth: float) -> Color:
	var front_amount: float = clamp((depth + 1.0) * 0.5, 0.0, 1.0)
	var brightness: float = lerp(0.82, 1.06, front_amount)
	var alpha: float = clamp(base_color.a * alpha_multiplier * lerp(0.62, 1.0, front_amount), 0.0, 1.0)
	return Color(
		clamp(base_color.r * brightness, 0.0, 1.0),
		clamp(base_color.g * brightness, 0.0, 1.0),
		clamp(base_color.b * brightness, 0.0, 1.0),
		alpha
	)


func _shade_width(depth: float) -> float:
	var front_amount: float = clamp((depth + 1.0) * 0.5, 0.0, 1.0)
	return max(base_width * lerp(0.88, 1.08, front_amount), 0.5)
