extends Node
## 手持管理器，角色（植物僵尸）
class_name HM_Character

const VENDETTA_PLANT_TYPE := CharacterRegistry.PlantType.P021JalapenoVendetta
const VENDETTA_CHARGE_TIME := 1.0
const VENDETTA_FOLLOW_OFFSET := Vector2(24.0, 48.0)
const VENDETTA_SLASH_EFFECT = preload("res://scripts/fx/plant_effect/plant_effect_vendetta_jalapeno_slash.gd")
## OW 僵尸卡图来源不一：有的是实战尺寸骨骼，有的是已经缩过的整张合成图。
## 手持时按实际可见高度兜底，保留巨人/旗帜等合理体型差异，同时修正极小和超大贴图。
const OW_ZOMBIE_PREVIEW_MIN_HEIGHT := 120.0
const OW_ZOMBIE_PREVIEW_MAX_HEIGHT := 220.0
const OW_CONE_TALON_PREVIEW_MAX_HEIGHT := 140.0
const OW_CONE_TALON_CARD_SPRITE_POSITION := Vector2(-6.0, -58.95)
const OW_CONE_TALON_CARD_SPRITE_SCALE := 0.3
const OW_ZOMBIE_PREVIEW_GROUND_Y := 12.0

@onready var hand_manager: HandManager = %HandManager

## 卡牌手动放置的角色已经完成创建。导演编辑模式用它自动归入当前幕。
signal signal_manual_character_placed(character: Character000Base)

## 角色临时挂载节点
@onready var temporary_character: Node2D = %TemporaryCharacter

## 当前卡片
var curr_card:Card = null
## 手持静态角色
var characte_static:Node2D
## 格子静态角色虚影
var characte_static_shadow:Node2D
## 植物种植条件
var plant_condition:ResourcePlantCondition
## 僵尸种植行条件
var zombie_row_type:CharacterRegistry.ZombieRowType
## 虚影在格子中，即可以种植
var is_shadow_in_cell:=false

## 柱子模式
var is_mode_column := false
## 柱子模式虚影
var characte_static_shadow_colum : Array[Node2D]

## 紫卡植物可以的预种植植物,点击卡片时明暗交替
var curr_all_preplant_purple:Array[Plant000Base]

## 上一次选中的非模仿者植物类型，模仿者种植时自动复制它
var last_non_imitater_plant_type: CharacterRegistry.PlantType = CharacterRegistry.PlantType.Null

## 斩仇火爆辣椒空中技能状态
var _vendetta_charge_player:AnimationPlayer
var _vendetta_animation_tree:AnimationTree
var _vendetta_is_charging := false
var _vendetta_charge_elapsed := 0.0
var _vendetta_target_lane := -1
var _vendetta_float_time := 0.0
var _vendetta_has_released := false
var _vendetta_release_on_next_frame := false
var _vendetta_latched_lane := -1

func init_hm_character():
	self.is_mode_column = hand_manager.game_para.is_mode_column

func character_process(delta:float) -> void:
	if not is_instance_valid(characte_static):
		return
	if _is_vendetta_selected():
		_vendetta_float_time += delta
		var charge_progress := clampf(_vendetta_charge_elapsed / VENDETTA_CHARGE_TIME, 0.0, 1.0)
		var float_offset := Vector2(0.0, sin(_vendetta_float_time * 5.0) * 3.0 - charge_progress * 10.0)
		characte_static.global_position = temporary_character.get_global_mouse_position() + VENDETTA_FOLLOW_OFFSET + float_offset
		_update_vendetta_indicator_position()
		if _vendetta_is_charging:
			# 满蓄完成态保留一个绘制帧，让第二格白芯与三排阴影真正可见；
			# 下一帧仍是自动释放，手感上保持“蓄满即炸”。
			if _vendetta_release_on_next_frame:
				_vendetta_target_lane = _vendetta_latched_lane
				_release_vendetta(true, true)
				return
			_vendetta_charge_elapsed = minf(_vendetta_charge_elapsed + delta, VENDETTA_CHARGE_TIME)
			charge_progress = clampf(_vendetta_charge_elapsed / VENDETTA_CHARGE_TIME, 0.0, 1.0)
			_update_vendetta_charge_preview(charge_progress)
			if charge_progress >= 1.0 and _vendetta_target_lane >= 0:
				_vendetta_latched_lane = _vendetta_target_lane
				_vendetta_release_on_next_frame = true
		return
	## CanvasItem方法获取位置
	characte_static.global_position = temporary_character.get_global_mouse_position()

