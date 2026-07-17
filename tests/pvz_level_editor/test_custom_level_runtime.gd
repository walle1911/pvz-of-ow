extends Node

const Logic := preload("res://addons/pvz_level_editor/level_editor_logic.gd")
const Runtime := preload("res://scripts/resources/level/level_custom_runtime.gd")

func _ready() -> void:
	var example := Logic.example_level()
	example["rewardPlant"] = int(CharacterRegistry.PlantType.P001PeaShooterSoldier76)
	var built := Runtime.build_game_para(example)
	assert(built["ok"], built["error"])
	var game_para: ResourceLevelData = built["game_para"]
	assert(game_para.reward_plant_type == int(CharacterRegistry.PlantType.P001PeaShooterSoldier76))
	var forced_level := Logic.example_level()
	forced_level["freePlantSelection"] = false
	forced_level["forcedPlants"] = [int(CharacterRegistry.PlantType.P001PeaShooterSoldier76)]
	forced_level["mapConfig"] = {"type": "roof", "rows": 5, "columns": 9}
	forced_level["environmentConfig"] = {"initialTombstones": 0, "tombstoneSpawns": false, "bungee": true}
	var forced_built := Runtime.build_game_para(forced_level)
	assert(forced_built["ok"], forced_built["error"])
	var forced_para: ResourceLevelData = forced_built["game_para"]
	assert(not forced_para.can_choosed_card)
	assert(forced_para.pre_choosed_card_list_plant.has(CharacterRegistry.PlantType.P001PeaShooterSoldier76))
	assert(forced_para.is_bungi)
	assert(game_para.custom_spawn_schedule.size() == 14)
	assert(game_para.custom_flag_data.size() == 2)
	var simple_level := Logic.example_level()
	simple_level["editorMode"] = "simple"
	var simple_built := Runtime.build_game_para(simple_level)
	assert(simple_built["ok"], simple_built["error"])
	var simple_para: ResourceLevelData = simple_built["game_para"]
	## PvZ1 原版在开局前按点值/权重预生成全部波次名单。
	assert(simple_para.custom_simple_original_mode)
	assert(simple_para.custom_initial_wave_delay == 18.0)
	assert(simple_para.max_wave == 20)
	assert(simple_para.custom_spawn_schedule.is_empty())
	assert(simple_para.custom_stage_schedule.is_empty())
	assert(simple_para.custom_flag_data.is_empty())
	assert(simple_para.custom_simple_wave_zombies.size() == 20)
	assert(simple_para.custom_simple_wave_zombies[0] == [int(CharacterRegistry.ZombieType.Z500Norm)])
	assert(simple_para.custom_simple_wave_zombies[9].has(int(CharacterRegistry.ZombieType.Z501Flag)))
	assert(simple_para.custom_simple_wave_zombies[19].has(int(CharacterRegistry.ZombieType.Z501Flag)))
	for allowed_type in simple_para.zombie_refresh_types:
		assert(simple_para.custom_simple_wave_zombies[19].has(int(allowed_type)))
	var twelve_wave_level := simple_level.duplicate(true)
	twelve_wave_level["simpleWaveCount"] = 12
	var twelve_wave_built := Runtime.build_game_para(twelve_wave_level)
	assert(twelve_wave_built["ok"], twelve_wave_built["error"])
	var twelve_wave_para: ResourceLevelData = twelve_wave_built["game_para"]
	assert(twelve_wave_para.custom_simple_wave_zombies[9].has(int(CharacterRegistry.ZombieType.Z501Flag)))
	assert(not twelve_wave_para.custom_simple_wave_zombies[11].has(int(CharacterRegistry.ZombieType.Z501Flag)))
	var normal_only_level := simple_level.duplicate(true)
	for stage in normal_only_level["waves"]:
		stage["spawnGroups"] = []
	var normal_only_built := Runtime.build_game_para(normal_only_level)
	assert(normal_only_built["ok"], normal_only_built["error"])
	assert((normal_only_built["game_para"] as ResourceLevelData).zombie_refresh_types == [CharacterRegistry.ZombieType.Z500Norm])
	var grass_cell := PlantCell.new()
	var pool_cell := PlantCell.new()
	pool_cell.plant_cell_type = PlantCell.PlantCellType.Pool
	assert(TombStoneManager._can_place_tombstone(grass_cell))
	assert(not TombStoneManager._can_place_tombstone(pool_cell))
	grass_cell.free()
	pool_cell.free()
	## 示例包含 0-28、28-38、38-66、66-76 四个阶段，完整时间轴应结束于 76 秒。
	assert(game_para.custom_timeline_duration == 76.0)
	assert(float(game_para.custom_spawn_schedule[0]["time"]) < float(game_para.custom_spawn_schedule[-1]["time"]))
	assert(load("res://scenes/main/07LevelWorkshop.tscn") != null)
	assert(load("res://scenes/main/06CustomChooesLevel.tscn") != null)
	var start_menu_scene: PackedScene = load("res://scenes/main/01StartMenu.tscn")
	var start_menu := start_menu_scene.instantiate()
	await get_tree().process_frame
	get_tree().root.add_child(start_menu)
	await get_tree().process_frame
	assert(start_menu.get_node("BG_Right/Menu/LevelWorkshopButton") is TextureButton)
	assert(start_menu.get_node("BG_Right/Menu/LevelWorkshopButton/Label").text == "开\n发\n者\n模\n式")
	start_menu.queue_free()
	await get_tree().process_frame
	Global.developer_level_adjustments_active = true
	var developer_chooser_scene: PackedScene = load("res://scenes/main/06CustomChooesLevel.tscn")
	var developer_chooser := developer_chooser_scene.instantiate()
	get_tree().root.add_child(developer_chooser)
	await get_tree().process_frame
	await get_tree().process_frame
	assert((developer_chooser.get_node("Label") as Label).text == "开 发 者 关 卡")
	var developer_buttons: Array[ChooseLevelButtonCustomize] = []
	for page in developer_chooser.get_node("AllPage").get_children():
		for child in page.get_children():
			if child is ChooseLevelButtonCustomize:
				developer_buttons.append(child)
	assert(developer_buttons.size() >= AdventureLevelPresets.list_presets("normal").size())
	for preset_index in AdventureLevelPresets.list_presets("normal").size():
		var preset_id := str(AdventureLevelPresets.list_presets("normal")[preset_index]["id"])
		var expected_name := str(AdventureLevelPresets.build_level(preset_id, true)["name"])
		assert(developer_buttons[preset_index].level_name == expected_name)
	developer_chooser.queue_free()
	await get_tree().process_frame
	Global.developer_level_adjustments_active = false
	var workshop_scene: PackedScene = load("res://scenes/main/07LevelWorkshop.tscn")
	var workshop := workshop_scene.instantiate()
	await get_tree().process_frame
	get_tree().root.add_child(workshop)
	await get_tree().process_frame
	await get_tree().process_frame
	workshop.call("_toggle_editor_complexity")
	workshop.level = Logic.example_level()
	workshop.selected_wave = 0
	workshop.call("_refresh_wave")
	workshop.level["waves"] = [
		Logic.make_wave("normal_1", "普通波 1", 0.0, 28.0, [], "interval"),
		Logic.make_wave("normal_2", "普通波 2", 28.0, 28.0, [], "interval"),
	]
	workshop.call("_normalize_timeline_structure")
	assert((workshop.level["waves"] as Array).size() == 2)
	workshop.level = AdventureLevelPresets.build_level("adventure_1_10")
	var formal_wave_count := (workshop.level["waves"] as Array).size()
	workshop.call("_recalculate_stage_times")
	assert((workshop.level["waves"] as Array).size() == formal_wave_count)
	workshop.level["waves"] = [Logic.make_wave("only_interval", "无旗帜关卡", 0.0, 28.0, [], "interval")]
	workshop.call("_insert_flag_in_interval", 0, 0.0)
	assert((workshop.level["waves"] as Array).size() == 2)
	assert(workshop.level["waves"][-1]["stageType"] == "flag")
	workshop.level = Logic.example_level()
	workshop.selected_wave = 0
	workshop.call("_refresh_wave")
	var expected_normal_zombies: Array = AllCards.all_zombie_card_prefabs.keys().filter(func(value):
		var zombie_id := int(value)
		return zombie_id != int(CharacterRegistry.ZombieType.Z520Bungi) and zombie_id > 0 \
			and (zombie_id < 500 or AdventureLevelPresets.NORMAL_SUPPORT_ZOMBIES.has(zombie_id)) \
			and bool(workshop.call("_has_original_pick_weight", zombie_id))
	)
	assert(workshop.zombie_card_order.size() == expected_normal_zombies.size())
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
	var clicked_preview: Node2D = workshop.preview_zombies[5]
	var untouched_preview: Node2D = workshop.preview_zombies[0]
	workshop.call("_remove_zombie", str(workshop.level["waves"][-2]["spawnGroups"][0]["zombieType"]), clicked_preview)
	assert(not workshop.preview_zombies.has(clicked_preview))
	assert(workshop.preview_zombies.has(untouched_preview))
	assert(workshop.preview_zombies.size() == workshop.PREVIEW_MAX_ZOMBIES - 1)
	assert(int(workshop.level["waves"][-2]["spawnGroups"][0]["count"]) == 24)
	## 两面旗帜之间的波间不能删除；改为删除刚创建的末尾旗帜。
	workshop.call("_select_stage", (workshop.level["waves"] as Array).size() - 1)
	workshop.call("_delete_current_stage")
	assert((workshop.level["waves"] as Array).size() == 5)
	workshop.queue_free()
	await get_tree().process_frame
	game_para.custom_spawn_schedule = [
		{"time": 0.0, "zombie_type": 500, "lane": 0, "stage_index": 0},
		{"time": 0.1, "zombie_type": 502, "lane": 3, "stage_index": 0},
	]
	game_para.custom_stage_schedule = [{
		"stage_index": 0,
		"stage_type": "interval",
		"name": "逐只生成测试",
		"events": game_para.custom_spawn_schedule.duplicate(true),
	}]
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
	var workshop_return_button := main_game.get_node_or_null("CanvasLayerUI/All_UI/WorkshopReturnButton") as BaseButton
	assert(workshop_return_button != null)
	assert((workshop_return_button.get_node("Label") as Label).text == "编辑")
	assert(workshop_return_button.position.x < (main_game.get_node("CanvasLayerUI/All_UI/MainGameMenuButton") as BaseButton).position.x)
	var progress_stages: Array[Dictionary] = []
	for stage_index in 20:
		progress_stages.append({"stage_index": stage_index, "stage_type": "flag" if stage_index % 10 == 9 else "interval"})
	var first_flag_progress := float(main_game.zombie_manager.zombie_wave_manager.call("_custom_stage_progress", progress_stages, 9, false))
	assert(is_equal_approx(first_flag_progress, 9.0 / 19.0))
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
