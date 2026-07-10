extends Node

const Logic := preload("res://addons/pvz_level_editor/level_editor_logic.gd")
const Runtime := preload("res://scripts/resources/level/level_custom_runtime.gd")

func _ready() -> void:
	var built := Runtime.build_game_para(Logic.example_level())
	assert(built["ok"], built["error"])
	var game_para: ResourceLevelData = built["game_para"]
	assert(game_para.custom_spawn_schedule.size() == 14)
	assert(game_para.custom_flag_data.size() == 2)
	assert(game_para.custom_timeline_duration == 56.0)
	assert(float(game_para.custom_spawn_schedule[0]["time"]) < float(game_para.custom_spawn_schedule[-1]["time"]))
	assert(load("res://scenes/main/07LevelWorkshop.tscn") != null)
	assert(load("res://scenes/main/06CustomChooesLevel.tscn") != null)
	var start_menu_scene: PackedScene = load("res://scenes/main/01StartMenu.tscn")
	var start_menu := start_menu_scene.instantiate()
	await get_tree().process_frame
	get_tree().root.add_child(start_menu)
	await get_tree().process_frame
	assert(start_menu.get_node("BG_Right/Menu/LevelWorkshopButton") is TextureButton)
	assert(start_menu.get_node("BG_Right/Menu/LevelWorkshopButton/Label").text == "关\n卡\n工\n坊")
	start_menu.queue_free()
	await get_tree().process_frame
	var workshop_scene: PackedScene = load("res://scenes/main/07LevelWorkshop.tscn")
	var workshop := workshop_scene.instantiate()
	await get_tree().process_frame
	get_tree().root.add_child(workshop)
	await get_tree().process_frame
	await get_tree().process_frame
	workshop.level = Logic.example_level()
	workshop.selected_wave = 0
	workshop.call("_refresh_wave")
	assert(workshop.zombie_card_order.size() == AllCards.all_zombie_card_prefabs.size())
	workshop.call("_create_next_wave")
	assert((workshop.level["waves"] as Array).size() == 6)
	assert(workshop.level["waves"][-2]["stageType"] == "interval")
	assert(workshop.level["waves"][-1]["stageType"] == "flag")
	workshop.call("_select_stage", (workshop.level["waves"] as Array).size() - 2)
	workshop.call("_add_zombie", "normal")
	assert(workshop.call("_wave_total_count", workshop.level["waves"][-2]) == 1)
	assert(workshop.level["waves"][-2]["spawnGroups"][0]["laneRule"] == "random")
	workshop.level["waves"][-2]["spawnGroups"][0]["count"] = 25
	workshop.call("_refresh_road_zombies")
	assert(workshop.preview_zombies.size() == workshop.PREVIEW_MAX_ZOMBIES)
	workshop.call("_delete_current_stage")
	assert((workshop.level["waves"] as Array).size() == 5)
	workshop.queue_free()
	await get_tree().process_frame
	game_para.custom_spawn_schedule = [
		{"time": 0.0, "zombie_type": 500, "lane": 0, "stage_index": 0},
		{"time": 0.1, "zombie_type": 502, "lane": 3, "stage_index": 1},
	]
	game_para.custom_flag_data = []
	game_para.custom_timeline_duration = 0.2
	game_para.set_choose_level(MainSceneRegistry.MainScenes.LevelWorkshop, 0, "runtime_test")
	Global.game_para = game_para
	var main_game_scene: PackedScene = load(Global.main_scene_registry.MainScenesMap[game_para.game_sences])
	var main_game := main_game_scene.instantiate()
	await get_tree().process_frame
	get_tree().root.add_child(main_game)
	await get_tree().process_frame
	await get_tree().process_frame
	assert(Global.main_game == main_game)
	main_game.zombie_manager.zombie_wave_manager.start_custom_timeline()
	await get_tree().create_timer(0.05, false).timeout
	assert(main_game.zombie_manager.curr_zombie_num == 1)
	await get_tree().create_timer(0.1, false).timeout
	assert(main_game.zombie_manager.curr_zombie_num == 2)
	await get_tree().create_timer(0.1, false).timeout
	main_game.queue_free()
	await get_tree().process_frame
	print("CUSTOM_LEVEL_SMOKE_OK events=", game_para.custom_spawn_schedule.size(), " flags=", game_para.custom_flag_data.size())
	get_tree().quit()
