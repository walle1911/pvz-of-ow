extends SceneTree

const PanelScript := preload("res://addons/pvz_level_editor/level_editor_panel.gd")
const Logic := preload("res://addons/pvz_level_editor/level_editor_logic.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var panel := PanelScript.new()
	root.add_child(panel)
	await process_frame
	var initial_waves := (panel.level["waves"] as Array).size()
	panel.call("_add_wave")
	if (panel.level["waves"] as Array).size() != initial_waves + 1:
		push_error("面板新增波次交互失败")
		quit(1)
		return
	panel.call("_add_group")
	if (panel.level["waves"][panel.selected_wave]["spawnGroups"] as Array).size() < 2:
		push_error("面板新增刷怪组交互失败")
		quit(1)
		return
	panel.call("_undo")
	panel.call("_redo")
	panel.call("_copy_wave")
	var id_issues := Logic.validate_level(panel.level).filter(func(value): return value["message"].begins_with("ID 必须唯一"))
	if not id_issues.is_empty():
		push_error("复制波次后生成了重复 ID")
		quit(1)
		return
	print("PVZ level editor panel smoke test: passed")
	quit(0)
