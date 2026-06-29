extends Node
## 手持管理器，铲子（植物僵尸）
class_name HM_Item

@onready var ui_shovel: UIShovel = %UIShovel
@onready var real_shovel: RealShovel = %RealShovel
@onready var temporary_character: Node2D = %TemporaryCharacter

const SHOVEL_PULL_DURATION := 0.55
const SHOVEL_PULL_END_SCALE := 0.35

## 手持道具状态
enum E_HmItemStatus{
	Null,
	Shovel
}
var curr_hm_item_status := E_HmItemStatus.Null

## 当前鼠标所在格子
var curr_plant_cell :PlantCell

## 当前铲子选择植物
var plant_be_shovel_look:Plant000Base
## 当前铲子所在格子植物数量
var curr_shovel_look_plant_num:int = 0


func click_shovel():
	curr_hm_item_status = E_HmItemStatus.Shovel
	real_shovel.change_is_using(true)

func item_process() -> void:
	## 如果有预铲植物并且当前格子有多个植物时
	if is_instance_valid(plant_be_shovel_look) and is_instance_valid(curr_plant_cell) and curr_shovel_look_plant_num >= 2:
		var new_plant_be_shovel_look = curr_plant_cell.return_plant_be_shovel_look()
		if new_plant_be_shovel_look == plant_be_shovel_look:
			pass
		else:
			plant_be_shovel_look.be_shovel_look_end()
			plant_be_shovel_look = new_plant_be_shovel_look
			plant_be_shovel_look.be_shovel_look()

## 鼠标进入cell
func mouse_enter(plant_cell:PlantCell):
	curr_plant_cell = plant_cell
	match curr_hm_item_status:
		E_HmItemStatus.Shovel:
				## 获取当前格子植物数量
				curr_shovel_look_plant_num = plant_cell.get_curr_plant_num()
				if curr_shovel_look_plant_num >= 1:
					plant_be_shovel_look = plant_cell.return_plant_be_shovel_look()
					if is_instance_valid(plant_be_shovel_look):
						plant_be_shovel_look.be_shovel_look()

## 鼠标移出cell
@warning_ignore("unused_parameter")
func mouse_exit(plant_cell:PlantCell):
	curr_plant_cell = null

	match curr_hm_item_status:
		E_HmItemStatus.Shovel:
			## 如果有被铲子关注的植物
			_clear_shovel_look()


## 点击铲掉植物
@warning_ignore("unused_parameter")
func click_cell(plant_cell:PlantCell):
	match curr_hm_item_status:
		E_HmItemStatus.Shovel:
			## 如果有被铲子关注的植物
			if is_instance_valid(plant_be_shovel_look):
				var plant := plant_be_shovel_look
				_clear_shovel_look()
				SoundManager.play_other_SFX("plant2")
				_play_shovel_pull_animation(plant)


## 退出当前状态
func exit_status():
	curr_hm_item_status = E_HmItemStatus.Null
	_clear_shovel_look()
	curr_shovel_look_plant_num = 0
	real_shovel.change_is_using(false)
	ui_shovel.ui_shovel_appear()

func _clear_shovel_look():
	if is_instance_valid(plant_be_shovel_look):
		plant_be_shovel_look.be_shovel_look_end()
	plant_be_shovel_look = null
	curr_shovel_look_plant_num = 0

func _play_shovel_pull_animation(plant:Plant000Base):
	if not is_instance_valid(plant):
		return

	var pull_visual := _create_shovel_pull_visual(plant)
	if pull_visual == null:
		plant.be_shovel_kill()
		return

	plant.visible = false
	if is_instance_valid(plant.hurt_box_component):
		plant.hurt_box_component.disable_component(ComponentNormBase.E_IsEnableFactor.Character)

	var target_position := _screen_position_to_parent_local(ui_shovel.get_shovel_screen_center(), temporary_character)
	var target_scale:Vector2 = pull_visual.scale * SHOVEL_PULL_END_SCALE

	var tween := pull_visual.create_tween()
	tween.set_parallel(true)
	tween.tween_property(pull_visual, ^"position", target_position, SHOVEL_PULL_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(pull_visual, ^"scale", target_scale, SHOVEL_PULL_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(pull_visual, ^"modulate:a", 0.0, SHOVEL_PULL_DURATION * 0.72).set_delay(SHOVEL_PULL_DURATION * 0.18)
	tween.chain().tween_callback(_finish_shovel_pull_animation.bind(plant, pull_visual))

func _create_shovel_pull_visual(plant:Plant000Base) -> Node2D:
	if not is_instance_valid(plant.body) or not is_instance_valid(temporary_character):
		return null

	var pull_visual := plant.body.duplicate() as Node2D
	if pull_visual == null:
		return null

	pull_visual.name = "ShovelPullPlant"
	temporary_character.add_child(pull_visual)
	pull_visual.transform = temporary_character.get_global_transform_with_canvas().affine_inverse() * plant.body.get_global_transform_with_canvas()
	pull_visual.z_as_relative = false
	pull_visual.z_index = 10000
	pull_visual.modulate.a = 1.0
	return pull_visual

func _screen_position_to_parent_local(screen_position:Vector2, parent_node:CanvasItem) -> Vector2:
	return parent_node.get_global_transform_with_canvas().affine_inverse() * screen_position

func _finish_shovel_pull_animation(plant:Plant000Base, pull_visual:Node2D):
	if is_instance_valid(pull_visual):
		pull_visual.queue_free()
	if is_instance_valid(plant):
		plant.be_shovel_kill()
