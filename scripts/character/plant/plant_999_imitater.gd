extends Plant000Base
class_name Plant999Imitater

## 模仿的植物类型
var imitater_plant_type :CharacterRegistry.PlantType = CharacterRegistry.PlantType.Null
@onready var imitater_effect: Node2D = $ImitaterEffect
@onready var animation_tree: AnimationTree = $AnimationTree

## 是否已经执行过模仿转换（防止重复调用）
var _imitater_transformed := false


## 初始化正常出战角色
func ready_norm():
	super()
	## 监听 explode 动画结束信号，触发模仿转换
	if is_instance_valid(animation_tree):
		animation_tree.animation_finished.connect(_on_animation_finished)
	## 兜底计时器：如果信号因故未触发，2 秒后强制转换
	var fallback_timer := get_tree().create_timer(2.0)
	fallback_timer.timeout.connect(_on_fallback_timer_timeout)


func _on_animation_finished(_anim_name: StringName):
	_do_imitater_transform()


func _on_fallback_timer_timeout():
	if not _imitater_transformed:
		_do_imitater_transform()


func _do_imitater_transform():
	if _imitater_transformed:
		return
	_imitater_transformed = true
	update_imitater()


## 更新模仿者植物
func update_imitater():
	## plant_cell创造植物,该函数会先等待一帧,当前模仿者死亡后创建
	if imitater_plant_type != CharacterRegistry.PlantType.Null and is_instance_valid(plant_cell):
		plant_cell.imitater_create_plant(imitater_plant_type, true, CharacterRegistry.PlantType.P999Imitater)
	if is_instance_valid(imitater_effect) and is_instance_valid(imitater_effect.owner) and is_instance_valid(imitater_effect.owner.get_parent()):
		imitater_effect.visible = true
		imitater_effect.z_index += 1
		imitater_effect.activate_it()
	## 角色死亡直接消失
	character_death_disappear()
