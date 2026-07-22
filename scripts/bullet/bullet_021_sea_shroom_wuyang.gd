extends BulletLinear000Base
class_name Bullet021SeaShroomWuyang

## 海蘑菇无恙的鼠标制导孢子。
## 按住鼠标左键并移动鼠标时逐步修正方向，其余时间依靠惯性直线飞行。

var travelled_distance := 0.0
@export var max_lifetime := 8.0
var lifetime := 0.0
@export var mouse_move_threshold := 0.5
## 鼠标制导时每秒允许转动的最大角度。
@export var max_turn_speed_degrees := 120.0
var last_mouse_position := Vector2.ZERO


func _ready() -> void:
	super()
	last_mouse_position = get_global_mouse_position()


func init_bullet(bullet_paras: Dictionary):
	super(bullet_paras)
	## 鼠标可以跨行移动，因此该子弹不使用发射者的行限制。
	is_activate_lane = false


func _physics_process(delta: float) -> void:
	lifetime += delta
	var mouse_position := get_global_mouse_position()
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var mouse_move_distance_squared := mouse_position.distance_squared_to(last_mouse_position)
		if mouse_move_distance_squared >= mouse_move_threshold * mouse_move_threshold:
			var guided_direction := global_position.direction_to(mouse_position)
			if not guided_direction.is_zero_approx():
				var max_turn_radians := deg_to_rad(max_turn_speed_degrees) * delta
				var turn_angle := clampf(direction.angle_to(guided_direction), -max_turn_radians, max_turn_radians)
				direction = direction.rotated(turn_angle).normalized()
				body.rotation = direction.angle()
			last_mouse_position = mouse_position
	else:
		## 未按下时只记录鼠标位置，避免刚按下就把历史位移当成制导输入。
		last_mouse_position = mouse_position

	var movement_distance := speed * delta
	global_position += direction * movement_distance
	travelled_distance += movement_distance

	if travelled_distance >= max_distance or lifetime >= max_lifetime:
		queue_free()