## 点击卡片
func click_card(card:Card) -> bool:
	if not _is_valid_hand_card(card):
		return false
	var character_type := GlobalUtils.get_character_type(card.card_plant_type, card.card_zombie_type)
	match character_type:
		CharacterRegistry.CharacterType.Plant:
			if not Global.character_registry.PlantInfo.has(card.card_plant_type):
				push_warning("手持卡失败，植物未注册: %s" % card.card_plant_type)
				return false
		CharacterRegistry.CharacterType.Zombie:
			if not Global.character_registry.ZombieInfo.has(card.card_zombie_type):
				push_warning("手持卡失败，僵尸未注册: %s" % card.card_zombie_type)
				return false
		CharacterRegistry.CharacterType.Null:
			push_warning("手持卡失败，卡牌没有植物或僵尸类型")
			return false

	if character_type == CharacterRegistry.CharacterType.Plant\
		and card.card_plant_type == VENDETTA_PLANT_TYPE:
		return _click_vendetta_card(card)
	if character_type == CharacterRegistry.CharacterType.Plant and _is_original_plant(card.card_plant_type):
		return _click_original_plant_card(card)

	var character_static_copy := card.character_static.duplicate() as Node2D
	if not is_instance_valid(character_static_copy) or character_static_copy.get_child_count() == 0:
		if is_instance_valid(character_static_copy):
			character_static_copy.queue_free()
		push_warning("手持卡失败，卡牌缺少静态角色节点: %s" % card.name)
		return false

	var character_child := character_static_copy.get_child(0) as Node2D
	if not is_instance_valid(character_child):
		character_static_copy.queue_free()
		push_warning("手持卡失败，静态角色节点不是 Node2D: %s" % card.name)
		return false

	## 清除之前数据
	if curr_card != null:
		_clear_curr_data()
	## 新植物数据
	curr_card = card
	EventBus.push_event("hm_character_hand_card", [curr_card])
	characte_static = character_static_copy
	## 植物
	if character_type == CharacterRegistry.CharacterType.Plant:
		## 记住上一个非模仿者植物类型
		if not curr_card.is_imitater\
			and curr_card.card_plant_type != CharacterRegistry.PlantType.P1499Imitater\
			and curr_card.card_plant_type != CharacterRegistry.PlantType.P999ImitaterEcho:
			last_non_imitater_plant_type = curr_card.card_plant_type

		plant_condition = Global.character_registry.get_plant_info(curr_card.card_plant_type, CharacterRegistry.PlantInfoAttribute.PlantConditionResource)
		## 如果卡牌没有种植条件（如模仿者本体），使用上一次选中植物的条件
		if plant_condition == null and last_non_imitater_plant_type != CharacterRegistry.PlantType.Null:
			plant_condition = Global.character_registry.get_plant_info(last_non_imitater_plant_type, CharacterRegistry.PlantInfoAttribute.PlantConditionResource)
		## 静态植物以及植物虚影
		character_child.scale = Vector2.ONE
		character_child.position = Vector2.ZERO
		characte_static_shadow = character_child.duplicate()
		characte_static_shadow.modulate.a = 0
		characte_static.z_index = 1

		temporary_character.add_child(characte_static)
		temporary_character.add_child(characte_static_shadow)

		if click_card_column:
			click_card_column()

		# 如果是紫卡植物
		if plant_condition != null and plant_condition.is_purple_card:
			start_preplant_purple_light(plant_condition, curr_card.card_plant_type)

	## 僵尸
	else:
		zombie_row_type = Global.character_registry.get_zombie_info(curr_card.card_zombie_type, CharacterRegistry.ZombieInfoAttribute.ZombieRowType)
		## 静态僵尸以及僵尸虚影
		if curr_card.card_zombie_type == CharacterRegistry.ZombieType.Z003ConeTalon:
			character_child = _wrap_cone_talon_card_sprite(character_static_copy, character_child)
		else:
			character_child.scale = Vector2.ONE
			character_child.position = Vector2.ZERO
		_normalize_ow_zombie_preview(character_child, curr_card.card_zombie_type)
		characte_static_shadow = character_child.duplicate()
		characte_static_shadow.modulate.a = 0
		characte_static.z_index = 1

		temporary_character.add_child(characte_static)
		temporary_character.add_child(characte_static_shadow)

		if click_card_column:
			click_card_column()

	return true


func _is_original_plant(plant_type:CharacterRegistry.PlantType) -> bool:
	return (int(plant_type) >= 501 and int(plant_type) <= 549) \
		or plant_type == CharacterRegistry.PlantType.P1499Imitater


func _click_original_plant_card(card:Card) -> bool:
	var preview_plant := _create_original_plant_preview(card)
	var preview_shadow := _create_original_plant_preview(card)
	if not is_instance_valid(preview_plant) or not is_instance_valid(preview_shadow):
		if is_instance_valid(preview_plant):
			preview_plant.queue_free()
		if is_instance_valid(preview_shadow):
			preview_shadow.queue_free()
		push_warning("手持原版植物失败，无法创建展示实例: %s" % card.card_plant_type)
		return false

	if curr_card != null:
		_clear_curr_data()
	curr_card = card
	EventBus.push_event("hm_character_hand_card", [curr_card])
	if not card.is_imitater and card.card_plant_type != CharacterRegistry.PlantType.P1499Imitater:
		last_non_imitater_plant_type = card.card_plant_type
	plant_condition = Global.character_registry.get_plant_info(
		card.card_plant_type,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource
	)
	if plant_condition == null and last_non_imitater_plant_type != CharacterRegistry.PlantType.Null:
		plant_condition = Global.character_registry.get_plant_info(
			last_non_imitater_plant_type,
			CharacterRegistry.PlantInfoAttribute.PlantConditionResource
		)

	characte_static = preview_plant
	characte_static_shadow = preview_shadow
	characte_static.z_index = 1
	characte_static_shadow.modulate.a = 0.0
	temporary_character.add_child(characte_static)
	temporary_character.add_child(characte_static_shadow)

	if click_card_column:
		click_card_column()
	if plant_condition != null and plant_condition.is_purple_card:
		start_preplant_purple_light(plant_condition, card.card_plant_type)
	return true


