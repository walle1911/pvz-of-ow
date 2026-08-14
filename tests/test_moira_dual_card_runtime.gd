extends Node

const NUMERICAL_POLICY := preload("res://scripts/resources/numerical_adjustment_policy.gd")

func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
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
		and Global.main_game.main_game_progress == MainGameManager.E_MainGameProgress.MAIN_GAME:
			break

	var battle: CardSlotBattle = Global.main_game.card_manager.card_slot_battle
	Global.main_game.main_game_progress = MainGameManager.E_MainGameProgress.MAIN_GAME
	var moira_card: Card
	for card: Card in battle.curr_cards:
		if card.get_availability_plant_type() == CharacterRegistry.PlantType.P043GloomShroomMoira:
			moira_card = card
			break
	assert(is_instance_valid(moira_card))
	moira_card._ensure_moira_toggle_in_battle()
	assert(is_instance_valid(moira_card._moira_mode_toggle))
	assert(moira_card.sun_cost == 175)
	assert(is_equal_approx(moira_card.cool_time, 50.0))

	## 形态二已冷却 3 秒，切换形态一后仍保留同一轮 50 秒冷却池的剩余时间。
	moira_card.card_cool()
	moira_card._cool_timer = 47.0
	moira_card._set_moira_form_one(true)
	assert(moira_card.card_plant_type == CharacterRegistry.PlantType.P063MoiraSunPuff)
	assert(moira_card.get_availability_plant_type() == CharacterRegistry.PlantType.P043GloomShroomMoira)
	assert(moira_card.sun_cost == 25)
	assert(is_equal_approx(moira_card.cool_time, 7.5))
	assert(is_equal_approx(moira_card._cool_timer, 47.0))
	assert(is_equal_approx(moira_card._moira_shared_cool_duration, 50.0))

	## 下一次从形态一使用时，新的共享冷却池采用形态一的 7.5 秒。
	moira_card.set_card_cool_end()
	moira_card.card_cool()
	assert(is_equal_approx(moira_card._cool_timer, 7.5))
	assert(is_equal_approx(moira_card._moira_shared_cool_duration, 7.5))

	var form_one_scene := Global.character_registry.get_plant_info(
		CharacterRegistry.PlantType.P063MoiraSunPuff,
		CharacterRegistry.PlantInfoAttribute.PlantScenes
	) as PackedScene
	var form_one := form_one_scene.instantiate() as Plant071MoiraSunPuff
	assert(is_instance_valid(form_one))
	assert(is_equal_approx(form_one.yellow_fume_chance, 0.8))
	assert(form_one.mini_sun_value == 15)
	assert(form_one.norm_sun_value == 25)
	var form_one_attack := form_one.get_node("AttackComponent") as AttackComponentBulletBase
	assert(is_equal_approx(form_one_attack.attack_cd, 1.5))
	assert(form_one_attack.attack_value_bullet == 20)
	for property_name in [
		"yellow_fume_chance", "yellow_fume_heal_value", "time_grow",
		"mini_sun_value", "norm_sun_value", "small_body_scale", "grown_body_scale",
		"first_sun_time_min", "first_sun_time_max", "repeat_sun_time_min", "repeat_sun_time_max",
	]:
		assert(not NUMERICAL_POLICY.get_rule(
			form_one, property_name, form_one.scene_file_path, "."
		).is_empty())
	assert(not NUMERICAL_POLICY.get_rule(
		form_one_attack, "attack_cd", form_one.scene_file_path, "AttackComponent"
	).is_empty())
	assert(not NUMERICAL_POLICY.get_rule(
		form_one_attack, "attack_value_bullet", form_one.scene_file_path, "AttackComponent"
	).is_empty())
	form_one.free()

	var form_two_scene := Global.character_registry.get_plant_info(
		CharacterRegistry.PlantType.P043GloomShroomMoira,
		CharacterRegistry.PlantInfoAttribute.PlantScenes
	) as PackedScene
	var form_two := form_two_scene.instantiate() as Plant063GloomShroomMoira
	assert(is_instance_valid(form_two))
	assert(is_equal_approx(form_two.yellow_fume_chance, 0.2))
	assert(form_two.death_sun_value == 75)
	assert(form_two.death_sun_count == 1)
	for property_name in [
		"yellow_fume_chance", "yellow_fume_heal_value", "death_sun_value", "death_sun_count",
	]:
		assert(not NUMERICAL_POLICY.get_rule(
			form_two, property_name, form_two.scene_file_path, "."
		).is_empty())
	form_two.free()

	print("test_moira_dual_card_runtime: PASS")
	get_tree().quit(0)
