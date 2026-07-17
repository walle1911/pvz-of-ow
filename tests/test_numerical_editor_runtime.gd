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
	_assert_exported_tuning(editor, "res://scenes/character/plant/plant_019_threepeater_daotian.tscn", "AttackComponent", "bullet_attack_values")
	_assert_exported_tuning(editor, "res://scenes/character/plant/plant_019_threepeater_daotian.tscn", "AttackComponent", "bullet_speeds")
	_assert_exported_tuning(editor, "res://scenes/character/plant/plant_002_sunflower_mercy.tscn", ".", "damage_boost_multiplier")
	_assert_exported_tuning(editor, "res://scenes/character/zombie/zombie_500_norm.tscn", "HpComponent", "max_hp")
	_assert_exported_tuning(editor, "res://scenes/character/zombie/zombie_500_norm.tscn", "AttackComponent", "init_attack_value_per_min")
	_assert_not_exported_tuning(editor, "res://scenes/character/plant/plant_001_pea_shooter_soldier76.tscn", ".", "is_attack")
	_assert_not_exported_tuning(editor, "res://scenes/character/zombie/zombie_500_norm.tscn", ".", "is_walk")

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
	policy_soldier.free()
	Policy._scene_rules_loaded = policy_script_rules_loaded
	Policy._scene_rules = policy_scene_rules
	var data := {
		"characters": {
			soldier_path: {
				".": {"heal_amount_per_second": 777, "is_attack": true},
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
	assert(soldier.get_node("HpComponent").max_hp == 888)
	assert(is_equal_approx(soldier.get_node("AttackComponent").attack_cd, 0.77))
	soldier.free()
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
