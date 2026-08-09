extends SceneTree

const Store := preload("res://scripts/resources/numerical_adjustment_store.gd")
const Policy := preload("res://scripts/resources/numerical_adjustment_policy.gd")
const L10n := preload("res://scripts/ui/numerical_editor/numerical_editor_localization.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var original_adjustments := Store.load_data(true).duplicate(true)
	var editor_scene := load("res://scenes/main/08NumericalEditor.tscn") as PackedScene
	assert(editor_scene != null)
	var editor := editor_scene.instantiate()
	root.add_child(editor)
	await process_frame
	assert((editor.selection_page.get_child(0) as TextureRect).texture.resource_path == "res://assets/image/ui/ui_level/Challenge_Background.jpg")
	assert(editor.call("_text_style").texture.resource_path == "res://assets/image/ui/ui_level/SeedChooser_Button2_Glow.png")
	assert(editor.theme.default_font.resource_path == "res://assets/fonts/方正少儿_GBK.ttf")
	assert(editor.catalog.size() > 80)
	assert(editor.card_grid.get_child_count() == 24)
	Global.numerical_editor_context = {"origin": "level_workshop", "kind": "plant", "id": int(editor.catalog[0]["id"])}
	editor.call("_open_requested_character")
	assert(editor.return_to_workshop)
	assert(editor.selected_item["id"] == editor.catalog[0]["id"])
	assert((editor.detail_page.get_child(editor.detail_page.get_child_count() - 3).get_child(0) as Label).text == "返回选卡")
	Global.numerical_editor_context = {}
	editor.return_to_workshop = false
	editor.call("_open_detail", editor.catalog[0])
	await process_frame
	assert((editor.detail_page.get_child(0) as TextureRect).texture.resource_path == "res://assets/image/Almanac/Almanac_PlantBack.jpg")
	assert(editor.field_box.get_child_count() > 0)
	var almanac_panel: Node = editor.detail_page.get_node_or_null("AlmanacCharacterShowPanel")
	assert(almanac_panel != null)
	assert(almanac_panel.character_name.texture == null)
	assert(almanac_panel.character_name_text.text == editor.catalog[0]["display_name"])
	for ui_node in editor.call("_all_nodes", editor):
		if ui_node is Label or ui_node is LineEdit:
			var ui_font: Font = ui_node.get_theme_font("font")
			assert(ui_font.resource_path == "res://assets/fonts/方正少儿_GBK.ttf", "Wrong numerical editor font: %s" % ui_node.get_path())
	var total_tunable_fields := 0
	for item in editor.catalog:
		var character := (load(item["scene_path"]) as PackedScene).instantiate()
		for node in editor.call("_all_nodes", character):
			var tunable_properties = editor.call("_tunable_properties", node)
			total_tunable_fields += tunable_properties.size()
			for property_info in tunable_properties:
				var translated_name: String = L10n.property_name(property_info["name"])
				assert(translated_name != "其他玩法参数", "Missing Chinese property name: %s" % property_info["name"])
		character.free()
	assert(total_tunable_fields > 100)
	_assert_exported_tuning(editor, "res://scenes/character/plant/plant_001_pea_shooter_soldier76.tscn", ".", "heal_amount_per_second")
	_assert_exported_tuning(editor, "res://scenes/character/plant/plant_001_pea_shooter_soldier76.tscn", ".", "smart_escape_route_enabled")
	_assert_exported_tuning(editor, "res://scenes/character/plant/plant_019_threepeater_daotian.tscn", "AttackComponent", "bullet_attack_values")
	_assert_exported_tuning(editor, "res://scenes/character/plant/plant_019_threepeater_daotian.tscn", "AttackComponent", "bullet_speeds")
	_assert_exported_tuning(editor, "res://scenes/character/plant/plant_002_sunflower_mercy.tscn", ".", "damage_boost_multiplier")
	_assert_exported_tuning(editor, "res://scenes/character/plant/plant_004_wall_nut_brigitte.tscn", ".", "heal_pulse_interval")
	_assert_exported_tuning(editor, "res://scenes/character/plant/plant_006_snow_pea_mei.tscn", "AttackComponent", "close_spray_hits_to_freeze")
	_assert_exported_tuning(editor, "res://scenes/character/plant/plant_016_doom_shroom_dva.tscn", ".", "baby_grow_time")
	_assert_exported_tuning(editor, "res://scenes/character/plant/plant_020_tanglekelp_mizuki.tscn", ".", "first_ally_heal")
	_assert_exported_tuning(editor, "res://scenes/character/plant/plant_021_jalapeno_vendetta.tscn", ".", "center_lane_damage")
	_assert_exported_tuning(editor, "res://scenes/character/plant/plant_022_caltrop_hazard.tscn", ".", "downpour_immobilize_time")
	_assert_exported_tuning(editor, "res://scenes/character/plant/plant_025_sea_shroom_wuyang.tscn", "AttackComponent", "guidance_attack_damage")
	_assert_exported_tuning(editor, "res://scenes/character/plant/plant_024_tall_nut_sigma.tscn", ".", "slam_hold_time")
	_assert_exported_tuning(editor, "res://scenes/character/plant/plant_031_pumpkin_zarya.tscn", ".", "gravity_hold_duration")
	_assert_exported_tuning(editor, "res://scenes/character/plant/plant_032_magnet_shroom_sombra.tscn", ".", "emp_duration")
	_assert_exported_tuning(editor, "res://scenes/character/plant/plant_036_coffee_bean_ana.tscn", ".", "boost_duration")
	_assert_exported_tuning(editor, "res://scenes/character/plant/plant_037_garlic_mauga.tscn", ".", "chain_last_stand_duration")
	_assert_exported_tuning(editor, "res://scenes/character/plant/plant_043_gloom_shroom_moira.tscn", ".", "yellow_fume_chance")
	_assert_exported_tuning(editor, "res://scenes/character/plant/plant_044_cattail_jetpack_cat.tscn", ".", "critical_knockback_distance")
	_assert_exported_tuning(editor, "res://scenes/character/zombie/zombie_501_norm.tscn", "HpComponent", "max_hp")
	_assert_exported_tuning(editor, "res://scenes/character/zombie/zombie_501_norm.tscn", "AttackComponent", "init_attack_value_per_min")
	_assert_not_exported_tuning(editor, "res://scenes/character/plant/plant_001_pea_shooter_soldier76.tscn", ".", "is_attack")
	_assert_not_exported_tuning(editor, "res://scenes/character/zombie/zombie_501_norm.tscn", ".", "is_walk")
	_assert_not_exported_tuning(editor, "res://scenes/character/zombie/zombie_501_norm.tscn", "DropItemComponent", "drop_coin_rate")
	_assert_not_exported_tuning(editor, "res://scenes/character/zombie/zombie_501_norm.tscn", "DropItemComponent", "drop_coin_silver_glod_diamond_rate")

	var soldier_path := "res://scenes/character/plant/plant_001_pea_shooter_soldier76.tscn"
	var policy_script_rules_loaded: bool = Policy._scene_rules_loaded
	var policy_scene_rules: Dictionary = Policy._scene_rules.duplicate(true)
	Policy._scene_rules_loaded = true
	Policy._scene_rules = {
		soldier_path: {
			"HpComponent": {
				"max_hp": {"enabled": false},
			},
			".": {
				"heal_amount_per_second": {"enabled": true, "min": 10.0, "max": 900.0, "step": 10.0},
			},
		},
	}
	var policy_soldier := (load(soldier_path) as PackedScene).instantiate()
	assert(Policy.get_rule(policy_soldier.get_node("HpComponent"), "max_hp", soldier_path, "HpComponent").is_empty())
	var heal_rule := Policy.get_rule(policy_soldier, "heal_amount_per_second", soldier_path, ".")
	assert(heal_rule["max"] == 900.0)
	assert(not Policy.validate_value(policy_soldier, "heal_amount_per_second", 901, soldier_path, ".")["ok"])
	assert(Policy.get_rule(policy_soldier, "smart_escape_route_enabled", soldier_path, ".")["kind"] == "bool")
	policy_soldier.free()
	Policy._scene_rules_loaded = policy_script_rules_loaded
	Policy._scene_rules = policy_scene_rules
	var snow_pea := (load("res://scenes/character/plant/plant_006_snow_pea_mei.tscn") as PackedScene).instantiate()
	var snow_attack := snow_pea.get_node("AttackComponent")
	assert(Policy.get_rule(snow_attack, "close_spray_freeze_time")["max"] == 60.0)
	assert(not Policy.validate_value(snow_attack, "close_spray_freeze_time", 61.0)["ok"])
	snow_pea.free()
	var normal_zombie := (load("res://scenes/character/zombie/zombie_501_norm.tscn") as PackedScene).instantiate()
	var drop_item := normal_zombie.get_node("DropItemComponent")
	assert(Policy.get_rule(drop_item, "drop_coin_rate").is_empty())
	assert(Policy.get_rule(drop_item, "drop_coin_silver_glod_diamond_rate").is_empty())
	normal_zombie.free()
	var wall_nut := (load("res://scenes/character/plant/plant_004_wall_nut_brigitte.tscn") as PackedScene).instantiate()
	var hp_stage := wall_nut.get_node("HpStageChangeComponent")
	assert(Policy.validate_value(hp_stage, "boundary_value_hp", [2666, 1333, 0])["ok"])
	assert(not Policy.validate_value(hp_stage, "boundary_value_hp", [1333, 2666, 0])["ok"])
	wall_nut.free()
	var data := {
		"characters": {
			soldier_path: {
				".": {"heal_amount_per_second": 777, "smart_escape_route_enabled": false, "is_attack": true},
				"HpComponent": {"max_hp": 888},
				"AttackComponent": {"attack_cd": 0.77, "attack_para": "hacked"},
			}
		}
	}
	assert(Store.save_data(data))
	var sanitized := Store.load_data()
	assert(not sanitized["characters"][soldier_path]["."].has("is_attack"))
	assert(not sanitized["characters"][soldier_path]["AttackComponent"].has("attack_para"))
	var normal_soldier := (load(soldier_path) as PackedScene).instantiate()
	Store.apply_to_character(normal_soldier, false)
	assert(normal_soldier.heal_amount_per_second != 777)
	normal_soldier.free()

	var soldier := (load(soldier_path) as PackedScene).instantiate()
	Store.apply_to_character(soldier, true)
	assert(soldier.heal_amount_per_second == 777)
	assert(not soldier.smart_escape_route_enabled)
	assert(soldier.get_node("HpComponent").max_hp == 888)
	assert(is_equal_approx(soldier.get_node("AttackComponent").attack_cd, 0.77))
	soldier.free()

	var normal_zombie_path := "res://scenes/character/zombie/zombie_501_norm.tscn"
	var zombie_data := {
		"version": Store.DATA_VERSION,
		"characters": {
			normal_zombie_path: {
				"@registry": {"zombie_spawn_weight": 6},
				"DropItemComponent": {
					"drop_coin_rate": 1.0,
					"drop_coin_silver_glod_diamond_rate": [0.0, 0.0, 1.0],
				},
			}
		}
	}
	assert(Store.save_data(zombie_data))
	var sanitized_zombie_data := Store.load_data()
	assert(not sanitized_zombie_data["characters"][normal_zombie_path].has("DropItemComponent"))
	assert(Store.get_registry_override(normal_zombie_path, "zombie_spawn_weight", 1, true) == 6)
	assert(Store.get_registry_override(normal_zombie_path, "zombie_spawn_weight", 1, false) == 1)
	assert(Store.zombie_spawn_weight_from_grade(1) == 4000)
	assert(Store.zombie_spawn_weight_from_grade(6) == 1000)
	assert(Store.zombie_spawn_weight_from_grade(7) == 1000)
	assert(Store.zombie_spawn_weight_to_grade(3500) == 2)
	assert(not Store.validate_registry_value("zombie_spawn_weight", 7, 1).get("ok", false))
	assert(ZombieWaveCreateManager.scaled_decay_weight(4000, 4000, 180, 25) == 400)
	assert(ZombieWaveCreateManager.scaled_decay_weight(1000, 4000, 180, 25) == 100)
	var legacy_zombie_data := {
		"version": 2,
		"characters": {
			normal_zombie_path: {
				"@registry": {"zombie_spawn_weight": 3500},
			}
		}
	}
	Store._migrate_data(legacy_zombie_data)
	assert(legacy_zombie_data["characters"][normal_zombie_path]["@registry"]["zombie_spawn_weight"] == 2)
	var legacy_boss_grade_data := {
		"version": 4,
		"characters": {
			normal_zombie_path: {
				"@registry": {"zombie_spawn_weight": 7},
			}
		}
	}
	Store._migrate_data(legacy_boss_grade_data)
	assert(not legacy_boss_grade_data["characters"][normal_zombie_path]["@registry"].has("zombie_spawn_weight"))
	var wave_create_manager := ZombieWaveCreateManager.new()
	wave_create_manager.call("_reset_zombie_weights_from_adjustments")
	assert(wave_create_manager.zombie_weights[CharacterRegistry.ZombieType.Z501Norm] == 1000)
	wave_create_manager.free()
	var normal_zombie_item: Dictionary
	for item in editor.catalog:
		if item["kind"] == "zombie" and int(item["id"]) == int(CharacterRegistry.ZombieType.Z501Norm):
			normal_zombie_item = item
			break
	assert(not normal_zombie_item.is_empty())
	editor.call("_open_detail", normal_zombie_item)
	var has_spawn_weight_field := false
	for child in editor.field_box.get_children():
		if child is HBoxContainer and child.get_child_count() > 0 and child.get_child(0) is Label:
			if (child.get_child(0) as Label).text == "刷怪权重等级":
				has_spawn_weight_field = true
				assert(child.get_child(1) is OptionButton)
				break
	assert(has_spawn_weight_field)
	Store.save_data(original_adjustments)
	editor.queue_free()
	print("Numerical editor runtime test: passed (%d characters, %d tunable fields)" % [editor.catalog.size(), total_tunable_fields])
	quit()


func _assert_exported_tuning(editor: Node, scene_path: String, node_path: String, property_name: String) -> void:
	var instance := (load(scene_path) as PackedScene).instantiate()
	var node := instance if node_path == "." else instance.get_node(node_path)
	var found := false
	for property_info in editor.call("_tunable_properties", node):
		if property_info["name"] == property_name:
			found = true
			break
	assert(found, "%s:%s:%s should be tunable" % [scene_path, node_path, property_name])
	instance.free()


func _assert_not_exported_tuning(editor: Node, scene_path: String, node_path: String, property_name: String) -> void:
	var instance := (load(scene_path) as PackedScene).instantiate()
	var node := instance if node_path == "." else instance.get_node(node_path)
	for property_info in editor.call("_tunable_properties", node):
		assert(property_info["name"] != property_name, "%s:%s:%s should not be tunable" % [scene_path, node_path, property_name])
	instance.free()
