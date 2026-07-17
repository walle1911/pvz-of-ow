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
	assert(workshop.card_grid.get_child_count() == mini(workshop.CARDS_PER_PAGE, workshop.zombie_card_order.size()))
	assert(workshop.card_grid.columns == 6)
	assert(workshop.card_page_label != null)
	assert(workshop.editor_complexity == LevelWorkshop.EditorComplexity.SIMPLE)
	assert(workshop.get_node("TopActions/AdvancedModeButton") is BaseButton)
	assert((workshop.get_node("TopActions/AdvancedModeButton/Label") as Label).text == "进阶模式")
	assert((workshop.get_node("TopActions/AdvancedModeButton") as Control).size == (workshop.get_node("TopActions/PlaytestButton") as Control).size)
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
	assert(workshop.delete_timeline_button.disabled)
	assert(workshop.reset_timeline_button.disabled)
	assert(workshop.add_flag_button.disabled)
	assert((workshop.delete_timeline_button.get_node("Label") as Label).text == "总波数")
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
	workshop.call("_on_add_flag_pressed")
	assert(workshop.call("_count_stage_type", "flag") == simple_flag_count)
	assert(workshop.selected_wave == simple_selection)
	assert(workshop.timeline_mode == LevelWorkshop.TimelineMode.NORMAL)
	assert(workshop.flag_cursor_preview == null or not workshop.flag_cursor_preview.visible)
	workshop.call("_on_remove_flag_pressed")
	assert(workshop.call("_count_stage_type", "flag") == simple_flag_count)
	workshop.call("_reset_timeline")
	assert(workshop.call("_count_stage_type", "flag") == simple_flag_count)

	workshop.call("_toggle_reward_catalog")
	assert(workshop.catalog_mode == LevelWorkshop.CatalogMode.REWARD_CARDS)
	assert(not workshop.timeline_meter.visible)
	assert(workshop.clear_cards_button.visible)
	if not workshop.reward_card_order.is_empty():
		var plant_entry: Dictionary = workshop.reward_card_order[0]
		var plant_type := int(plant_entry["id"])
		workshop.level["availablePlants"] = [plant_type]
		var selected_plant_holder: Control = workshop.call("_make_reward_card", plant_entry)
		assert((selected_plant_holder.get_child(0) as Card).modulate.a < 1.0)
		workshop.call("_clear_all_cards")
		assert((workshop.level["availablePlants"] as Array).is_empty())
	workshop.call("_toggle_reward_catalog")
	assert(workshop.timeline_meter.visible)
	assert(not workshop.clear_cards_button.visible)

	workshop.level = Logic.example_level()
	workshop.level["waves"] = [Logic.make_wave("wave_redesign", "尺寸测试", 0.0, 10.0, [], "flag")]
	workshop.selected_wave = 0
	workshop.call("_refresh_wave")
	workshop.call("_select_simple_zombie", "500")
	assert(workshop.preview_zombies.size() == 1)
	assert((workshop.level["waves"][0]["spawnGroups"] as Array).size() == 1)
	var selected_zombie_holder: Control = workshop.call("_make_zombie_card", 500)
	assert((selected_zombie_holder.get_child(0) as Card).modulate.a < 1.0)
	workshop.call("_open_simple_zombie_dialog", "500")
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
	workshop.call("_open_zombie_quantity_dialog", "500")
	assert(workshop.quantity_dialog_layer != null)
	workshop.call("_close_quantity_dialog")

	workshop.call("_set_zombie_quantity", "500", 2)
	workshop.call("_set_zombie_quantity", "502", 1)
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
