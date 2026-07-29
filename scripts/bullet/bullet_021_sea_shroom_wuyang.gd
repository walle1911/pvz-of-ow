extends BulletLinear000Base
class_name Bullet021SeaShroomWuyang

## 海蘑菇无恙的鼠标制导孢子。
## 制导状态下仅在鼠标移动时修正方向；鼠标静止时保持当前方向飞行。

var travelled_distance := 0.0
@export var max_lifetime := 8.0
var lifetime := 0.0
var guidance_source: Node

@export_group("鼠标制导")
## 过滤鼠标的细微抖动，位移超过此值才修正子弹方向。
@export var mouse_move_threshold := 0.5

var last_mouse_position := Vector2.ZERO


func _ready() -> void:
	super()
	last_mouse_position = get_global_mouse_position()


func init_bullet(bullet_paras: Dictionary):
	super(bullet_paras)
	## 鼠标可以跨行移动，因此该子弹不使用发射者的行限制。
	is_activate_lane = false
	if _is_guidance_active():
		scale *= 2.0


func set_guidance_source(source: Node) -> void:
	guidance_source = source


func _is_guidance_active() -> bool:
	return (
		is_instance_valid(guidance_source)
		and guidance_source.has_method("is_bullet_guidance_active")
		and bool(guidance_source.call("is_bullet_guidance_active"))
	)


func _physics_process(delta: float) -> void:
	lifetime += delta
	var mouse_position := get_global_mouse_position()
	var is_guidance_active := _is_guidance_active()
	var movement_distance := speed * delta
	if is_guidance_active:
		var mouse_move_distance_squared := mouse_position.distance_squared_to(last_mouse_position)
		if mouse_move_distance_squared >= mouse_move_threshold * mouse_move_threshold:
			last_mouse_position = mouse_position
			var guided_direction := global_position.direction_to(mouse_position)
			if not guided_direction.is_zero_approx():
				direction = guided_direction
				body.rotation = direction.angle()
	else:
		last_mouse_position = mouse_position

	global_position += direction * movement_distance
	travelled_distance += movement_distance

	if travelled_distance >= max_distance or lifetime >= max_lifetime:
		queue_free()
