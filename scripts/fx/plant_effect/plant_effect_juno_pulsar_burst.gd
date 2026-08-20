extends Node2D

var _elapsed:= 0.0
var _lifetime:= 0.32
var _is_launch:= false


func _ready() -> void:
	z_as_relative = false
	z_index = 4002
	queue_redraw()


func setup(is_launch:bool) -> void:
	_is_launch = is_launch
	_lifetime = 0.40 if is_launch else 0.28
	queue_redraw()


func _process(delta:float) -> void:
	_elapsed += delta
	if _elapsed >= _lifetime:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var progress:= clampf(_elapsed / maxf(_lifetime, 0.001), 0.0, 1.0)
	var alpha:= 1.0 - progress
	var radius:= lerpf(4.0, 25.0 if _is_launch else 18.0, ease(progress, 0.55))
	draw_circle(Vector2.ZERO, radius * 0.70, Color(0.66, 0.45, 1.0, 0.12 * alpha))
	draw_circle(Vector2.ZERO, maxf(0.0, 8.0 * (1.0 - progress)), Color(0.92, 0.95, 1.0, 0.82 * alpha))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(0.70, 0.48, 1.0, 0.72 * alpha), 2.0, true)
	draw_arc(Vector2.ZERO, radius * 0.62, 0.0, TAU, 36, Color(0.66, 0.86, 1.0, 0.78 * alpha), 1.2, true)
	if _is_launch:
		for ray_index in 8:
			var direction:= Vector2.RIGHT.rotated(float(ray_index) * TAU / 8.0)
			draw_line(direction * radius * 0.55, direction * radius * 1.25, Color(0.88, 0.91, 1.0, 0.64 * alpha), 1.4, true)
