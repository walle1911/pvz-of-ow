extends Control
## 正常卡槽
class_name CardSlotNorm


## 临时卡片存放节点，避免卡片被挡住
@onready var temporary_card: Control = $TemporaryCard
## 待选卡槽
@onready var card_slot_candidate: CardSlotCandidate = $CardSlotCandidate
## 出战卡槽节点
@onready var card_slot_battle: CardSlotBattle = $CardSlotBattle
var director_pages_enabled := false


## 初始化出战卡槽，管理器调用
func init_card_slot_norm(game_para:ResourceLevelData):
	var initial_card_slot_num := game_para.max_choosed_card_num
	if is_instance_valid(Global.main_game) \
	and Global.main_game.is_test \
	and Global.main_game.test_dynamic_card_slot_expansion:
		initial_card_slot_num = Global.main_game.test_max_choosed_card_num
	card_slot_battle.init_card_slot_battle(
		game_para.max_choosed_card_num,
		game_para.start_sun,
		initial_card_slot_num
	)

	for i in card_slot_candidate.all_card_candidate_containers_plant:
		var card:Card = card_slot_candidate.all_card_candidate_containers_plant[i].card
		card.signal_card_click.connect(_on_card_click.bind(card))
	for i in card_slot_candidate.all_card_candidate_containers_zombie:
		var card:Card = card_slot_candidate.all_card_candidate_containers_zombie[i].card
		card.signal_card_click.connect(_on_card_click.bind(card))
	for i in card_slot_candidate.all_card_candidate_containers_plant_imitater:
		var card:Card = card_slot_candidate.all_card_candidate_containers_plant_imitater[i].card
		card.signal_card_click.connect(_on_imitater_card_click.bind(card))

	## 初始化预选卡
	if game_para.pre_choosed_card_list_plant or game_para.pre_choosed_card_list_zombie:
		init_pre_choosed_card(game_para.pre_choosed_card_list_plant, game_para.pre_choosed_card_list_zombie)


func enable_director_card_pages() -> void:
	director_pages_enabled = true
	card_slot_battle.enable_director_card_pages()


func toggle_director_card_page() -> bool:
	if not director_pages_enabled:
		return false
	return card_slot_battle.toggle_director_card_page()

# 重选上次卡片
func _on_re_card_button_pressed() -> void:
	Global.save_service.load_selected_cards()
	var previous_director_page := card_slot_battle.director_current_page
	for card_type_data:Dictionary in Global.global_game_state.selected_cards:
		if card_type_data.has("plant_type"):
			if director_pages_enabled:
				card_slot_battle.show_director_card_page(0)
			var plant_type:CharacterRegistry.PlantType = card_type_data["plant_type"]
			## 如果是模仿者
			if card_type_data.get("is_imitater", false):
				## 未选择模仿者时
				if not card_slot_candidate.card_imitater.is_be_choosed_imitater:
					var plant_imitater_container := _get_candidate_plant_container(plant_type, true)
					if plant_imitater_container != null:
						plant_imitater_container.card._on_button_pressed()
			else:
				var plant_container := _get_candidate_plant_container(plant_type)
				if plant_container != null and not plant_container.card.is_choosed_pre_card:
					plant_container.card._on_button_pressed()

		elif card_type_data.has("zombie_type"):
			if director_pages_enabled:
				card_slot_battle.show_director_card_page(1)
			var zombie_type:CharacterRegistry.ZombieType = card_type_data["zombie_type"]
			var zombie_container := _get_candidate_zombie_container(zombie_type)
			if zombie_container != null and not zombie_container.card.is_choosed_pre_card:
				zombie_container.card._on_button_pressed()
	if director_pages_enabled:
		card_slot_battle.show_director_card_page(previous_director_page)



## 取消所有已选卡片
func _on_cancal_card_button_pressed() -> void:
	for i in range(card_slot_battle.curr_cards.size()-1, -1, -1):
		var card: Card = card_slot_battle.curr_cards[i]
		if _is_valid_card(card):
			card._on_button_pressed()