func _create_original_plant_preview(card:Card) -> Plant000Base:
	var plant_scene := Global.character_registry.get_plant_info(
		card.card_plant_type,
		CharacterRegistry.PlantInfoAttribute.PlantScenes
	) as PackedScene
	if not is_instance_valid(plant_scene):
		return null
	var preview := plant_scene.instantiate() as Plant000Base
	if not is_instance_valid(preview):
		return null
	preview.init_plant({
		Plant000Base.E_PInitAttr.CharacterInitType: Character000Base.E_CharacterInitType.IsShow,
		Plant000Base.E_PInitAttr.IsImitaterMaterial: card.is_imitater,
	})
	preview.position = Vector2.ZERO
	preview.scale = Vector2.ONE
	var plant_shadow := preview.get_node_or_null(^"Shadow") as CanvasItem
	if is_instance_valid(plant_shadow):
		plant_shadow.visible = false
	var preview_hp := preview.get_node_or_null(^"HpComponent/HpControl") as CanvasItem
	if is_instance_valid(preview_hp):
		preview_hp.visible = false
	return preview


func _wrap_cone_talon_card_sprite(character_static_copy:Node2D, card_sprite:Node2D) -> Node2D:
	## normal/bucket 卡图都是“根节点 + 内层合成图”；路障卡图原本少了一层根节点，
	## 导致手持本体和格子虚影的脚底原点与另外两张 Talon 卡不一致。
	var preview_root := Node2D.new()
	preview_root.name = "Zombie002ConeTalonPreviewRoot"
	character_static_copy.remove_child(card_sprite)
	character_static_copy.add_child(preview_root)
	preview_root.add_child(card_sprite)
	card_sprite.position = OW_CONE_TALON_CARD_SPRITE_POSITION
	card_sprite.scale = Vector2.ONE * OW_CONE_TALON_CARD_SPRITE_SCALE
	return preview_root


func _normalize_ow_zombie_preview(character_root:Node2D, zombie_type:CharacterRegistry.ZombieType) -> void:
	## 500 起是原版僵尸，其卡图本来就按实战尺寸制作；只校正 OW/Talon 卡图。
	if zombie_type <= CharacterRegistry.ZombieType.Null or zombie_type >= CharacterRegistry.ZombieType.Z501Norm:
		return

	var sprite_bounds:Array[Rect2] = []
	_collect_visible_sprite_bounds(character_root, Transform2D.IDENTITY, sprite_bounds)
	if sprite_bounds.is_empty():
		return

	var visual_bounds := sprite_bounds[0]
	for i in range(1, sprite_bounds.size()):
		visual_bounds = visual_bounds.merge(sprite_bounds[i])
	if visual_bounds.size.y <= 0.0:
		return

	var preview_max_height := OW_ZOMBIE_PREVIEW_MAX_HEIGHT
	## 路障海鸥僵尸使用 250x473 的整张卡图，不能按巨型/旗帜僵尸的上限显示。
	## 140px 与普通 Talon 的实战预选体型一致。
	if zombie_type == CharacterRegistry.ZombieType.Z003ConeTalon:
		preview_max_height = OW_CONE_TALON_PREVIEW_MAX_HEIGHT

	var preview_scale := 1.0
	if visual_bounds.size.y < OW_ZOMBIE_PREVIEW_MIN_HEIGHT:
		preview_scale = OW_ZOMBIE_PREVIEW_MIN_HEIGHT / visual_bounds.size.y
	elif visual_bounds.size.y > preview_max_height:
		preview_scale = preview_max_height / visual_bounds.size.y

	character_root.scale = Vector2.ONE * preview_scale
	## 卡片内的合成图常以中心为原点；把可见底边重新落到鼠标/格子基准线附近。
	character_root.position.y = OW_ZOMBIE_PREVIEW_GROUND_Y - visual_bounds.end.y * preview_scale


func _collect_visible_sprite_bounds(
		node:Node,
		transform_from_root:Transform2D,
		result:Array[Rect2]) -> void:
	if node is CanvasItem and not (node as CanvasItem).visible:
		return

	if node is Sprite2D:
		var sprite := node as Sprite2D
		if is_instance_valid(sprite.texture):
			result.append(transform_from_root * sprite.get_rect())

	for child in node.get_children():
		var child_transform := transform_from_root
		if child is Node2D:
			child_transform *= (child as Node2D).transform
		_collect_visible_sprite_bounds(child, child_transform, result)


