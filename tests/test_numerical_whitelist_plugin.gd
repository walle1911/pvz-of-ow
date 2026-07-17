extends SceneTree

const PanelScript := preload("res://addons/numerical_whitelist_editor/whitelist_panel.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var panel := PanelScript.new()
	root.add_child(panel)
	await process_frame
	assert(panel.scene_paths.size() > 60)
	panel.call("_load_scene", "res://scenes/character/plant/plant_001_pea_shooter_soldier76.tscn")
	assert(not panel.current_scene_path.is_empty())
	assert(panel.property_tree.get_root() != null)
	assert(panel.property_tree.get_root().get_child_count() > 0)
	var plant_count: int = panel.scene_paths.size()
	panel.queue_free()
	await process_frame
	print("Numerical whitelist plugin smoke test: passed (%d plant scenes)" % plant_count)
	quit()
