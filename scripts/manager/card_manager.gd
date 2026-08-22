extends MainGameSubManager
class_name CardManager

@onready var card_slot_root: CardSlotRoot = %CardSlotRoot
@onready var card_slot_container: PanelContainer = %CardSlotContainer
@onready var canvas_layer_card_slot_front: CanvasLayer = %CanvasLayerCardSlotFront

## 普通卡槽
var card_slot_norm: CardSlotNorm
var card_slot_battle:CardSlotBattle
## 普通卡槽是否已出现
var is_norm_appeared:=false

## 传送带卡槽
var card_slot_conveyor_belt: CardSlotConveyorBelt
## 排位模式独立奖励卡槽；横向放在铲子右侧。
var ranked_reward_card_slot:RankedRewardCardSlot

## 金币卡槽
var card_slot_coin: CardSlotCoin
var card_slot_battle_coin: CardSlotBattleCoin

var card_mode:ConstLevelData.E_CardMode

## 是否有种子雨
var is_seed_rain:bool = false
## 种子雨卡槽
var card_slot_seed_rain :CardSlotSeedRain

## 是否有铲子
var is_shovel:=true

## 当前临时卡片
var curr_temp_cards:Array[Card]
## 当前手持的临时卡片
var curr_temp_card_in_hm:Card
## 手持管理器取消卡片
signal signal_hm_character_clear_card(card:Card)

func _ready():
	EventBus.subscribe("hm_character_clear_card", _on_hm_character_clear_card)
	EventBus.subscribe("hm_character_hand_card", _on_hm_character_hand_card)

## 当手持管理器拿到新卡片时
func _on_hm_character_hand_card(curr_card:Card):
	curr_temp_card_in_hm = curr_card
	for temp_card in curr_temp_cards:
		temp_card.mouse_filter_stop()

## 当手持管理器清除当前手持卡片数据时
func _on_hm_character_clear_card(curr_card:Card):
	signal_hm_character_clear_card.emit(curr_card)
	for temp_card in curr_temp_cards:
		temp_card.mouse_filter_start()

func init_manager() -> void:
	self.card_mode = game_para.card_mode
	self.is_shovel = game_para.is_shovel
	self.is_seed_rain = game_para.is_seed_rain
	if game_para.is_seed_rain:
		card_slot_seed_rain = load("res://scenes/card_slot/card_slot_seed_rain.tscn").instantiate()
		canvas_layer_card_slot_front.add_child(card_slot_seed_rain)
		card_slot_seed_rain.init_card_slot_seed_rain(game_para)

	match self.card_mode:
		ConstLevelData.E_CardMode.Norm:
			var card_slot_scene := load("res://scenes/card_slot/card_slot_norm.tscn") as PackedScene
			card_slot_norm = card_slot_scene.instantiate()
			card_slot_root.add_child(card_slot_norm)
			card_slot_norm.init_card_slot_norm(game_para)
			card_slot_battle = card_slot_norm.card_slot_battle
			card_slot_root.curr_cards = card_slot_battle.curr_cards

		ConstLevelData.E_CardMode.ConveyorBelt:
			card_slot_conveyor_belt = load("res://scenes/card_slot/card_slot_conveyor_belt.tscn").instantiate()
			card_slot_root.add_child(card_slot_conveyor_belt)
			card_slot_conveyor_belt.init_card_slot_conveyor_belt(game_para)
			card_slot_root.curr_cards = card_slot_conveyor_belt.curr_cards

		ConstLevelData.E_CardMode.Coin:
			card_slot_coin = load("res://scenes/card_slot/card_slot_coin.tscn").instantiate()
			card_slot_root.add_child(card_slot_coin)
			card_slot_coin.init_card_slot_coin(game_para)
			card_slot_battle_coin = card_slot_coin.card_slot_battle_coin
			card_slot_root.curr_cards = card_slot_battle_coin.curr_cards
	if game_para.is_ranked_mode:
		ranked_reward_card_slot = load("res://scenes/card_slot/ranked_reward_card_slot.tscn").instantiate()
		ranked_reward_card_slot.name = "RankedRewardCardSlot"
		canvas_layer_card_slot_front.add_child(ranked_reward_card_slot)
		ranked_reward_card_slot.visible = false