## 斩仇版火爆辣椒不是“种下去”的植物，而是鼠标旁悬空释放的整排技能。
func _click_vendetta_card(card:Card) -> bool:
	var plant_scene:PackedScene = Global.character_registry.get_plant_info(
		VENDETTA_PLANT_TYPE,
		CharacterRegistry.PlantInfoAttribute.PlantScenes
	)
	if not is_instance_valid(plant_scene):
		push_warning("手持斩仇火爆辣椒失败，角色场景未注册")
		return false

	var preview_plant := plant_scene.instantiate() as Plant000Base
	if not is_instance_valid(preview_plant):
		push_warning("手持斩仇火爆辣椒失败，角色场景不是植物")
		return false

	if curr_card != null:
		_clear_curr_data()

	curr_card = card
	EventBus.push_event("hm_character_hand_card", [curr_card])
	plant_condition = Global.character_registry.get_plant_info(
		VENDETTA_PLANT_TYPE,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource
	)
	if not curr_card.is_imitater:
		last_non_imitater_plant_type = VENDETTA_PLANT_TYPE

	preview_plant.init_plant({
		Plant000Base.E_PInitAttr.CharacterInitType: Character000Base.E_CharacterInitType.IsShow,
		Plant000Base.E_PInitAttr.IsImitaterMaterial: curr_card.is_imitater,
	})
	characte_static = preview_plant
	temporary_character.add_child(preview_plant)
	preview_plant.z_as_relative = false
	preview_plant.z_index = 302

	var preview_shadow := preview_plant.get_node_or_null(^"Shadow") as CanvasItem
	if is_instance_valid(preview_shadow):
		preview_shadow.visible = false
	var preview_hp := preview_plant.get_node_or_null(^"HpComponent/HpControl") as CanvasItem
	if is_instance_valid(preview_hp):
		preview_hp.visible = false
	var preview_bomb := preview_plant.get_node_or_null(^"BombComponent") as ComponentNormBase
	if is_instance_valid(preview_bomb):
		preview_bomb.disable_component(ComponentNormBase.E_IsEnableFactor.InitType)

	_vendetta_charge_player = preview_plant.get_node_or_null(^"VendettaChargeAnimationPlayer") as AnimationPlayer
	_vendetta_animation_tree = preview_plant.get_node_or_null(^"AnimationTree") as AnimationTree
	var targeting_effect := VENDETTA_SLASH_EFFECT.new() as Node2D
	if not is_instance_valid(targeting_effect):
		_clear_curr_data()
		push_warning("手持斩仇火爆辣椒失败，范围特效无法创建")
		return false
	characte_static_shadow = targeting_effect
	temporary_character.add_child(targeting_effect)
	targeting_effect.position = Vector2.ZERO
	targeting_effect.z_as_relative = false
	targeting_effect.z_index = 301

	_vendetta_is_charging = false
	_vendetta_charge_elapsed = 0.0
	_vendetta_target_lane = -1
	_vendetta_float_time = 0.0
	_vendetta_has_released = false
	_vendetta_release_on_next_frame = false
	_vendetta_latched_lane = -1
	return true


func _is_vendetta_selected() -> bool:
	return is_instance_valid(curr_card)\
		and curr_card.card_plant_type == VENDETTA_PLANT_TYPE


func is_vendetta_charging() -> bool:
	return _is_vendetta_selected() and _vendetta_is_charging


## 在格子上按下左键后开始空中蓄力；提前松开斩一排，蓄满自动斩三排。
func handle_mouse_button(event:InputEventMouseButton) -> bool:
	if not _is_vendetta_selected() or event.button_index != MOUSE_BUTTON_LEFT:
		return false

	if event.pressed:
		if not is_instance_valid(hand_manager.curr_plant_cell):
			return false
		_start_vendetta_charge(hand_manager.curr_plant_cell)
		return true

	if not _vendetta_is_charging:
		return false
	if _vendetta_release_on_next_frame and _vendetta_latched_lane >= 0:
		_vendetta_target_lane = _vendetta_latched_lane
	elif is_instance_valid(hand_manager.curr_plant_cell):
		_vendetta_target_lane = hand_manager.curr_plant_cell.row_col.x
	if _vendetta_target_lane >= 0:
		_release_vendetta(_vendetta_charge_elapsed >= VENDETTA_CHARGE_TIME, true)
	else:
		_cancel_vendetta_charge()
	return true


func _start_vendetta_charge(plant_cell:PlantCell) -> void:
	if _vendetta_has_released:
		return
	_vendetta_is_charging = true
	_vendetta_charge_elapsed = 0.0
	_vendetta_release_on_next_frame = false
	_vendetta_latched_lane = -1
	_show_vendetta_target(plant_cell)
	_update_vendetta_charge_preview(0.0)
	## 角色原本的 AnimationTree 会持续把 idle 轨道写回同一批身体节点，
	## 使独立的 explode 蓄力动画只剩下不冲突的整体效果。
	if is_instance_valid(_vendetta_animation_tree):
		_vendetta_animation_tree.active = false
	if is_instance_valid(_vendetta_charge_player):
		_vendetta_charge_player.stop()
		_vendetta_charge_player.play(&"Vendetta_charge")
		_vendetta_charge_player.advance(0.0)


