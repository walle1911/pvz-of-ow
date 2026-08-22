extends Node

const Logic := preload("res://addons/pvz_level_editor/level_editor_logic.gd")
const Runtime := preload("res://scripts/resources/level/level_custom_runtime.gd")
const AdventurePresets := preload("res://scripts/resources/level/adventure_level_presets.gd")
const FormalStore := preload("res://scripts/resources/level/adventure_level_store.gd")

func _ready() -> void:
	## 1-1 只有中间三行草皮；刷怪权重必须同步屏蔽上下两条未铺草皮行。
	assert(ZombieChooseRowSystem.mask_inactive_rows([1, 1, 1, 1, 1], [1, 2, 3]) == [0.0, 1.0, 1.0, 1.0, 0.0])
	var bobsled_dependency_level := Logic.example_level()
	bobsled_dependency_level["editorMode"] = "simple"
	bobsled_dependency_level["mapConfig"] = {"type": "pool", "rows": 6, "columns": 9}
	bobsled_dependency_level["simpleZombiePool"] = [
		int(CharacterRegistry.ZombieType.Z001NormTalon),
		int(CharacterRegistry.ZombieType.Z514Bobsled),
	]
	var bobsled_dependency_built := Runtime.build_game_para(bobsled_dependency_level)
	assert(bobsled_dependency_built["ok"], bobsled_dependency_built["error"])
	var bobsled_dependency_para := bobsled_dependency_built["game_para"] as ResourceLevelData
	assert(bobsled_dependency_para.zombie_refresh_types.has(CharacterRegistry.ZombieType.Z514Bobsled))
	assert(bobsled_dependency_para.zombie_refresh_types.has(CharacterRegistry.ZombieType.Z013ZomboniShion))
	assert(ZombieWaveCreateManager.resolve_bobsled_spawn_type(
		CharacterRegistry.ZombieType.Z514Bobsled,
		false
	) == CharacterRegistry.ZombieType.Z013ZomboniShion)
	assert(ZombieWaveCreateManager.resolve_bobsled_spawn_type(
		CharacterRegistry.ZombieType.Z514Bobsled,
		true
	) == CharacterRegistry.ZombieType.Z514Bobsled)
	print("BOBSLED_SHION_RUNTIME_OK")
	var example := Logic.example_level()
	example["rewardPlants"] = [
		int(CharacterRegistry.PlantType.P001PeaShooterSoldier76),
		int(CharacterRegistry.PlantType.P002SunflowerMercy),
	]
	var built := Runtime.build_game_para(example)
	assert(built["ok"], built["error"])
	var game_para: ResourceLevelData = built["game_para"]
	assert(game_para.reward_plant_type == int(CharacterRegistry.PlantType.P001PeaShooterSoldier76))
	assert(game_para.reward_plant_types == [
		CharacterRegistry.PlantType.P001PeaShooterSoldier76,
		CharacterRegistry.PlantType.P002SunflowerMercy,
	])
	var special_reward_type := int(CharacterRegistry.PlantType.P548CobCannon)
	var special_reward_level := Logic.example_level()
	special_reward_level["id"] = "special_reward_source"
	special_reward_level["rewardPlants"] = [special_reward_type]
	special_reward_level["specialRewardCardLevels"] = {str(special_reward_type): ["adventure_1_1", "adventure_1_2"]}
	var special_reward_built := Runtime.build_game_para(special_reward_level)
	assert(special_reward_built["ok"], special_reward_built["error"])
	var special_reward_para := special_reward_built["game_para"] as ResourceLevelData
	assert(special_reward_para.special_reward_card_levels == {str(special_reward_type): ["adventure_1_1", "adventure_1_2"]})
	assert(Logic.validate_level(special_reward_level).all(func(issue): return issue["severity"] != "error"))
	var boss_level := Logic.example_level()
	boss_level["bossConfig"] = {
		"enabled": true,
		"zombieType": int(CharacterRegistry.ZombieType.Z003ConeTalon),
		"rewardPlant": int(CharacterRegistry.PlantType.P003CherryBombJunkrat),
	}
	boss_level["simpleZombiePool"] = [
		int(CharacterRegistry.ZombieType.Z001NormTalon),
		int(CharacterRegistry.ZombieType.Z003ConeTalon),
	]
	var boss_built := Runtime.build_game_para(boss_level)
	assert(boss_built["ok"], boss_built["error"])
	var boss_para := boss_built["game_para"] as ResourceLevelData
	assert(boss_para.boss_enabled)
	assert(boss_para.boss_zombie_type == CharacterRegistry.ZombieType.Z003ConeTalon)
	assert(boss_para.boss_reward_plant_type == int(CharacterRegistry.PlantType.P003CherryBombJunkrat))
	assert(boss_para.game_BGM == ConstLevelData.GameBGM.Boss)
	assert(not boss_para.zombie_refresh_types.has(CharacterRegistry.ZombieType.Z003ConeTalon))
	assert(Logic.validate_level(boss_level).all(func(issue): return issue["severity"] != "error"))
	var invalid_boss_level := boss_level.duplicate(true)
	invalid_boss_level["bossConfig"]["rewardPlant"] = -1
	assert(Logic.validate_level(invalid_boss_level).any(func(issue): return issue["path"] == "bossConfig/rewardPlant"))
	var legacy_reward_level := Logic.example_level()
	legacy_reward_level["rewardPlant"] = int(CharacterRegistry.PlantType.P003CherryBombJunkrat)
	legacy_reward_level.erase("rewardPlants")
	assert(Logic.normalize_level(legacy_reward_level)["rewardPlants"] == [int(CharacterRegistry.PlantType.P003CherryBombJunkrat)])
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
	simple_level["zombieRefreshSpeedMultiplier"] = 2.0
	simple_level["initialWaveDelay"] = 0.25
	simple_level["openingFirstZombieAdvanceCells"] = 7.5
	simple_level["formalPresetId"] = "adventure_1_1"
	var simple_built := Runtime.build_game_para(simple_level)
	assert(simple_built["ok"], simple_built["error"])
	var simple_para: ResourceLevelData = simple_built["game_para"]
	## 简易关卡保留专属入场规则，僵尸名单由自然波次管理器开战前预生成。
	assert(simple_para.custom_simple_original_mode)
	assert(simple_para.custom_initial_wave_delay == 0.25)
	assert(simple_para.opening_first_zombie_advance_cells == 7.5)
	assert(simple_para.opening_battlefield_zombie_type == CharacterRegistry.ZombieType.Z501Norm)
	assert(simple_para.zombie_refresh_speed_multiplier == 2.0)
	assert(ZombieWaveRefreshManager.scaled_refresh_duration(simple_para.custom_initial_wave_delay, simple_para.zombie_refresh_speed_multiplier) == 0.125)
	assert(ZombieWaveRefreshManager.scaled_refresh_duration(25.0, simple_para.zombie_refresh_speed_multiplier) == 12.5)
	assert(ZombieWaveRefreshManager.scaled_refresh_duration(6.0, simple_para.zombie_refresh_speed_multiplier) == 3.0)
	assert(simple_para.max_wave == 20)
	assert(simple_para.custom_spawn_schedule.is_empty())
	assert(simple_para.custom_stage_schedule.is_empty())
	assert(simple_para.custom_flag_data.is_empty())
	assert(simple_para.simple_base_zombie_type == CharacterRegistry.ZombieType.Z001NormTalon)
	assert(simple_para.simple_flag_zombie_type == CharacterRegistry.ZombieType.Z002FlagTalon)
	assert(simple_para.zombie_refresh_types == [
		CharacterRegistry.ZombieType.Z001NormTalon,
		CharacterRegistry.ZombieType.Z003ConeTalon,
		CharacterRegistry.ZombieType.Z005BucketTalon,
	])
	assert(simple_para.simple_zombie_intro_waves == {
		int(CharacterRegistry.ZombieType.Z003ConeTalon): 11,
		int(CharacterRegistry.ZombieType.Z005BucketTalon): 11,
	})
	var alternate_roles := simple_level.duplicate(true)
	alternate_roles["simpleBaseZombieType"] = int(CharacterRegistry.ZombieType.Z501Norm)
	alternate_roles["simpleFlagZombieType"] = int(CharacterRegistry.ZombieType.Z502Flag)
	var alternate_built := Runtime.build_game_para(alternate_roles)
	assert(alternate_built["ok"], alternate_built["error"])
	var alternate_para := alternate_built["game_para"] as ResourceLevelData
	assert(alternate_para.simple_base_zombie_type == CharacterRegistry.ZombieType.Z501Norm)
	assert(alternate_para.simple_flag_zombie_type == CharacterRegistry.ZombieType.Z502Flag)
	assert(alternate_para.zombie_refresh_types.has(CharacterRegistry.ZombieType.Z501Norm))
	assert(ZombieWaveCreateManager.zombie_power[CharacterRegistry.ZombieType.Z001NormTalon] == 1)
	assert(ZombieWaveCreateManager.zombie_weights_ori[CharacterRegistry.ZombieType.Z001NormTalon] == 4000)
	## 原版同帧创建整波，靠屏幕右侧出生距离错开入场；旗帜波再整体后移 40。
	assert(ZombieWaveCreateManager.original_spawn_x_offset(8, 20, 0) == 0.0)
	assert(ZombieWaveCreateManager.original_spawn_x_offset(8, 20, 39) == 39.0)
	assert(ZombieWaveCreateManager.original_spawn_x_offset(9, 20, 0) == 40.0)
	## 第一面旗帜后的普通波必须恢复普通 0..39 偏移，不得继承旗帜波状态。
	assert(ZombieWaveCreateManager.original_spawn_x_offset(10, 20, 0) == 0.0)
	assert(ZombieWaveCreateManager.original_spawn_x_offset(10, 20, 39) == 39.0)
	assert(ZombieWaveCreateManager.original_spawn_x_offset(19, 20, 39) == 79.0)
	assert(ZombieWaveCreateManager.opening_spawn_x_offset(20.0, 7.5, 80.0) == -580.0)
	## 选卡前只放置静止展示替身；它不计入实战僵尸，正式首波创建后才开始移动。
	simple_para.set_choose_level(MainSceneRegistry.MainScenes.LevelWorkshop, 0, "opening_preview_test")
	Global.game_para = simple_para
	var opening_scene := (load(Global.main_scene_registry.MainScenesMap[simple_para.game_sences]) as PackedScene).instantiate()
	await get_tree().process_frame
	get_tree().root.add_child(opening_scene)
	await get_tree().process_frame
	await get_tree().process_frame
	var opening_show := opening_scene.zombie_manager.zombie_show_in_start.opening_battlefield_zombie as Zombie000Base
	assert(is_instance_valid(opening_show))
	assert(opening_show.zombie_type == CharacterRegistry.ZombieType.Z501Norm)
	assert(opening_scene.zombie_manager.curr_zombie_num == 0)
	var opening_show_position := opening_show.global_position
	await get_tree().create_timer(0.2, false).timeout
	assert(is_instance_valid(opening_show) and opening_show.global_position.is_equal_approx(opening_show_position))
	opening_scene.zombie_manager.zombie_wave_manager.start_first_wave()
	await get_tree().process_frame
	assert(opening_scene.zombie_manager.zombie_show_in_start.opening_battlefield_zombie == null)
	assert(opening_scene.zombie_manager.curr_zombie_num == 1)
	var opening_real := opening_scene.zombie_manager.all_zombies_1d[0] as Zombie000Base
	var opening_real_position := opening_real.global_position
	await get_tree().create_timer(0.2, false).timeout
	assert(opening_real.global_position.x < opening_real_position.x)
	opening_scene.queue_free()
	await get_tree().process_frame
	var three_flag_level := simple_level.duplicate(true)
	three_flag_level["simpleFlagCount"] = 3
	three_flag_level["simpleWaveCount"] = 30
	var three_flag_built := Runtime.build_game_para(three_flag_level)
	assert(three_flag_built["ok"], three_flag_built["error"])
	var three_flag_para: ResourceLevelData = three_flag_built["game_para"]
	assert(three_flag_para.max_wave == 30)
	var legacy_simple_level := simple_level.duplicate(true)
	legacy_simple_level.erase("simpleFlagCount")
	legacy_simple_level["simpleWaveCount"] = 30
	var normalized_legacy := Logic.normalize_level(legacy_simple_level)
	assert(int(normalized_legacy["simpleFlagCount"]) == 3)
	assert(int(normalized_legacy["simpleWaveCount"]) == 30)
	var normal_only_level := simple_level.duplicate(true)
	normal_only_level.erase("simpleZombiePool")
	for stage in normal_only_level["waves"]:
		stage["spawnGroups"] = []
	var normal_only_built := Runtime.build_game_para(normal_only_level)
	assert(normal_only_built["ok"], normal_only_built["error"])
	assert((normal_only_built["game_para"] as ResourceLevelData).zombie_refresh_types == [CharacterRegistry.ZombieType.Z001NormTalon])
	assert(ZombieWaveCreateManager.zombie_power[CharacterRegistry.ZombieType.Z511Duckytube] == 1)
	assert(ZombieWaveCreateManager.zombie_weights_ori[CharacterRegistry.ZombieType.Z511Duckytube] == 3600)
	assert(ZombieWaveCreateManager.zombie_weights_ori[CharacterRegistry.ZombieType.Z020ZombieYetiWinston] == 300)
	## 1-1～3-10 工坊曲线必须全部可构建，自动推导的首秀表也必须闭合。
	for world in range(1, 4):
		for level_number in range(1, 11):
			var preset_id := "adventure_%d_%d" % [world, level_number]
			var stored := FormalStore.load_developer_level(preset_id)
			assert(stored["ok"], "%s: %s" % [preset_id, stored["error"]])
			var curve_level := Logic.normalize_level(stored["level"])
			var curve_errors := Logic.validate_level(curve_level).filter(
				func(issue): return str((issue as Dictionary).get("severity", "")) == "error"
			)
			assert(curve_errors.is_empty(), "%s: %s" % [preset_id, str(curve_errors)])
			var curve_built := Runtime.build_game_para(curve_level)
			assert(curve_built["ok"], "%s: %s" % [preset_id, curve_built["error"]])
			var curve_para := curve_built["game_para"] as ResourceLevelData
			assert(curve_para.max_wave == int(curve_level["simpleFlagCount"]) * 10)
			for zombie_type_value in curve_level["simpleZombiePool"]:
				var zombie_type := int(zombie_type_value)
				assert(ZombieWaveCreateManager.zombie_power.has(zombie_type), "%s missing power %d" % [preset_id, zombie_type])
				assert(ZombieWaveCreateManager.zombie_weights_ori.has(zombie_type), "%s missing weight %d" % [preset_id, zombie_type])
			assert(not curve_level.has("simpleZombieIntroWaves"))
			for zombie_type in AdventureLevelPresets.automatically_introduced_zombies(curve_level):
				assert((curve_level["simpleZombiePool"] as Array).has(zombie_type))
				assert(curve_para.simple_zombie_intro_waves.has(zombie_type))
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
		return zombie_id != int(CharacterRegistry.ZombieType.Null) and CharacterRegistry.ZombieInfo.has(zombie_id)
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
		{"time": 0.0, "zombie_type": 501, "lane": 0, "stage_index": 0},
		{"time": 0.1, "zombie_type": 503, "lane": 3, "stage_index": 0},
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
