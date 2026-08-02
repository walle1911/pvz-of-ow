extends BulletLinear000Base
class_name Bullet021SeaShroomWuyang

## 海蘑菇无恙的孢子。普通射击保持直线；点击发射的特殊弹会有限转向地接受鼠标引导。

signal signal_mouse_guidance_finished

var travelled_distance := 0.0
@export var max_lifetime := 8.0
var lifetime := 0.0
var is_mouse_guided := false
var is_mouse_control_active := false
var guidance_start_damage := 20
var guidance_max_damage := 100
var guidance_growth_distance := 800.0
var guidance_growth_travelled_distance := 0.0
var guidance_max_scale_multiplier := 2.5
var guidance_turn_speed := deg_to_rad(240.0)
var guidance_start_opacity := 0.35
var guidance_mouse_anchor := Vector2.ZERO
var guidance_mouse_deadzone := 24.0
var guidance_turn_ramp_time := 0.6
var guidance_initial_turn_multiplier := 0.2
var external_damage_multiplier := 1.0
var initial_scale := Vector2.ONE

@export_group("制导弹离屏回收")
## 子弹中心越过画面边缘这段距离后，开始计算离屏宽限时间。
@export_range(0.0, 500.0, 1.0, "or_greater", "suffix:像素") var offscreen_margin := 32.0
## 制导弹离开扩展画面范围后继续保留的时间。
@export_range(0.0, 5.0, 0.05, "or_greater", "suffix:秒") var offscreen_grace_time := 0.2
var has_entered_screen := false
var offscreen_elapsed := 0.0


func _ready() -> void:
	super()
	initial_scale = scale
	_update_guidance_growth()
	_update_offscreen_cleanup(0.0)


func init_bullet(bullet_paras: Dictionary):
	super(bullet_paras)
	if is_mouse_guided:
		## 鼠标可把子弹引向其他行，因此制导弹不使用发射者的行限制。
		is_activate_lane = false
		attack_value = guidance_start_damage


func configure_guidance(
		start_damage: int,
		max_damage: int,
		growth_distance: float,
		max_scale_multiplier: float,
		turn_speed: float,
		start_opacity: float,
		mouse_anchor: Vector2,
		mouse_deadzone: float,
		turn_ramp_time: float,
		initial_turn_multiplier: float,
		owner_damage_multiplier: float
) -> void:
	is_mouse_guided = true
	is_mouse_control_active = true
	var base_max_damage := clampi(max_damage, 1, 100)
	var base_start_damage := clampi(start_damage, 1, base_max_damage)
	var safe_owner_multiplier := maxf(owner_damage_multiplier, 0.0)
	guidance_start_damage = maxi(1, int(round(float(base_start_damage) * safe_owner_multiplier)))
	guidance_max_damage = maxi(
		guidance_start_damage,
		int(round(float(base_max_damage) * safe_owner_multiplier))
	)
	guidance_growth_distance = maxf(growth_distance, 1.0)
	guidance_max_scale_multiplier = maxf(max_scale_multiplier, 1.0)
	guidance_turn_speed = maxf(turn_speed, 0.0)
	guidance_start_opacity = clampf(start_opacity, 0.0, 1.0)
	guidance_mouse_anchor = mouse_anchor
	guidance_mouse_deadzone = maxf(mouse_deadzone, 0.0)
	guidance_turn_ramp_time = maxf(turn_ramp_time, 0.01)
	guidance_initial_turn_multiplier = clampf(initial_turn_multiplier, 0.0, 1.0)


func _physics_process(delta: float) -> void:
	lifetime += delta
	var movement_distance := speed * delta
	if is_mouse_control_active and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_finish_mouse_guidance()
	if is_mouse_control_active:
		var mouse_offset := get_global_mouse_position() - guidance_mouse_anchor
		if mouse_offset.length_squared() >= guidance_mouse_deadzone * guidance_mouse_deadzone:
			var desired_direction := mouse_offset.normalized()
			var ramp_progress := clampf(lifetime / guidance_turn_ramp_time, 0.0, 1.0)
			var current_turn_speed := guidance_turn_speed * lerpf(
				guidance_initial_turn_multiplier,
				1.0,
				ramp_progress
			)
			var turn_amount := clampf(
				direction.angle_to(desired_direction),
				-current_turn_speed * delta,
				current_turn_speed * delta
			)
			direction = direction.rotated(turn_amount).normalized()
			body.rotation = direction.angle()

	global_position += direction * movement_distance
	travelled_distance += movement_distance
	if is_mouse_control_active:
		guidance_growth_travelled_distance += movement_distance
	if is_mouse_guided:
		_update_guidance_growth()
		_update_offscreen_cleanup(delta)
		if is_queued_for_deletion():
			return

	if travelled_distance >= max_distance or lifetime >= max_lifetime:
		queue_free()


## 松开左键后只结束鼠标控制，子弹继续沿松开瞬间的方向飞行和成长。
func _finish_mouse_guidance() -> void:
	if not is_mouse_control_active:
		return
	is_mouse_control_active = false
	signal_mouse_guidance_finished.emit()


func _update_guidance_growth() -> void:
	if not is_mouse_guided:
		return
	var growth_progress := clampf(
		guidance_growth_travelled_distance / guidance_growth_distance,
		0.0,
		1.0
	)
	scale = initial_scale * lerpf(1.0, guidance_max_scale_multiplier, growth_progress)
	modulate.a = lerpf(guidance_start_opacity, 1.0, growth_progress)
	attack_value = maxi(1, int(round(lerpf(
		float(guidance_start_damage),
		float(guidance_max_damage),
		growth_progress
	) * external_damage_multiplier)))


## 巴蒂斯特等途中强化使用该入口，确保后续成长刷新不会覆盖增伤。
func apply_external_damage_multiplier(multiplier: float) -> void:
	external_damage_multiplier *= maxf(multiplier, 0.0)
	_update_guidance_growth()


## 只回收制导弹：正常直线弹仍沿用原本的距离销毁规则。
func _update_offscreen_cleanup(delta: float) -> void:
	if not is_mouse_guided or not is_inside_tree():
		return
	var screen_position := get_viewport().get_canvas_transform() * global_position
	var cleanup_rect := get_viewport().get_visible_rect().grow(offscreen_margin)
	if cleanup_rect.has_point(screen_position):
		has_entered_screen = true
		offscreen_elapsed = 0.0
	elif has_entered_screen:
		offscreen_elapsed += delta
		if offscreen_elapsed >= offscreen_grace_time:
			queue_free()