## 开始游戏按钮
func _on_texture_button_pressed() -> void:
	## 卡槽正常选卡结束开始游戏
	EventBus.push_event("card_slot_norm_start_game")
	#card_disconnect_click_in_choose()
	## 保存上次选卡
	Global.global_game_state.selected_cards.clear()
	for card:Card in card_slot_battle.curr_cards:
		if not _is_valid_card(card):
			continue
		var card_type_data:={}
		if card.card_plant_type != CharacterRegistry.PlantType.Null:
			card_type_data["plant_type"] = card.card_plant_type
			if card.is_imitater:
				card_type_data["is_imitater"] = true
		elif card.card_zombie_type != CharacterRegistry.ZombieType.Null:
			card_type_data["zombie_type"] = card.card_zombie_type
		else:
			print("error:当前卡牌类型不为植物也不为僵尸")
			continue
		Global.global_game_state.selected_cards.append(card_type_data)

	Global.save_service.save_selected_cards()

## 初始化系统预选卡
## 从AllCards中复制一张新卡,隐藏card_slot_candidate的卡片
func init_pre_choosed_card(card_type_list:Array[CharacterRegistry.PlantType], card_type_list_zombie:Array[CharacterRegistry.ZombieType]):
	for i in card_type_list.size():
		if card_slot_battle.curr_cards.size() >= card_slot_battle.card_selection_limit:
			push_warning("预选卡超过当前关卡选卡上限，已跳过后续卡片")
			break
		var card:Card
		var plant_type:CharacterRegistry.PlantType = card_type_list[i]
		var zombie_type:CharacterRegistry.ZombieType = card_type_list_zombie[i]
		var character_type:CharacterRegistry.CharacterType = GlobalUtils.get_character_type(plant_type, zombie_type)
		match character_type:
			CharacterRegistry.CharacterType.Plant:
				var plant_container := _get_candidate_plant_container(plant_type)
				var plant_card_prefab := _get_plant_card_prefab(plant_type)
				if plant_container == null or plant_card_prefab == null:
					continue
				plant_container.card.visible = false
				plant_container.card.is_choosed_pre_card = true
				card = plant_card_prefab.duplicate()
			CharacterRegistry.CharacterType.Zombie:
				var zombie_container := _get_candidate_zombie_container(zombie_type)
				var zombie_card_prefab := _get_zombie_card_prefab(zombie_type)
				if zombie_container == null or zombie_card_prefab == null:
					continue
				zombie_container.card.visible = false
				zombie_container.card.is_choosed_pre_card = true
				card = zombie_card_prefab.duplicate()
			CharacterRegistry.CharacterType.Null:
				continue

		# 如果卡槽已满，动态扩展
		if card_slot_battle.curr_cards.size() >= card_slot_battle.cards_placeholder.size():
			var new_placeholder := card_slot_battle.add_card_placeholder()
			if not is_instance_valid(new_placeholder):
				break
		card_slot_battle.curr_cards.append(card)
		pre_choosed_card(card, card_slot_battle.cards_placeholder[len(card_slot_battle.curr_cards)-1])
	## 预选卡断开鼠标点击信号
	card_disconnect_click_in_choose()

func _get_candidate_plant_container(plant_type: CharacterRegistry.PlantType, is_imitater := false) -> CardCandidateContainer:
	if not AllCards.plant_card_ids.has(plant_type):
		push_warning("跳过不存在的植物卡片编号: %s" % plant_type)
		return null
	var card_id: int = AllCards.plant_card_ids[plant_type]
	var containers: Dictionary = card_slot_candidate.all_card_candidate_containers_plant_imitater if is_imitater else card_slot_candidate.all_card_candidate_containers_plant
	if not containers.has(card_id):
		push_warning("跳过不存在的植物卡槽编号: %s" % card_id)
		return null
	return containers[card_id]

