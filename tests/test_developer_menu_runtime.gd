extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var menu := (load("res://scenes/main/01StartMenu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	await process_frame
	var buttons: Array[TextureButton] = [
		menu.get_node("BG_Right/Menu/DeveloperMenu/Button1"),
		menu.get_node("BG_Right/Menu/DeveloperMenu/Button2"),
		menu.get_node("BG_Right/Menu/DeveloperMenu/Button3"),
		menu.get_node("BG_Right/Menu/DeveloperMenu/Button4"),
	]
	for button in buttons:
		assert(button.texture_click_mask != null)
		assert(button.texture_click_mask.get_size() == Vector2i(button.texture_normal.get_size()))
		var transparent_count := 0
		var opaque_count := 0
		for y in range(button.texture_click_mask.get_size().y):
			for x in range(button.texture_click_mask.get_size().x):
				if button.texture_click_mask.get_bit(x, y):
					opaque_count += 1
				else:
					transparent_count += 1
		assert(opaque_count > 0 and transparent_count > 0)
	menu.call("_on_developer_button_hover", buttons[2], true)
	await create_timer(0.2).timeout
	assert(buttons[2].self_modulate != Color.WHITE)
	menu.call("_on_developer_button_hover", buttons[2], false)
	await create_timer(0.2).timeout
	assert(buttons[2].self_modulate.is_equal_approx(Color.WHITE))
	menu.queue_free()
	print("Developer menu runtime test: passed")
	quit()
