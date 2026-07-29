extends Plant000Base
class_name Plant064SeaShroomWuyang

@onready var attack_component: AttackComponentBulletSeaShroomWuyang = $AttackComponent
@onready var area_2d_mouse: Area2D = $Body/Area2DMouse
@onready var guidance_effect_target: CanvasItem = $Body/BodyCorrect/SeaShroom_head/SeaShroom_Wuyang_Hair

var guidance_active := false
var guidance_ready_tween: Tween


func ready_norm() -> void:
	super()
	area_2d_mouse.visible = true
	if not is_sleeping:
		_start_guidance_ready_effect()


## 初始化正常出战角色信号连接
func ready_norm_signal_connect():
	super()
	signal_update_speed.connect(attack_component.owner_update_speed)
	sleep_component.signal_is_sleep.connect(_on_guidance_owner_sleep)
	sleep_component.signal_not_is_sleep.connect(_on_guidance_owner_wake)


func is_bullet_guidance_active() -> bool:
	return guidance_active


func _toggle_guidance() -> void:
	if is_sleeping:
		return
	guidance_active = not guidance_active
	body.body_light_and_dark_end()
	attack_component.set_guidance_mode(guidance_active)
	if guidance_active:
		_stop_guidance_ready_effect()
	else:
		_start_guidance_ready_effect()


func _on_guidance_owner_sleep() -> void:
	_stop_guidance_ready_effect()
	body.body_light_and_dark_end()


func _on_guidance_owner_wake() -> void:
	if not guidance_active:
		_start_guidance_ready_effect()


func _start_guidance_ready_effect() -> void:
	_stop_guidance_ready_effect()
	guidance_ready_tween = create_tween()
	guidance_ready_tween.set_loops()
	guidance_ready_tween.tween_property(guidance_effect_target, "modulate", Color(0.6, 0.6, 0.6), 0.5)
	guidance_ready_tween.tween_property(guidance_effect_target, "modulate", Color(1.5, 1.5, 1.5), 0.5)


func _stop_guidance_ready_effect() -> void:
	if guidance_ready_tween and guidance_ready_tween.is_running():
		guidance_ready_tween.kill()
	guidance_effect_target.modulate = Color.WHITE


func _on_area_2d_mouse_entered() -> void:
	if not is_sleeping:
		body.body_light_and_dark()


func _on_area_2d_mouse_exited() -> void:
	body.body_light_and_dark_end()


@warning_ignore("unused_parameter")
func _on_area_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_toggle_guidance()
