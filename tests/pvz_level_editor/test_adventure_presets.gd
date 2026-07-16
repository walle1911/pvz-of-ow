extends Node

const Presets := preload("res://scripts/resources/level/adventure_level_presets.gd")
const Runtime := preload("res://scripts/resources/level/level_custom_runtime.gd")
const Store := preload("res://scripts/resources/level/adventure_level_store.gd")
const MAP_TYPES := ["front_lawn", "night_lawn", "pool", "fog", "roof"]

var failures: Array[String] = []


func _ready() -> void:
	_test_all_normal_levels_build()
	_test_card_unlock_curve()
	_test_zombie_pool_resolution()
	_test_bob_boss_profile()
	_test_environment_tools()
	_test_map_runtime_assignments()
	_test_pool_lane_rules()
	_test_difficulty_growth()
	_test_formal_level_ids()
	_test_developer_override_isolation()
	await _test_choose_level_pages()
	if failures.is_empty():
		print("ADVENTURE_PRESETS_OK levels=50 final_plants=51 pool_rule=ow_first")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)


func _test_all_normal_levels_build() -> void:
	var presets: Array[Dictionary] = Presets.list_presets("normal")
	_expect(presets.size() == 50, "普通正式主线应包含 50 关")
	for world in range(1, 6):
		for level_number in range(1, 11):
			var preset_id := "adventure_%d_%d" % [world, level_number]
			var source: Dictionary = Presets.build_level(preset_id)
			_expect(str((source.get("mapConfig", {}) as Dictionary).get("type", "")) == MAP_TYPES[world - 1], "%s 地图类型错误" % preset_id)
			var built: Dictionary = Runtime.build_game_para(source)
			_expect(bool(built.get("ok", false)), "%s 无法转换为正式运行时资源：%s" % [preset_id, str(built.get("error", ""))])


func _test_card_unlock_curve() -> void:
	for global_level in range(1, 51):
		var world := int((global_level - 1) / 10) + 1
		var level_number := (global_level - 1) % 10 + 1
		var source: Dictionary = Presets.build_level("adventure_%d_%d" % [world, level_number])
		var available: Array = source.get("availablePlants", [])
		for original_type in Presets.ORIGINAL_PLANT_INTRO_LEVEL:
			if global_level < int(Presets.ORIGINAL_PLANT_INTRO_LEVEL[original_type]):
				continue
			var replacements: Array = Presets.PLANT_OW_REPLACEMENTS.get(original_type, [original_type])
			for resolved_type in replacements:
				_expect(available.has(int(resolved_type)), "%d-%d 缺少已解锁植物 %d" % [world, level_number, int(resolved_type)])
			if Presets.PLANT_OW_REPLACEMENTS.has(original_type):
				_expect(not available.has(int(original_type)), "%d-%d 同时出现了原版植物 %d 与 OW 替代" % [world, level_number, int(original_type)])
		for plant_type in available:
			_expect(CharacterRegistry.PlantInfo.has(int(plant_type)), "%d-%d 含未注册植物 %d" % [world, level_number, int(plant_type)])

	var day_mixed: Array = Presets.build_level("adventure_1_6").get("availablePlants", [])
	_expect(day_mixed.has(504), "1-6 应保留没有 OW 版的原版土豆雷")
	_expect(day_mixed.has(52), "1-5 起应加入 OW 独占的拉玛刹菜")
	var night_first: Array = Presets.build_level("adventure_2_1").get("availablePlants", [])
	_expect(night_first.has(508), "2-1 应保留没有 OW 版的原版小喷菇")
	var roof_first: Array = Presets.build_level("adventure_5_1").get("availablePlants", [])
	_expect(roof_first.has(532) and roof_first.has(533), "5-1 应提供原版卷心菜和花盆以适配屋顶")
	var final_pool: Array = Presets.build_level("adventure_5_10").get("availablePlants", [])
	_expect(final_pool.size() == 51, "最终植物池应由 49 个原版槽位、第二 OW 猫尾草和 OW 独占植物组成")
	_expect(final_pool.has(1) and final_pool.has(504) and final_pool.has(544), "最终池应同时包含 OW 替代、原版基础回退和原版升级回退")


