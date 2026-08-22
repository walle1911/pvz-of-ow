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
## 仅录制导演启用：顶部卡槽分成植物页与僵尸页，Shift 切换。
var director_pages_enabled := false
var director_current_page := 0
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
	_setup_target_range_sun_button()


func _setup_target_range_sun_button() -> void:
	if not is_instance_valid(Global.game_para) or not Global.game_para.is_target_range:
		return
	var refresh_button := Button.new()
	refresh_button.name = "TargetRangeCooldownRefreshButton"
	refresh_button.position = Vector2(-78, 0)
	refresh_button.size = Vector2(78, 70)
	refresh_button.flat = true
	refresh_button.focus_mode = Control.FOCUS_NONE
	refresh_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	refresh_button.tooltip_text = "刷新全部卡片冷却"
	refresh_button.pressed.connect(_refresh_target_range_card_cooldowns)
	$SunLabelControl.add_child(refresh_button)


func _refresh_target_range_card_cooldowns() -> void:
	_remove_invalid_curr_cards()
	for card: Card in curr_cards:
		card.set_card_cool_end()
		card.judge_card_ready()

func _process(delta: float) -> void:
	if not is_instance_valid(Global.main_game) or Global.main_game.main_game_progress != MainGameManager.E_MainGameProgress.MAIN_GAME:
		return

	_squash_doomfist_card_attack_check_timer -= delta
	if _squash_doomfist_card_attack_check_timer > 0:
		return

	_squash_doomfist_card_attack_check_timer = 0.2
	_try_squash_doomfist_attack_coffee_bean_ana()

## 初始化出战卡槽，管理器调用
func init_card_slot_battle(max_choosed_card_num:int, sun:int, initial_card_slot_num := -1):
	self.sun_value = sun
	card_selection_limit = mini(maxi(0, max_choosed_card_num), max_visible_card_num)
	if initial_card_slot_num < 0:
		initial_card_slot_num = card_selection_limit
	initial_card_slot_num = mini(maxi(0, initial_card_slot_num), card_selection_limit)
	card_placeholder_template = card_placeholder_ori.duplicate()
	for i in range(initial_card_slot_num):
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


func enable_director_card_pages() -> void:
	if director_pages_enabled:
		return
	director_pages_enabled = true
	director_current_page = 0
	refresh_director_card_page()


func toggle_director_card_page() -> bool:
	if not director_pages_enabled:
		return false
	director_current_page = 1 - director_current_page
	refresh_director_card_page()
	return true


func show_director_card_page(page: int) -> void:
	if not director_pages_enabled:
		return
	director_current_page = clampi(page, 0, 1)
	refresh_director_card_page()


func director_page_for_card(card: Card) -> int:
	return 1 if is_instance_valid(card) \
		and card.card_zombie_type != CharacterRegistry.ZombieType.Null else 0


func director_cards_on_page(page: int) -> Array[Card]:
	var result: Array[Card] = []
	for card in curr_cards:
		if _is_valid_card(card) and director_page_for_card(card) == page:
			result.append(card)
	return result


func director_page_is_full(card: Card) -> bool:
	return director_pages_enabled \
		and director_cards_on_page(director_page_for_card(card)).size() >= card_selection_limit


func director_placeholder_index_for_new_card(card: Card) -> int:
	return director_cards_on_page(director_page_for_card(card)).size()


func refresh_director_card_page() -> void:
	if not director_pages_enabled:
		return
	_remove_invalid_curr_cards()
	var visible_cards := director_cards_on_page(director_current_page)
	# 两个逻辑页复用同一排占位节点。卡片最初可能按 curr_cards 的全局顺序
	# 挂在后面的占位节点上，因此切页时必须按“当前页内序号”重新排到首格。
	for i in range(mini(visible_cards.size(), cards_placeholder.size())):
		var visible_card := visible_cards[i]
		var target_placeholder: Control = cards_placeholder[i]
		if visible_card.get_parent() != target_placeholder:
			visible_card.reparent(target_placeholder, false)
		visible_card.position = Vector2.ZERO
	for card in curr_cards:
		if not _is_valid_card(card):
			continue
		var is_on_current_page := director_page_for_card(card) == director_current_page
		card.visible = is_on_current_page
		if Global.main_game.main_game_progress == MainGameManager.E_MainGameProgress.MAIN_GAME:
			if is_on_current_page:
				card.set_shortcut((visible_cards.find(card) + 1) % 10)
			else:
				card.set_shortcut_disappear()
	if is_instance_valid(Global.main_game) \
	and is_instance_valid(Global.main_game.card_manager) \
	and is_instance_valid(Global.main_game.card_manager.card_slot_root):
		Global.main_game.card_manager.card_slot_root.curr_cards = visible_cards
	judge_disappear_add_card_bar()

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
		if not director_pages_enabled:
			card.set_shortcut((i+1)%10)
	if director_pages_enabled:
		refresh_director_card_page()
	judge_disappear_add_card_bar()