func _cancel_vendetta_charge() -> void:
	_vendetta_is_charging = false
	_vendetta_charge_elapsed = 0.0
	_vendetta_release_on_next_frame = false
	_vendetta_latched_lane = -1
	_update_vendetta_charge_preview(0.0)
	if is_instance_valid(_vendetta_charge_player):
		_vendetta_charge_player.stop()
		_vendetta_charge_player.play(&"RESET")
		_vendetta_charge_player.advance(0.0)
	if is_instance_valid(_vendetta_animation_tree):
		_vendetta_animation_tree.active = true
	if not is_instance_valid(hand_manager.curr_plant_cell):
		if is_instance_valid(characte_static_shadow):
			characte_static_shadow.call(&"hide_target")
		is_shadow_in_cell = false
		_vendetta_target_lane = -1


func _show_vendetta_target(plant_cell:PlantCell) -> void:
	if not is_instance_valid(characte_static_shadow):
		return
	# 满蓄完成帧已经把范围锁定；忽略这一帧内的跨排输入，保证玩家
	# 看到的三排阴影与下一帧实际释放的排完全一致。
	if _vendetta_release_on_next_frame:
		return
	_vendetta_target_lane = plant_cell.row_col.x
	is_shadow_in_cell = true
	characte_static_shadow.call(
		&"show_target",
		_vendetta_target_lane,
		_get_vendetta_lane_polygons(characte_static_shadow)
	)
	if _vendetta_is_charging:
		_update_vendetta_charge_preview(
			clampf(_vendetta_charge_elapsed / VENDETTA_CHARGE_TIME, 0.0, 1.0)
		)


func _update_vendetta_charge_preview(progress:float) -> void:
	if is_instance_valid(characte_static_shadow):
		characte_static_shadow.call(&"set_charge_progress", clampf(progress, 0.0, 1.0))


## 将空中角色的画布位置转换到范围特效局部坐标，供蓄力档位标志跟随。
func _update_vendetta_indicator_position() -> void:
	if not is_instance_valid(characte_static) or not is_instance_valid(characte_static_shadow):
		return
	var effect_inverse := characte_static_shadow.get_global_transform_with_canvas().affine_inverse()
	var indicator_position:Vector2 = effect_inverse * characte_static.get_global_transform_with_canvas().origin
	characte_static_shadow.call(&"set_indicator_position", indicator_position)


## 用真实格子的四角生成范围，屋顶斜面也不会被近似成错误的水平矩形。
func _get_vendetta_lane_polygons(effect_root:CanvasItem) -> Array:
	var result:Array = []
	if not is_instance_valid(effect_root)\
		or not is_instance_valid(Global.main_game)\
		or not is_instance_valid(Global.main_game.plant_cell_manager):
		return result

	var effect_inverse := effect_root.get_global_transform_with_canvas().affine_inverse()
	for lane_cells:Array in Global.main_game.plant_cell_manager.all_plant_cells:
		var lane_polygons:Array = []
		for cell_value in lane_cells:
			var plant_cell := cell_value as PlantCell
			if not is_instance_valid(plant_cell):
				continue
			var cell_transform := effect_inverse * plant_cell.get_global_transform_with_canvas()
			var cell_size := plant_cell.size
			lane_polygons.append(PackedVector2Array([
				cell_transform * Vector2.ZERO,
				cell_transform * Vector2(cell_size.x, 0.0),
				cell_transform * cell_size,
				cell_transform * Vector2(0.0, cell_size.y),
			]))
		result.append(lane_polygons)
	return result


func _release_vendetta(is_charged:bool, suppress_following_cell_click:bool) -> void:
	if _vendetta_has_released or not _is_vendetta_selected() or _vendetta_target_lane < 0:
		return
	if not is_instance_valid(Global.main_game)\
		or not is_instance_valid(Global.main_game.plant_cell_manager):
		return

	var all_lane_cells:Array = Global.main_game.plant_cell_manager.all_plant_cells
	if _vendetta_target_lane >= all_lane_cells.size():
		return

	_vendetta_has_released = true
	_vendetta_is_charging = false
	_vendetta_release_on_next_frame = false
	_vendetta_latched_lane = -1
	if suppress_following_cell_click:
		hand_manager.suppress_vendetta_cell_click_after_release()
	if is_instance_valid(_vendetta_charge_player):
		if is_charged:
			## HandManager 比临时角色更早处理帧，先落到最后一帧再释放。
			_vendetta_charge_player.seek(VENDETTA_CHARGE_TIME, true)
		## 释放后只让独立的 SwordPivot 挥砍；辣椒膨胀停在当前蓄力姿态，
		## 避免瞬发后还在刀落过程中继续播放 explode。
		_vendetta_charge_player.pause()

	var release_effect := VENDETTA_SLASH_EFFECT.new() as Node2D
	var airborne_actor := characte_static
	if is_instance_valid(release_effect):
		temporary_character.add_child(release_effect)
		release_effect.position = Vector2.ZERO
		release_effect.z_as_relative = false
		## 剑气覆盖草地，空中火爆辣椒和挥刀本体保持在其上。
		release_effect.z_index = 301
		var release_origin := release_effect.to_local(airborne_actor.global_position)\
			if is_instance_valid(airborne_actor) else Vector2.ZERO
		release_effect.call(
			&"start_release",
			_vendetta_target_lane,
			is_charged,
			_get_vendetta_lane_polygons(release_effect),
			release_origin,
			airborne_actor
		)
	else:
		push_warning("斩仇火爆辣椒释放特效无法创建")
		if is_instance_valid(airborne_actor):
			airborne_actor.queue_free()

	## 释放特效已接管空中角色，清理手持状态时不再删掉它。
	characte_static = null
	_vendetta_charge_player = null

	SoundManager.play_other_SFX(&"swing")
	SoundManager.play_character_SFX(&"Jalapeno")
	var center_lane_damage := 1800
	var edge_lane_damage := 900
	if airborne_actor is Plant059JalapenoVendetta:
		center_lane_damage = airborne_actor.center_lane_damage
		edge_lane_damage = airborne_actor.edge_lane_damage
	var first_lane := _vendetta_target_lane
	var end_lane := _vendetta_target_lane + 1
	if is_charged:
		first_lane = maxi(0, _vendetta_target_lane - 1)
		end_lane = mini(all_lane_cells.size(), _vendetta_target_lane + 2)
	for lane_index in range(first_lane, end_lane):
		var lane_damage := center_lane_damage
		if is_charged and lane_index != _vendetta_target_lane:
			lane_damage = edge_lane_damage
		EventBus.push_event("jalapeno_bomb_effect", [lane_index])
		EventBus.push_event("jalapeno_bomb_lane_zombie", [lane_index, lane_damage])
		EventBus.push_event("jalapeno_bomb_item_lane", [lane_index])

	var used_card := curr_card
	if is_instance_valid(used_card):
		used_card.signal_card_use_end.emit()
	hand_manager.curr_hm_status = HandManager.E_HandManagerStatus.Null