func _get_candidate_zombie_container(zombie_type: CharacterRegistry.ZombieType) -> CardCandidateContainer:
	if not AllCards.zombie_card_ids.has(zombie_type):
		push_warning("跳过不存在的僵尸卡片编号: %s" % zombie_type)
		return null
	var card_id: int = AllCards.zombie_card_ids[zombie_type]
	if not card_slot_candidate.all_card_candidate_containers_zombie.has(card_id):
		push_warning("跳过不存在的僵尸卡槽编号: %s" % card_id)
		return null
	return card_slot_candidate.all_card_candidate_containers_zombie[card_id]

func _get_plant_card_prefab(plant_type: CharacterRegistry.PlantType) -> Card:
	if not AllCards.all_plant_card_prefabs.has(plant_type):
		push_warning("跳过不存在的植物卡片预制: %s" % plant_type)
		return null
	return AllCards.all_plant_card_prefabs[plant_type]

func _get_zombie_card_prefab(zombie_type: CharacterRegistry.ZombieType) -> Card:
	if not AllCards.all_zombie_card_prefabs.has(zombie_type):
		push_warning("跳过不存在的僵尸卡片预制: %s" % zombie_type)
		return null
	return AllCards.all_zombie_card_prefabs[zombie_type]

## 游戏选卡阶段时，卡片被点击
func _on_card_click(card:Card):
	if not _is_valid_card(card):
		return
	if Global.main_game.game_para.adventure_card_lock_active \
		and card.card_plant_type != CharacterRegistry.PlantType.Null \
		and not RewardCardRuntime.is_plant_available_in_level(
			int(card.card_plant_type),
			Global.main_game.game_para.level_id,
			Global.main_game.game_para.available_plant_types.has(card.card_plant_type),
			Global.main_game.game_para.special_reward_card_source_dir
		):
		return
	## 非选卡阶段直接返回
	if Global.main_game.main_game_progress != MainGameManager.E_MainGameProgress.CHOOSE_CARD\
		and Global.main_game.main_game_progress != MainGameManager.E_MainGameProgress.RE_CHOOSE_CARD:
		return
	if director_pages_enabled:
		_on_director_card_click(card)
		return
	## 达到当前关卡上限后，未选卡片不再响应点击；已选卡片仍可取消。
	if not card.is_choosed_pre_card \
	and card_slot_battle.curr_cards.size() >= card_slot_battle.card_selection_limit:
		return
	SoundManager.play_other_SFX("tap")
	# 如果card被选择，取消选取，后面的card向前移动
	if card.is_choosed_pre_card:
		card.is_choosed_pre_card = false
		card.visible = true
		var card_idx = card_slot_battle.curr_cards.find(card)
		card_slot_battle.curr_cards.erase(card)
		for i in range(card_idx, card_slot_battle.curr_cards.size()):
			move_card_to(card_slot_battle.curr_cards[i], card_slot_battle.cards_placeholder[i])
		move_card_to(card, card.card_candidate_container)

	## 如果没被选取，放在最后一位；达到当前关卡上限则拒绝选择。
	else:
		if card_slot_battle.curr_cards.size() >= card_slot_battle.cards_placeholder.size():
			var new_placeholder = card_slot_battle.add_card_placeholder()
			if not is_instance_valid(new_placeholder):
				return
		card.is_choosed_pre_card = true
		card_slot_battle.curr_cards.append(card)
		move_card_to(card, card_slot_battle.cards_placeholder[card_slot_battle.curr_cards.size()-1])


