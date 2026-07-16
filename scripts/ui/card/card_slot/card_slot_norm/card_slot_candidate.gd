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

	_add_plant_card_page(AllCards.all_plant_cards_parent_node_root[0])
	_add_zombie_card_page(AllCards.all_zombie_cards_parent_node_root[0])
	_add_plant_card_page(AllCards.all_plant_cards_parent_node_root[1])
	_add_plant_card_page(AllCards.all_plant_cards_parent_node_root[2])
	_add_zombie_card_page(AllCards.all_zombie_cards_parent_node_root[1])

	grid_container_plant.queue_free()
	grid_container_zombie.queue_free()


func _add_plant_card_page(cards_parent_node:GridContainer):
	var ordered_cards:Array[Card] = []
	for node in cards_parent_node.get_children():
		var card := node as Card
		if card == null or card.card_plant_type == CharacterRegistry.PlantType.Null:
			continue
		if _adventure_card_lock_active() and not _is_adventure_plant_available(card.card_plant_type):
			continue
		# 非冒险锁定的棋盘格场景也只提供 500+ 的原版植物。
		if not _adventure_card_lock_active() and _is_chessboard_mode() and (int(card.card_plant_type) < 500 or int(card.card_plant_type) >= 1000):
			continue
		ordered_cards.append(card)

	_add_card_page(grid_container_plant, ordered_cards, all_card_candidate_containers_plant)


func _add_zombie_card_page(cards_parent_node:GridContainer):
	## 两条冒险主线都是植物选卡，棋盘格也不提供友军僵尸卡。
	if _adventure_card_lock_active():
		return
	var ordered_cards:Array[Card] = []
	for node in cards_parent_node.get_children():
		var card := node as Card
		if card == null or card.card_zombie_type == CharacterRegistry.ZombieType.Null:
			continue
		ordered_cards.append(card)

	_add_card_page(grid_container_zombie, ordered_cards, all_card_candidate_containers_zombie)


func _add_card_page(page_template:GridContainer, ordered_cards:Array[Card], card_candidate_containers:Dictionary[int, CardCandidateContainer]):
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
		if not _adventure_card_lock_active() and _is_chessboard_mode() and (int(plant_type) < 500 or int(plant_type) >= 1000):
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


func _adventure_card_lock_active() -> bool:
	return is_instance_valid(Global.main_game) and Global.main_game.game_para.adventure_card_lock_active


func _is_adventure_plant_available(plant_type: CharacterRegistry.PlantType) -> bool:
	return Global.main_game.game_para.available_plant_types.has(plant_type)


## 上一页
func _on_last_page_button_pressed() -> void:
	change_page(-1)

## 下一页
func _on_next_page_button_pressed() -> void:
	change_page(1)


func change_page(change_num:int= 1):
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