## 开始下一轮出战卡槽更新数据
func start_next_game_card_slot_battle_update():
	_remove_invalid_curr_cards()
	for i in range(curr_cards.size()):
		var card:Card = curr_cards[i]
		if card.is_echo_imitater_card():
			card.clear_echo_imitater_target()
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
	_update_echo_imitater_targets_from_used_card(card)


func _update_echo_imitater_targets_from_used_card(used_card:Card) -> void:
	## Echo 只记录刚刚成功使用的普通植物卡；模仿卡和僵尸卡不能递归成为目标。
	if not is_instance_valid(used_card) \
	or used_card.card_plant_type == CharacterRegistry.PlantType.Null \
	or used_card.is_imitater \
	or used_card.is_echo_imitater_card() \
	or used_card.card_plant_type == CharacterRegistry.PlantType.P1499Imitater:
		return
	var target_plant_type := used_card.get_gameplay_plant_type()
	for echo_card:Card in curr_cards:
		if not is_instance_valid(echo_card) or not echo_card.is_echo_imitater_card():
			continue
		if echo_card.bind_echo_imitater_target(target_plant_type):
			if is_instance_valid(Global.main_game):
				echo_card.judge_sun_enough(sun_value)

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
	var visible_card_count := curr_cards.size()
	if director_pages_enabled:
		visible_card_count = director_cards_on_page(director_current_page).size()
	## 在游戏进行阶段
	if Global.main_game.main_game_progress == MainGameManager.E_MainGameProgress.MAIN_GAME:
		if Global.config_service.disappear_spare_card_Placeholder:
			if director_pages_enabled:
				for i in range(cards_placeholder.size()):
					cards_placeholder[i].visible = i < visible_card_count
				return
			if visible_card_count < cards_placeholder.size():
				for i in range(visible_card_count, cards_placeholder.size()):
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
		var gameplay_plant_type := card.get_gameplay_plant_type()
		if card.is_purple_card and Global.main_game.plant_cell_manager.curr_plant_num.has(gameplay_plant_type):
			card.sun_cost = Global.character_registry.get_plant_info(gameplay_plant_type, CharacterRegistry.PlantInfoAttribute.SunCost) + 50 * Global.main_game.plant_cell_manager.curr_plant_num[gameplay_plant_type]
			card.judge_sun_enough(sun_value)

func _remove_invalid_curr_cards() -> void:
	for i in range(curr_cards.size() - 1, -1, -1):
		var card: Card = curr_cards[i]
		if not _is_valid_card(card):
			if is_instance_valid(card):
				card.queue_free()
			curr_cards.remove_at(i)

func _is_valid_card(card: Card) -> bool:
	var availability_plant_type := card.get_availability_plant_type() \
		if is_instance_valid(card) else CharacterRegistry.PlantType.Null
	return is_instance_valid(card) \
		and (
			card.card_plant_type != CharacterRegistry.PlantType.Null \
			or card.card_zombie_type != CharacterRegistry.ZombieType.Null
			) \
		and (
			not Global.main_game.game_para.adventure_card_lock_active \
			or availability_plant_type == CharacterRegistry.PlantType.Null \
			or RewardCardRuntime.is_plant_available_in_level(
				int(availability_plant_type),
				Global.main_game.game_para.level_id,
				Global.main_game.game_para.available_plant_types.has(availability_plant_type),
				Global.main_game.game_para.special_reward_card_source_dir
			)
		)
