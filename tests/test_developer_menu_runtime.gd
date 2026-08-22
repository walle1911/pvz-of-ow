extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var menu := (load("res://scenes/main/01StartMenu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	await process_frame
	_assert_credits_dialog_layout(menu)
	await _assert_start_menu_modal_blocking(menu)
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


func _assert_credits_dialog_layout(menu: Control) -> void:
	var text_paths := {
		"Dialog_Help": "Label",
		"ProducerInfoDialog": "InfoText",
	}
	for dialog_path: String in text_paths:
		var dialog := menu.get_node(dialog_path) as Control
		var panel := dialog.get_node("Panel") as Control
		var return_button := dialog.get_node("PVZButton") as Control
		var info_text := dialog.get_node(text_paths[dialog_path]) as RichTextLabel
		assert(is_equal_approx(dialog.size.x, 390.0))
		assert(is_equal_approx(panel.size.x, 390.0))
		assert(is_equal_approx(return_button.position.x, 115.0))
		assert(is_equal_approx(return_button.size.x, 160.0))
		assert(info_text.position.x >= 0.0)
		assert(info_text.position.x + info_text.size.x <= panel.size.x)
		assert(is_equal_approx(info_text.position.x + info_text.size.x * 0.5, panel.size.x * 0.5))
		assert(info_text.text.begins_with("[center]"))
		assert(info_text.text.ends_with("[/center]"))


func _assert_start_menu_modal_blocking(menu: Control) -> void:
	var blocker := menu.get_node("ModalInputBlocker") as Control
	var help_dialog := menu.get_node("Dialog_Help") as Control
	assert(not blocker.visible)
	assert(blocker.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	menu.call("_on_option_button_2_pressed")
	assert(blocker.visible)
	assert(blocker.mouse_filter == Control.MOUSE_FILTER_STOP)
	assert(blocker.z_index < help_dialog.z_index)
	assert(blocker.size.is_equal_approx(menu.size))
	await create_timer(0.12).timeout
	assert(help_dialog.visible)
	help_dialog.call("_on_button_pressed")
	assert(blocker.visible)
	await create_timer(0.12).timeout
	assert(not help_dialog.visible)
	assert(not blocker.visible)
	assert(blocker.mouse_filter == Control.MOUSE_FILTER_IGNORE)
