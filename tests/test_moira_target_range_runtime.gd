extends Node


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := (load("res://scenes/main/test/MainGameDebug9999Night.tscn") as PackedScene).instantiate() as MainGameManager
	get_tree().root.add_child(main)
	for _index in 4:
		await get_tree().process_frame
	main.main_game_progress = MainGameManager.E_MainGameProgress.MAIN_GAME
	var moira_card := AllCards.all_plant_card_prefabs[CharacterRegistry.PlantType.P043GloomShroomMoira] as Card
	assert(moira_card.sun_cost == 150)
	assert(is_equal_approx(moira_card.cool_time, 50.0))
	main.game_para.is_day = true
	main._show_target_range_hint()
	var hint_panel := main.target_range_hint_layer.get_child(1) as Panel
	var hint_message := hint_panel.get_child(1) as Label
	assert(hint_message.text.contains("黑夜靶场"))
	for child in hint_panel.get_children():
		if child is TextureButton:
			assert(child.position.y + child.size.y <= hint_panel.size.y)
	main._dismiss_target_range_hint()
	main.game_para.is_day = false

	var plant_cell: PlantCell = main.plant_cell_manager.all_plant_cells[2][4]
	var moira := plant_cell.create_plant(CharacterRegistry.PlantType.P043GloomShroomMoira) as Plant063GloomShroomMoira
	assert(is_instance_valid(moira))
	assert(moira.plant_sun_cost == -1)
	assert(moira.plant_cool_time == -1.0)
	assert(moira.attack_component.attack_value_bullet == -1)
	assert(moira.attack_value == 20)
	assert(moira.yellow_fume_chance == 0.3)
	assert(moira.yellow_fume_heal_value == 35)
	for _index in 3:
		await get_tree().physics_frame
	print("test_moira_target_range_runtime: PASS")
	main.queue_free()
	await get_tree().process_frame
	get_tree().quit(0)
