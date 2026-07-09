extends Node
## 手持管理器，角色（植物僵尸）
class_name HM_Character

@onready var hand_manager: HandManager = %HandManager

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

## 缓存：游戏场景中的 BodyCorrect 位置，按植物类型索引
var _game_body_correct_cache: Dictionary = {}

func init_hm_character():
	self.is_mode_column = hand_manager.game_para.is_mode_column

func character_process() -> void:
	if not is_instance_valid(characte_static):
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
			and curr_card.card_plant_type != CharacterRegistry.PlantType.P548Imitater\
			and curr_card.card_plant_type != CharacterRegistry.PlantType.P053ImitaterEcho:
			last_non_imitater_plant_type = curr_card.card_plant_type

		plant_condition = Global.character_registry.get_plant_info(curr_card.card_plant_type, CharacterRegistry.PlantInfoAttribute.PlantConditionResource)
		## 如果卡牌没有种植条件（如模仿者本体），使用上一次选中植物的条件
		if plant_condition == null and last_non_imitater_plant_type != CharacterRegistry.PlantType.Null:
			plant_condition = Global.character_registry.get_plant_info(last_non_imitater_plant_type, CharacterRegistry.PlantInfoAttribute.PlantConditionResource)
		## 静态植物以及植物虚影
		character_child.scale = Vector2.ONE
		character_child.position = Vector2.ZERO
		_fix_body_correct_from_game_scene(character_child, curr_card.card_plant_type)
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
		character_child.scale = Vector2.ONE
		character_child.position = Vector2.ZERO
		characte_static_shadow = character_child.duplicate()
		characte_static_shadow.modulate.a = 0
		characte_static.z_index = 1

		temporary_character.add_child(characte_static)
		temporary_character.add_child(characte_static_shadow)

		if click_card_column:
			click_card_column()

	return true

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
		if not plant_cell.can_common_zombie and curr_card.card_zombie_type != CharacterRegistry.ZombieType.Z520Bungi:
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
	if is_instance_valid(characte_static_shadow):
		characte_static_shadow.modulate.a = 0
	if is_mode_column:
		_mouse_exit_column()

## 点击种植植物\僵尸
func click_cell(plant_cell:PlantCell):
	if not is_instance_valid(curr_card):
		return
	if is_shadow_in_cell:
		if curr_card.card_plant_type != 0:
			var plant_type := curr_card.card_plant_type
			var is_imitater := curr_card.is_imitater
			var imitater_variant := CharacterRegistry.PlantType.P053ImitaterEcho  # 默认改版模仿者
			## 如果卡牌是模仿者本体（没有指定模仿目标），复制上一次选中的植物
			if not is_imitater\
				and (plant_type == CharacterRegistry.PlantType.P548Imitater or plant_type == CharacterRegistry.PlantType.P053ImitaterEcho)\
				and last_non_imitater_plant_type != CharacterRegistry.PlantType.Null:
				imitater_variant = plant_type  # 记住具体变体
				plant_type = last_non_imitater_plant_type
				is_imitater = true
			plant_cell.create_plant(plant_type, is_imitater, true, false, false, imitater_variant)
		else:
			var zombie_init_para:Dictionary = {
				Zombie000Base.E_ZInitAttr.CharacterInitType:Character000Base.E_CharacterInitType.IsNorm,
				Zombie000Base.E_ZInitAttr.Lane:plant_cell.row_col.x,
			}

			Global.main_game.zombie_manager.create_norm_zombie(
				curr_card.card_zombie_type,
				Global.main_game.zombie_manager.all_zombie_rows[plant_cell.row_col.x],
				zombie_init_para,
				Vector2(
					plant_cell.global_position.x + plant_cell.size.x/2,
					Global.main_game.zombie_manager.all_zombie_rows[plant_cell.row_col.x].zombie_create_position.global_position.y
				),
				GlobalUtils.get_special_zombie_callable(curr_card.card_zombie_type, plant_cell)
			)

		## 卡片种植完成发射信号
		curr_card.signal_card_use_end.emit()
		if is_mode_column:
			_click_cell_column(plant_cell)