## 开始下一轮游戏更新卡片管理器
func start_next_game_card_manager_update():
	card_slot_root.ui_shovel.visible = false
	if is_instance_valid(ranked_reward_card_slot):
		ranked_reward_card_slot.visible = false
	if is_seed_rain:
		card_slot_seed_rain.pause_seed_rain()

	match self.card_mode:
		ConstLevelData.E_CardMode.Norm:
			card_slot_battle.reparent(card_slot_norm)
			card_slot_battle.start_next_game_card_slot_battle_update()

		ConstLevelData.E_CardMode.ConveyorBelt:
			pass

		ConstLevelData.E_CardMode.Coin:
			pass


## 卡槽出现(选卡)
func card_slot_appear_choose():
	is_norm_appeared = true
	card_slot_norm.move_card_slot_battle(true)
	card_slot_norm.move_card_slot_candidate(true)

## 卡槽出现（主游戏阶段开始）
func card_slot_update_main_game():
	if is_seed_rain:
		card_slot_seed_rain.start_seed_rain()

	match self.card_mode:
		ConstLevelData.E_CardMode.Norm:
			if not is_norm_appeared:
				await card_slot_norm.move_card_slot_battle(true)
			#card_slot_norm.remove_child(card_slot_battle)
			#card_slot_container.add_child(card_slot_battle)
			card_slot_battle.reparent(card_slot_container)
			card_slot_battle.main_game_refresh_card()
			for card: Card in card_slot_battle.curr_cards:
				card.card_change_cool_time(card.cool_time * maxf(0.0, game_para.card_cooldown_multiplier))
			## 测试模式卡片没有冷却
			if Global.main_game.is_test:
				for card in card_slot_battle.curr_cards:
					card.card_change_cool_time(0)

		ConstLevelData.E_CardMode.ConveyorBelt:
			await card_slot_conveyor_belt.move_card_slot_conveyor_belt(true)
			#card_slot_root.remove_child(card_slot_conveyor_belt)
			#card_slot_container.add_child(card_slot_conveyor_belt)
			card_slot_conveyor_belt.reparent(card_slot_container)
			card_slot_conveyor_belt.start_conveyor_belt()
		ConstLevelData.E_CardMode.Coin:
			if not is_norm_appeared:
				await card_slot_coin.move_card_slot_battle(true)
			#card_slot_coin.remove_child(card_slot_battle_coin)
			#card_slot_container.add_child(card_slot_battle_coin)
			card_slot_battle_coin.reparent(card_slot_container)
			card_slot_battle_coin.main_game_refresh_card()
			## 测试模式卡片没有冷却
			if Global.main_game.is_test:
				for card in card_slot_battle_coin.curr_cards:
					card.card_change_cool_time(0)
	if is_shovel:
		card_slot_root.ui_shovel.visible = true
	if is_instance_valid(ranked_reward_card_slot):
		await get_tree().process_frame
		_layout_ranked_reward_card_slot()
		ranked_reward_card_slot.visible = true

func _layout_ranked_reward_card_slot() -> void:
	if not is_instance_valid(ranked_reward_card_slot) or not is_instance_valid(card_slot_battle):
		return
	var shovel_rect := card_slot_root.ui_shovel.get_global_rect()
	var battle_rect := card_slot_battle.get_global_rect()
	ranked_reward_card_slot.global_position = Vector2(shovel_rect.end.x, battle_rect.position.y)

func enqueue_ranked_plant_reward(plant_type:CharacterRegistry.PlantType) -> void:
	if is_instance_valid(ranked_reward_card_slot):
		ranked_reward_card_slot.enqueue_ranked_reward(&"plant", int(plant_type))

func enqueue_ranked_zombie_reward(zombie_type:CharacterRegistry.ZombieType) -> void:
	if is_instance_valid(ranked_reward_card_slot):
		ranked_reward_card_slot.enqueue_ranked_reward(&"zombie", int(zombie_type))

