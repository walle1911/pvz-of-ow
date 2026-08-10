extends PanelContainer
## 出战卡槽
class_name CardSlotBattle


## 顶部卡槽在当前 16:9 UI 中能完整显示的上限。
@export_range(1, 15) var max_visible_card_num := 13

@onready var curr_sun_value: Label = $SunLabelControl/CurrSunValue
@onready var card_placeholder_ori: TextureRect = $CardUiList/CardPlaceholder_ori
@onready var card_ui_list: HBoxContainer = $CardUiList
@onready var marker_2d_sun_target: Marker2D = %Marker2DSunTarget

## 永远不挂载卡片子节点的空卡槽模板。
var card_placeholder_template: TextureRect
## 出战卡槽占位节点
var cards_placeholder:Array = []
## 出战卡片
var curr_cards : Array[Card]
## 当前关卡允许选择的卡片数量；不得用界面可见上限替代。
var card_selection_limit := 0
var _squash_doomfist_card_attack_check_timer := 0.0
## 阳光值
var sun_value:
	set(value):
		if is_instance_valid(Global.game_para) and Global.game_para.is_sun_value_locked:
			value = Global.game_para.start_sun
		sun_value = value
		_remove_invalid_curr_cards()
		curr_sun_value.text = str(value)

		for card in curr_cards:
			card.judge_sun_enough(value)

func _ready() -> void:
	Global.config_service.signal_change_disappear_spare_card_placeholder.connect(judge_disappear_add_card_bar)
	EventBus.subscribe("test_change_sun_value", func(value): sun_value = value)
	EventBus.subscribe("add_sun_value", func(value): sun_value+=value)
	EventBus.subscribe("update_card_purple_sun_cost", update_card_purple_sun_cost)

func _process(delta: float) -> void:
	if not is_instance_valid(Global.main_game) or Global.main_game.main_game_progress != MainGameManager.E_MainGameProgress.MAIN_GAME:
		return

	_squash_doomfist_card_attack_check_timer -= delta
	if _squash_doomfist_card_attack_check_timer > 0:
		return

	_squash_doomfist_card_attack_check_timer = 0.2
	_try_squash_doomfist_attack_coffee_bean_ana()

## 初始化出战卡槽，管理器调用
func init_card_slot_battle(max_choosed_card_num:int, sun:int):
	self.sun_value = sun
	card_selection_limit = mini(maxi(0, max_choosed_card_num), max_visible_card_num)
	card_placeholder_template = card_placeholder_ori.duplicate()
	for i in range(card_selection_limit):
		var cloned_card_placeholder = card_placeholder_template.duplicate()
		card_ui_list.add_child(cloned_card_placeholder)

	card_placeholder_ori.free()		## 立即删除掉该节点，下面获取卡槽占位节点
	cards_placeholder = card_ui_list.get_children()
	## 更新阳光收集位置
	EventBus.push_event("update_marker_2d_sun_target", marker_2d_sun_target)

	return cards_placeholder


## 动态补充缺失的占位节点，但不能突破当前关卡的选卡上限。
func add_card_placeholder() -> Control:
	if cards_placeholder.size() >= card_selection_limit:
		return null
	if not is_instance_valid(card_placeholder_template):
		return null
	var cloned_card_placeholder = card_placeholder_template.duplicate()
	card_ui_list.add_child(cloned_card_placeholder)
	cards_placeholder.append(cloned_card_placeholder)
	return cloned_card_placeholder

func _exit_tree() -> void:
	if is_instance_valid(card_placeholder_template):
		card_placeholder_template.free()

## 主游戏刷新卡片
func main_game_refresh_card():
	_remove_invalid_curr_cards()
	update_card_purple_sun_cost()
	for i in range(curr_cards.size()):
		var card:Card = curr_cards[i]
		if not card.signal_card_use_end.is_connected(card_use_end.bind(card)):
			card.signal_card_use_end.connect(card_use_end.bind(card))
		if not card.signal_card_ready.is_connected(_on_card_ready):
			card.signal_card_ready.connect(_on_card_ready)
		card.judge_sun_enough(sun_value)
		card.set_shortcut((i+1)%10)
	judge_disappear_add_card_bar()

## 开始下一轮出战卡槽更新数据
func start_next_game_card_slot_battle_update():
	_remove_invalid_curr_cards()
	for i in range(curr_cards.size()):
		var card:Card = curr_cards[i]
		## 卡牌冷却结束,可以点击
		card.set_card_cool_end()
		card.card_ready()
		card.set_shortcut_disappear()
		if card.signal_card_use_end.is_connected(card_use_end.bind(card)):
			card.signal_card_use_end.disconnect(card_use_end.bind(card))
		if card.signal_card_ready.is_connected(_on_card_ready):
			card.signal_card_ready.disconnect(_on_card_ready)

