extends Node2D
class_name Trophy

@onready var main_game: MainGameManager

@onready var pick_up_glow: Sprite2D = $PickUpGlow

@onready var all_rays: Node2D = $AllRays
@onready var glow: Node2D = $Glow
@onready var trophy_button: TextureButton = $TrophyButton
@onready var reward_screen: Node2D = $RewardScreen
@onready var reward_card_holder: Control = $RewardScreen/RewardCardHolder
@onready var reward_glow: Sprite2D = $RewardScreen/RewardGlow
@onready var reward_flash: Sprite2D = $RewardScreen/RewardFlash
@onready var reward_title: Label = $RewardScreen/Title
@onready var reward_description: Label = $RewardScreen/Description
@onready var reward_continue_button: Button = $RewardScreen/RewardContinueButton

var reward_cards: Array[Card] = []
var reward_is_being_collected := false

func _ready():
	main_game = get_tree().current_scene
	var tween = create_tween()
	tween.tween_property(pick_up_glow, "scale", Vector2(1.5, 1.5), 1.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(pick_up_glow, "scale", Vector2(1, 1), 1.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.set_loops()  # 无限循环
	Global.save_service.save_now()

func _on_trophy_button_pressed() -> void:
	SoundManager.play_other_SFX("winmusic")
	trophy_button.disabled = true
	var center = get_viewport().get_visible_rect().size / 2 + Global.main_game.camera_2d.global_position
	var tween = create_tween()
	tween.tween_property(self, "position", center, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	all_rays.visible = true
	for ray in all_rays.get_children():
		var tween_rays1 = create_tween()
		# 无限循环旋转
		tween_rays1.tween_property(ray, "rotation", ray.rotation + TAU, 5.0) \
			.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)

		var tween_rays2 = create_tween()
		# 无限放大
		tween_rays2.tween_property(ray, "scale", Vector2(10, 10), 5.0) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	glow.visible = true
	var tween_glow = create_tween()
	tween_glow.tween_property(glow, "modulate:a", 1, 5.0)

	await tween.finished
	var reward_plant_types := _reward_plant_types()
	if not reward_plant_types.is_empty():
		_show_reward_plants(reward_plant_types)
		return
	await get_tree().create_timer(3.5).timeout
	EventBus.push_event("win_main_game")


func _reward_plant_types() -> Array[CharacterRegistry.PlantType]:
	var result: Array[CharacterRegistry.PlantType] = []
	if not is_instance_valid(main_game) or main_game.game_para == null:
		return result
	for plant_type in main_game.game_para.reward_plant_types:
		if AllCards.all_plant_card_prefabs.has(plant_type) and not result.has(plant_type):
			result.append(plant_type)
	if result.is_empty():
		var legacy_reward := int(main_game.game_para.reward_plant_type)
		if legacy_reward >= 0 and AllCards.all_plant_card_prefabs.has(legacy_reward):
			result.append(legacy_reward as CharacterRegistry.PlantType)
	return result


func _show_reward_plants(plant_types: Array[CharacterRegistry.PlantType]) -> void:
	trophy_button.visible = false
	pick_up_glow.visible = false
	all_rays.visible = false
	glow.visible = false
	reward_screen.visible = true
	reward_screen.modulate.a = 0.0
	reward_screen.scale = Vector2(0.94, 0.94)

	var card_count := plant_types.size()
	_update_reward_copy(plant_types)
	var card_spacing := 62.0
	var holder_scale := minf(2.0, 5.5 / float(card_count))
	reward_card_holder.scale = Vector2.ONE * holder_scale
	reward_card_holder.position = Vector2(-25.0 * holder_scale, -105.0 - 35.0 * holder_scale)
	for card_index in card_count:
		var plant_type := plant_types[card_index]
		var reward_card := (AllCards.all_plant_card_prefabs[plant_type] as Card).duplicate() as Card
		reward_card.name = "RewardPlantCard%d" % (card_index + 1)
		var target_x := (float(card_index) - float(card_count - 1) * 0.5) * card_spacing
		reward_card.position = Vector2(target_x, 70)
		reward_card.set_meta("reward_target_x", target_x)
		reward_card.pivot_offset = Vector2(25, 35)
		reward_card.scale = Vector2(0.25, 0.25)
		reward_card.tooltip_text = "点击继续游戏"
		reward_card_holder.add_child(reward_card)
		reward_cards.append(reward_card)
		var cost_label := reward_card.get_node_or_null("CardBg/Cost") as Label
		if cost_label != null:
			cost_label.visible = true
		var progress_bar := reward_card.get_node_or_null("ProgressBar") as ProgressBar
		if progress_bar != null:
			progress_bar.visible = false
		var card_button := reward_card.get_node_or_null("Button") as Button
		if card_button != null:
			card_button.pressed.connect(_on_reward_continue_pressed, CONNECT_ONE_SHOT)

	SoundManager.play_other_SFX("prize")
	var reveal := create_tween().set_parallel(true)
	reveal.tween_property(reward_screen, "modulate:a", 1.0, 0.35)
	reveal.tween_property(reward_screen, "scale", Vector2.ONE, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for reward_card in reward_cards:
		reveal.tween_property(reward_card, "position", Vector2(float(reward_card.get_meta("reward_target_x")), 0), 0.65) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		reveal.tween_property(reward_card, "scale", Vector2.ONE, 0.65) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var flash_tween := create_tween().set_parallel(true)
	flash_tween.tween_property(reward_flash, "scale", Vector2(4.5, 4.5), 0.55)
	flash_tween.tween_property(reward_flash, "modulate:a", 0.0, 0.55)
	var glow_tween := create_tween()
	glow_tween.tween_property(reward_glow, "rotation", TAU, 6.0).set_trans(Tween.TRANS_LINEAR)
	glow_tween.set_loops()


func _update_reward_copy(plant_types: Array[CharacterRegistry.PlantType]) -> void:
	if plant_types.size() != 1:
		reward_title.text = "你得到 %d 株新植物！" % plant_types.size()
		reward_description.text = "这些新植物已经加入你的卡片收藏。"
		reward_description.add_theme_font_size_override("font_size", 16)
		return

	reward_title.text = "你得到一株新植物！"
	var plant_type := plant_types[0]
	if main_game.game_para.level_id == "adventure_1_9" \
	and plant_type == CharacterRegistry.PlantType.P505PotatoMine:
		reward_description.text = "能击败恶魔的只有土豆"
		reward_description.add_theme_font_size_override("font_size", 16)
		return
	var registry_name: String = Global.character_registry.get_plant_info(
		plant_type,
		CharacterRegistry.PlantInfoAttribute.PlantName,
	)
	Global.global_read_data.ensure_almanac_loaded()
	var plant_group: Dictionary = Global.global_read_data.data_almanac.get("Plant", {})
	var plant_data: Dictionary = plant_group.get(registry_name, {})
	reward_description.text = str(plant_data.get("描述", "这株新植物已经加入你的卡片收藏。"))
	var description_length := reward_description.text.length()
	var description_font_size := 16
	if description_length > 66:
		description_font_size = 13
	elif description_length > 44:
		description_font_size = 14
	reward_description.add_theme_font_size_override("font_size", description_font_size)


func _on_reward_continue_pressed() -> void:
	if reward_is_being_collected or reward_cards.is_empty():
		return
	reward_is_being_collected = true
	reward_continue_button.disabled = true
	for reward_card in reward_cards:
		var card_button := reward_card.get_node_or_null("Button") as Button
		if card_button != null:
			card_button.disabled = true
	SoundManager.play_other_SFX("seedlift")
	var collect := create_tween().set_parallel(true)
	for reward_card in reward_cards:
		collect.tween_property(reward_card, "position:y", -45.0, 0.45) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		collect.tween_property(reward_card, "modulate:a", 0.0, 0.45)
	await collect.finished
	EventBus.push_event("win_main_game")


func _on_trophy_button_mouse_entered() -> void:
	## 如果有锤子
	if main_game.game_para.is_hammer:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