func _test_zombie_pool_resolution() -> void:
	var all_seen: Array[int] = []
	for world in range(1, 6):
		for level_number in range(1, 11):
			var level_types := _level_zombie_types(Presets.build_level("adventure_%d_%d" % [world, level_number]))
			for zombie_type in level_types:
				if not all_seen.has(zombie_type):
					all_seen.append(zombie_type)
				_expect(CharacterRegistry.ZombieInfo.has(zombie_type), "%d-%d 含未注册僵尸 %d" % [world, level_number, zombie_type])
				for original_type in Presets.ZOMBIE_OW_REPLACEMENTS:
					_expect(zombie_type != int(original_type), "%d-%d 刷出了已有 OW 替代的原版僵尸 %d" % [world, level_number, zombie_type])

	var day_pole := _level_zombie_types(Presets.build_level("adventure_1_6"))
	_expect(day_pole.has(503), "1-6 应使用没有 OW 版的原版撑杆僵尸")
	var night_dancer := _level_zombie_types(Presets.build_level("adventure_2_8"))
	_expect(night_dancer.has(9) and not night_dancer.has(508), "2-8 舞王槽位应只使用 OW 卢西奥版本")
	var pool_late := _level_zombie_types(Presets.build_level("adventure_3_8"))
	_expect(pool_late.has(13) and not pool_late.has(512), "泳池冰车槽位应只使用 OW 紫苑版本")
	_expect(pool_late.has(513) and pool_late.has(514), "泳池后期应保留没有 OW 版的雪橇和海豚僵尸")
	var fog_intro := _level_zombie_types(Presets.build_level("adventure_4_3"))
	_expect(fog_intro.has(16) and not fog_intro.has(515), "雾夜玩偶匣槽位应只使用 OW 死神版本")
	_expect(fog_intro.has(516), "雾夜应保留没有 OW 版的气球僵尸")
	var roof_garg := _level_zombie_types(Presets.build_level("adventure_5_8"))
	_expect(roof_garg.has(24), "5-8 常规巨人槽位应使用 OW 莱因哈特版本")
	_expect(not roof_garg.has(25), "Bob Boss 不应在 5-10 前进入常规波次")
	_expect(roof_garg.has(27) and roof_garg.has(28), "5-8 小鬼槽位应包含两个 OW 小鬼版本")
	_expect(not roof_garg.has(523) and not roof_garg.has(524), "5-8 不应混入已被替代的原版巨人和小鬼")
	var final_boss := _level_zombie_types(Presets.build_level("adventure_5_10"))
	_expect(final_boss.has(25), "5-10 最终关必须出现 Bob Boss")
	for fallback_type in Presets.NORMAL_SUPPORT_ZOMBIES:
		_expect(all_seen.has(int(fallback_type)), "普通冒险线应实际使用无 OW 版的原版僵尸 %d" % int(fallback_type))


func _test_bob_boss_profile() -> void:
	var reinhardt := (load("res://scenes/character/zombie/zombie_024_gargantuar_reinhardt.tscn") as PackedScene).instantiate()
	var bob := (load("res://scenes/character/zombie/zombie_025_gargantuar_bob.tscn") as PackedScene).instantiate()
	var reinhardt_hp := reinhardt.get_node("HpComponent") as HpComponentZombie
	var bob_hp := bob.get_node("HpComponent") as HpComponentZombie
	var reinhardt_attack := reinhardt.get_node("AttackComponent") as AttackComponentZombieGargantuar
	var bob_attack := bob.get_node("AttackComponent") as AttackComponentZombieGargantuar
	_expect(bob_hp.max_hp == 9000 and bob_hp.max_hp >= reinhardt_hp.max_hp * 3, "Bob Boss 应有普通 OW 巨人三倍本体耐久")
	_expect(bob_attack.smash_attack_value >= reinhardt_attack.smash_attack_value * 2, "Bob Boss 对僵尸目标的重击应为普通巨人两倍")
	_expect((bob as Zombie025GargantuarBob).boss_throw_thresholds.size() == 2, "Bob Boss 应有两次阶段性投掷小鬼")
	_expect(bob.scale == Vector2.ONE * 1.25, "Bob Boss 的角色根节点体型应放大到 1.25 倍")
	reinhardt.free()
	bob.free()


func _level_zombie_types(source: Dictionary) -> Array[int]:
	var result: Array[int] = []
	for wave in source.get("waves", []) as Array:
		for group in (wave as Dictionary).get("spawnGroups", []) as Array:
			var zombie_type := int((group as Dictionary).get("zombieType", 0))
			if zombie_type != 0 and not result.has(zombie_type):
				result.append(zombie_type)
	return result


