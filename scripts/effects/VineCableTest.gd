extends Node2D
class_name VineCableTest

@export var end_center_position: Vector2 = Vector2(520.0, 300.0)
@export var end_move_range: float = 190.0
@export var end_vertical_range: float = 34.0
@export var end_move_speed: float = 1.4

@onready var start_point: Marker2D = $StartPoint
@onready var end_point: Marker2D = $EndPoint
@onready var vine: Node2D = $VineCable2D

var _elapsed_time: float = 0.0


func _ready() -> void:
	vine.call("set_points", start_point.global_position, end_point.global_position)


func _process(delta: float) -> void:
	_elapsed_time += delta

	end_point.position = end_center_position + Vector2(
		sin(_elapsed_time * end_move_speed) * end_move_range,
		sin(_elapsed_time * end_move_speed * 0.7) * end_vertical_range
	)

	vine.call("set_points", start_point.global_position, end_point.global_position)
	queue_redraw()


func _draw() -> void:
	draw_line(start_point.position, end_point.position, Color(1.0, 1.0, 1.0, 0.18), 1.0, true)
	draw_circle(start_point.position, 8.0, Color(0.35, 1.0, 0.42, 0.9))
	draw_circle(end_point.position, 8.0, Color(1.0, 0.45, 0.25, 0.9))