func _on_director_card_click(card: Card) -> void:
	var card_page := card_slot_battle.director_page_for_card(card)
	if not card.is_choosed_pre_card and card_page != card_slot_battle.director_current_page:
		SoundManager.play_other_SFX("buzzer")
		return
	SoundManager.play_other_SFX("tap")
	if card.is_choosed_pre_card:
		card.is_choosed_pre_card = false
		card.visible = true
		var page_cards := card_slot_battle.director_cards_on_page(card_page)
		var page_index := page_cards.find(card)
		card_slot_battle.curr_cards.erase(card)
		page_cards.erase(card)
		for i in range(maxi(page_index, 0), page_cards.size()):
			move_card_to(page_cards[i], card_slot_battle.cards_placeholder[i])
		await move_card_to(card, card.card_candidate_container)
	else:
		if card_slot_battle.director_page_is_full(card):
			SoundManager.play_other_SFX("buzzer")
			return
		var placeholder_index := card_slot_battle.director_placeholder_index_for_new_card(card)
		if placeholder_index >= card_slot_battle.cards_placeholder.size():
			var new_placeholder := card_slot_battle.add_card_placeholder()
			if not is_instance_valid(new_placeholder):
				return
		card.is_choosed_pre_card = true
		card_slot_battle.curr_cards.append(card)
		await move_card_to(card, card_slot_battle.cards_placeholder[placeholder_index])
	card_slot_battle.refresh_director_card_page()

## 游戏选卡阶段时，模仿者卡片被点击
func _on_imitater_card_click(card:Card):
	if not _is_valid_card(card):
		return
	if Global.main_game.game_para.adventure_card_lock_active \
		and card.card_plant_type != CharacterRegistry.PlantType.Null \
		and not RewardCardRuntime.is_plant_available_in_level(
			int(card.card_plant_type),
			Global.main_game.game_para.level_id,
			Global.main_game.game_para.available_plant_types.has(card.card_plant_type),
			Global.main_game.game_para.special_reward_card_source_dir
		):
		return
	## 非选卡阶段直接返回
	if Global.main_game.main_game_progress != MainGameManager.E_MainGameProgress.CHOOSE_CARD\
		and Global.main_game.main_game_progress != MainGameManager.E_MainGameProgress.RE_CHOOSE_CARD:
		return
	## 达到当前关卡上限后，未选模仿者卡片不再响应点击。
	if not card.is_choosed_pre_card \
	and (
		card_slot_battle.director_page_is_full(card)
		if director_pages_enabled
		else card_slot_battle.curr_cards.size() >= card_slot_battle.card_selection_limit
	):
		return
	if director_pages_enabled \
	and not card.is_choosed_pre_card \
	and card_slot_battle.director_current_page != 0:
		SoundManager.play_other_SFX("buzzer")
		return
	SoundManager.play_other_SFX("tap")
	# 如果card被选择，取消选取，后面的card向前移动
	if card.is_choosed_pre_card:
		card.is_choosed_pre_card = false
		card.visible = true
		var card_idx = (
			card_slot_battle.director_cards_on_page(0).find(card)
			if director_pages_enabled
			else card_slot_battle.curr_cards.find(card)
		)
		card_slot_battle.curr_cards.erase(card)
		var remaining_cards := card_slot_battle.director_cards_on_page(0) if director_pages_enabled else card_slot_battle.curr_cards
		for i in range(card_idx, remaining_cards.size()):
			move_card_to(remaining_cards[i], card_slot_battle.cards_placeholder[i])
		await move_card_to(card, card_slot_candidate.card_imitater)
		card.reparent(card.card_candidate_container, false)
		card_slot_candidate.imitater_be_choosed_cancel()

	## 如果没被选取，放在最后一位；达到当前关卡上限则拒绝选择。
	else:
		var placeholder_index := (
			card_slot_battle.director_placeholder_index_for_new_card(card)
			if director_pages_enabled
			else card_slot_battle.curr_cards.size()
		)
		if placeholder_index >= card_slot_battle.cards_placeholder.size():
			var new_placeholder = card_slot_battle.add_card_placeholder()
			if not is_instance_valid(new_placeholder):
				return
		card.is_choosed_pre_card = true
		card_slot_battle.curr_cards.append(card)
		card.reparent(card_slot_candidate.card_imitater, false)
		move_card_to(card, card_slot_battle.cards_placeholder[placeholder_index])
		card_slot_candidate.imitater_be_choosed()
	if director_pages_enabled:
		card_slot_battle.refresh_director_card_page.call_deferred()