## 卡片种植后信号调用函数
func card_use_end(card:Card):
	## 减少阳光，卡片冷却
	sun_value = sun_value - card.sun_cost
	card.card_cool()

func _on_card_ready(card:Card):
	_try_squash_doomfist_attack_card(card)

func _try_squash_doomfist_attack_coffee_bean_ana():
	_remove_invalid_curr_cards()
	for card:Card in curr_cards:
		if _try_squash_doomfist_attack_card(card):
			return

func _try_squash_doomfist_attack_card(card:Card) -> bool:
	if not _is_valid_card(card):
		return false
	if card.card_plant_type != CharacterRegistry.PlantType.P036CoffeeBeanAna:
		return false
	if not card.is_ana_coffee_mode_active():
		return false
	if card.is_hidden_by_squash_doomfist:
		return false
	if card.is_being_attacked_by_squash_doomfist:
		return false
	if not card.is_can_click:
		return false
	if not is_instance_valid(Global.main_game) or Global.main_game.main_game_progress != MainGameManager.E_MainGameProgress.MAIN_GAME:
		return false

	var squash_doomfist := _get_available_squash_doomfist()
	if not is_instance_valid(squash_doomfist):
		return false

	return squash_doomfist.attack_card(card)

func _get_available_squash_doomfist() -> Plant054SquashDoomfist:
	if not is_instance_valid(Global.main_game) or not is_instance_valid(Global.main_game.plant_cell_manager):
		return null

	for plant_cells_row in Global.main_game.plant_cell_manager.all_plant_cells:
		for plant_cell:PlantCell in plant_cells_row:
			for place_plant_in_cell in plant_cell.plant_in_cell:
				var plant:Plant000Base = plant_cell.plant_in_cell[place_plant_in_cell]
				if is_instance_valid(plant) and plant is Plant054SquashDoomfist:
					var squash_doomfist := plant as Plant054SquashDoomfist
					if not squash_doomfist.is_attack:
						return squash_doomfist
	return null

#region 控制台相关
## 是否显示多余卡槽
func judge_disappear_add_card_bar():
	## 在游戏进行阶段
	if Global.main_game.main_game_progress == MainGameManager.E_MainGameProgress.MAIN_GAME:
		if Global.config_service.disappear_spare_card_Placeholder:
			if curr_cards.size() < cards_placeholder.size():
				for i in range(curr_cards.size(), cards_placeholder.size()):
					cards_placeholder[i].visible = false
		else:
			for i in range(cards_placeholder.size()):
				cards_placeholder[i].visible = true
	else:
		for i in range(cards_placeholder.size()):
			cards_placeholder[i].visible = true

#endregion

## 等待一帧(阳光减少)后 更新当前卡片的紫卡价格,每次植物种植或死亡时调用
func update_card_purple_sun_cost():
	await get_tree().process_frame
	_remove_invalid_curr_cards()
	for card:Card in curr_cards:
		if card.is_purple_card and Global.main_game.plant_cell_manager.curr_plant_num.has(card.card_plant_type):
			card.sun_cost = Global.character_registry.get_plant_info(card.card_plant_type, CharacterRegistry.PlantInfoAttribute.SunCost) + 50 * Global.main_game.plant_cell_manager.curr_plant_num[card.card_plant_type]
			card.judge_sun_enough(sun_value)

func _remove_invalid_curr_cards() -> void:
	for i in range(curr_cards.size() - 1, -1, -1):
		var card: Card = curr_cards[i]
		if not _is_valid_card(card):
			if is_instance_valid(card):
				card.queue_free()
			curr_cards.remove_at(i)

func _is_valid_card(card: Card) -> bool:
	return is_instance_valid(card) \
		and (
			card.card_plant_type != CharacterRegistry.PlantType.Null \
			or card.card_zombie_type != CharacterRegistry.ZombieType.Null
			) \
		and (
			not Global.main_game.game_para.adventure_card_lock_active \
			or card.card_plant_type == CharacterRegistry.PlantType.Null \
			or RewardCardRuntime.is_plant_available_in_level(
				int(card.card_plant_type),
				Global.main_game.game_para.level_id,
				Global.main_game.game_para.available_plant_types.has(card.card_plant_type),
				Global.main_game.game_para.special_reward_card_source_dir
			)
		)
