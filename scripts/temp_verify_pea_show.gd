extends Node

func _ready() -> void:
	var bundled_level = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/adventure_levels/adventure_1_10.json"
	))
	var built_level := LevelCustomRuntime.build_game_para(bundled_level)
	var adventure_game_para := built_level.get("game_para") as ResourceLevelData
	## 模拟旧工坊存档：Boss 只在 bossConfig 中，普通刷新池没有它。
	var game_para := ResourceLevelData.new()
	game_para.zombie_refresh_types.assign([
		CharacterRegistry.ZombieType.Z001NormTalon,
		CharacterRegistry.ZombieType.Z005BucketTalon,
	])
	game_para.boss_enabled = true
	game_para.boss_zombie_type = CharacterRegistry.ZombieType.Z026PeashooterZombie
	var show_types := ZombieShowInStart.resolve_prepare_show_zombie_types(
		game_para.zombie_refresh_types,
		game_para,
	)
	var special_ranges: Dictionary[CharacterRegistry.ZombieType, Vector2i] = {}
	var boss_show_range := ZombieShowInStart.resolve_prepare_show_zombie_num_range(
		CharacterRegistry.ZombieType.Z026PeashooterZombie,
		Vector2i(1, 4),
		special_ranges,
		game_para,
	)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(320, 320)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)
	var background := ColorRect.new()
	background.color = Color("8fbf72")
	background.size = Vector2(320, 320)
	viewport.add_child(background)
	var zombie := load("res://scenes/character/zombie/zombie_026_peashooter_soj.tscn").instantiate() as Zombie000Base
	zombie.init_zombie({
		Zombie000Base.E_ZInitAttr.CharacterInitType: Character000Base.E_CharacterInitType.IsShow,
		Zombie000Base.E_ZInitAttr.CurrZombieRowType: CharacterRegistry.ZombieRowType.Land,
	})
	viewport.add_child(zombie)
	zombie.position = Vector2(110, 105)
	await get_tree().process_frame
	await get_tree().process_frame
	var visible_textured_sprites := 0
	for child in zombie.find_children("*", "Sprite2D", true, false):
		var sprite := child as Sprite2D
		if sprite.is_visible_in_tree() and sprite.texture != null:
			visible_textured_sprites += 1
	print(
		"ADVENTURE_BGM=", adventure_game_para.game_BGM,
		"USER_REFRESH_HAS_26=", game_para.zombie_refresh_types.has(CharacterRegistry.ZombieType.Z026PeashooterZombie),
		" RESOLVED_SHOW_HAS_26=", show_types.has(CharacterRegistry.ZombieType.Z026PeashooterZombie),
		" BOSS_SHOW_RANGE=", boss_show_range,
		" PEA_SHOW_VISIBLE=", zombie.is_visible_in_tree(),
		" VISIBLE_TEXTURED_SPRITES=", visible_textured_sprites,
	)
	var passed := adventure_game_para.game_BGM == ConstLevelData.GameBGM.FrontDay \
		and not game_para.zombie_refresh_types.has(CharacterRegistry.ZombieType.Z026PeashooterZombie) \
		and show_types.has(CharacterRegistry.ZombieType.Z026PeashooterZombie) \
		and boss_show_range == Vector2i.ONE \
		and zombie.is_visible_in_tree() \
		and visible_textured_sprites > 0
	get_tree().quit(0 if passed else 1)