## 移动card到目标点位置
func move_card_to(card:Card, target_parent):
	if not _is_valid_card(card) or not is_instance_valid(target_parent):
		return
	card.button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.reparent(temporary_card)
	## 新增占位槽需要等待容器完成布局，否则读到的仍是第一格附近的旧坐标。
	await get_tree().process_frame
	if not _is_valid_card(card) or not is_instance_valid(target_parent):
		if _is_valid_card(card):
			card.button.mouse_filter = Control.MOUSE_FILTER_PASS
		return

	var tween = create_tween()
	tween.tween_property(card, "global_position", target_parent.global_position, 0.2) # 时间可以改短点

	await tween.finished
	if not _is_valid_card(card) or not is_instance_valid(target_parent):
		return
	card.reparent(target_parent, false)
	card.position = Vector2.ZERO

	card.button.mouse_filter = Control.MOUSE_FILTER_PASS
	card_slot_battle.refresh_director_card_page()

## 选卡结束后，卡片断开连接，游戏开始后修改点击信号连接
func card_disconnect_click_in_choose():
	for card in card_slot_battle.curr_cards:
		if not _is_valid_card(card):
			continue
		if card.signal_card_click.is_connected(_on_card_click.bind(card)):
			card.signal_card_click.disconnect(_on_card_click.bind(card))

## 系统预选卡
func pre_choosed_card(card:Card, target_parent):
	if not _is_valid_card(card) or not is_instance_valid(target_parent):
		return
	target_parent.add_child(card)
	card.position = Vector2.ZERO
	#card.card_change_cool_time(0)

	## 罐子模式下系统预选卡无冷却
	if Global.main_game.game_para.is_pot_mode:
		if card.card_plant_type != CharacterRegistry.PlantType.Null:
			if Global.global_read_data.zero_cd_plnat_card_type_on_pot_mode.has(card.card_plant_type):
				card.card_change_cool_time(0)
		## 僵尸卡牌都无冷却
		elif card.card_zombie_type != CharacterRegistry.ZombieType.Null:
			card.card_change_cool_time(0)

### 预选卡隐藏对应待选卡槽的卡片(植物)
#func disappear_card_slot_candidate_plant(plant_type):
	#card_slot_candidate.all_card_candidate_containers_plant[AllCards.plant_card_ids[plant_type]].card.visible = false
	#
### 预选卡隐藏对应待选卡槽的卡片(僵尸)
#func disappear_card_slot_candidate_zombie(zombie_type):
	#card_slot_candidate.all_card_candidate_containers_zombie[AllCards.zombie_card_ids[zombie_type]].card.visible = false

## 移动卡槽（出现或隐藏）
func move_card_slot_candidate(is_appeal:bool):
	var tween = create_tween()
	if is_appeal:
		tween.tween_property(card_slot_candidate, "position",Vector2(0, 89.0), 0.2) # 时间可以改短点
	else:
		tween.tween_property(card_slot_candidate, "position",Vector2(0, 615.0), 0.2) # 时间可以改短点

	await tween.finished

func _is_valid_card(card: Card) -> bool:
	return is_instance_valid(card) \
		and (
			card.card_plant_type != CharacterRegistry.PlantType.Null \
			or card.card_zombie_type != CharacterRegistry.ZombieType.Null
		)

## 移动待选卡槽（出现或隐藏）
func move_card_slot_battle(is_appeal:bool, appeal_time:= 0.2):
	var tween = create_tween()
	if is_appeal:
		tween.tween_property(card_slot_battle, "position",Vector2(0, 0), appeal_time)
	else:
		tween.tween_property(card_slot_battle, "position",Vector2(0, -100.0), appeal_time)
	await tween.finished