## 紫卡预种植植物身体明暗发光开始
func start_preplant_purple_light(curr_plant_condition:ResourcePlantCondition, plant_type:CharacterRegistry.PlantType):
	curr_all_preplant_purple = curr_plant_condition.get_all_preplant_purple(Global.main_game.plant_cell_manager.all_plant_cells, plant_type)
	for preplant_purple in curr_all_preplant_purple:
		preplant_purple.preplant_purple_body_light_and_dark()
#
## 紫卡预种植植物身体明暗发光结束
func end_preplant_purple_light():
	for preplant_purple in curr_all_preplant_purple:
		if is_instance_valid(preplant_purple):
			preplant_purple.preplant_purple_body_light_and_dark_end()

## 清除数据
func _clear_curr_data():
	# 如果是紫卡植物
	if plant_condition != null and plant_condition.is_purple_card:
		end_preplant_purple_light()

	_vendetta_is_charging = false
	_vendetta_charge_elapsed = 0.0
	_vendetta_target_lane = -1
	_vendetta_float_time = 0.0
	_vendetta_has_released = false
	_vendetta_release_on_next_frame = false
	_vendetta_latched_lane = -1
	_vendetta_charge_player = null
	_vendetta_animation_tree = null
	is_shadow_in_cell = false
	## 若当前存在卡片,事件总线推清除当前卡片数据,种子雨卡槽接受判断
	if is_instance_valid(curr_card):
		EventBus.push_event("hm_character_clear_card", [curr_card])

	curr_card = null
	if is_instance_valid(characte_static):
		characte_static.queue_free()
	if is_instance_valid(characte_static_shadow):
		characte_static_shadow.queue_free()
	characte_static = null
	characte_static_shadow = null
	plant_condition = null
	zombie_row_type = CharacterRegistry.ZombieRowType.Land
	if is_mode_column:
		_clear_curr_data_column()

## 鼠标进入cell
func mouse_enter(plant_cell:PlantCell):
	if not is_instance_valid(curr_card) or not is_instance_valid(characte_static_shadow):
		return
	if _is_vendetta_selected():
		_show_vendetta_target(plant_cell)
		return
	is_shadow_in_cell = _update_cell_shadow(plant_cell, characte_static_shadow)
	if is_shadow_in_cell and is_mode_column:
		_mouse_enter_column(plant_cell)

## 更新植物格子虚影,返回是否能种植
func _update_cell_shadow(plant_cell:PlantCell, curr_characte_static_shadow:Node2D) -> bool:
	if not is_instance_valid(curr_card) or not is_instance_valid(curr_characte_static_shadow):
		return false
	## 植物
	if curr_card.card_plant_type != 0:
		## 如果是判定是否可以种植植物
		if plant_condition == null:
			curr_characte_static_shadow.modulate.a = 0
			return false
		if plant_condition.judge_is_can_plant(plant_cell, curr_card.card_plant_type):
			curr_characte_static_shadow.global_position = _get_plant_static_shadow_global_position(plant_cell)
			curr_characte_static_shadow.modulate.a = 0.5
			return true
		else:
			curr_characte_static_shadow.modulate.a = 0
			return false

	## 僵尸
	else:
		## 如果当前格子不能种植僵尸(蹦极除外)
		if not plant_cell.can_common_zombie and curr_card.card_zombie_type != CharacterRegistry.ZombieType.Z521Bungi:
			return false
		## 如果不是双地形
		if zombie_row_type != CharacterRegistry.ZombieRowType.Both:
			if zombie_row_type == Global.main_game.zombie_manager.all_zombie_rows[plant_cell.row_col.x].zombie_row_type:
				curr_characte_static_shadow.global_position =  get_zombie_static_shadow_global_position(plant_cell)
				curr_characte_static_shadow.modulate.a = 0.5
				return true
			else:
				curr_characte_static_shadow.modulate.a = 0
				return false
		else:
			curr_characte_static_shadow.global_position = get_zombie_static_shadow_global_position(plant_cell)
			curr_characte_static_shadow.modulate.a = 0.5
			return true

