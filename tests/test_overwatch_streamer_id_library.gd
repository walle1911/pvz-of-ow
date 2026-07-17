extends SceneTree

const IdLibrary := preload("res://scripts/start_menu/overwatch_streamer_id_library.gd")


func _initialize() -> void:
	assert(IdLibrary.IDS.size() == 209)
	var unique_ids: Dictionary[String, bool] = {}
	for streamer_id in IdLibrary.IDS:
		assert(not streamer_id.is_empty())
		assert(not unique_ids.has(streamer_id), "重复的主播模式 ID：%s" % streamer_id)
		assert(not streamer_id.contains("/"))
		assert(not streamer_id.contains("\\"))
		unique_ids[streamer_id] = true

	var all_but_one: Array[String] = IdLibrary.IDS.duplicate()
	var expected_id := String(all_but_one.pop_back())
	assert(IdLibrary.pick_available(all_but_one) == expected_id)
	assert(IdLibrary.pick_available(IdLibrary.IDS.duplicate()).is_empty())

	var start_menu_scene := load("res://scenes/main/01StartMenu.tscn") as PackedScene
	assert(start_menu_scene != null)
	var start_menu := start_menu_scene.instantiate()
	var button_row := start_menu.get_node("User/PanelCreateNewUser/HBoxContainer") as HBoxContainer
	var button_ok := button_row.get_node("ButtonOK") as TextureButton
	var button_random := button_row.get_node("ButtonRandomID") as TextureButton
	assert(button_row.get_child_count() == 3)
	assert(button_random.texture_normal == button_ok.texture_normal)
	assert(button_random.get_script() == button_ok.get_script())
	assert(button_random.get_node("Label").label_settings == button_ok.get_node("Label").label_settings)
	start_menu.free()
	print("Overwatch streamer ID library test: passed (%d IDs)" % IdLibrary.IDS.size())
	quit()
