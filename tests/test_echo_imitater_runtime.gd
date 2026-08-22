extends Node


func _ready() -> void:
	call_deferred(&"_run")


func _run() -> void:
	if not AllCards.all_plant_card_prefabs.has(CharacterRegistry.PlantType.P999ImitaterEcho):
		await AllCards.hydrate_from_packed_scene(
			load("res://scenes/autoload/all_cards.tscn") as PackedScene
		)

	var target_card := AllCards.all_plant_card_prefabs[
		CharacterRegistry.PlantType.P001PeaShooterSoldier76
	] as Card
	var next_target_card := AllCards.all_plant_card_prefabs[
		CharacterRegistry.PlantType.P003CherryBombJunkrat
	] as Card
	var echo_card := AllCards.all_plant_card_prefabs[
		CharacterRegistry.PlantType.P999ImitaterEcho
	].duplicate() as Card
	add_child(echo_card)
	await get_tree().process_frame

	assert(target_card.card_plant_type == CharacterRegistry.PlantType.P001PeaShooterSoldier76)
	assert(echo_card.card_plant_type == CharacterRegistry.PlantType.P999ImitaterEcho)
	assert(not echo_card.has_echo_imitater_target())
	assert(echo_card.cost.text == "???")
	assert(echo_card.bind_echo_imitater_target(target_card.card_plant_type))
	assert(echo_card.has_echo_imitater_target())
	assert(echo_card.get_gameplay_plant_type() == target_card.card_plant_type)
	assert(echo_card.sun_cost == target_card.sun_cost)
	assert(is_equal_approx(echo_card.cool_time, target_card.cool_time))
	assert(echo_card.cost.text == str(target_card.sun_cost))
	assert(echo_card.plant_condition == target_card.plant_condition)

	## 本轮独立冷却使用绑定目标的快照，不会启动原卡冷却。
	echo_card.card_cool()
	assert(echo_card._is_cooling)
	assert(is_equal_approx(echo_card._cool_timer, target_card.cool_time))
	assert(not target_card._is_cooling)

	var card_slot_scene := load("res://scenes/card_slot/card_slot_norm.tscn") as PackedScene
	var card_slot_root := card_slot_scene.instantiate() as CardSlotNorm
	add_child(card_slot_root)
	await get_tree().process_frame
	assert(not card_slot_root.get_node(^"CardSlotCandidate/ImitaterBG").visible)
	echo_card.set_card_cool_end()
	echo_card.clear_echo_imitater_target()
	card_slot_root.card_slot_battle.curr_cards.assign([target_card, echo_card])
	assert(not echo_card.has_echo_imitater_target())
	card_slot_root.card_slot_battle._update_echo_imitater_targets_from_used_card(target_card)
	assert(echo_card.get_gameplay_plant_type() == target_card.card_plant_type)
	assert(echo_card.sun_cost == target_card.sun_cost)
	assert(is_equal_approx(echo_card.cool_time, target_card.cool_time))

	## 新植物种下后实时换目标，但不能篡改已经开始的旧冷却。
	echo_card.card_cool()
	echo_card._cool_timer = target_card.cool_time * 0.5
	var active_cooldown_max := echo_card._cool_mask.max_value
	var active_cooldown_left := echo_card._cool_timer
	card_slot_root.card_slot_battle._update_echo_imitater_targets_from_used_card(next_target_card)
	assert(echo_card.get_gameplay_plant_type() == next_target_card.card_plant_type)
	assert(echo_card.sun_cost == next_target_card.sun_cost)
	assert(is_equal_approx(echo_card.cool_time, next_target_card.cool_time))
	assert(is_equal_approx(echo_card._cool_timer, active_cooldown_left))
	assert(is_equal_approx(echo_card._cool_mask.max_value, active_cooldown_max))
	echo_card.set_card_cool_end()
	echo_card.card_cool()
	assert(is_equal_approx(echo_card._cool_timer, next_target_card.cool_time))
	card_slot_root.free()

	print("test_echo_imitater_runtime: PASS")
	get_tree().quit(0)
