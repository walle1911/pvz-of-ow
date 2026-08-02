extends Plant000Base
class_name Plant064SeaShroomWuyang

@onready var attack_component: AttackComponentBulletSeaShroomWuyang = $AttackComponent
@onready var area_2d_mouse: Area2D = $Body/Area2DMouse

@export_range(1.0, 3.0, 0.1, "or_greater") var guidance_body_brightness := 1.5

var is_mouse_hovered := false
var is_guidance_active := false


func ready_norm() -> void:
	super()
	area_2d_mouse.visible = true


## 初始化正常出战角色信号连接
func ready_norm_signal_connect():
	super()
	signal_update_speed.connect(attack_component.owner_update_speed)
	attack_component.signal_guidance_started.connect(_on_guidance_started)
	attack_component.signal_guidance_ended.connect(_on_guidance_ended)


func _on_area_2d_mouse_entered() -> void:
	is_mouse_hovered = true
	if not is_sleeping and not is_guidance_active:
		body.body_light_and_dark()


func _on_area_2d_mouse_exited() -> void:
	is_mouse_hovered = false
	if not is_guidance_active:
		body.body_light_and_dark_end()


func _on_guidance_started() -> void:
	is_guidance_active = true
	body.body_light_and_dark_end()
	body.set_other_color(
		BodyCharacter.E_ChangeColors.LightAndDark,
		Color(guidance_body_brightness, guidance_body_brightness, guidance_body_brightness, 1.0)
	)


func _on_guidance_ended() -> void:
	is_guidance_active = false
	body.body_light_and_dark_end()
	if is_mouse_hovered and not is_sleeping:
		body.body_light_and_dark()


@warning_ignore("unused_parameter")
func _on_area_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not is_sleeping:
			attack_component.shoot_guided_bullet(get_global_mouse_position())