func _get_plant_static_shadow_global_position(plant_cell:PlantCell) -> Vector2:
	var global_pos:Vector2 = plant_cell.get_new_plant_static_shadow_global_position(plant_condition.place_plant_in_cell)
	## 埃姆雷版玉米加农炮实际会同时占用当前格与右侧格，预选虚影也应居中跨在两格上。
	if curr_card.card_plant_type == CharacterRegistry.PlantType.P048CobCannonEmre:
		var next_col := plant_cell.row_col.y + 1
		if next_col < Global.main_game.plant_cell_manager.row_col.y:
			var next_plant_cell:PlantCell = Global.main_game.plant_cell_manager.all_plant_cells[plant_cell.row_col.x][next_col]
			var next_global_pos:Vector2 = next_plant_cell.get_new_plant_static_shadow_global_position(plant_condition.place_plant_in_cell)
			global_pos = (global_pos + next_global_pos) * 0.5

	return global_pos

## 获取种植僵尸的虚影位置
func get_zombie_static_shadow_global_position(plant_cell)->Vector2:
	var global_pos =  Vector2(
		plant_cell.global_position.x + plant_cell.size.x/2,
		Global.main_game.zombie_manager.all_zombie_rows[plant_cell.row_col.x].zombie_create_position.global_position.y
	)

	## 如果有斜面
	if is_instance_valid(Global.main_game.main_game_slope):
		global_pos += Vector2(0, Global.main_game.main_game_slope.get_all_slope_y(global_pos.x))


	return global_pos

## 鼠标移出cell
func mouse_exit(_plant_cell:PlantCell):
	if _is_vendetta_selected():
		## 蓄力时保留最后一个有效排，避免格子缝隙让满蓄静默取消。
		if _vendetta_is_charging:
			return
		if is_instance_valid(characte_static_shadow):
			characte_static_shadow.call(&"hide_target")
		is_shadow_in_cell = false
		_vendetta_target_lane = -1
		return
	if is_instance_valid(characte_static_shadow):
		characte_static_shadow.modulate.a = 0
	if is_mode_column:
		_mouse_exit_column()

## 点击种植植物\僵尸
func click_cell(plant_cell:PlantCell):
	if not is_instance_valid(curr_card):
		return
	if _is_vendetta_selected():
		if _vendetta_release_on_next_frame and _vendetta_latched_lane >= 0:
			_vendetta_target_lane = _vendetta_latched_lane
		else:
			_vendetta_target_lane = plant_cell.row_col.x
		_release_vendetta(
			_vendetta_is_charging and _vendetta_charge_elapsed >= VENDETTA_CHARGE_TIME,
			false
		)
		return
	if is_shadow_in_cell:
		if curr_card.card_plant_type != 0:
			var plant_type := curr_card.card_plant_type
			var is_imitater := curr_card.is_imitater
			var imitater_variant := CharacterRegistry.PlantType.P999ImitaterEcho  # 默认改版模仿者
			## 如果卡牌是模仿者本体（没有指定模仿目标），复制上一次选中的植物
			if not is_imitater\
				and (plant_type == CharacterRegistry.PlantType.P1499Imitater or plant_type == CharacterRegistry.PlantType.P999ImitaterEcho)\
				and last_non_imitater_plant_type != CharacterRegistry.PlantType.Null:
				imitater_variant = plant_type  # 记住具体变体
				plant_type = last_non_imitater_plant_type
				is_imitater = true
			var created_plant := plant_cell.create_plant(plant_type, is_imitater, true, false, false, imitater_variant)
			if is_instance_valid(created_plant):
				signal_manual_character_placed.emit(created_plant)
		else:
			var zombie_init_para:Dictionary = {
				Zombie000Base.E_ZInitAttr.CharacterInitType:Character000Base.E_CharacterInitType.IsNorm,
				Zombie000Base.E_ZInitAttr.Lane:plant_cell.row_col.x,
			}

			var created_zombie: Zombie000Base = Global.main_game.zombie_manager.create_norm_zombie(
				curr_card.card_zombie_type,
				Global.main_game.zombie_manager.all_zombie_rows[plant_cell.row_col.x],
				zombie_init_para,
				Vector2(
					plant_cell.global_position.x + plant_cell.size.x/2,
					Global.main_game.zombie_manager.all_zombie_rows[plant_cell.row_col.x].zombie_create_position.global_position.y
				),
				GlobalUtils.get_special_zombie_callable(curr_card.card_zombie_type, plant_cell)
			)
			if is_instance_valid(created_zombie):
				signal_manual_character_placed.emit(created_zombie)
			if curr_card.is_chessboard_hypno_reward and is_instance_valid(created_zombie):
				created_zombie.be_hypno()

		## 卡片种植完成发射信号
		curr_card.signal_card_use_end.emit()
		if is_mode_column:
			_click_cell_column(plant_cell)

