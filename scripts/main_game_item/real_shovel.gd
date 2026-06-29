extends Sprite2D
class_name RealShovel

@export var follow_scale := 0.42
@export var follow_alpha := 0.55
@export var follow_offset := Vector2(18, 18)

var is_using := false

func _ready() -> void:
	centered = true
	offset = Vector2.ZERO
	scale = Vector2.ONE * follow_scale
	self_modulate.a = follow_alpha

func _process(_delta: float) -> void:
	if is_using:
		global_position = get_global_mouse_position() + follow_offset

func change_is_using(value:bool):
	is_using = value
	visible = value
	scale = Vector2.ONE * follow_scale
	self_modulate.a = follow_alpha
