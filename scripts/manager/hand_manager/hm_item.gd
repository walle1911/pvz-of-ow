extends Node
## 手持管理器，铲子（植物僵尸）
class_name HM_Item

@onready var ui_shovel: UIShovel = %UIShovel
@onready var real_shovel: RealShovel = %RealShovel
@onready var temporary_character: Node2D = %TemporaryCharacter

@export_range(0.0, 1.0, 0.01) var shovel_vine_alpha: float = 1.0:
	set(value):
		shovel_vine_alpha = clamp(value, 0.0, 1.0)
		if is_instance_valid(shovel_vine_cable):
			shovel_vine_cable.set("alpha_multiplier", shovel_vine_alpha)
			shovel_vine_cable.queue_redraw()
@export_range(0.0, 2.0, 0.01) var shovel_vine_flash_boost: float = 0.85
@export_range(0.01, 0.5, 0.01) var shovel_vine_flash_duration: float = 0.12

const SHOVEL_PULL_DURATION := 0.55
const SHOVEL_PULL_END_SCALE := 0.35
## 植物开始移动前的延迟，让绳子先收紧再拉回，增强拉扯感
const SHOVEL_PULL_PLANT_DELAY := 0.08
const SHOVEL_VINE_TENSION_DURATION := 0.34
const SHOVEL_VINE_START_OFFSET := Vector2.ZERO
const SHOVEL_VINE_Z_INDEX := 80
const SHOVEL_PULL_VISUAL_Z_INDEX := 90
const SHOVEL_VINE_TIGHT_BULGE_RATIO := 1.0 / 3.0
const VINE_CABLE_SCENE: PackedScene = preload("res://scenes/effects/VineCable2D.tscn")

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

## 铲子三股藤蔓拉线
var shovel_vine_cable: Node2D
var shovel_vine_target: Node2D
var shovel_vine_tween: Tween
var shovel_vine_alpha_tween: Tween
var shovel_vine_flash_tween: Tween
## 是否正在播放拉取动画
var is_pulling := false


func _ready() -> void:
	var canvas_temp: CanvasLayer = temporary_character.get_parent() as CanvasLayer
	shovel_vine_cable = VINE_CABLE_SCENE.instantiate() as Node2D
	shovel_vine_cable.name = "ShovelVineCable2D"
	shovel_vine_cable.visible = false
	shovel_vine_cable.z_as_relative = false
	shovel_vine_cable.z_index = SHOVEL_VINE_Z_INDEX
	canvas_temp.add_child(shovel_vine_cable)
	canvas_temp.move_child(shovel_vine_cable, real_shovel.get_index())
	_configure_shovel_vine()


