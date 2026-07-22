extends Plant000Base
class_name Plant064SeaShroomWuyang

const GUIDANCE_BULLET_SCENE := preload("res://scenes/bullet/bullet_021_sea_shroom_wuyang.tscn")

@onready var attack_component: AttackComponentBulletBase = $AttackComponent
@onready var area_2d_mouse: Area2D = $Body/Area2DMouse
@onready var guidance_effect_target: CanvasItem = $Body/BodyCorrect/SeaShroom_head/SeaShroom_Wuyang_Hair

var guidance_duration := 10.0
var guidance_cooldown := 35.0 * 2.0 / 3.0
var guidance_attack_speed_multiplier := 1.5

var guidance_active := false
var guidance_ready := true
var guidance_duration_timer: Timer
var guidance_cooldown_timer: Timer
var guidance_ready_tween: Tween


func ready_norm() -> void:
	super()
	_load_guidance_config_from_bullet_scene()
	guidance_duration_timer = Timer.new()
	guidance_duration_timer.one_shot = true
	guidance_duration_timer.timeout.connect(_on_guidance_duration_timeout)
	add_child(guidance_duration_timer)

	guidance_cooldown_timer = Timer.new()
	guidance_cooldown_timer.one_shot = true
	guidance_cooldown_timer.timeout.connect(_on_guidance_cooldown_timeout)
	add_child(guidance_cooldown_timer)

	area_2d_mouse.visible = true
	if not is_sleeping:
		_start_guidance_ready_effect()


func _load_guidance_config_from_bullet_scene() -> void:
	var config_bullet := GUIDANCE_BULLET_SCENE.instantiate()
	guidance_duration = float(config_bullet.get("guidance_duration"))
	guidance_cooldown = float(config_bullet.get("guidance_cooldown"))
	guidance_attack_speed_multiplier = float(config_bullet.get("guidance_attack_speed_multiplier"))
	config_bullet.free()


## 初始化正常出战角色信号连接
func ready_norm_signal_connect():
	super()
	signal_update_speed.connect(attack_component.owner_update_speed)
	sleep_component.signal_is_sleep.connect(_on_guidance_owner_sleep)
	sleep_component.signal_not_is_sleep.connect(_on_guidance_owner_wake)


func is_bullet_guidance_active() -> bool:
	return guidance_active


func _activate_guidance() -> void:
	if not guidance_ready or guidance_active or is_sleeping:
		return
	guidance_ready = false
	guidance_active = true
	_stop_guidance_ready_effect()
	body.body_light_and_dark_end()
	attack_component.add_attack_speed_multiplier(self, guidance_attack_speed_multiplier)
	attack_component.call("set_global_detection_enabled", true)
	guidance_duration_timer.start(guidance_duration)
	guidance_cooldown_timer.start(guidance_cooldown)


func _on_guidance_duration_timeout() -> void:
	guidance_active = false
	attack_component.remove_attack_speed_multiplier(self)
	attack_component.call("set_global_detection_enabled", false)
	if guidance_ready and not is_sleeping:
		_start_guidance_ready_effect()


func _on_guidance_cooldown_timeout() -> void:
	guidance_ready = true
	if not guidance_active and not is_sleeping:
		_start_guidance_ready_effect()


func _on_guidance_owner_sleep() -> void:
	_stop_guidance_ready_effect()
	body.body_light_and_dark_end()


func _on_guidance_owner_wake() -> void:
	if guidance_ready and not guidance_active:
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
	if guidance_ready and not guidance_active and not is_sleeping:
		body.body_light_and_dark()


func _on_area_2d_mouse_exited() -> void:
	body.body_light_and_dark_end()


@warning_ignore("unused_parameter")
func _on_area_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_activate_guidance()
