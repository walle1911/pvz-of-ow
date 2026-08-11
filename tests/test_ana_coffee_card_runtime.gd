extends Node

const ANA_NANO_BOOST := preload("res://scripts/character/effects/ana_nano_boost.gd")

func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(Plant052SunflowerMercy.is_blue_line_damage_boost_target_type(
		CharacterRegistry.PlantType.P008PeaShooterDoubleRework
	))
	var mercy := load("res://scenes/character/plant/plant_002_sunflower_mercy.tscn").instantiate() \
		as Plant052SunflowerMercy
	assert(mercy.damage_boost_target_plant_types.has(
		CharacterRegistry.PlantType.P008PeaShooterDoubleRework
	))
	mercy.free()
	assert(Plant067CoffeeBeanAna.is_nano_boost_target_type(
		CharacterRegistry.PlantType.P008PeaShooterDoubleRework
	))
	for _frame in range(120):
		await get_tree().process_frame
		if is_instance_valid(Global.main_game) \
			and is_instance_valid(Global.main_game.card_manager.card_slot_battle) \
			and not Global.main_game.card_manager.card_slot_battle.curr_cards.is_empty():
			Global.main_game.choosed_card_start_game()
			break
	for _frame in range(600):
		await get_tree().process_frame
		if is_instance_valid(Global.main_game) \
			and Global.main_game.main_game_progress == MainGameManager.E_MainGameProgress.MAIN_GAME \
			and is_instance_valid(Global.main_game.card_manager.card_slot_battle):
			break

	var battle:CardSlotBattle = Global.main_game.card_manager.card_slot_battle
	## 本测试只验证卡牌运行态；跳过 Ready/Set/Plant 的真实时间动画。
	Global.main_game.main_game_progress = MainGameManager.E_MainGameProgress.MAIN_GAME
	var ana_card:Card
	for card:Card in battle.curr_cards:
		if card.is_ana_coffee_mode_active():
			ana_card = card
			break
	assert(is_instance_valid(ana_card))

	ana_card._ensure_ana_coffee_toggle_in_battle()
	assert(is_instance_valid(ana_card._ana_coffee_mode_toggle))
	var ana_cooldown := float(Global.character_registry.get_plant_info(36, CharacterRegistry.PlantInfoAttribute.CoolTime))
	var ana_cost := int(Global.character_registry.get_plant_info(36, CharacterRegistry.PlantInfoAttribute.SunCost))
	var normal_cooldown := float(Global.character_registry.get_plant_info(536, CharacterRegistry.PlantInfoAttribute.CoolTime))
	var normal_cost := int(Global.character_registry.get_plant_info(536, CharacterRegistry.PlantInfoAttribute.SunCost))
	assert(is_equal_approx(ana_card.cool_time, ana_cooldown))
	assert(ana_card.sun_cost == ana_cost)

	## 已冷却 3 秒：安娜 3/15，切普通后应保留为 3/7.5。
	ana_card.card_cool()
	ana_card._cool_timer = ana_cooldown - 3.0
	ana_card._set_ana_coffee_mode(false)
	assert(ana_card.card_plant_type == CharacterRegistry.PlantType.P536CoffeeBean)
	assert(is_equal_approx(ana_card.cool_time, normal_cooldown))
	assert(is_equal_approx(ana_card._cool_timer, normal_cooldown - 3.0))
	assert(ana_card.sun_cost == normal_cost)
	assert(not ana_card.is_ana_coffee_mode_active())

	## 已冷却 8 秒：切到普通形态应立即完成冷却。
	ana_card._set_ana_coffee_mode(true)
	ana_card._cool_timer = ana_cooldown - 8.0
	ana_card._set_ana_coffee_mode(false)
	assert(not ana_card._is_cooling)

	## 任一形态使用后共享进度归零；切回安娜应重新等待完整 15 秒。
	ana_card.card_cool()
	ana_card._set_ana_coffee_mode(true)
	assert(ana_card._is_cooling)
	assert(is_equal_approx(ana_card._cool_timer, ana_cooldown))
	assert(ana_card.is_ana_coffee_mode_active())

	## 天使与安娜乘算；安娜同时立即治疗 50、提供 30% 减伤，并阻止同目标重复使用。
	var target_cell:PlantCell = Global.main_game.plant_cell_manager.all_plant_cells[0][0]
	var target := target_cell.create_plant(CharacterRegistry.PlantType.P001PeaShooterSoldier76) as Plant000Base
	assert(is_instance_valid(target))
	await get_tree().process_frame
	await get_tree().process_frame
	target.hp_component.curr_hp = 100
	var nano_boost := ANA_NANO_BOOST.new() as AnaNanoBoost
	nano_boost.name = "AnaNanoBoost"
	target.add_child(nano_boost)
	nano_boost.start_boost(target, 1.5, 1.5, 0.3, 50, 12.0)
	assert(target.hp_component.curr_hp == 150)
	assert(is_equal_approx(target.hp_component.get_damage_taken_multiplier(), 0.7))
	var mercy_source := Node.new()
	target.add_child(mercy_source)
	target.add_attack_damage_multiplier(mercy_source, 1.25)
	assert(is_equal_approx(target.get_attack_damage_multiplier(), 1.875))
	target.hp_component.Hp_loss(100)
	assert(target.hp_component.curr_hp == 80)
	## 动画或状态切换可能在强化期间释放原身体精灵；同步流光时不能转换已释放对象。
	assert(not nano_boost.glow_pairs.is_empty())
	var removed_source_value:Variant = nano_boost.glow_pairs[0].get("source")
	assert(is_instance_valid(removed_source_value))
	(removed_source_value as Sprite2D).queue_free()
	await get_tree().process_frame
	nano_boost._sync_full_body_glow()
	for glow_pair:Dictionary in nano_boost.glow_pairs:
		assert(is_instance_valid(glow_pair.get("source")))
	var ana_condition := Global.character_registry.get_plant_info(
		CharacterRegistry.PlantType.P036CoffeeBeanAna,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource
	) as ResourcePlantCondition
	assert(not ana_condition.judge_is_can_plant(target_cell, CharacterRegistry.PlantType.P036CoffeeBeanAna))
	nano_boost.finish_boost()
	assert(is_equal_approx(target.hp_component.get_damage_taken_multiplier(), 1.0))
	assert(is_equal_approx(target.get_attack_damage_multiplier(), 1.25))

	print("test_ana_coffee_card_runtime: PASS")
	get_tree().quit(0)
