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

var reward_card: Card
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
	var reward_plant_type := _reward_plant_type()
	if reward_plant_type >= 0 and AllCards.all_plant_card_prefabs.has(reward_plant_type):
		_show_reward_plant(reward_plant_type)
		return
	await get_tree().create_timer(3.5).timeout
	EventBus.push_event("win_main_game")


func _reward_plant_type() -> int:
	if not is_instance_valid(main_game) or main_game.game_para == null:
		return -1
	return int(main_game.game_para.reward_plant_type)


func _show_reward_plant(plant_type: int) -> void:
	trophy_button.visible = false
	pick_up_glow.visible = false
	all_rays.visible = false
	glow.visible = false
	reward_screen.visible = true
	reward_screen.modulate.a = 0.0
	reward_screen.scale = Vector2(0.94, 0.94)

	reward_card = (AllCards.all_plant_card_prefabs[plant_type] as Card).duplicate() as Card
	reward_card.name = "RewardPlantCard"
	reward_card.position = Vector2(0, 70)
	reward_card.pivot_offset = Vector2(25, 35)
	reward_card.scale = Vector2(0.25, 0.25)
	reward_card.tooltip_text = "点击领取通关奖励"
	reward_card_holder.add_child(reward_card)
	var cost_label := reward_card.get_node_or_null("CardBg/Cost") as Label
	if cost_label != null:
		cost_label.visible = false
	var card_button := reward_card.get_node_or_null("Button") as Button
	if card_button != null:
		card_button.pressed.connect(_on_reward_card_pressed, CONNECT_ONE_SHOT)

	SoundManager.play_other_SFX("prize")
	var reveal := create_tween().set_parallel(true)
	reveal.tween_property(reward_screen, "modulate:a", 1.0, 0.35)
	reveal.tween_property(reward_screen, "scale", Vector2.ONE, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	reveal.tween_property(reward_card, "position", Vector2.ZERO, 0.65) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	reveal.tween_property(reward_card, "scale", Vector2.ONE, 0.65) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var flash_tween := create_tween().set_parallel(true)
	flash_tween.tween_property(reward_flash, "scale", Vector2(4.5, 4.5), 0.55)
	flash_tween.tween_property(reward_flash, "modulate:a", 0.0, 0.55)
	var glow_tween := create_tween()
	glow_tween.tween_property(reward_glow, "rotation", TAU, 6.0).set_trans(Tween.TRANS_LINEAR)
	glow_tween.set_loops()


func _on_reward_card_pressed() -> void:
	if reward_is_being_collected or not is_instance_valid(reward_card):
		return
	reward_is_being_collected = true
	var card_button := reward_card.get_node_or_null("Button") as Button
	if card_button != null:
		card_button.disabled = true
	SoundManager.play_other_SFX("seedlift")
	var collect := create_tween()
	collect.tween_property(reward_card, "scale", Vector2(1.18, 1.18), 0.2) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	collect.tween_property(reward_card, "position:y", -45.0, 0.35) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	collect.parallel().tween_property(reward_card, "modulate:a", 0.0, 0.35)
	await collect.finished
	EventBus.push_event("win_main_game")


func _on_trophy_button_mouse_entered() -> void:
	## 如果有锤子
	if main_game.game_para.is_hammer:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