## 待选卡槽卡槽消失
func card_slot_disappear_choose():
	await card_slot_norm.move_card_slot_candidate(false)

#region 临时卡片
enum E_TempCardParaAttr{
	PlantType,
	ZombieType,
	GlobalPos,
	ExistTime,	## 存在时间，若没有，则永久存在
}

## 创建临时卡片
func create_temp_card(temp_card_para:Dictionary) -> Card:
	var new_card_prefabs:Card
	if temp_card_para.has(E_TempCardParaAttr.PlantType) and temp_card_para[E_TempCardParaAttr.PlantType] != CharacterRegistry.PlantType.Null:
		new_card_prefabs = AllCards.all_plant_card_prefabs[temp_card_para[E_TempCardParaAttr.PlantType]]
	elif temp_card_para.has(E_TempCardParaAttr.ZombieType) and temp_card_para[E_TempCardParaAttr.ZombieType] !=  CharacterRegistry.ZombieType.Null:
		new_card_prefabs = AllCards.all_zombie_card_prefabs[temp_card_para[E_TempCardParaAttr.ZombieType]]
	else:
		print("error: 没有卡片类型")
		return
	var temp_card = new_card_prefabs.duplicate()
	curr_temp_cards.append(temp_card)
	canvas_layer_card_slot_front.add_child(temp_card)
	temp_card.global_position = temp_card_para.get(E_TempCardParaAttr.GlobalPos, Vector2(100, 100))
	temp_card.signal_card_use_end.connect(card_use_end.bind(temp_card))

	if temp_card_para.has(E_TempCardParaAttr.ExistTime):
		temp_card_add_exist_timer(temp_card, temp_card_para[E_TempCardParaAttr.ExistTime])

	return temp_card

func temp_card_add_exist_timer(temp_card:Card, temp_card_exist_time:float):
	var temp_card_timer:Timer = Timer.new()
	temp_card_timer.autostart = false
	temp_card_timer.one_shot = true
	temp_card_timer.timeout.connect(_on_temp_card_timer_timeout.bind(temp_card))
	temp_card.add_child(temp_card_timer)
	temp_card_timer.start(temp_card_exist_time)

func _on_temp_card_timer_timeout(temp_card:Card):
	temp_card.card_blink_start()
	## 五秒闪烁后消失
	await get_tree().create_timer(5.0, false).timeout
	if curr_temp_card_in_hm == temp_card:
		await signal_hm_character_clear_card
	## 如果还未被使用
	if is_instance_valid(temp_card):
		card_use_end(temp_card)

func card_use_end(card:Card):
	if not card.is_queued_for_deletion():
		curr_temp_cards.erase(card)
		card.queue_free()

#endregion

#region 存档
func get_save_game_data_card_manager()->Dictionary:
	var save_game_data_card_manager:Dictionary = {}
	match self.card_mode:
		ConstLevelData.E_CardMode.Norm:
			save_game_data_card_manager["curr_sun_value"] = card_slot_battle.sun_value
			## Boss 检查点会重新实例化整张主游戏场景，必须一并保存本局实际出战卡。
			## 两个数组按相同下标对齐，Null 表示该位置属于另一种角色类型。
			var selected_plant_types:Array[int] = []
			var selected_zombie_types:Array[int] = []
			for card:Card in card_slot_battle.curr_cards:
				if not is_instance_valid(card):
					continue
				selected_plant_types.append(int(card.card_plant_type))
				selected_zombie_types.append(int(card.card_zombie_type))
			save_game_data_card_manager["selected_plant_types"] = selected_plant_types
			save_game_data_card_manager["selected_zombie_types"] = selected_zombie_types
	return save_game_data_card_manager

func load_game_data_card_manager(save_game_data_card_manager:Dictionary):
	match self.card_mode:
		ConstLevelData.E_CardMode.Norm:
			card_slot_battle.sun_value = save_game_data_card_manager["curr_sun_value"]

#endregion
