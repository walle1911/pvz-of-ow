extends Node

const WorkshopScene := preload("res://scenes/main/07LevelWorkshop.tscn")
const AdventurePresets := preload("res://scripts/resources/level/adventure_level_presets.gd")
const DraftStore := preload("res://scripts/resources/level/level_draft_store.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	## 工坊载入关卡会触发自动保存；测试必须隔离玩家真实的未命名草稿。
	DraftStore.AUTOSAVE_PATH = "/tmp/pvz_special_reward_card_workshop_autosave.json"
	if AllCards.all_plant_card_prefabs.is_empty():
		await AllCards.hydrate_from_packed_scene(load("res://scenes/autoload/all_cards.tscn") as PackedScene)
	var workshop := WorkshopScene.instantiate()
	add_child(workshop)
	await get_tree().process_frame
	await get_tree().process_frame
	workshop.call("_refresh_zombie_catalog")
	var potato_mine := int(CharacterRegistry.PlantType.P505PotatoMine)

	workshop.call("_load_preset_for_edit", "adventure_1_9")
	var source_holder := workshop.call("_make_reward_card", {"id": potato_mine, "is_plant": true}) as Control
	if not _badge_text_is(source_holder.get_node_or_null("CardStateBadge"), "奖") \
		or not _badge_text_is(source_holder.get_node_or_null("CardStateBadgeLimited"), "限"):
		_fail("限定卡来源关应同时显示上方“奖”和正下方“限”")
		return
	if source_holder.get_node("CardStateBadgeLimited").position != Vector2(20, 24):
		_fail("来源关的“限”必须与“奖”左对齐并显示在正下方")
		return

	workshop.call("_load_preset_for_edit", "adventure_1_10")
	var target_holder := workshop.call("_make_reward_card", {"id": potato_mine, "is_plant": true}) as Control
	if not _badge_text_is(target_holder.get_node_or_null("CardStateBadge"), "限") \
		or target_holder.get_node_or_null("CardStateBadgeLimited") != null:
		_fail("限定目标关只能在原奖励位置显示“限”")
		return

	workshop.call("_load_preset_for_edit", "adventure_2_1")
	var denied_holder := workshop.call("_make_reward_card", {"id": potato_mine, "is_plant": true}) as Control
	if denied_holder.get_node_or_null("CardStateBadge") != null \
	or (denied_holder.get_child(0) as Card).modulate != workshop.UNSELECTED_CARD_MODULATE:
		_fail("非目标关不应把限定卡作为可用卡加入")
		return

	var boss_source := AdventurePresets.build_level("adventure_1_10", true)
	var boss_reward_type := int((boss_source.get("bossConfig", {}) as Dictionary).get("rewardPlant", -1))
	var original_level_states := Global.global_game_state.curr_all_level_state_data.duplicate(true)
	Global.global_game_state.curr_all_level_state_data = {
		"101_0_adventure_1_10": {"IsSuccess": true, "RewardPlants": []},
	}
	workshop.call("_load_preset_for_edit", "adventure_1_1")
	var locked_boss_holder := workshop.call("_make_reward_card", {"id": boss_reward_type, "is_plant": true}) as Control
	Global.global_game_state.curr_all_level_state_data["101_0_adventure_1_10"]["RewardPlants"] = [boss_reward_type]
	workshop.call("_refresh_locked_available_plants")
	var earned_boss_holder := workshop.call("_make_reward_card", {"id": boss_reward_type, "is_plant": true}) as Control
	workshop.call("_load_preset_for_edit", "adventure_1_10")
	var source_boss_holder := workshop.call("_make_reward_card", {"id": boss_reward_type, "is_plant": true}) as Control
	Global.global_game_state.curr_all_level_state_data = original_level_states
	if not _badge_text_is(locked_boss_holder.get_node_or_null("CardStateBadgeBoss"), "Boss") \
	or (locked_boss_holder.get_child(0) as Card).modulate != workshop.UNSELECTED_CARD_MODULATE \
	or locked_boss_holder.get_node_or_null("CardStateGlow") != null:
		_fail("未领取的 Boss 战利品应保持灰色并显示 Boss 角标")
		return
	if not _badge_text_is(earned_boss_holder.get_node_or_null("CardStateBadgeBoss"), "Boss") \
	or (earned_boss_holder.get_child(0) as Card).modulate != Color.WHITE \
	or earned_boss_holder.get_node_or_null("CardStateGlow") == null:
		_fail("已领取的 Boss 战利品应在所有正式关卡中亮起并显示紫色光效")
		return
	if not _badge_text_is(source_boss_holder.get_node_or_null("CardStateBadgeBoss"), "B奖") \
	or source_boss_holder.get_node_or_null("CardStateGlow") == null:
		_fail("Boss 来源关应把额外奖励显示为 B奖")
		return

	print("PVZ special reward card workshop test: passed")
	get_tree().quit(0)


func _badge_text_is(badge: Node, expected_text: String) -> bool:
	return badge != null and badge.get_child_count() > 0 and (badge.get_child(0) as Label).text == expected_text


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
