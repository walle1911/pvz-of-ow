extends SceneTree

const Store := preload("res://scripts/resources/numerical_adjustment_store.gd")
const L10n := preload("res://scripts/ui/numerical_editor/numerical_editor_localization.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
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
	for ui_node in editor.call("_all_nodes", editor):
		if ui_node is Label or ui_node is LineEdit:
			var ui_font: Font = ui_node.get_theme_font("font")
			assert(ui_font.resource_path == "res://assets/fonts/方正少儿_GBK.ttf", "Wrong numerical editor font: %s" % ui_node.get_path())
	var total_tunable_fields := 0
	for item in editor.catalog:
		assert(item["display_name"] != "未命名角色", "Missing Chinese character name: %s" % item["name"])
		var character := (load(item["scene_path"]) as PackedScene).instantiate()
		for node in editor.call("_all_nodes", character):
			var tunable_properties = editor.call("_tunable_properties", node)
			total_tunable_fields += tunable_properties.size()
			for property_info in tunable_properties:
				var translated_name: String = L10n.property_name(property_info["name"])
				assert(translated_name != "其他玩法参数", "Missing Chinese property name: %s" % property_info["name"])
		character.free()
	assert(total_tunable_fields > 500)
	_assert_exported_tuning(editor, "res://scenes/character/plant/plant_001_pea_shooter_soldier76.tscn", ".", "heal_amount_per_second")
	_assert_exported_tuning(editor, "res://scenes/character/plant/plant_019_threepeater_daotian.tscn", "AttackComponent", "bullet_attack_values")
	_assert_exported_tuning(editor, "res://scenes/character/plant/plant_019_threepeater_daotian.tscn", "AttackComponent", "bullet_speeds")
	_assert_exported_tuning(editor, "res://scenes/character/plant/plant_002_sunflower_mercy.tscn", ".", "damage_boost_multiplier")
	_assert_exported_tuning(editor, "res://scenes/character/zombie/zombie_500_norm.tscn", "HpComponent", "max_hp")
	_assert_exported_tuning(editor, "res://scenes/character/zombie/zombie_500_norm.tscn", "AttackComponent", "init_attack_value_per_min")

	var soldier_path := "res://scenes/character/plant/plant_001_pea_shooter_soldier76.tscn"
	var data := {
		"characters": {
			soldier_path: {
				".": {"heal_amount_per_second": 777},
				"HpComponent": {"max_hp": 888},
				"AttackComponent": {"attack_cd": 0.77},
			}
		}
	}
	assert(Store.save_data(data))
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
	Store.save_data({"characters": {}})
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
