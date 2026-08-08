extends Node

const WorkshopScene := preload("res://scenes/main/07LevelWorkshop.tscn")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var workshop := WorkshopScene.instantiate()
	add_child(workshop)
	await get_tree().process_frame
	await get_tree().process_frame
	var potato_mine := int(CharacterRegistry.PlantType.P504PotatoMine)

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

	print("PVZ special reward card workshop test: passed")
	get_tree().quit(0)


func _badge_text_is(badge: Node, expected_text: String) -> bool:
	return badge != null and badge.get_child_count() > 0 and (badge.get_child(0) as Label).text == expected_text


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