func _test_environment_tools() -> void:
	var night: Dictionary = Runtime.build_game_para(Presets.build_level("adventure_2_2"))
	var night_para: ResourceLevelData = night["game_para"]
	_expect(night_para.is_have_tombston and night_para.init_tombstone_num > 0, "2-2 应启用墓碑机制")
	_expect(not night_para.available_plant_types.has(511 as CharacterRegistry.PlantType), "墓碑吞噬者应沿原版节奏在 2-4 才可用")
	var night_four: Dictionary = Runtime.build_game_para(Presets.build_level("adventure_2_4"))
	_expect((night_four["game_para"] as ResourceLevelData).available_plant_types.has(511 as CharacterRegistry.PlantType), "2-4 应提供墓碑吞噬者")
	var pool: Dictionary = Runtime.build_game_para(Presets.build_level("adventure_3_1"))
	_expect((pool["game_para"] as ResourceLevelData).available_plant_types.has(516 as CharacterRegistry.PlantType), "3-1 应提供睡莲")
	var roof: Dictionary = Runtime.build_game_para(Presets.build_level("adventure_5_1"))
	var roof_para: ResourceLevelData = roof["game_para"]
	_expect(roof_para.available_plant_types.has(533 as CharacterRegistry.PlantType), "5-1 起应提供花盆")
	_expect(roof_para.is_bungi, "5-1 起应启用原版屋顶的蹦极大波机制")


func _test_map_runtime_assignments() -> void:
	var day := (Runtime.build_game_para(Presets.build_level("adventure_1_1"))["game_para"] as ResourceLevelData)
	var night := (Runtime.build_game_para(Presets.build_level("adventure_2_1"))["game_para"] as ResourceLevelData)
	var pool := (Runtime.build_game_para(Presets.build_level("adventure_3_1"))["game_para"] as ResourceLevelData)
	var fog := (Runtime.build_game_para(Presets.build_level("adventure_4_1"))["game_para"] as ResourceLevelData)
	var roof := (Runtime.build_game_para(Presets.build_level("adventure_5_1"))["game_para"] as ResourceLevelData)
	_expect(day.game_BG == ConstLevelData.GameBg.FrontDay and day.game_sences == MainSceneRegistry.MainScenes.MainGameFront, "第一世界应进入白天前院")
	_expect(night.game_BG == ConstLevelData.GameBg.FrontNight and not night.is_day_sun, "第二世界应进入无天降阳光的夜晚前院")
	_expect(pool.game_BG == ConstLevelData.GameBg.Pool and pool.game_sences == MainSceneRegistry.MainScenes.MainGameBack, "第三世界应进入泳池六路场景")
	_expect(fog.game_BG == ConstLevelData.GameBg.Fog and fog.is_fog and not fog.is_day, "第四世界应进入雾夜泳池场景")
	_expect(roof.game_BG == ConstLevelData.GameBg.Roof and roof.game_sences == MainSceneRegistry.MainScenes.MainGameRoof, "第五世界应进入屋顶场景")
	for value in [day, night, pool, fog, roof]:
		var game_para: ResourceLevelData = value
		_expect(load(Global.main_scene_registry.MainScenesMap[game_para.game_sences]) is PackedScene, "正式地图场景应可载入")


func _test_pool_lane_rules() -> void:
	var built: Dictionary = Runtime.build_game_para(Presets.build_level("adventure_3_10"))
	var schedule: Array = (built["game_para"] as ResourceLevelData).custom_spawn_schedule
	var saw_pool_zombie := false
	for event in schedule:
		var zombie_type := int((event as Dictionary).get("zombie_type", 0))
		var lane := int((event as Dictionary).get("lane", -1))
		if Presets.POOL_ONLY_ZOMBIES.has(zombie_type):
			saw_pool_zombie = true
			_expect(lane == 2 or lane == 3, "水生僵尸 %d 被分配到非水路 %d" % [zombie_type, lane])
		elif not Presets.BOTH_ROW_ZOMBIES.has(zombie_type):
			_expect(lane != 2 and lane != 3, "陆地僵尸 %d 被分配到水路 %d" % [zombie_type, lane])
	_expect(saw_pool_zombie, "泳池后期关卡应实际刷新水生僵尸")


