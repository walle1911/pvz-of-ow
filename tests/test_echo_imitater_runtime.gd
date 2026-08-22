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

	await _test_echo_killer_copy_trigger_rules()

	print("test_echo_imitater_runtime: PASS")
	get_tree().quit(0)


func _test_echo_killer_copy_trigger_rules() -> void:
	var plant_scene := load("res://scenes/character/plant/plant_501_pea_shooter_single.tscn") as PackedScene
	var zombie_scene := load("res://scenes/character/zombie/zombie_501_norm.tscn") as PackedScene
	var echo_scene := load("res://scenes/character/plant/plant_999_imitater_echo.tscn") as PackedScene

	var zombie := zombie_scene.instantiate() as Zombie000Base
	zombie.character_init_type = Character000Base.E_CharacterInitType.IsShow
	add_child(zombie)

	var echo_template := echo_scene.instantiate() as Plant061ImitaterEcho
	assert(is_equal_approx(echo_template.echo_killer_copy_window_seconds, 4.0))
	var killer_copy_effect := echo_template.get_node(^"ImitaterEffect").duplicate() as Node2D
	echo_template.free()

	var killed_by_zombie := plant_scene.instantiate() as Plant000Base
	killed_by_zombie.character_init_type = Character000Base.E_CharacterInitType.IsShow
	killed_by_zombie.apply_common_pre_ready_data({
		Plant000Base.ECHO_KILLER_COPY_PRE_READY_KEY:{
			&"window_seconds":2.0,
			&"effect":killer_copy_effect,
		}
	})
	add_child(killed_by_zombie)
	await get_tree().process_frame

	killed_by_zombie.be_zombie_eat(killed_by_zombie.hp_component.max_hp, zombie)
	assert(killed_by_zombie._echo_killer_copy_triggered)
	assert(killer_copy_effect.get_parent() == self)
	assert((killer_copy_effect.get_node(^"GPUParticles2D") as GPUParticles2D).emitting)

	## 主动清空生命没有攻击者来源，不能复制僵尸。
	var self_consumed := plant_scene.instantiate() as Plant000Base
	self_consumed.character_init_type = Character000Base.E_CharacterInitType.IsShow
	self_consumed.apply_common_pre_ready_data({
		Plant000Base.ECHO_KILLER_COPY_PRE_READY_KEY:{&"window_seconds":2.0}
	})
	add_child(self_consumed)
	await get_tree().process_frame
	self_consumed.hp_component.curr_hp = 0
	assert(not self_consumed._echo_killer_copy_triggered)

	## 明确来自僵尸的致死攻击发生在窗口外，也不能复制。
	var expired := plant_scene.instantiate() as Plant000Base
	expired.character_init_type = Character000Base.E_CharacterInitType.IsShow
	expired.apply_common_pre_ready_data({
		Plant000Base.ECHO_KILLER_COPY_PRE_READY_KEY:{&"window_seconds":2.0}
	})
	add_child(expired)
	await get_tree().process_frame
	expired._echo_killer_copy_deadline_msec = Time.get_ticks_msec() - 1
	expired.be_zombie_eat(expired.hp_component.max_hp, zombie)
	assert(not expired._echo_killer_copy_triggered)
