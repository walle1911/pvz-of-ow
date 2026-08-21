extends TextureRect
## 待选卡槽
class_name CardSlotCandidate


## 所有卡片页面的父节点
@onready var all_card_page: Control = $AllCardPage
## 卡片Grid
@onready var grid_container_plant: GridContainer = $AllCardPage/GridContainerPlant
@onready var grid_container_zombie: GridContainer = $AllCardPage/GridContainerZombie

## 所有的备选卡片
var all_card_candidate_containers_plant:Dictionary[int, CardCandidateContainer] = {}
var all_card_candidate_containers_zombie:Dictionary[int, CardCandidateContainer] = {}

## 所有的卡片页面列表
var all_card_page_array:Array[GridContainer] =[]
## 当前页
var curr_page := 0
## 可以显示的页面
var all_show_page:Array[GridContainer] =[]
## 当前页码显示
@onready var label_page: Label = $LabelPage


## 模仿者卡槽对应的父节点
@onready var all_imitater_card: Control = %AllImitaterCard
## 模仿者卡片页面的父节点
@onready var all_card_page_imitater: Control = $AllImitaterCard/Panel/AllCardPageImitater
## 模仿者卡片Grid
@onready var grid_container_plant_imitater: GridContainer = $AllImitaterCard/Panel/AllCardPageImitater/GridContainerPlantImitater


## 所有的模仿者备选卡片
var all_card_candidate_containers_plant_imitater:Dictionary[int, CardCandidateContainer] = {}
## 模仿者卡片背景
@onready var imitater_bg: TextureRect = $ImitaterBG
## 模仿者卡片
@onready var card_imitater: CardImitater = $ImitaterBG/CardImitater
## 所有的模仿者卡片页面列表
var all_card_page_array_imitater:Array[GridContainer] =[]
## 当前模仿者卡片页
var curr_page_imitater := 0
## 可以显示的页面
var all_show_page_imitater:Array[GridContainer] =[]

func _ready() -> void:
	_init_card_slot_candidate_pages()
	_init_card_slot_candidate_imitater()
	if _adventure_card_lock_active():
		imitater_bg.visible = false

	_init_card_page()

	curr_page_imitater = 0
	all_card_page_array_imitater[0].visible = true

	card_imitater.signal_card_click.connect(imitater_card_slot_appear)

## 初始化卡片页面，计算可以显示的页面
func _init_card_page():
	for card_page:GridContainer in all_card_page_array:
		var all_card_selected_placeholder = card_page.get_children()
		for card_selected_placeholder in all_card_selected_placeholder:
			if card_selected_placeholder.get_child_count() == 0:
				continue
			var card_candidate_container :CardCandidateContainer = card_selected_placeholder.get_child(0)
			if card_candidate_container.visible:
				all_show_page.append(card_page)
				break

	curr_page = 0
	all_show_page[0].visible = true

	label_page.text = str(1) + "/" + str(all_show_page.size())

	for card_page:GridContainer in all_card_page_array_imitater:
		var all_card_selected_placeholder = card_page.get_children()
		for card_selected_placeholder in all_card_selected_placeholder:
			if card_selected_placeholder.get_child_count() == 0:
				continue
			var card_candidate_container :CardCandidateContainer = card_selected_placeholder.get_child(0)
			if card_candidate_container.visible:
				all_show_page_imitater.append(card_page)
				break

## 初始化生成正式选卡页
func _init_card_slot_candidate_pages():
	all_card_page.remove_child(grid_container_plant)
	all_card_page.remove_child(grid_container_zombie)

	var ordered_plant_cards := _collect_plant_cards()
	if _adventure_card_lock_active():
		## available_plant_types 按关卡逐步获得卡片的顺序生成；冒险待选卡槽沿用该顺序。
		ordered_plant_cards.sort_custom(_sort_adventure_card_by_acquisition_order)
	else:
		ordered_plant_cards.sort_custom(_sort_card_by_id)
	## 冒险关只展示本关卡池，数量通常不满一页；此时保持连续排布，
	## 避免仅有一张原版卡（例如 1-10 的土豆地雷）被单独拆到第二页。
	if _adventure_card_lock_active():
		_add_card_pages(grid_container_plant, ordered_plant_cards, all_card_candidate_containers_plant)
	else:
		_add_grouped_plant_pages(ordered_plant_cards)

	var ordered_zombie_cards := _collect_zombie_cards()
	ordered_zombie_cards.sort_custom(_sort_card_by_id)
	_add_card_pages(grid_container_zombie, ordered_zombie_cards, all_card_candidate_containers_zombie)

	grid_container_plant.queue_free()
	grid_container_zombie.queue_free()