func _process(_delta: float) -> void:
	_update_shovel_vine_points()

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
	# 如果正在播放拉取动画，不隐藏线（由动画结束回调处理）
	if not is_pulling:
		_hide_shovel_vine()

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

	is_pulling = true
	# 先让 UI 铲子可见，确保 PanelContainer 完成布局后再获取屏幕坐标
	ui_shovel.ui_shovel_appear()
	_start_shovel_vine_pull(pull_visual)

	plant.visible = false
	if is_instance_valid(plant.hurt_box_component):
		plant.hurt_box_component.disable_component(ComponentNormBase.E_IsEnableFactor.Character)

	var target_position := _screen_position_to_parent_local(_get_shovel_vine_start_pos(), temporary_character)
	var target_scale:Vector2 = pull_visual.scale * SHOVEL_PULL_END_SCALE

	var tween := pull_visual.create_tween()
	# 短暂延迟，让绳子的收缩动画先跑一步，产生「绳子咬住再拉回」的层次感
	tween.tween_interval(SHOVEL_PULL_PLANT_DELAY)
	var move_duration := SHOVEL_PULL_DURATION - SHOVEL_PULL_PLANT_DELAY
	tween.set_parallel(true)
	tween.tween_property(pull_visual, "position", target_position, move_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(pull_visual, "scale", target_scale, move_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	var fade_duration := move_duration * 0.72
	var fade_delay := move_duration * 0.18
	tween.tween_property(pull_visual, "modulate:a", 0.0, fade_duration).set_delay(fade_delay)
	_start_shovel_vine_fade(SHOVEL_PULL_PLANT_DELAY + fade_delay, fade_duration)
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
	pull_visual.z_index = SHOVEL_PULL_VISUAL_Z_INDEX
	pull_visual.modulate.a = 1.0
	return pull_visual

func _screen_position_to_parent_local(screen_position:Vector2, parent_node:CanvasItem) -> Vector2:
	return parent_node.get_global_transform_with_canvas().affine_inverse() * screen_position

func _finish_shovel_pull_animation(plant:Plant000Base, pull_visual:Node2D):
	is_pulling = false
	if shovel_vine_target == pull_visual:
		_hide_shovel_vine()
	if is_instance_valid(pull_visual):
		pull_visual.queue_free()
	if is_instance_valid(plant):
		plant.be_shovel_kill()


func _configure_shovel_vine() -> void:
	if not is_instance_valid(shovel_vine_cable):
		return

	shovel_vine_cable.set("point_count", 42)
	shovel_vine_cable.set("loose_amplitude", 18.0)
	shovel_vine_cable.set("tight_amplitude", 6.0)
	shovel_vine_cable.set("loose_turns", 2.7)
	shovel_vine_cable.set("tight_turns", 0.35)
	shovel_vine_cable.set("base_width", 2.1)
	shovel_vine_cable.set("twist_speed", 6.0)
	shovel_vine_cable.set("follow_speed", 0.0)
	shovel_vine_cable.set("end_bulge_strength", 1.8)
	shovel_vine_cable.set("end_bulge_position", 0.84)
	shovel_vine_cable.set("end_bulge_width", 0.22)
	shovel_vine_cable.set("middle_bulge_ratio", 0.4)
	shovel_vine_cable.set("start_bulge_ratio", 0.03)
	shovel_vine_cable.set("tight_bulge_ratio", SHOVEL_VINE_TIGHT_BULGE_RATIO)
	shovel_vine_cable.set("tight_strand_separation", 2.12)
	shovel_vine_cable.set("alpha_multiplier", shovel_vine_alpha)
	shovel_vine_cable.set("loose_brightness_boost", 0.3)
	shovel_vine_cable.set("loose_alpha_boost", 0.5)
	shovel_vine_cable.set("strand_colors", [
		Color(1.0, 0.72, 0.84, 0.42),
		Color(1.0, 0.72, 0.84, 0.38),
		Color(1.0, 0.72, 0.84, 0.34),
	])


func _start_shovel_vine_pull(pull_visual: Node2D) -> void:
	if not is_instance_valid(shovel_vine_cable) or not is_instance_valid(pull_visual):
		return

	if shovel_vine_tween:
		shovel_vine_tween.kill()

	_kill_shovel_vine_alpha_tween()
	shovel_vine_cable.set("alpha_multiplier", shovel_vine_alpha)
	shovel_vine_cable.set("line_flash_boost", 0.0)
	shovel_vine_target = pull_visual
	shovel_vine_cable.visible = true
	shovel_vine_cable.call("set_tension_override", 0.0, true)
	shovel_vine_cable.call("snap_points", _get_shovel_vine_start_pos(), pull_visual.get_global_transform_with_canvas().origin)
	_start_shovel_vine_flash()

	shovel_vine_tween = create_tween()
	shovel_vine_tween.tween_method(_set_shovel_vine_tension, 0.0, 1.0, SHOVEL_VINE_TENSION_DURATION)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _update_shovel_vine_points() -> void:
	if not is_instance_valid(shovel_vine_cable) or not shovel_vine_cable.visible:
		return

	if is_instance_valid(shovel_vine_target):
		shovel_vine_cable.call("set_points", _get_shovel_vine_start_pos(), shovel_vine_target.get_global_transform_with_canvas().origin)
	else:
		_hide_shovel_vine()


func _set_shovel_vine_tension(value: float) -> void:
	if is_instance_valid(shovel_vine_cable):
		shovel_vine_cable.call("set_tension_override", value, false)


func _start_shovel_vine_flash() -> void:
	if not is_instance_valid(shovel_vine_cable) or shovel_vine_flash_boost <= 0.0:
		return

	_kill_shovel_vine_flash_tween()
	shovel_vine_cable.set("line_flash_boost", shovel_vine_flash_boost)
	shovel_vine_flash_tween = create_tween()
	shovel_vine_flash_tween.tween_property(shovel_vine_cable, "line_flash_boost", 0.0, shovel_vine_flash_duration)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	shovel_vine_flash_tween.tween_callback(_clear_shovel_vine_flash_tween)


func _kill_shovel_vine_flash_tween() -> void:
	if shovel_vine_flash_tween:
		shovel_vine_flash_tween.kill()
		shovel_vine_flash_tween = null


func _clear_shovel_vine_flash_tween() -> void:
	shovel_vine_flash_tween = null


func _start_shovel_vine_fade(delay: float, duration: float) -> void:
	if not is_instance_valid(shovel_vine_cable):
		return

	_kill_shovel_vine_alpha_tween()
	shovel_vine_alpha_tween = create_tween()
	if delay > 0.0:
		shovel_vine_alpha_tween.tween_interval(delay)
	shovel_vine_alpha_tween.tween_property(shovel_vine_cable, "alpha_multiplier", 0.0, duration)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	shovel_vine_alpha_tween.tween_callback(_clear_shovel_vine_alpha_tween)


func _kill_shovel_vine_alpha_tween() -> void:
	if shovel_vine_alpha_tween:
		shovel_vine_alpha_tween.kill()
		shovel_vine_alpha_tween = null


func _clear_shovel_vine_alpha_tween() -> void:
	shovel_vine_alpha_tween = null


func _get_shovel_vine_start_pos() -> Vector2:
	return ui_shovel.get_shovel_screen_center() + SHOVEL_VINE_START_OFFSET


func _hide_shovel_vine() -> void:
	if shovel_vine_tween:
		shovel_vine_tween.kill()
		shovel_vine_tween = null
	_kill_shovel_vine_alpha_tween()
	_kill_shovel_vine_flash_tween()
	shovel_vine_target = null
	if is_instance_valid(shovel_vine_cable):
		shovel_vine_cable.visible = false
		shovel_vine_cable.call("clear_tension_override")
		shovel_vine_cable.set("alpha_multiplier", shovel_vine_alpha)
		shovel_vine_cable.set("line_flash_boost", 0.0)