## 退出当前状态
func exit_status():
	_clear_curr_data()


func _is_valid_hand_card(card: Card) -> bool:
	return is_instance_valid(card) \
		and is_instance_valid(card.character_static) \
		and (
			card.card_plant_type != CharacterRegistry.PlantType.Null \
			or card.card_zombie_type != CharacterRegistry.ZombieType.Null
		)


#region 柱子模式额外操作函数
## 柱子模式 点击卡片产生多余植物虚影
func click_card_column() -> void:
	if curr_card.card_plant_type != 0:
		for plant_cell_i in range(Global.main_game.plant_cell_manager.row_col.x):
			var column_characte_static_shadow = characte_static_shadow.duplicate()
			column_characte_static_shadow.modulate.a = 0
			temporary_character.add_child(column_characte_static_shadow)
			characte_static_shadow_colum.append(column_characte_static_shadow)
	else:
		for zombie_rows_i in range(Global.main_game.zombie_manager.all_zombie_rows.size()):
			var column_characte_static_shadow = characte_static_shadow.duplicate()
			column_characte_static_shadow.modulate.a = 0
			temporary_character.add_child(column_characte_static_shadow)
			characte_static_shadow_colum.append(column_characte_static_shadow)

## 柱子模式 鼠标进入判断其他格子是否可以种植，产生虚影
func _mouse_enter_column(plant_cell:PlantCell):
	for plant_cell_i in range(Global.main_game.plant_cell_manager.row_col.x):
		if plant_cell_i == plant_cell.row_col.x:
			continue

		## 判断是否产生虚影
		_update_cell_shadow(
			Global.main_game.plant_cell_manager.all_plant_cells[plant_cell_i][plant_cell.row_col.y],\
			characte_static_shadow_colum[plant_cell_i]
		)

## 柱子模式 鼠标移出cell
func _mouse_exit_column():
	for _characte_static_shadow in characte_static_shadow_colum:
		_characte_static_shadow.modulate.a = 0

## 柱子模式 点击种植或铲掉植物
func _click_cell_column(plant_cell:PlantCell):
	if curr_card.card_plant_type != 0:
		for i in range(characte_static_shadow_colum.size()):
			## 当前格子的图像透明
			var _characte_static_shadow = characte_static_shadow_colum[i]
			if _characte_static_shadow.modulate.a != 0:
				var _plant_cell:PlantCell = Global.main_game.plant_cell_manager.all_plant_cells[i][plant_cell.row_col.y]
				var _plant_type := curr_card.card_plant_type
				var _is_imitater := curr_card.is_imitater
				var _imitater_variant := CharacterRegistry.PlantType.P999ImitaterEcho  # 默认改版模仿者
				if not _is_imitater\
					and (_plant_type == CharacterRegistry.PlantType.P1499Imitater or _plant_type == CharacterRegistry.PlantType.P999ImitaterEcho)\
					and last_non_imitater_plant_type != CharacterRegistry.PlantType.Null:
					_imitater_variant = _plant_type  # 记住具体变体
					_plant_type = last_non_imitater_plant_type
					_is_imitater = true
				var created_plant := _plant_cell.create_plant(_plant_type, _is_imitater, true, false, false, _imitater_variant)
				if is_instance_valid(created_plant):
					signal_manual_character_placed.emit(created_plant)
	else:
		for i in range(characte_static_shadow_colum.size()):
			## 当前格子的图像透明
			var _characte_static_shadow = characte_static_shadow_colum[i]
			if _characte_static_shadow.modulate.a != 0:
				var _plant_cell:PlantCell = Global.main_game.plant_cell_manager.all_plant_cells[i][plant_cell.row_col.y]

				var zombie_init_para:Dictionary = {
					Zombie000Base.E_ZInitAttr.CharacterInitType:Character000Base.E_CharacterInitType.IsNorm,
					Zombie000Base.E_ZInitAttr.Lane:_plant_cell.row_col.x,
				}

				var created_zombie: Zombie000Base = Global.main_game.zombie_manager.create_norm_zombie(
					curr_card.card_zombie_type,
					Global.main_game.zombie_manager.all_zombie_rows[_plant_cell.row_col.x],
					zombie_init_para,

					Vector2(_characte_static_shadow.global_position.x,
						Global.main_game.zombie_manager.all_zombie_rows[_plant_cell.row_col.x].zombie_create_position.global_position.y
					),
					GlobalUtils.get_special_zombie_callable(curr_card.card_zombie_type, _plant_cell)
				)
				if is_instance_valid(created_zombie):
					signal_manual_character_placed.emit(created_zombie)

## 柱子模式 清除数据
func _clear_curr_data_column():
	for _characte_static_shadow in characte_static_shadow_colum:
		_characte_static_shadow.queue_free()
	characte_static_shadow_colum.clear()

#endregion
