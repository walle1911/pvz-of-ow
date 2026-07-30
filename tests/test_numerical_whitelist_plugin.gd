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
	_assert_scene_has_property(panel, "res://scenes/character/plant/plant_052_bonk_choy_ramattra.tscn", "attack_value")
	_assert_property_search(panel, "attack_value")
	var plant_count: int = panel.scene_paths.size()
	panel.queue_free()
	await process_frame
	print("Numerical whitelist plugin smoke test: passed (%d plant scenes)" % plant_count)
	quit()


func _assert_scene_has_property(panel: Control, scene_path: String, property_name: String) -> void:
	panel.call("_load_scene", scene_path)
	var item: TreeItem = panel.property_tree.get_root().get_next_in_tree()
	while item != null:
		var metadata = item.get_metadata(0)
		if metadata is Dictionary and str(metadata.get("property", "")) == property_name:
			return
		item = item.get_next_in_tree()
	assert(false, "%s should expose %s" % [scene_path, property_name])


func _assert_property_search(panel: Control, property_name: String) -> void:
	panel.search_edit.text = property_name
	panel.call("_apply_property_filter", property_name)
	var item: TreeItem = panel.property_tree.get_root().get_next_in_tree()
	var found_visible_match := false
	while item != null:
		var metadata = item.get_metadata(0)
		if metadata is Dictionary:
			var searchable_text := "%s %s" % [
				metadata.get("property", ""),
				metadata.get("node_path", ""),
			]
			var is_match := property_name in searchable_text.to_lower()
			assert(item.is_visible() == is_match)
			found_visible_match = found_visible_match or is_match
		item = item.get_next_in_tree()
	assert(found_visible_match)
	panel.search_edit.clear()
	panel.call("_apply_property_filter", "")