func _add_grouped_plant_pages(ordered_plant_cards: Array[Card]) -> void:
	var ow_plant_cards:Array[Card] = []
	var original_plant_cards:Array[Card] = []
	for card in ordered_plant_cards:
		if _is_pvz_original_plant_type(card.card_plant_type):
			original_plant_cards.append(card)
		else:
			ow_plant_cards.append(card)
	## 两类植物从新页面开始，避免按容量切页时把 OW 改版卡和原版卡混在同一页。
	_add_card_pages(grid_container_plant, ow_plant_cards, all_card_candidate_containers_plant)
	_add_card_pages(grid_container_plant, original_plant_cards, all_card_candidate_containers_plant)


func _collect_plant_cards() -> Array[Card]:
	var ordered_cards:Array[Card] = []
	for cards_parent_node:GridContainer in AllCards.all_plant_cards_parent_node_root:
		for node in cards_parent_node.get_children():
			var card := node as Card
			if card == null or card.card_plant_type == CharacterRegistry.PlantType.Null:
				continue
			if _adventure_card_lock_active() and not _is_adventure_plant_available(card.card_plant_type):
				continue
			# 非冒险锁定的棋盘格场景也只提供 500+ 的原版植物。
			if not _adventure_card_lock_active() and _is_chessboard_mode() and not _is_original_plant_type(card.card_plant_type):
				continue
			ordered_cards.append(card)
	return ordered_cards


func _collect_zombie_cards() -> Array[Card]:
	## 两条冒险主线都是植物选卡，棋盘格也不提供友军僵尸卡。
	if _adventure_card_lock_active() or _is_chessboard_mode():
		return []
	var ordered_cards:Array[Card] = []
	for cards_parent_node:GridContainer in AllCards.all_zombie_cards_parent_node_root:
		for node in cards_parent_node.get_children():
			var card := node as Card
			if card == null or card.card_zombie_type == CharacterRegistry.ZombieType.Null:
				continue
			ordered_cards.append(card)
	return ordered_cards


func _sort_card_by_id(card_a:Card, card_b:Card) -> bool:
	return card_a.card_id < card_b.card_id


func _sort_adventure_card_by_acquisition_order(card_a: Card, card_b: Card) -> bool:
	var available_plants: Array[CharacterRegistry.PlantType] = Global.main_game.game_para.available_plant_types
	var order_a: int = available_plants.find(card_a.card_plant_type)
	var order_b: int = available_plants.find(card_b.card_plant_type)
	## 限定卡等独立投放卡不一定写入普通卡池，统一接在关卡卡片之后并保持原卡册顺序。
	if order_a < 0:
		order_a = available_plants.size() + card_a.card_id
	if order_b < 0:
		order_b = available_plants.size() + card_b.card_id
	return order_a < order_b


func _add_card_pages(page_template:GridContainer, ordered_cards:Array[Card], card_candidate_containers:Dictionary[int, CardCandidateContainer]):
	if ordered_cards.is_empty():
		return
	var cards_per_page := page_template.get_child_count()
	if cards_per_page <= 0:
		return
	var page_start := 0
	while page_start < ordered_cards.size():
		var new_grid_container:GridContainer = page_template.duplicate()
		all_card_page.add_child(new_grid_container)
		all_card_page_array.append(new_grid_container)
		new_grid_container.visible = false

		var all_card_selected_placeholder:Array = new_grid_container.get_children()
		var cards_on_page := mini(cards_per_page, ordered_cards.size() - page_start)
		for page_card_i:int in cards_on_page:
			var curr_card:Card = ordered_cards[page_start + page_card_i]
			var new_card:Card = curr_card.duplicate()
			var card_candidate_container:CardCandidateContainer = SceneRegistry.CARD_CANDIDATE_CONTAINER.instantiate()

			card_candidate_container.init_card_in_seed_chooser(new_card)
			all_card_selected_placeholder[page_card_i].add_child(card_candidate_container)
			card_candidate_containers[curr_card.card_id] = card_candidate_container
			card_candidate_container.visible = true
		page_start += cards_on_page

