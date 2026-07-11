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
	assert(workshop.card_grid.get_child_count() == mini(workshop.CARDS_PER_PAGE, AllCards.all_zombie_card_prefabs.size()))
	assert(workshop.card_grid.columns == 7)
	assert(workshop.card_page_label != null)
	for holder in workshop.card_grid.get_children():
		if holder.get_child_count() > 0:
			assert(not (holder.get_child(0) as Card).is_imitater)
	if AllCards.all_zombie_card_prefabs.size() > workshop.CARDS_PER_PAGE:
		workshop.call("_change_card_page", 1)
		assert(workshop.current_card_page == 1)
		assert(workshop.card_grid.get_child_count() == AllCards.all_zombie_card_prefabs.size() - workshop.CARDS_PER_PAGE)
		workshop.call("_change_card_page", -1)
	assert(workshop.timeline_stages != null)
	assert(workshop.timeline_meter.size == Vector2(158, 54))
	assert(workshop.timeline_meter.scale == Vector2.ONE * workshop.TIMELINE_SCALE)

	workshop.level = Logic.example_level()
	workshop.level["waves"] = [Logic.make_wave("wave_redesign", "尺寸测试", 0.0, 10.0, [], "flag")]
	workshop.selected_wave = 0
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
		assert(stage_control.position.x + stage_control.size.x <= 158.01)
	print("PVZ level workshop redesign test: passed")
	get_tree().quit(0)
