extends Plant000Base
class_name Plant061ImitaterEcho

## 模仿的植物类型
var imitater_plant_type :CharacterRegistry.PlantType = CharacterRegistry.PlantType.Null
@export_group("复制僵尸染色", "imitater_zombie_")
@export var imitater_zombie_tint_color: Color = Color(0.72, 0.88, 1.0, 1.0)
@export_range(0.0, 1.0) var imitater_zombie_whiteness := 0.62
@export_range(0.0, 1.0) var imitater_zombie_gray_strength := 0.0
@export_range(-1.0, 1.0) var imitater_zombie_brightness := 0.08
@export_range(0.0, 3.0) var imitater_zombie_contrast := 0.95
@export_group("Echo 亡语")
@export_range(0.0, 30.0, 0.1, "or_greater", "suffix:s") var echo_killer_copy_window_seconds := 4.0
@onready var imitater_effect: Node2D = $ImitaterEffect
@onready var animation_tree: AnimationTree = $AnimationTree

## 是否已经执行过模仿转换（防止重复调用）
var _imitater_transformed := false
var imitater_echo_can_explode := false
var _fallback_timer_started := false


## 初始化正常出战角色
func ready_norm():
	super()
	imitater_echo_can_explode = imitater_plant_type != CharacterRegistry.PlantType.Null
	## 监听 explode 动画结束信号，触发模仿转换
	if is_instance_valid(animation_tree):
		animation_tree.animation_finished.connect(_on_animation_finished)
	if imitater_echo_can_explode:
		_start_fallback_timer()


func _on_animation_finished(anim_name: StringName):
	if anim_name != &"ImitaterEcho_explode":
		return
	_do_imitater_transform()


func _on_fallback_timer_timeout():
	if not _imitater_transformed:
		_do_imitater_transform()


func _do_imitater_transform():
	if _imitater_transformed:
		return
	update_imitater()


## 更新模仿者植物
func update_imitater():
	if _imitater_transformed:
		return
	_imitater_transformed = true
	imitater_echo_can_explode = false
	## plant_cell创造植物,该函数会先等待一帧,当前模仿者死亡后创建
	if imitater_plant_type != CharacterRegistry.PlantType.Null and is_instance_valid(plant_cell):
		var killer_copy_effect:Node2D = null
		if echo_killer_copy_window_seconds > 0.0 and is_instance_valid(imitater_effect):
			killer_copy_effect = imitater_effect.duplicate()
		var echo_config := {
			&"window_seconds": echo_killer_copy_window_seconds,
			&"effect": killer_copy_effect,
			&"tint_color": imitater_zombie_tint_color,
			&"whiteness": imitater_zombie_whiteness,
			&"gray_strength": imitater_zombie_gray_strength,
			&"brightness": imitater_zombie_brightness,
			&"contrast": imitater_zombie_contrast,
		}
		plant_cell.imitater_create_plant(
			imitater_plant_type,
			true,
			CharacterRegistry.PlantType.P999ImitaterEcho,
			{Plant000Base.ECHO_KILLER_COPY_PRE_READY_KEY:echo_config}
		)
	if is_instance_valid(imitater_effect) and is_instance_valid(imitater_effect.owner) and is_instance_valid(imitater_effect.owner.get_parent()):
		imitater_effect.visible = true
		imitater_effect.z_index += 1
		imitater_effect.activate_it()
	## 角色死亡直接消失
	character_death_disappear()


func _start_fallback_timer():
	if _fallback_timer_started:
		return
	_fallback_timer_started = true
	## 兜底计时器：如果信号因故未触发，2 秒后强制转换
	var fallback_timer := get_tree().create_timer(2.0)
	fallback_timer.timeout.connect(_on_fallback_timer_timeout)