## 初始化生成模仿者待选卡槽
func _init_card_slot_candidate_imitater():
	## 每一页的卡片数量
	var num_card_every_page = grid_container_plant_imitater.get_child_count()
	all_card_page_imitater.remove_child(grid_container_plant_imitater)
	## 当前页面的所有卡片占位
	var all_card_selected_placeholder:Array
	var curr_num_page_imitater:=-1
	for idx:int in Global.global_game_state.curr_plant.size():
		var plant_type = Global.global_game_state.curr_plant[idx]
		if _adventure_card_lock_active() and not _is_adventure_plant_available(plant_type):
			continue
		if not _adventure_card_lock_active() and _is_chessboard_mode() and not _is_original_plant_type(plant_type):
			continue
		if not AllCards.all_plant_card_prefabs.has(plant_type):
			continue
		var page_i:int
		if idx < 25:
			page_i = 0
		else:
			page_i = 1 + int(float(idx - 25) / num_card_every_page)
		if curr_num_page_imitater < page_i:
			curr_num_page_imitater += 1
			var new_grid_container = grid_container_plant_imitater.duplicate()
			all_card_page_imitater.add_child(new_grid_container)
			all_card_page_array_imitater.append(new_grid_container)
			new_grid_container.visible = false
			## 当前页面的所有卡片占位
			all_card_selected_placeholder = new_grid_container.get_children()
		## 当前植物类型对应的card
		var curr_plant_card = AllCards.all_plant_card_prefabs[plant_type]
		var new_card = curr_plant_card.duplicate()
		new_card.is_imitater = true
		var card_candidate_container: CardCandidateContainer = SceneRegistry.CARD_CANDIDATE_CONTAINER.instantiate()

		card_candidate_container.init_card_in_seed_chooser(new_card)
		all_card_selected_placeholder[curr_plant_card.card_id % num_card_every_page].add_child(card_candidate_container)
		all_card_candidate_containers_plant_imitater[curr_plant_card.card_id] = card_candidate_container

		card_candidate_container.visible = true

	grid_container_plant_imitater.queue_free()


func _is_chessboard_mode() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.get_node_or_null(^"ChessboardMode") != null


func _is_original_plant_type(plant_type: CharacterRegistry.PlantType) -> bool:
	return (int(plant_type) >= 500 and int(plant_type) < 1000) \
		or plant_type == CharacterRegistry.PlantType.P1499Imitater


func _is_pvz_original_plant_type(plant_type: CharacterRegistry.PlantType) -> bool:
	## 原版 PVZ 的 48 种植物恰好占满一页；P549 反向双发和其他特殊植物归入 OW 改版页。
	return int(plant_type) >= int(CharacterRegistry.PlantType.P501PeaShooterSingle) \
		and int(plant_type) <= int(CharacterRegistry.PlantType.P548CobCannon)


func _adventure_card_lock_active() -> bool:
	return is_instance_valid(Global.main_game) and Global.main_game.game_para.adventure_card_lock_active


func _is_adventure_plant_available(plant_type: CharacterRegistry.PlantType) -> bool:
	return RewardCardRuntime.is_plant_available_in_level(
		int(plant_type),
		Global.main_game.game_para.level_id,
		Global.main_game.game_para.available_plant_types.has(plant_type),
		Global.main_game.game_para.special_reward_card_source_dir
	)


## 上一页
func _on_last_page_button_pressed() -> void:
	change_page(-1)

## 下一页
func _on_next_page_button_pressed() -> void:
	change_page(1)


func change_page(change_num:int= 1):
	if all_show_page.is_empty():
		return
	all_show_page[curr_page].visible = false
	curr_page += change_num + all_show_page.size()
	curr_page %= all_show_page.size()
	all_show_page[curr_page].visible = true

	label_page.text = str(curr_page + 1) + "/" + str(all_show_page.size())
## 模仿者卡槽出现
func imitater_card_slot_appear():
	all_imitater_card.visible = true

## 模仿者卡槽隐藏
func imitater_card_slot_disappear():
	all_imitater_card.visible = false

## 模仿者卡片被选中时
func imitater_be_choosed() -> void:
	imitater_card_slot_disappear()
	card_imitater.imitater_card_be_choosed()

## 模仿者卡片被选中取消时
func imitater_be_choosed_cancel() -> void:
	card_imitater.imitater_card_be_choosed_cancal()



#region 模仿者页面翻页
func _on_imitater_last_page_button_pressed() -> void:
	change_page_imitater(-1)


func _on_imitater_next_page_button_pressed() -> void:
	change_page_imitater(1)


func change_page_imitater(change_num:int= 1):
	all_show_page_imitater[curr_page_imitater].visible = false
	curr_page_imitater += change_num + all_show_page_imitater.size()
	curr_page_imitater %= all_show_page_imitater.size()
	all_show_page_imitater[curr_page_imitater].visible = true
#endregion