## 退出当前状态
func exit_status():
	_clear_curr_data()


## 从游戏场景获取正确的 BodyCorrect 及其子节点结构，应用到卡片预览节点上
func _fix_body_correct_from_game_scene(plant_child: Node2D, plant_type: CharacterRegistry.PlantType) -> void:
	if not _game_body_correct_cache.has(plant_type):
		_game_body_correct_cache[plant_type] = _make_game_body_correct_snapshot(plant_type)

	var snapshot: Dictionary = _game_body_correct_cache.get(plant_type, {})
	if snapshot.is_empty():
		return

	var card_body_correct = plant_child.get_node_or_null("Body/BodyCorrect") as Node2D
	if not card_body_correct:
		return

	_apply_node_snapshot(card_body_correct, snapshot)


func _make_game_body_correct_snapshot(plant_type: CharacterRegistry.PlantType) -> Dictionary:
	var snapshot: Dictionary = {}
	var plant_scene = Global.character_registry.get_plant_info(plant_type, CharacterRegistry.PlantInfoAttribute.PlantScenes)
	if not plant_scene:
		return snapshot

	var instance = plant_scene.instantiate()
	var body_correct = instance.get_node_or_null("Body/BodyCorrect") as Node2D
	if body_correct:
		_collect_node_snapshot(body_correct, snapshot)
	instance.queue_free()
	return snapshot


func _collect_node_snapshot(node: Node2D, snapshot: Dictionary) -> void:
	snapshot[&"pos"] = node.position
	snapshot[&"scale"] = node.scale
	var children_snapshot: Dictionary = {}
	for child in node.get_children():
		var child_node2d := child as Node2D
		if child_node2d:
			var child_snap: Dictionary = {}
			_collect_node_snapshot(child_node2d, child_snap)
			children_snapshot[child.name] = child_snap
	if not children_snapshot.is_empty():
		snapshot[&"children"] = children_snapshot


func _apply_node_snapshot(node: Node2D, snapshot: Dictionary) -> void:
	if snapshot.has("pos"):
		node.position = snapshot["pos"]
	if snapshot.has("scale"):
		node.scale = snapshot["scale"]
	var children_snapshot: Dictionary = snapshot.get("children", {})
	for child in node.get_children():
		var child_name: String = child.name
		if children_snapshot.has(child_name):
			var child_node2d := child as Node2D
			if child_node2d:
				_apply_node_snapshot(child_node2d, children_snapshot[child_name])

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
				var _imitater_variant := CharacterRegistry.PlantType.P053ImitaterEcho  # 默认改版模仿者
				if not _is_imitater\
					and (_plant_type == CharacterRegistry.PlantType.P548Imitater or _plant_type == CharacterRegistry.PlantType.P053ImitaterEcho)\
					and last_non_imitater_plant_type != CharacterRegistry.PlantType.Null:
					_imitater_variant = _plant_type  # 记住具体变体
					_plant_type = last_non_imitater_plant_type
					_is_imitater = true
				_plant_cell.create_plant(_plant_type, _is_imitater, true, false, false, _imitater_variant)
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

				Global.main_game.zombie_manager.create_norm_zombie(
					curr_card.card_zombie_type,
					Global.main_game.zombie_manager.all_zombie_rows[_plant_cell.row_col.x],
					zombie_init_para,

					Vector2(_characte_static_shadow.global_position.x,
						Global.main_game.zombie_manager.all_zombie_rows[_plant_cell.row_col.x].zombie_create_position.global_position.y
					),
					GlobalUtils.get_special_zombie_callable(curr_card.card_zombie_type, _plant_cell)
				)

## 柱子模式 清除数据
func _clear_curr_data_column():
	for _characte_static_shadow in characte_static_shadow_colum:
		_characte_static_shadow.queue_free()
	characte_static_shadow_colum.clear()

#endregion
