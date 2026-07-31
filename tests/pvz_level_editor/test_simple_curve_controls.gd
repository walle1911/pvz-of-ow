extends Node

const Logic := preload("res://addons/pvz_level_editor/level_editor_logic.gd")
const Runtime := preload("res://scripts/resources/level/level_custom_runtime.gd")


func _ready() -> void:
	var workshop := (load("res://scenes/main/07LevelWorkshop.tscn") as PackedScene).instantiate()
	await get_tree().process_frame
	get_tree().root.add_child(workshop)
	await get_tree().process_frame
	await get_tree().process_frame

	workshop.editor_complexity = LevelWorkshop.EditorComplexity.SIMPLE
	workshop.level = Logic.example_level()
	workshop.level["editorMode"] = "simple"
	workshop.level["simpleZombiePool"] = [int(CharacterRegistry.ZombieType.Z000NormTalon)]
	workshop.level["simpleZombieIntroWaves"] = {}
	workshop.level["waves"] = [Logic.make_wave("simple_curve", "简易曲线", 0.0, 28.0, [], "flag")]
	workshop.selected_wave = 0
	workshop.call("_sanitize_simple_allowed_pool")

	var base_type := int(CharacterRegistry.ZombieType.Z000NormTalon)
	var original_normal := int(CharacterRegistry.ZombieType.Z500Norm)
	assert((workshop.level["simpleZombiePool"] as Array).has(base_type))
	assert((workshop.level["waves"][0]["spawnGroups"] as Array).size() == 1)

	workshop.call("_select_simple_zombie", str(original_normal))
	assert((workshop.level["simpleZombiePool"] as Array).has(original_normal))
	assert(int((workshop.level["simpleZombieIntroWaves"] as Dictionary)[str(original_normal)]) == 1)
	assert((workshop.level["waves"][0]["spawnGroups"] as Array).size() == 2)
	workshop.call("_set_simple_intro_wave", original_normal, 6)
	assert(int((workshop.level["simpleZombieIntroWaves"] as Dictionary)[str(original_normal)]) == 6)

	var built := Runtime.build_game_para(Logic.normalize_level(workshop.level))
	assert(built["ok"], built["error"])
	var game_para := built["game_para"] as ResourceLevelData
	assert(game_para.zombie_refresh_types.has(CharacterRegistry.ZombieType.Z500Norm))
	assert(int(game_para.simple_zombie_intro_waves[original_normal]) == 6)

	## 原本只用于召唤的小鬼现在也可由简易自然波次直接抽取。
	var summoned_type := int(CharacterRegistry.ZombieType.Z524Imp)
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
		CharacterRegistry.ZombieType.Z524Imp
	))
	workshop.call("_delete_simple_zombie", str(summoned_type))

	## 蹦极使用既有的旗帜波目标格机制，不能作为道路行走僵尸创建。
	var bungee_type := int(CharacterRegistry.ZombieType.Z520Bungi)
	workshop.call("_select_simple_zombie", str(bungee_type))
	var bungee_built := Runtime.build_game_para(Logic.normalize_level(workshop.level))
	assert(bungee_built["ok"], bungee_built["error"])
	var bungee_para := bungee_built["game_para"] as ResourceLevelData
	assert(bungee_para.is_bungi)
	assert(not bungee_para.zombie_refresh_types.has(CharacterRegistry.ZombieType.Z520Bungi))
	workshop.call("_delete_simple_zombie", str(bungee_type))

	workshop.call("_delete_simple_zombie", str(original_normal))
	assert(not (workshop.level["simpleZombiePool"] as Array).has(original_normal))
	assert(not (workshop.level["simpleZombieIntroWaves"] as Dictionary).has(str(original_normal)))
	workshop.call("_delete_simple_zombie", str(base_type))
	assert((workshop.level["simpleZombiePool"] as Array).has(base_type))

	workshop.queue_free()
	await get_tree().process_frame

	## 首秀既要阻止提前随机，也要在目标波先于旗帜波普通填充预留战力。
	var intro_level := Logic.example_level()
	intro_level["editorMode"] = "simple"
	intro_level["simpleFlagCount"] = 1
	intro_level["simpleWaveCount"] = 10
	intro_level["simpleZombiePool"] = [
		base_type,
		int(CharacterRegistry.ZombieType.Z002ConeTalon),
		int(CharacterRegistry.ZombieType.Z013ZomboniShion),
	]
	intro_level["simpleZombieIntroWaves"] = {
		str(int(CharacterRegistry.ZombieType.Z002ConeTalon)): 7,
		str(int(CharacterRegistry.ZombieType.Z013ZomboniShion)): 10,
	}
	var intro_built := Runtime.build_game_para(Logic.normalize_level(intro_level))
	assert(intro_built["ok"], intro_built["error"])
	var intro_para := intro_built["game_para"] as ResourceLevelData
	intro_para.set_choose_level(MainSceneRegistry.MainScenes.LevelWorkshop, 0, "simple_intro_budget_test")
	Global.game_para = intro_para
	var main_scene := (load(Global.main_scene_registry.MainScenesMap[intro_para.game_sences]) as PackedScene).instantiate()
	get_tree().root.add_child(main_scene)
	await get_tree().process_frame
	await get_tree().process_frame
	var wave_creator := main_scene.get_node("Manager/ZombieManager/ZombieWaveManager/ZombieWaveCreateManager") as ZombieWaveCreateManager
	var before_intro: Array[CharacterRegistry.ZombieType] = wave_creator.create_curr_wave_zombie_list(3, false)
	assert(not before_intro.has(CharacterRegistry.ZombieType.Z002ConeTalon))
	var cone_intro: Array[CharacterRegistry.ZombieType] = wave_creator.create_curr_wave_zombie_list(6, false)
	assert(cone_intro.has(CharacterRegistry.ZombieType.Z002ConeTalon))
	var flag_intro: Array[CharacterRegistry.ZombieType] = wave_creator.create_curr_wave_zombie_list(9, true)
	assert(flag_intro.has(CharacterRegistry.ZombieType.Z013ZomboniShion))
	assert(_zombie_power_total(flag_intro) <= wave_creator.calculate_wave_power_limit(9, true))
	main_scene.queue_free()
	await get_tree().process_frame
	print("test_simple_curve_controls: PASS")
	get_tree().quit(0)


func _zombie_power_total(zombie_types: Array[CharacterRegistry.ZombieType]) -> int:
	var total := 0
	for zombie_type in zombie_types:
		total += int(ZombieWaveCreateManager.zombie_power[zombie_type])
	return total
