extends SceneTree

const WorkshopScene := preload("res://scenes/main/07LevelWorkshop.tscn")
const DraftStore := preload("res://scripts/resources/level/level_draft_store.gd")
const Logic := preload("res://addons/pvz_level_editor/level_editor_logic.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var workshop := WorkshopScene.instantiate()
	root.add_child(workshop)
	await process_frame
	await process_frame
	if workshop.sidebar_content == null or workshop.preview_root == null:
		_fail("运行时工坊没有生成卡片侧栏或道路预览区")
		return
	workshop.call("_toggle_editor_complexity")
	workshop.level = Logic.example_level()
	workshop.level["id"] = "runtime_workshop_test"
	workshop.level["name"] = "运行时工坊测试"
	workshop.level["waves"] = [Logic.make_wave("wave_test_1", "第 1 波", 0.0, 20.0, [], "flag")]
	workshop.selected_wave = 0
	workshop.call("_refresh_wave")
	workshop.call("_add_zombie", "normal")
	workshop.call("_add_zombie", "normal")
	await process_frame
	if workshop.preview_zombies.size() != 2:
		_fail("点击卡片后，道路没有生成对应数量的真实僵尸")
		return
	var first_wave_count: int = workshop.call("_wave_total_count", workshop.level["waves"][0])
	workshop.call("_create_next_wave")
	await process_frame
	if workshop.selected_wave != 2 or (workshop.level["waves"] as Array).size() != 3 or not workshop.preview_zombies.is_empty():
		_fail("新增旗帜后，没有同时创建波间阶段并清空道路")
		return
	workshop.call("_add_zombie", "conehead")
	await process_frame
	if workshop.preview_zombies.size() != 1:
		_fail("新波次无法独立选择僵尸")
		return
	workshop.call("_select_stage", 0)
	await process_frame
	if workshop.preview_zombies.size() != 2 or workshop.call("_wave_total_count", workshop.level["waves"][0]) != first_wave_count:
		_fail("返回上一旗帜波后，已保存的僵尸数量没有恢复")
		return
	var saved := DraftStore.save_draft(workshop.level)
	if not saved["ok"]:
		_fail("运行时草稿保存失败：%s" % saved["error"])
		return
	var loaded := DraftStore.load_draft(saved["path"])
	if not loaded["ok"] or (loaded["level"]["waves"] as Array).size() != 3:
		_fail("包含旗帜波和波间阶段的草稿无法重新载入")
		return
	print("PVZ level workshop runtime test: passed")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
