extends Node

const Logic := preload("res://addons/pvz_level_editor/level_editor_logic.gd")
const Runtime := preload("res://scripts/resources/level/level_custom_runtime.gd")
const AdventureStore := preload("res://scripts/resources/level/adventure_level_store.gd")
const AdventurePresets := preload("res://scripts/resources/level/adventure_level_presets.gd")


func _ready() -> void:
	var workshop := (load("res://scenes/main/07LevelWorkshop.tscn") as PackedScene).instantiate()
	await get_tree().process_frame
	get_tree().root.add_child(workshop)
	await get_tree().process_frame
	await get_tree().process_frame

	workshop.editor_complexity = LevelWorkshop.EditorComplexity.SIMPLE
	workshop.level = Logic.example_level()
	workshop.level["editorMode"] = "simple"
	workshop.level["simpleZombiePool"] = [int(CharacterRegistry.ZombieType.Z001NormTalon)]
	workshop.level["waves"] = [Logic.make_wave("simple_curve", "简易曲线", 0.0, 28.0, [], "flag")]
	workshop.selected_wave = 0
	workshop.call("_sanitize_simple_allowed_pool")

	var base_type := int(CharacterRegistry.ZombieType.Z001NormTalon)
	var original_normal := int(CharacterRegistry.ZombieType.Z501Norm)
	assert((workshop.level["simpleZombiePool"] as Array).has(base_type))
	assert((workshop.level["waves"][0]["spawnGroups"] as Array).size() == 1)

	workshop.call("_select_simple_zombie", str(original_normal))
	assert((workshop.level["simpleZombiePool"] as Array).has(original_normal))
	assert(not workshop.level.has("simpleZombieIntroWaves"))
	assert((workshop.level["waves"][0]["spawnGroups"] as Array).size() == 2)

	var built := Runtime.build_game_para(Logic.normalize_level(workshop.level))
	assert(built["ok"], built["error"])
	var game_para := built["game_para"] as ResourceLevelData
	assert(game_para.zombie_refresh_types.has(CharacterRegistry.ZombieType.Z501Norm))
	## 没有冒险关 ID 的自制关无法比较前置关卡，因此不自动标记首秀。
	assert(game_para.simple_zombie_intro_waves.is_empty())

	## 原本只用于召唤的小鬼现在也可由简易自然波次直接抽取。
	var summoned_type := int(CharacterRegistry.ZombieType.Z525Imp)
	workshop.call("_select_simple_zombie", str(summoned_type))
	assert((workshop.level["simpleZombiePool"] as Array).has(summoned_type))
	var summoned_holder := workshop.call("_make_zombie_card", summoned_type) as Control
	assert(not ((summoned_holder.get_child(0) as Card).get_node("Button") as Button).disabled)
	var summoned_level := Logic.normalize_level(workshop.level)
	assert(not Logic.validate_level(summoned_level).any(func(issue):
		return str((issue as Dictionary).get("severity", "")) == "error"
	))
	var summoned_built := Runtime.build_game_para(summoned_level)
	assert(summoned_built["ok"], summoned_built["error"])
	var summoned_para := summoned_built["game_para"] as ResourceLevelData
	summoned_para.call("_init_zombie_refresh_from_whitelist")
	assert(summoned_para.zombie_refresh_types.has(
		CharacterRegistry.ZombieType.Z525Imp
	))
	workshop.call("_delete_simple_zombie", str(summoned_type))

	## 蹦极使用既有的旗帜波目标格机制，不能作为道路行走僵尸创建。
	var bungee_type := int(CharacterRegistry.ZombieType.Z521Bungi)
	workshop.call("_select_simple_zombie", str(bungee_type))
	var bungee_built := Runtime.build_game_para(Logic.normalize_level(workshop.level))
	assert(bungee_built["ok"], bungee_built["error"])
	var bungee_para := bungee_built["game_para"] as ResourceLevelData
	assert(bungee_para.is_bungi)
	assert(not bungee_para.zombie_refresh_types.has(CharacterRegistry.ZombieType.Z521Bungi))
	workshop.call("_delete_simple_zombie", str(bungee_type))

	workshop.call("_delete_simple_zombie", str(original_normal))
	assert(not (workshop.level["simpleZombiePool"] as Array).has(original_normal))
	workshop.call("_delete_simple_zombie", str(base_type))
	assert((workshop.level["simpleZombiePool"] as Array).has(base_type))

	## 后半程增压必须在简易设置中可见、可保存，并能设为 1.0 完全关闭。
	workshop.level["simpleLateGamePowerMultiplier"] = 1.4
	workshop.call("_open_level_settings")
	await get_tree().process_frame
	var late_game_power_setting: SpinBox
	var sun_setting: SpinBox
	for setting in workshop.quantity_dialog_layer.find_children("*", "SpinBox", true, false):
		var setting_label = (setting as SpinBox).get_meta("settings_label", null)
		if setting_label is Label and (setting_label as Label).text == "后半程出怪战力倍率":
			late_game_power_setting = setting as SpinBox
		if setting_label is Label and (setting_label as Label).text == "开局阳光":
			sun_setting = setting as SpinBox
	assert(late_game_power_setting != null)
	assert(sun_setting != null)
	assert(is_equal_approx(late_game_power_setting.value, 1.4))
	assert(is_equal_approx(late_game_power_setting.min_value, 1.0))
	assert(is_equal_approx(late_game_power_setting.max_value, 1.6))
	assert(sun_setting.position.x + sun_setting.size.x <= late_game_power_setting.position.x)
	late_game_power_setting.value = 1.0
	var saved_late_game_power := false
	var found_cancel_button := false
	for button in workshop.quantity_dialog_layer.find_children("*", "", true, false):
		if not button is TextureButton:
			continue
		var button_label := (button as TextureButton).get_child(0) as Label if (button as TextureButton).get_child_count() > 0 else null
		if button_label != null and button_label.text == "取消":
			found_cancel_button = true
			assert((button as TextureButton).visible)
			assert(workshop.get_viewport_rect().encloses((button as TextureButton).get_global_rect()))
		if button_label != null and button_label.text == "确认":
			assert((button as TextureButton).visible)
			assert(workshop.get_viewport_rect().encloses((button as TextureButton).get_global_rect()))
			(button as TextureButton).pressed.emit()
			saved_late_game_power = true
			break
	assert(saved_late_game_power)
	assert(found_cancel_button)
	assert(is_equal_approx(float(workshop.level["simpleLateGamePowerMultiplier"]), 1.0))

	workshop.queue_free()
	await get_tree().process_frame

	## 正式冒险的默认后半程补偿会在新世界开头重置：
	## 1-1～1-6 不变，第二世界的 2-1～2-3 也不额外加难。
	assert(ZombieWaveCreateManager.simple_late_game_power_limit(10, 9, 10, 1.0) == 10)
	assert(ZombieWaveCreateManager.simple_late_game_power_limit(2, 4, 10, 1.4) == 2)
	assert(ZombieWaveCreateManager.simple_late_game_power_limit(3, 7, 10, 1.4) == 4)
	assert(ZombieWaveCreateManager.simple_late_game_power_limit(10, 9, 10, 1.4) == 14)
	assert(ZombieWaveCreateManager.simple_late_game_power_limit(4, 9, 20, 1.6) == 4)
	assert(ZombieWaveCreateManager.simple_late_game_power_limit(5, 13, 20, 1.6) == 6)
	assert(ZombieWaveCreateManager.simple_late_game_power_limit(17, 19, 20, 1.6) == 27)
	for pressure_case in [
		["adventure_1_6", 1.0],
		["adventure_1_7", 1.2],
		["adventure_1_8", 1.4],
		["adventure_1_9", 1.6],
		["adventure_2_1", 1.0],
		["adventure_2_3", 1.0],
		["adventure_2_4", 1.1],
		["adventure_2_8", 1.5],
		["adventure_2_9", 1.6],
	]:
		var pressure_level := Logic.normalize_level(AdventurePresets.build_level(str(pressure_case[0])))
		var pressure_built := Runtime.build_game_para(pressure_level)
		assert(pressure_built["ok"], pressure_built["error"])
		var pressure_para := pressure_built["game_para"] as ResourceLevelData
		assert(is_equal_approx(
			pressure_para.simple_late_game_max_power_multiplier,
			float(pressure_case[1])
		))
		assert(is_equal_approx(
			pressure_para.duplicate_runtime().simple_late_game_max_power_multiplier,
			float(pressure_case[1])
		))
	## 关卡工坊的显式值覆盖默认曲线；1.0 会完全恢复原版点数。
	var disabled_pressure_level := AdventurePresets.build_level("adventure_1_8")
	disabled_pressure_level["simpleLateGamePowerMultiplier"] = 1.0
	var disabled_pressure_built := Runtime.build_game_para(Logic.normalize_level(disabled_pressure_level))
	assert(disabled_pressure_built["ok"], disabled_pressure_built["error"])
	assert(is_equal_approx(
		(disabled_pressure_built["game_para"] as ResourceLevelData).simple_late_game_max_power_multiplier,
		1.0
	))
	var custom_pressure_level := Logic.example_level()
	custom_pressure_level["editorMode"] = "simple"
	custom_pressure_level["simpleLateGamePowerMultiplier"] = 1.35
	var custom_pressure_built := Runtime.build_game_para(Logic.normalize_level(custom_pressure_level))
	assert(custom_pressure_built["ok"], custom_pressure_built["error"])
	assert(is_equal_approx(
		(custom_pressure_built["game_para"] as ResourceLevelData).simple_late_game_max_power_multiplier,
		1.35
	))

	## 直接读取关卡工坊当前保存的 1-3：铁桶未出现在 1-1、1-2，
	## 因而会被自动判定为本关首秀，在中间波强制出现，并于最终波再次补齐。
	var level_1_3_loaded := AdventureStore.load_developer_level("adventure_1_3")
	assert(level_1_3_loaded["ok"], level_1_3_loaded["error"])
	var level_1_3_built := Runtime.build_game_para(Logic.normalize_level(level_1_3_loaded["level"]))
	assert(level_1_3_built["ok"], level_1_3_built["error"])
	var level_1_3_para := level_1_3_built["game_para"] as ResourceLevelData
	assert(is_equal_approx(level_1_3_para.simple_late_game_max_power_multiplier, 1.0))
	assert(int(level_1_3_para.simple_zombie_intro_waves[CharacterRegistry.ZombieType.Z505Bucket]) == 6)
	level_1_3_para.set_choose_level(MainSceneRegistry.MainScenes.LevelWorkshop, 0, "adventure_1_3_auto_intro_test")
	Global.game_para = level_1_3_para
	var level_1_3_scene := (load(Global.main_scene_registry.MainScenesMap[level_1_3_para.game_sences]) as PackedScene).instantiate()
	get_tree().root.add_child(level_1_3_scene)
	await get_tree().process_frame
	await get_tree().process_frame
	var level_1_3_creator := level_1_3_scene.get_node("Manager/ZombieManager/ZombieWaveManager/ZombieWaveCreateManager") as ZombieWaveCreateManager
	assert(level_1_3_creator.simple_wave_plan.size() == 10)
	## 早期关的最终大波仍是原版 10 点；后期补偿只改最终预算，
	## 原版 wave/3+1 与大波 2.5 倍的计算顺序不变。
	assert(level_1_3_creator.calculate_wave_power_limit(9, true) == 10)
	level_1_3_para.simple_late_game_max_power_multiplier = 1.4
	assert(level_1_3_creator.calculate_wave_power_limit(4, false) == 2)
	assert(level_1_3_creator.calculate_wave_power_limit(7, false) == 4)
	assert(level_1_3_creator.calculate_wave_power_limit(9, true) == 14)
	level_1_3_para.simple_late_game_max_power_multiplier = 1.0
	var before_intro: Array[CharacterRegistry.ZombieType] = level_1_3_creator.create_curr_wave_zombie_list(4, false)
	assert(not before_intro.has(CharacterRegistry.ZombieType.Z505Bucket))
	var middle_intro: Array[CharacterRegistry.ZombieType] = level_1_3_creator.create_curr_wave_zombie_list(5, false)
	assert(middle_intro.has(CharacterRegistry.ZombieType.Z505Bucket))
	assert(level_1_3_creator.zombie_weights[CharacterRegistry.ZombieType.Z501Norm] < 4000)
	assert(level_1_3_creator.zombie_weights[CharacterRegistry.ZombieType.Z503Cone] < 4000)
	var level_1_3_final_wave := level_1_3_para.max_wave - 1
	var level_1_3_types: Array[CharacterRegistry.ZombieType] = level_1_3_creator.create_curr_wave_zombie_list(level_1_3_final_wave, true)
	var all_planned_types := {}
	for planned_wave in level_1_3_creator.simple_wave_plan:
		for zombie_type in planned_wave:
			all_planned_types[int(zombie_type)] = true
	assert(all_planned_types.has(int(CharacterRegistry.ZombieType.Z501Norm)))
	assert(all_planned_types.has(int(CharacterRegistry.ZombieType.Z503Cone)))
	assert(all_planned_types.has(int(CharacterRegistry.ZombieType.Z505Bucket)))
	var level_1_3_bucket_index := level_1_3_types.find(CharacterRegistry.ZombieType.Z505Bucket)
	assert(level_1_3_bucket_index >= 0)
	var level_1_3_zombies: Array[Zombie000Base] = level_1_3_creator.create_curr_wave_all_zombies(level_1_3_final_wave, true)
	var level_1_3_bucket := level_1_3_zombies[level_1_3_bucket_index]
	level_1_3_bucket.global_position.x = 1029.0
	var level_1_3_zombie_manager := level_1_3_scene.get_node("Manager/ZombieManager") as ZombieManager
	level_1_3_zombie_manager.set_zombie_death_over_view()
	assert(not level_1_3_bucket.is_death)
	level_1_3_scene.queue_free()
	await get_tree().process_frame

	## 非首秀类型若因战力过高而整关前九波都无法抽中，最终波必须由
	## PutInMissingZombies 补入；这验证的不是“末波无条件塞满全部类型”。
	var missing_level := Logic.example_level()
	missing_level.erase("formalPresetId")
	missing_level["editorMode"] = "simple"
	missing_level["simpleFlagCount"] = 1
	missing_level["simpleBaseZombieType"] = int(CharacterRegistry.ZombieType.Z501Norm)
	missing_level["simpleFlagZombieType"] = int(CharacterRegistry.ZombieType.Z502Flag)
	missing_level["simpleZombiePool"] = [
		int(CharacterRegistry.ZombieType.Z501Norm),
		int(CharacterRegistry.ZombieType.Z524Gargantuar),
	]
	var missing_built := Runtime.build_game_para(Logic.normalize_level(missing_level))
	assert(missing_built["ok"], missing_built["error"])
	var missing_para := missing_built["game_para"] as ResourceLevelData
	assert(missing_para.simple_zombie_intro_waves.is_empty())
	missing_para.set_choose_level(MainSceneRegistry.MainScenes.LevelWorkshop, 0, "put_in_missing_test")
	Global.game_para = missing_para
	var missing_scene := (load(Global.main_scene_registry.MainScenesMap[missing_para.game_sences]) as PackedScene).instantiate()
	get_tree().root.add_child(missing_scene)
	await get_tree().process_frame
	await get_tree().process_frame
	var missing_creator := missing_scene.get_node("Manager/ZombieManager/ZombieWaveManager/ZombieWaveCreateManager") as ZombieWaveCreateManager
	for wave_index in range(0, 9):
		assert(not missing_creator.simple_wave_plan[wave_index].has(CharacterRegistry.ZombieType.Z524Gargantuar))
	assert(missing_creator.simple_wave_plan[9].has(CharacterRegistry.ZombieType.Z524Gargantuar))
	missing_scene.queue_free()
	await get_tree().process_frame
	print("test_simple_curve_controls: PASS")
	get_tree().quit(0)
