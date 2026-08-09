extends Node

const WorkshopScene := preload("res://scenes/main/07LevelWorkshop.tscn")
const Logic := preload("res://addons/pvz_level_editor/level_editor_logic.gd")
const Runtime := preload("res://scripts/resources/level/level_custom_runtime.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var workshop := WorkshopScene.instantiate()
	add_child(workshop)
	await get_tree().process_frame
	await get_tree().process_frame
	assert(workshop.drawer != null)
	assert(is_equal_approx(workshop.drawer.size.x, workshop.DRAWER_WIDTH))
	var expected_zombie_cards := 0
	for zombie_type in workshop.zombie_card_prefabs.keys():
		if int(zombie_type) != int(CharacterRegistry.ZombieType.Null) and CharacterRegistry.ZombieInfo.has(int(zombie_type)):
			expected_zombie_cards += 1
	assert(workshop.zombie_card_order.size() == expected_zombie_cards)
	assert(workshop.card_grid.get_child_count() == mini(workshop.CARDS_PER_PAGE, workshop.zombie_card_order.size()))
	assert(workshop.card_grid.columns == 6)
	assert(workshop.card_page_label != null)
	assert(workshop.editor_complexity == LevelWorkshop.EditorComplexity.SIMPLE)
	assert(workshop.get_node("TopActions/AdvancedModeButton") is BaseButton)
	assert((workshop.get_node("TopActions/AdvancedModeButton/Label") as Label).text == "进阶模式")
	assert((workshop.get_node("TopActions/AdvancedModeButton") as Control).size == (workshop.get_node("TopActions/PlaytestButton") as Control).size)
	assert((workshop.get_node("AlmanacDrawer/Content/BottomActions/LoadButton/Label") as Label).text == "编辑正式关卡")
	var editing_existing: bool = workshop.loaded_source_kind == "template" or workshop.loaded_source_kind == "custom"
	assert(workshop.new_level_button.button_pressed == not editing_existing)
	assert(workshop.edit_level_button.button_pressed == editing_existing)
	assert(workshop.new_level_button.button_pressed != workshop.edit_level_button.button_pressed)
	var active_source_button: TextureButton = workshop.edit_level_button if editing_existing else workshop.new_level_button
	var idle_source_button: TextureButton = workshop.new_level_button if editing_existing else workshop.edit_level_button
	assert(active_source_button.position.y == workshop.ACTIVE_SOURCE_BUTTON_OFFSET_Y)
	assert(active_source_button.self_modulate == workshop.ACTIVE_SOURCE_BUTTON_MODULATE)
	assert(idle_source_button.position.y == 0.0)
	assert(idle_source_button.self_modulate == Color.WHITE)
	assert((workshop.new_level_button.get_node("Label") as Label).text == "自制关卡")
	assert((workshop.reward_mode_button.get_child(0) as Label).text == "植物卡片")
	workshop.call("_load_preset_for_edit", "adventure_2_1")
	assert(workshop.background_sprite.texture == workshop.NIGHT_LAWN)
	assert((workshop.reward_mode_button.get_child(0) as Label).text == "植物卡片")
	workshop.call("_toggle_reward_catalog")
	assert((workshop.reward_mode_button.get_child(0) as Label).text.begins_with("登场僵尸"))
	workshop.call("_load_preset_for_edit", "adventure_3_1")
	assert(workshop.catalog_mode == LevelWorkshop.CatalogMode.REWARD_CARDS)
	assert(workshop.background_sprite.texture == workshop.POOL_LAWN)
	workshop.call("_create_new_level")
	var first_zombie_holder := workshop.card_grid.get_child(0) as Control
	var first_zombie_card := first_zombie_holder.get_child(0) as Card
	var first_zombie_button := first_zombie_card.get_node("Button") as Button
	assert(first_zombie_button.gui_input.get_connections().size() > 0)
	var context_click := InputEventMouseButton.new()
	context_click.button_index = MOUSE_BUTTON_RIGHT
	context_click.pressed = true
	workshop.call("_on_workshop_card_gui_input", context_click, "zombie", int(first_zombie_card.card_zombie_type))
	assert(workshop.card_context_menu != null)
	assert(workshop.card_context_menu.get_item_text(0) == "编辑全局数值")
	assert(workshop.context_card_kind == "zombie")
	assert(workshop.context_card_type == int(first_zombie_card.card_zombie_type))
	workshop.card_context_menu.hide()
	var required_wave_type := int(CharacterRegistry.ZombieType.Z003ConeTalon)
	var simple_pool: Array = workshop.call("_simple_zombie_pool")
	if not simple_pool.has(required_wave_type):
		workshop.call("_select_simple_zombie", str(required_wave_type))
	var required_wave_holder := workshop.call("_make_zombie_card", required_wave_type) as Control
	assert(required_wave_holder.get_node_or_null("CardStateBadge") == null)
	required_wave_holder.free()
	workshop.call("_on_workshop_card_gui_input", context_click, "zombie", required_wave_type)
	assert(workshop.card_context_menu.item_count == 1)
	assert(workshop.card_context_menu.get_item_text(0) == "编辑全局数值")
	workshop.card_context_menu.hide()
	for holder in workshop.card_grid.get_children():
		if holder.get_child_count() > 0:
			assert(not (holder.get_child(0) as Card).is_imitater)
	if workshop.zombie_card_order.size() > workshop.CARDS_PER_PAGE:
		workshop.call("_change_card_page", 1)
		assert(workshop.current_card_page == 1)
		assert(workshop.card_grid.get_child_count() == mini(workshop.CARDS_PER_PAGE, workshop.zombie_card_order.size() - workshop.CARDS_PER_PAGE))
		workshop.call("_change_card_page", -1)
	assert(workshop.timeline_stages != null)
	assert(workshop.timeline_meter.size.x > 0.0)
	assert(is_equal_approx(workshop.timeline_meter.size.y, 54.0))
	assert(workshop.timeline_meter.scale == Vector2.ONE * workshop.TIMELINE_SCALE)
	assert(not workshop.delete_timeline_button.disabled)
	assert(workshop.reset_timeline_button.disabled)
	assert(workshop.add_flag_button.disabled)
	assert(not workshop.add_flag_button.visible)
	assert((workshop.delete_timeline_button.get_node("Label") as Label).text == "旗帜数")
	assert(not workshop.simple_pool_toggle_button.visible)
	assert(workshop.timeline_stages.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	var simple_selection: int = int(workshop.selected_wave)
	var timeline_click := InputEventMouseButton.new()
	timeline_click.button_index = MOUSE_BUTTON_LEFT
	timeline_click.pressed = true
	timeline_click.position = Vector2(120, 30)
	workshop.call("_on_timeline_gui_input", timeline_click)
	assert(workshop.selected_wave == simple_selection)
	var initial_stage_type: String = str(workshop.call("_selected_stage_type"))
	workshop.call("_toggle_simple_stage_type")
	assert(workshop.call("_selected_stage_type") == initial_stage_type)
	assert(workshop.selected_wave == simple_selection)
	var simple_flag_count := int(workshop.call("_count_stage_type", "flag"))
	workshop.call("_apply_simple_flag_count", 3)
	assert(int(workshop.level["simpleFlagCount"]) == 3)
	assert(int(workshop.level["simpleWaveCount"]) == 30)
	assert(workshop.call("_count_stage_type", "flag") == 3)
	assert(is_equal_approx(float(workshop.simple_flag_progress_ratio(1, 1)), 1.0))
	assert(float(workshop.simple_flag_progress_ratio(1, 2)) < 0.5)
	assert(is_equal_approx(float(workshop.simple_flag_progress_ratio(2, 2)), 1.0))
	workshop.level["zombieRefreshSpeedMultiplier"] = 1.4
	workshop.call("_open_level_settings")
	await get_tree().process_frame
	var found_refresh_speed_setting := false
	var found_duplicate_flag_setting := false
	var found_reward_plant_setting := false
	var refresh_speed_setting: SpinBox
	for setting in workshop.quantity_dialog_layer.find_children("*", "SpinBox", true, false):
		var setting_label = (setting as SpinBox).get_meta("settings_label", null)
		if setting_label is Label and (setting_label as Label).text == "旗帜数量":
			found_duplicate_flag_setting = true
		if setting_label is Label and (setting_label as Label).text == "僵尸刷新速度倍率":
			found_refresh_speed_setting = true
			refresh_speed_setting = setting as SpinBox
			assert(is_equal_approx((setting as SpinBox).value, 1.4))
			assert(is_equal_approx((setting as SpinBox).min_value, 0.1))
			assert(is_equal_approx((setting as SpinBox).max_value, 5.0))
	for setting_label in workshop.quantity_dialog_layer.find_children("*", "Label", true, false):
		if (setting_label as Label).text == "通关奖励植物":
			found_reward_plant_setting = true
	assert(found_refresh_speed_setting)
	assert(not found_duplicate_flag_setting)
	assert(not found_reward_plant_setting)
	refresh_speed_setting.value = 1.65
	var saved_refresh_speed_setting := false
	for button in workshop.quantity_dialog_layer.find_children("*", "", true, false):
		if not button is TextureButton:
			continue
		var button_label := (button as TextureButton).get_child(0) as Label if (button as TextureButton).get_child_count() > 0 else null
		if button_label != null and button_label.text == "确认":
			(button as TextureButton).pressed.emit()
			saved_refresh_speed_setting = true
			break
	assert(saved_refresh_speed_setting)
	assert(is_equal_approx(float(workshop.level["zombieRefreshSpeedMultiplier"]), 1.65))
	## 测试可能从固定一旗的正式 1-1 打开；恢复后续时间轴测试所需的三旗状态。
	workshop.call("_apply_simple_flag_count", 3)
	simple_flag_count = 3
	workshop.call("_on_add_flag_pressed")
	assert(workshop.call("_count_stage_type", "flag") == simple_flag_count)
	assert(workshop.selected_wave == simple_selection)
	assert(workshop.timeline_mode == LevelWorkshop.TimelineMode.NORMAL)
	assert(workshop.flag_cursor_preview == null or not workshop.flag_cursor_preview.visible)
	workshop.call("_sanitize_simple_allowed_pool")
	var required_zombie := int(CharacterRegistry.ZombieType.Z001NormTalon)
	assert(not workshop.call("_find_group", workshop.level["waves"][workshop.selected_wave], str(required_zombie)).is_empty())
	workshop.call("_set_simple_zombie_role", int(CharacterRegistry.ZombieType.Z501Norm), "base")
	assert(int(workshop.level["simpleBaseZombieType"]) == int(CharacterRegistry.ZombieType.Z501Norm))
	assert(not workshop.call("_find_group", workshop.level["waves"][workshop.selected_wave], str(CharacterRegistry.ZombieType.Z501Norm)).is_empty())
	workshop.call("_set_simple_zombie_role", int(CharacterRegistry.ZombieType.Z502Flag), "flag")
	assert(int(workshop.level["simpleFlagZombieType"]) == int(CharacterRegistry.ZombieType.Z502Flag))
	var fixed_flag_holder := workshop.call("_make_zombie_card", int(CharacterRegistry.ZombieType.Z502Flag)) as Control
	assert((fixed_flag_holder.get_child(0) as Card).modulate == Color.WHITE)
	workshop.call("_select_simple_zombie", str(CharacterRegistry.ZombieType.Z502Flag))
	var fixed_flag_after_click := workshop.call("_make_zombie_card", int(CharacterRegistry.ZombieType.Z502Flag)) as Control
	assert((fixed_flag_after_click.get_child(0) as Card).modulate == Color.WHITE)
	workshop.call("_delete_simple_zombie", str(CharacterRegistry.ZombieType.Z502Flag))
	assert(int(workshop.level["simpleFlagZombieType"]) == int(CharacterRegistry.ZombieType.Z502Flag))
	workshop.call("_set_simple_zombie_role", required_zombie, "base")
	workshop.call("_delete_simple_zombie", str(required_zombie))
	assert(not workshop.call("_find_group", workshop.level["waves"][workshop.selected_wave], str(required_zombie)).is_empty())
	workshop.call("_on_remove_flag_pressed")
	assert(workshop.call("_count_stage_type", "flag") == simple_flag_count)
	workshop.call("_reset_timeline")
	assert(workshop.call("_count_stage_type", "flag") == simple_flag_count)

	workshop.call("_load_preset_for_edit", "adventure_1_1")
	assert(workshop.previous_formal_level_button.visible)
	assert(workshop.next_formal_level_button.visible)
	assert(workshop.previous_formal_level_button.disabled)
	assert(not workshop.next_formal_level_button.disabled)
	assert(workshop.previous_formal_level_button.tooltip_text == "上一关")
	assert(workshop.next_formal_level_button.tooltip_text == "下一关")
	var fixed_card_id := int(workshop.locked_available_plant_types[0])
	var fixed_card_holder := workshop.call("_make_reward_card", {"id": fixed_card_id, "is_plant": true}) as Control
	assert(fixed_card_holder.get_node_or_null("CardStateGlow") != null)
	assert(fixed_card_holder.get_node_or_null("CardStateBadge") == null)
	fixed_card_holder.free()
	var reward_card_id := -1
	for entry in workshop.reward_card_order:
		var candidate_id := int((entry as Dictionary)["id"])
		if not workshop.locked_available_plant_types.has(candidate_id):
			reward_card_id = candidate_id
			break
	assert(reward_card_id >= 0)
	workshop.level["rewardPlants"] = [reward_card_id]
	workshop.level["rewardPlant"] = reward_card_id
	var reward_card_holder := workshop.call("_make_reward_card", {"id": reward_card_id, "is_plant": true}) as Control
	var reward_glow := reward_card_holder.get_node("CardStateGlow") as TextureRect
	var reward_badge := reward_card_holder.get_node("CardStateBadge") as TextureRect
	assert(reward_glow.z_index == 0)
	assert((reward_card_holder.get_child(0) as Card).z_index == 1)
	assert(is_equal_approx(reward_glow.modulate.a, 0.95))
	assert((reward_badge.get_child(0) as Label).text == "奖")
	reward_card_holder.free()
	workshop.level["name"] = "%s（未保存）" % str(workshop.level["name"])
	workshop.call("_changed", "测试未保存修改")
	workshop.next_formal_level_button.pressed.emit()
	assert(workshop.formal_preset_id == "adventure_1_1")
	assert(workshop.unsaved_changes_dialog != null)
	assert(workshop.unsaved_changes_dialog.dialog_text.contains("尚未保存"))
	workshop.unsaved_changes_dialog.custom_action.emit(&"discard_changes")
	await get_tree().process_frame
	assert(workshop.formal_preset_id == "adventure_1_2")
	workshop.previous_formal_level_button.pressed.emit()
	assert(workshop.formal_preset_id == "adventure_1_1")
	workshop.call("_load_preset_for_edit", "adventure_1_7")
	var later_reward_conflicts: Array = workshop.call("_later_formal_reward_conflicts", 18)
	assert(not later_reward_conflicts.is_empty())
	var no_rewards: Array[int] = []
	workshop.call("_set_formal_reward_plants", no_rewards)
	workshop.call("_toggle_reward_card", 18, true)
	assert(workshop.reward_conflict_dialog != null)
	assert(workshop.reward_conflict_dialog.dialog_text.contains("后续关卡将需要新增奖励植物"))
	workshop.reward_conflict_dialog.confirmed.emit()
	await get_tree().process_frame
	assert(workshop.level["rewardPlants"] == [18])
	workshop.call("_load_preset_for_edit", "adventure_1_1")
	var opening_playtest := Runtime.build_game_para(workshop.level)
	assert(opening_playtest["ok"])
	var opening_para := opening_playtest["game_para"] as ResourceLevelData
	assert(opening_para.opening_battlefield_zombie_type == CharacterRegistry.ZombieType.Z501Norm)
	assert(opening_para.start_sun == 100)
	assert(is_equal_approx(opening_para.custom_initial_wave_delay, 0.1))
	assert(is_equal_approx(opening_para.opening_first_zombie_advance_cells, 7.5))
	## 1-1 锁定开场僵尸和中间三行，其余设置必须能由关卡工坊自由调整并进入试玩。
	workshop.level["playerConfig"]["initialSun"] = 325
	workshop.level["initialWaveDelay"] = 4.0
	workshop.level["zombieRefreshSpeedMultiplier"] = 1.7
	workshop.level["simpleFlagCount"] = 3
	workshop.level["simpleWaveCount"] = 30
	workshop.level["activeLawnRows"] = [0, 1, 2, 3, 4]
	workshop.level["sodLayoutRows"] = 5
	workshop.level["openingFirstZombieAdvanceCells"] = 0.0
	workshop.call("_apply_formal_map_constraints")
	var edited_opening_playtest := Runtime.build_game_para(workshop.level)
	assert(edited_opening_playtest["ok"])
	var edited_opening_para := edited_opening_playtest["game_para"] as ResourceLevelData
	assert(edited_opening_para.start_sun == 325)
	assert(is_equal_approx(edited_opening_para.custom_initial_wave_delay, 4.0))
	assert(is_equal_approx(edited_opening_para.zombie_refresh_speed_multiplier, 1.7))
	assert(edited_opening_para.max_wave == 30)
	assert(edited_opening_para.active_lawn_rows == [1, 2, 3])
	assert(edited_opening_para.sod_layout_rows == 5)
	assert(is_equal_approx(edited_opening_para.opening_first_zombie_advance_cells, 7.5))
	assert(not edited_opening_para.force_second_zombie_same_lane_as_first)

	workshop.call("_load_preset_for_edit", "adventure_1_2")
	assert(workshop.formal_preset_id == "adventure_1_2")
	var new_cone_holder := workshop.call("_make_zombie_card", int(CharacterRegistry.ZombieType.Z003ConeTalon)) as Control
	assert(new_cone_holder.get_node_or_null("CardStateBadge") != null)
	assert((new_cone_holder.get_node("CardStateBadge/Label") as Label).text == "新")
	new_cone_holder.free()
	workshop.level["bossConfig"] = {
		"enabled": true,
		"zombieType": int(CharacterRegistry.ZombieType.Z003ConeTalon),
		"rewardPlant": int(CharacterRegistry.PlantType.P003CherryBombJunkrat),
	}
	var boss_cone_holder := workshop.call("_make_zombie_card", int(CharacterRegistry.ZombieType.Z003ConeTalon)) as Control
	assert((boss_cone_holder.get_node("CardStateBadge/Label") as Label).text == "boss")
	assert((boss_cone_holder.get_child(0) as CanvasItem).modulate == Color.WHITE)
	boss_cone_holder.free()
	workshop.call("_refresh_road_zombies")
	assert(workshop.preview_zombie_keys.values().has(str(int(CharacterRegistry.ZombieType.Z003ConeTalon))))
	assert(not workshop.previous_formal_level_button.disabled)
	assert(not workshop.next_formal_level_button.disabled)
	assert(str(workshop.level.get("editorMode", "")) == "simple")
	var formal_simple_built := Runtime.build_game_para(workshop.level)
	assert(formal_simple_built["ok"])
	assert((formal_simple_built["game_para"] as ResourceLevelData).custom_simple_original_mode)
	assert(workshop.reward_mode_button.visible)
	assert(workshop.level["availablePlants"] == workshop.call("_formal_progression_available_plants"))
	assert(workshop.locked_available_plant_types == workshop.level["availablePlants"])
	assert(not workshop.new_level_button.button_pressed)
	assert(workshop.edit_level_button.button_pressed)
	assert(workshop.edit_level_button.position.y == workshop.ACTIVE_SOURCE_BUTTON_OFFSET_Y)
	assert(workshop.edit_level_button.self_modulate == workshop.ACTIVE_SOURCE_BUTTON_MODULATE)
	workshop.call("_toggle_reward_catalog")
	assert(workshop.catalog_mode == LevelWorkshop.CatalogMode.REWARD_CARDS)
	var inherited_plants_before: Array = (workshop.level["availablePlants"] as Array).duplicate()
	if not workshop.locked_available_plant_types.is_empty():
		workshop.call("_toggle_reward_card", workshop.locked_available_plant_types[0], true)
		assert(workshop.level["availablePlants"] == inherited_plants_before)
	var new_reward_types: Array[int] = []
	for reward_entry: Dictionary in workshop.reward_card_order:
		var reward_type := int(reward_entry["id"])
		if bool(reward_entry.get("is_plant", false)) and not workshop.locked_available_plant_types.has(reward_type):
			new_reward_types.append(reward_type)
			if new_reward_types.size() == 2:
				break
	assert(new_reward_types.size() == 2)
	workshop.call("_set_formal_reward_plants", no_rewards)
	workshop.call("_toggle_reward_card", new_reward_types[0], true)
	assert(workshop.level["rewardPlants"] == [new_reward_types[0]])
	assert(not (workshop.level["availablePlants"] as Array).has(new_reward_types[0]))
	var reward_card_entry: Dictionary = {}
	for reward_entry: Dictionary in workshop.reward_card_order:
		if int(reward_entry["id"]) == new_reward_types[0]:
			reward_card_entry = reward_entry
			break
	var current_reward_holder: Control = workshop.call("_make_reward_card", reward_card_entry)
	assert((current_reward_holder.get_child(0) as Card).modulate == Color.WHITE)
	var found_reward_badge := false
	for badge in current_reward_holder.find_children("*", "Label", true, false):
		if (badge as Label).text == "奖":
			found_reward_badge = true
	assert(found_reward_badge)
	workshop.call("_toggle_reward_card", new_reward_types[1], true)
	assert(workshop.level["rewardPlants"] == new_reward_types)
	assert((workshop.reward_mode_button.get_child(0) as Label).text.contains("奖✖️2"))
	assert(not (workshop.level["availablePlants"] as Array).has(new_reward_types[1]))
	workshop.call("_toggle_reward_card", new_reward_types[1], true)
	assert(workshop.level["rewardPlants"] == [new_reward_types[0]])
	assert(workshop.level["availablePlants"] == inherited_plants_before)
	workshop.call("_toggle_reward_catalog")
	assert(workshop.catalog_mode == LevelWorkshop.CatalogMode.SPAWN_ZOMBIES)
	workshop.call("_create_new_level")
	assert(workshop.reward_mode_button.visible)
	assert(not workshop.previous_formal_level_button.visible)
	assert(not workshop.next_formal_level_button.visible)
	assert(workshop.new_level_button.button_pressed)
	assert(not workshop.edit_level_button.button_pressed)
	assert(workshop.new_level_button.position.y == workshop.ACTIVE_SOURCE_BUTTON_OFFSET_Y)
	assert(workshop.new_level_button.self_modulate == workshop.ACTIVE_SOURCE_BUTTON_MODULATE)

	workshop.call("_toggle_reward_catalog")
	assert(workshop.catalog_mode == LevelWorkshop.CatalogMode.REWARD_CARDS)
	assert(not workshop.timeline_meter.visible)
	assert(workshop.clear_cards_button.visible)
	if not workshop.reward_card_order.is_empty():
		var plant_entry: Dictionary = workshop.reward_card_order[0]
		var plant_type := int(plant_entry["id"])
		workshop.level["availablePlants"] = [plant_type]
		var selected_plant_holder: Control = workshop.call("_make_reward_card", plant_entry)
		assert((selected_plant_holder.get_child(0) as Card).modulate == Color.WHITE)
		workshop.level["availablePlants"] = []
		var unselected_plant_holder: Control = workshop.call("_make_reward_card", plant_entry)
		assert((unselected_plant_holder.get_child(0) as Card).modulate.a < 1.0)
		workshop.level["availablePlants"] = []
		var plant_dialog_before: Control = workshop.quantity_dialog_layer
		workshop.call("_toggle_reward_card", plant_type, true)
		assert((workshop.level["availablePlants"] as Array).has(plant_type))
		workshop.call("_toggle_reward_card", plant_type, true)
		assert(not (workshop.level["availablePlants"] as Array).has(plant_type))
		assert(workshop.quantity_dialog_layer == plant_dialog_before)
		workshop.level["availablePlants"] = [plant_type]
		workshop.call("_clear_all_cards")
		assert((workshop.level["availablePlants"] as Array).is_empty())
	workshop.call("_toggle_reward_catalog")
	assert(workshop.timeline_meter.visible)
	assert(not workshop.clear_cards_button.visible)

	workshop.level = Logic.example_level()
	workshop.level["simpleZombiePool"] = [int(CharacterRegistry.ZombieType.Z001NormTalon)]
	workshop.level["waves"] = [Logic.make_wave("wave_redesign", "尺寸测试", 0.0, 10.0, [], "flag")]
	workshop.selected_wave = 0
	workshop.call("_refresh_wave")
	workshop.call("_select_simple_zombie", "501")
	assert(workshop.preview_zombies.size() == 2)
	assert((workshop.level["waves"][0]["spawnGroups"] as Array).size() == 2)
	assert((workshop.level["simpleZombiePool"] as Array).has(501))
	assert(not workshop.level.has("simpleZombieIntroWaves"))
	var selected_zombie_holder: Control = workshop.call("_make_zombie_card", 501)
	assert((selected_zombie_holder.get_child(0) as Card).modulate == Color.WHITE)
	assert(not ((selected_zombie_holder.get_child(0) as Card).get_node("CardBg/Cost") as Label).visible)
	workshop.call("_select_simple_zombie", "501")
	assert(workshop.preview_zombies.size() == 1)
	assert((workshop.level["waves"][0]["spawnGroups"] as Array).size() == 1)
	assert(not (workshop.level["simpleZombiePool"] as Array).has(501))
	workshop.call("_select_simple_zombie", "501")
	workshop.call("_open_simple_zombie_dialog", "501")
	assert(workshop.quantity_dialog_layer != null)
	var required_checkbox: TextureButton
	for button in workshop.quantity_dialog_layer.find_children("*", "TextureButton", true, false):
		if (button as TextureButton).get_meta("settings_checkbox_label", "") == "必须登场":
			required_checkbox = button as TextureButton
			break
	assert(required_checkbox == null)
	workshop.call("_close_quantity_dialog")
	workshop.call("_toggle_editor_complexity")
	assert(workshop.editor_complexity == LevelWorkshop.EditorComplexity.ADVANCED)
	assert(not workshop.delete_timeline_button.disabled)
	assert(not workshop.reset_timeline_button.disabled)
	assert(workshop.timeline_stages.mouse_filter == Control.MOUSE_FILTER_STOP)
	workshop.level["waves"][0]["spawnGroups"] = []
	workshop.call("_refresh_wave")
	workshop.call("_open_zombie_quantity_dialog", "501")
	assert(workshop.quantity_dialog_layer != null)
	workshop.call("_close_quantity_dialog")

	workshop.call("_set_zombie_quantity", "501", 2)
	workshop.call("_set_zombie_quantity", "503", 1)
	var groups: Array = workshop.level["waves"][0]["spawnGroups"]
	assert(groups.size() == 2)
	assert(int(groups[0]["count"]) == 2)
	assert(int(groups[1]["count"]) == 1)
	assert(workshop.preview_zombies.size() == 3)
	assert(workshop.preview_zombies.all(func(zombie): return zombie is Zombie000Base))
	assert(workshop.preview_zombies[0].position != workshop.preview_zombies[1].position)

	var built := Runtime.build_game_para(workshop.level)
	assert(built["ok"], built["error"])
	var schedule: Array[Dictionary] = built["game_para"].custom_spawn_schedule
	assert(schedule.size() == 3)

	workshop.call("_create_next_wave")
	assert((workshop.level["waves"] as Array).size() == 3)
	assert(workshop.level["waves"][1]["stageType"] == "interval")
	assert(workshop.level["waves"][2]["stageType"] == "flag")

	var dense_stages: Array = []
	for index in 15:
		dense_stages.append(Logic.make_wave("interval_dense_%d" % index, "间隔", index * 2.0, 1.0, [], "interval"))
		dense_stages.append(Logic.make_wave("flag_dense_%d" % index, "旗帜", index * 2.0 + 1.0, 1.0, [], "flag"))
	workshop.level["waves"] = dense_stages
	workshop.call("_refresh_timeline")
	for stage_control in workshop.timeline_stages.get_children():
		assert(stage_control.position.x >= -0.01)
		assert(stage_control.position.x + stage_control.size.x <= workshop.timeline_meter.size.x + 0.01)
	print("PVZ level workshop redesign test: passed")
	get_tree().quit(0)