func _test_difficulty_growth() -> void:
	var early: Dictionary = Runtime.build_game_para(Presets.build_level("adventure_1_1"))
	var night_first: Dictionary = Runtime.build_game_para(Presets.build_level("adventure_2_1"))
	var late: Dictionary = Runtime.build_game_para(Presets.build_level("adventure_5_10"))
	var early_count := (early["game_para"] as ResourceLevelData).custom_spawn_schedule.size()
	var late_count := (late["game_para"] as ResourceLevelData).custom_spawn_schedule.size()
	_expect((early["game_para"] as ResourceLevelData).custom_flag_data.is_empty(), "只有真正的 1-1 教程关可以没有大波")
	_expect(not (night_first["game_para"] as ResourceLevelData).custom_flag_data.is_empty(), "2-1 起每个世界首关都应恢复大波机制")
	_expect(late_count >= early_count * 5, "最终关的敌人规模应明显高于 1-1")
	_expect((late["game_para"] as ResourceLevelData).custom_flag_data.size() >= 2, "最终关应包含多次大波")


func _test_formal_level_ids() -> void:
	_expect(Store.is_formal_preset_id("adventure_5_10"), "5-10 应是合法正式关卡 ID")
	_expect(not Store.is_formal_preset_id("adventure_6_1"), "不应接受第六世界")
	_expect(not Store.is_formal_preset_id("chess_2_1"), "棋盘格线目前只保留第一世界")


func _test_developer_override_isolation() -> void:
	var preset_id := "adventure_1_2"
	var stored := Store.load_developer_level(preset_id)
	_expect(bool(stored["ok"]), "测试所需的开发者覆盖 %s 应可读取" % preset_id)
	if not stored["ok"]:
		return
	var normal_level := Presets.build_level(preset_id)
	var developer_level := Presets.build_level(preset_id, true)
	_expect(str(normal_level["name"]) == "1-2 重装改坚果", "普通冒险必须忽略开发者覆盖名称")
	_expect(str(developer_level["name"]) == str((stored["level"] as Dictionary)["name"]), "开发者入口应读取工坊覆盖")
	_expect(str(developer_level["name"]) != str(normal_level["name"]), "开发者覆盖与普通正式预设必须保持隔离")


func _test_choose_level_pages() -> void:
	Global.adventure_mainline_mode = "normal"
	var scene: PackedScene = load("res://scenes/main/02AdventureChooesLevel.tscn")
	var chooser := scene.instantiate()
	get_tree().root.add_child.call_deferred(chooser)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var all_page := chooser.get_node("AllPage")
	_expect(all_page.get_child_count() == 5, "冒险选关应生成五个世界分页")
	for page in all_page.get_children():
		var button_count := 0
		for child in page.get_children():
			if child is ChooseLevelButton:
				button_count += 1
		_expect(button_count == 10, "每个世界分页应包含十个正式关卡")
	_expect(chooser.get_node_or_null("LastWorld") is TextureButton, "选关页应使用已有美术的上一世界按钮")
	_expect(chooser.get_node_or_null("NextWorld") is TextureButton, "选关页应使用已有美术的下一世界按钮")
	var fog_first_button := all_page.get_child(3).get_child(0) as ChooseLevelButton
	var fog_cover := fog_first_button.get_node_or_null("Panel/MapBackground") as TextureRect
	_expect(fog_cover != null and fog_cover.texture == ChooseLevel.WORLD_COVER_TEXTURES[3], "第四世界封面应使用雾夜泳池底图")
	_expect(fog_first_button.get_node_or_null("Panel/Badge") == null and fog_first_button.get_node_or_null("Panel/BadgeBackground") == null, "正式关卡封面不应再显示新卡/新敌徽标")
	var mixed_cover := all_page.get_child(0).get_child(2) as ChooseLevelButton
	_expect(mixed_cover.get_node_or_null("Panel/PlantPreview") != null, "1-3 同时有新植物时应展示改版植物")
	_expect(mixed_cover.get_node_or_null("Panel/ZombiePreview") != null, "1-3 同时有新僵尸时应一并展示")
	var fallback_cover := all_page.get_child(0).get_child(5) as ChooseLevelButton
	_expect(fallback_cover.get_node_or_null("Panel/PlantPreview") != null, "1-6 应在封面展示原版回退植物")
	_expect(fallback_cover.get_node_or_null("Panel/ZombiePreview") != null, "1-6 应在封面展示原版回退僵尸")
	chooser.queue_free()
	await get_tree().process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
