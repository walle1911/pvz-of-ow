extends Node

## 录制专用运行时调试面板。
## F2 完全隐藏/显示面板，F3 进入/退出录制暂停，F4 触发全场射手齐射。
## 暂停时新增的角色会作为正式场上角色保留，也可将植物延迟到恢复 2 秒后批量种下。
## 指定事件在恢复 1.5 秒后触发。

const PANEL_WIDTH := 390.0
const EVENT_TRIGGER_DELAY := 1.5
const DELAYED_PLANT_TRIGGER_DELAY := 2.0
const EVENT_GARGANTUAR_THROW := &"gargantuar_throw"
const EVENT_JACKBOX_EXPLODE := &"jackbox_explode"

var main_game: MainGameManager
var is_recording_paused := false
var was_bgm_bus_muted := false
var target_characters: Array[Character000Base] = []
var queued_events: Array[Dictionary] = []
var queued_delayed_plants: Array[Dictionary] = []

var recording_canvas: CanvasLayer
var pause_button: Button
var status_label: Label
var feedback_label: Label
var plant_option: OptionButton
var zombie_option: OptionButton
var plant_lane_spin: SpinBox
var plant_col_spin: SpinBox
var plant_initial_hp_spin: SpinBox
var delay_plant_option: CheckButton
var zombie_lane_spin: SpinBox
var zombie_col_spin: SpinBox
var zombie_initial_hp_spin: SpinBox
var target_option: OptionButton
var event_option: OptionButton
var queue_button: Button
var queue_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bgm_bus_index := AudioServer.get_bus_index(&"BGM")
	if bgm_bus_index >= 0:
		was_bgm_bus_muted = AudioServer.is_bus_mute(bgm_bus_index)
		AudioServer.set_bus_mute(bgm_bus_index, true)
	main_game = Global.main_game
	_build_panel()
	_fill_character_options()
	_update_panel_state()
	await get_tree().process_frame
	_refresh_targets()


func _exit_tree() -> void:
	var bgm_bus_index := AudioServer.get_bus_index(&"BGM")
	if bgm_bus_index >= 0:
		AudioServer.set_bus_mute(bgm_bus_index, was_bgm_bus_muted)
	if is_recording_paused:
		TreePauseManager.end_tree_pause(TreePauseManager.E_PauseFactor.DebugRecording)


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F2:
		recording_canvas.visible = not recording_canvas.visible
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_F3:
		_toggle_recording_pause()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_F4:
		_force_all_shooters_fire()
		get_viewport().set_input_as_handled()


func _build_panel() -> void:
	recording_canvas = CanvasLayer.new()
	recording_canvas.name = "RecordingDebugCanvas"
	recording_canvas.layer = 100
	recording_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(recording_canvas)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	margin.offset_left = -PANEL_WIDTH - 12.0
	margin.offset_top = 12.0
	margin.offset_right = -12.0
	margin.offset_bottom = 710.0
	recording_canvas.add_child(margin)

	var panel := PanelContainer.new()
	margin.add_child(panel)
	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 7)
	panel.add_child(root_box)

	var title := Label.new()
	title.text = "录制调试台（F2 隐藏 / F3 暂停 / F4 齐射）"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_box.add_child(title)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_box.add_child(status_label)

	pause_button = Button.new()
	pause_button.pressed.connect(_toggle_recording_pause)
	root_box.add_child(pause_button)

	_add_separator(root_box)
	_add_section_label(root_box, "暂停期间放置植物（恢复后保留）")
	plant_option = OptionButton.new()
	plant_option.fit_to_longest_item = false
	root_box.add_child(plant_option)
	var plant_position_row := HBoxContainer.new()
	root_box.add_child(plant_position_row)
	plant_lane_spin = _add_labeled_spin(plant_position_row, "行", 1, 5, 1)
	plant_col_spin = _add_labeled_spin(plant_position_row, "列", 1, 9, 1)
	plant_initial_hp_spin = _add_labeled_spin(plant_position_row, "血量（0满）", 0, 999999, 0)
	plant_initial_hp_spin.tooltip_text = "0 表示默认满血；超过该植物血量上限时按上限设置。"
	delay_plant_option = CheckButton.new()
	delay_plant_option.text = "恢复 2 秒后同时种下"
	root_box.add_child(delay_plant_option)
	var add_plant_button := Button.new()
	add_plant_button.text = "放置植物"
	add_plant_button.pressed.connect(_add_plant_during_pause)
	root_box.add_child(add_plant_button)

	_add_separator(root_box)
	_add_section_label(root_box, "暂停期间放置僵尸（恢复后保留）")
	zombie_option = OptionButton.new()
	zombie_option.fit_to_longest_item = false
	root_box.add_child(zombie_option)
	var zombie_position_row := HBoxContainer.new()
	root_box.add_child(zombie_position_row)
	zombie_lane_spin = _add_labeled_spin(zombie_position_row, "行", 1, 5, 1)
	zombie_col_spin = _add_labeled_spin(zombie_position_row, "列", 1, 9, 9)
	zombie_initial_hp_spin = _add_labeled_spin(zombie_position_row, "血量（0满）", 0, 999999, 0)
	zombie_initial_hp_spin.tooltip_text = "0 表示默认满血；只设置僵尸本体当前血量，不修改护甲和任何血量上限。"
	var add_zombie_button := Button.new()
	add_zombie_button.text = "放置僵尸"
	add_zombie_button.pressed.connect(_add_zombie_during_pause)
	root_box.add_child(add_zombie_button)

	_add_separator(root_box)
	_add_section_label(root_box, "选择场上角色")
	target_option = OptionButton.new()
	target_option.fit_to_longest_item = false
	target_option.item_selected.connect(_on_target_selected)
	root_box.add_child(target_option)
	var target_buttons := HBoxContainer.new()
	root_box.add_child(target_buttons)
	var refresh_button := Button.new()
	refresh_button.text = "刷新列表"
	refresh_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	refresh_button.pressed.connect(_refresh_targets)
	target_buttons.add_child(refresh_button)
	var delete_button := Button.new()
	delete_button.text = "删除所选"
	delete_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	delete_button.pressed.connect(_delete_selected_character)
	target_buttons.add_child(delete_button)

	_add_section_label(root_box, "恢复时触发事件")
	event_option = OptionButton.new()
	event_option.fit_to_longest_item = false
	root_box.add_child(event_option)
	queue_button = Button.new()
	queue_button.text = "加入恢复后 1.5 秒事件队列"
	queue_button.pressed.connect(_queue_selected_event)
	root_box.add_child(queue_button)
	queue_label = Label.new()
	queue_label.text = "待触发事件：0"
	root_box.add_child(queue_label)

	feedback_label = Label.new()
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_label.text = "进入录制暂停后才能布置、删除或排队事件。"
	root_box.add_child(feedback_label)


func _fill_character_options() -> void:
	var plant_types: Array = Global.character_registry.PlantInfo.keys()
	plant_types.sort()
	for plant_type in plant_types:
		var display_name := str(Global.character_registry.get_plant_info(plant_type, CharacterRegistry.PlantInfoAttribute.PlantName))
		plant_option.add_item("%s  [%s]" % [display_name, plant_type])
		plant_option.set_item_metadata(plant_option.item_count - 1, plant_type)

	var zombie_types: Array = Global.character_registry.ZombieInfo.keys()
	zombie_types.sort()
	for zombie_type in zombie_types:
		var display_name := str(Global.character_registry.get_zombie_info(zombie_type, CharacterRegistry.ZombieInfoAttribute.ZombieName))
		zombie_option.add_item("%s  [%s]" % [display_name, zombie_type])
		zombie_option.set_item_metadata(zombie_option.item_count - 1, zombie_type)


func _force_all_shooters_fire() -> void:
	if not is_instance_valid(main_game):
		_feedback("主游戏尚未初始化。")
		return
	var triggered_plants: Array[Plant000Base] = []
	for row_cells: Array in main_game.plant_cell_manager.all_plant_cells:
		for plant_cell: PlantCell in row_cells:
			for plant_value in plant_cell.plant_in_cell.values():
				var plant := plant_value as Plant000Base
				if not is_instance_valid(plant) or plant.is_death or triggered_plants.has(plant):
					continue
				if not Plant052SunflowerMercy.is_blue_line_damage_boost_target_type(plant.plant_type):
					continue
				var attack_component := plant.get_node_or_null(^"AttackComponent") as AttackComponentBulletBase
				if not is_instance_valid(attack_component):
					continue
				attack_component.call(&"_on_bullet_attack_cd_timer_timeout")
				triggered_plants.append(plant)
	_feedback("F4 齐射：已触发 %d 株射手植物的一轮攻击。" % triggered_plants.size())


func _toggle_recording_pause() -> void:
	if not is_instance_valid(main_game):
		_feedback("主游戏尚未初始化。")
		return
	if not is_recording_paused:
		is_recording_paused = true
		TreePauseManager.start_tree_pause(TreePauseManager.E_PauseFactor.DebugRecording)
		_refresh_targets()
		_feedback("玩法已暂停：现在可以布置、删除或排队事件。")
	else:
		await _resume_recording()
	_update_panel_state()


func _resume_recording() -> void:
	var events_to_trigger := queued_events.duplicate()
	var delayed_plants_to_create := queued_delayed_plants.duplicate()
	queued_events.clear()
	queued_delayed_plants.clear()
	is_recording_paused = false
	TreePauseManager.end_tree_pause(TreePauseManager.E_PauseFactor.DebugRecording)
	for event_data in events_to_trigger:
		_trigger_queued_event_after_delay(event_data)
	if not delayed_plants_to_create.is_empty():
		_create_delayed_plants_after_delay(delayed_plants_to_create)
	_refresh_targets()
	_update_delayed_plant_option()
	_feedback("已恢复：%d 株植物将在 2 秒后同时种下，%d 个事件将在 1.5 秒后触发。" % [
		delayed_plants_to_create.size(), events_to_trigger.size()
	])


func _add_plant_during_pause() -> void:
	if not _require_recording_pause() or plant_option.item_count == 0:
		return
	var row := int(plant_lane_spin.value) - 1
	var col := int(plant_col_spin.value) - 1
	var cells := main_game.plant_cell_manager.all_plant_cells
	if row < 0 or row >= cells.size() or col < 0 or col >= cells[row].size():
		_feedback("植物格坐标超出当前地图范围。")
		return
	var plant_type: int = plant_option.get_item_metadata(plant_option.selected)
	var plant_condition: ResourcePlantCondition = Global.character_registry.get_plant_info(
		plant_type, CharacterRegistry.PlantInfoAttribute.PlantConditionResource
	)
	var plant_cell: PlantCell = cells[row][col]
	if not is_instance_valid(plant_condition):
		_feedback("该植物没有可直接种植的条件资源。")
		return
	if delay_plant_option.button_pressed:
		queued_delayed_plants.append({
			"plant_type": plant_type,
			"row": row,
			"col": col,
			"initial_hp": int(plant_initial_hp_spin.value),
		})
		_update_delayed_plant_option()
		_feedback("已排队 %s；将在恢复 2 秒后与其他延迟植物同时种下。" % plant_option.get_item_text(plant_option.selected))
		return
	if not plant_condition.judge_is_can_plant(plant_cell, plant_type):
		_feedback("第 %d 行第 %d 列不满足该植物的种植条件。" % [row + 1, col + 1])
		return
	var plant: Plant000Base = plant_cell.create_plant(plant_type, false, false)
	if not is_instance_valid(plant):
		_feedback("植物创建失败。")
		return
	_apply_initial_hp(plant, int(plant_initial_hp_spin.value))
	_refresh_targets(plant)
	_feedback("已放置 %s，初始血量 %d/%d；恢复后会继续留在场上。" % [
		plant.name, plant.hp_component.curr_hp, plant.hp_component.max_hp
	])


func _create_delayed_plants_after_delay(plant_data_list: Array[Dictionary]) -> void:
	await get_tree().create_timer(DELAYED_PLANT_TRIGGER_DELAY, false).timeout
	if not is_instance_valid(main_game):
		return
	var created_count := 0
	for plant_data in plant_data_list:
		var row: int = plant_data.get("row", -1)
		var col: int = plant_data.get("col", -1)
		var cells := main_game.plant_cell_manager.all_plant_cells
		if row < 0 or row >= cells.size() or col < 0 or col >= cells[row].size():
			continue
		var plant_type: int = plant_data.get("plant_type", -1)
		var plant_condition: ResourcePlantCondition = Global.character_registry.get_plant_info(
			plant_type, CharacterRegistry.PlantInfoAttribute.PlantConditionResource
		)
		var plant_cell: PlantCell = cells[row][col]
		if not is_instance_valid(plant_condition) or not plant_condition.judge_is_can_plant(plant_cell, plant_type):
			continue
		var plant: Plant000Base = plant_cell.create_plant(plant_type, false, false)
		if not is_instance_valid(plant):
			continue
		_apply_initial_hp(plant, int(plant_data.get("initial_hp", 0)))
		created_count += 1
	_refresh_targets()
	_feedback("延迟种植完成：%d/%d 株植物已同时种下。" % [created_count, plant_data_list.size()])


func _add_zombie_during_pause() -> void:
	if not _require_recording_pause() or zombie_option.item_count == 0:
		return
	var lane := int(zombie_lane_spin.value) - 1
	var col := int(zombie_col_spin.value) - 1
	var cells := main_game.plant_cell_manager.all_plant_cells
	if lane < 0 or lane >= main_game.zombie_manager.all_zombie_rows.size() \
	or lane >= cells.size() or col < 0 or col >= cells[lane].size():
		_feedback("僵尸行列坐标超出当前地图范围。")
		return
	var zombie_type: int = zombie_option.get_item_metadata(zombie_option.selected)
	var required_row_type: CharacterRegistry.ZombieRowType = Global.character_registry.get_zombie_info(
		zombie_type, CharacterRegistry.ZombieInfoAttribute.ZombieRowType
	)
	var zombie_row: ZombieRow = main_game.zombie_manager.all_zombie_rows[lane]
	var plant_cell: PlantCell = cells[lane][col]
	if not plant_cell.can_common_zombie and zombie_type != CharacterRegistry.ZombieType.Z520Bungi:
		_feedback("第 %d 行第 %d 列不能放置普通僵尸。" % [lane + 1, col + 1])
		return
	if required_row_type != CharacterRegistry.ZombieRowType.Both and required_row_type != zombie_row.zombie_row_type:
		_feedback("所选僵尸不能放在这一类地形的行。")
		return
	var global_pos := Vector2(
		plant_cell.global_position.x + plant_cell.size.x * 0.5,
		zombie_row.zombie_create_position.global_position.y
	)
	if is_instance_valid(main_game.main_game_slope):
		global_pos.y += main_game.main_game_slope.get_all_slope_y(global_pos.x)
	var init_para := {
		Zombie000Base.E_ZInitAttr.CharacterInitType: Character000Base.E_CharacterInitType.IsNorm,
		Zombie000Base.E_ZInitAttr.Lane: lane,
		Zombie000Base.E_ZInitAttr.CurrZombieRowType: zombie_row.zombie_row_type,
		Zombie000Base.E_ZInitAttr.CurrWave: -1,
	}
	var zombie: Zombie000Base = main_game.zombie_manager.create_norm_zombie(
		zombie_type, zombie_row, init_para, global_pos
	)
	if not is_instance_valid(zombie):
		_feedback("僵尸创建失败。")
		return
	_apply_initial_hp(zombie, int(zombie_initial_hp_spin.value))
	_refresh_targets(zombie)
	_feedback("已放置 %s，本体初始血量 %d/%d；恢复后会继续留在场上。" % [
		zombie.name, zombie.hp_component.curr_hp, zombie.hp_component.max_hp
	])


func _apply_initial_hp(character: Character000Base, requested_hp: int) -> void:
	if requested_hp <= 0 or not is_instance_valid(character) or not is_instance_valid(character.hp_component):
		return
	var hp_component := character.hp_component
	var minimum_alive_hp := mini(maxi(hp_component.death_hp + 1, 1), hp_component.max_hp)
	hp_component.curr_hp = clampi(requested_hp, minimum_alive_hp, hp_component.max_hp)
	hp_component.signal_hp_loss.emit(hp_component.curr_hp, true)


func _refresh_targets(prefer_target: Character000Base = null) -> void:
	if not is_instance_valid(target_option) or not is_instance_valid(main_game):
		return
	target_option.clear()
	target_characters.clear()
	for row_cells: Array in main_game.plant_cell_manager.all_plant_cells:
		for plant_cell: PlantCell in row_cells:
			for plant in plant_cell.plant_in_cell.values():
				if is_instance_valid(plant) and not target_characters.has(plant):
					_add_target(plant, "植物 %s  行%d列%d" % [plant.name, plant.row_col.x + 1, plant.row_col.y + 1])
	for zombie: Zombie000Base in main_game.zombie_manager.all_zombies_1d:
		if is_instance_valid(zombie):
			_add_target(zombie, "僵尸 %s  行%d列%d" % [zombie.name, zombie.lane + 1, _get_zombie_col(zombie) + 1])
	if target_characters.is_empty():
		target_option.add_item("（场上没有角色）")
		target_option.disabled = true
	else:
		target_option.disabled = false
		if is_instance_valid(prefer_target):
			var preferred_index := target_characters.find(prefer_target)
			if preferred_index >= 0:
				target_option.select(preferred_index)
	_update_event_options()


func _add_target(character: Character000Base, label_text: String) -> void:
	target_characters.append(character)
	target_option.add_item(label_text)


func _delete_selected_character() -> void:
	if not _require_recording_pause():
		return
	var target := _get_selected_target()
	if not is_instance_valid(target):
		_feedback("没有可删除的角色。")
		return
	queued_events = queued_events.filter(func(data): return data.get("target") != target)
	target.is_can_death_language = false
	target.character_death_disappear()
	_refresh_targets()
	_update_queue_label()
	_feedback("已删除所选角色。")


func _on_target_selected(_index: int) -> void:
	_update_event_options()


func _update_event_options() -> void:
	if not is_instance_valid(event_option):
		return
	event_option.clear()
	var target := _get_selected_target()
	if target is Zombie025GargantuarBob or target is Zombie026GargantuarReinhardt:
		_add_event_option("恢复 1.5 秒后：投掷小鬼", EVENT_GARGANTUAR_THROW)
	elif target is Zombie016JackboxReaper:
		_add_event_option("恢复 1.5 秒后：直接爆炸", EVENT_JACKBOX_EXPLODE)
	else:
		event_option.add_item("（该角色没有录制事件）")
	queue_button.disabled = not (
		target is Zombie025GargantuarBob
		or target is Zombie026GargantuarReinhardt
		or target is Zombie016JackboxReaper
	)


func _add_event_option(label_text: String, event_key: StringName) -> void:
	event_option.add_item(label_text)
	event_option.set_item_metadata(event_option.item_count - 1, event_key)


func _queue_selected_event() -> void:
	if not _require_recording_pause():
		return
	var target := _get_selected_target()
	if not is_instance_valid(target) or queue_button.disabled or event_option.item_count == 0:
		_feedback("事件只支持 Bob、莱因哈特巨人和死神小丑。")
		return
	var event_key: StringName = event_option.get_item_metadata(event_option.selected)
	queued_events.append({"target": target, "event": event_key})
	_update_queue_label()
	_feedback("事件已排队，将在恢复后 1.5 秒触发。")


func _trigger_queued_event_after_delay(event_data: Dictionary) -> void:
	await get_tree().create_timer(EVENT_TRIGGER_DELAY).timeout
	var target: Character000Base = event_data.get("target")
	if not is_instance_valid(target):
		return
	match event_data.get("event"):
		EVENT_GARGANTUAR_THROW:
			target.set("is_throw_once", true)
			target.set("is_throw", true)
		EVENT_JACKBOX_EXPLODE:
			target.call(&"_strigger_bomb")


func _get_selected_target() -> Character000Base:
	if not is_instance_valid(target_option) or target_characters.is_empty():
		return null
	var index := target_option.selected
	if index < 0 or index >= target_characters.size():
		return null
	return target_characters[index]


func _require_recording_pause() -> bool:
	if is_recording_paused:
		return true
	_feedback("请先按 F3 或面板按钮进入录制暂停。")
	return false


func _update_panel_state() -> void:
	if not is_instance_valid(pause_button):
		return
	status_label.text = "● 已暂停，可布置" if is_recording_paused else "▶ 正在运行"
	pause_button.text = "恢复并执行队列（F3）" if is_recording_paused else "进入录制暂停（F3）"
	_update_queue_label()
	_update_delayed_plant_option()


func _update_queue_label() -> void:
	if is_instance_valid(queue_label):
		queue_label.text = "待触发事件：%d" % queued_events.size()


func _update_delayed_plant_option() -> void:
	if is_instance_valid(delay_plant_option):
		delay_plant_option.text = "恢复 2 秒后同时种下（待种：%d）" % queued_delayed_plants.size()


func _feedback(message: String) -> void:
	if is_instance_valid(feedback_label):
		feedback_label.text = message


func _get_zombie_col(zombie: Zombie000Base) -> int:
	if zombie.lane < 0 or zombie.lane >= main_game.plant_cell_manager.all_plant_cells.size():
		return -1
	var row_cells: Array = main_game.plant_cell_manager.all_plant_cells[zombie.lane]
	var nearest_col := -1
	var nearest_distance := INF
	for col in row_cells.size():
		var plant_cell: PlantCell = row_cells[col]
		var cell_x := plant_cell.global_position.x + plant_cell.size.x * 0.5
		var distance := absf(zombie.global_position.x - cell_x)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_col = col
	return nearest_col


func _add_separator(parent: VBoxContainer) -> void:
	parent.add_child(HSeparator.new())


func _add_section_label(parent: VBoxContainer, text_value: String) -> void:
	var label := Label.new()
	label.text = text_value
	parent.add_child(label)


func _add_label(parent: Control, text_value: String) -> void:
	var label := Label.new()
	label.text = text_value
	parent.add_child(label)


func _add_labeled_spin(parent: HBoxContainer, label_text: String, min_value: float, max_value: float, value: float) -> SpinBox:
	_add_label(parent, label_text)
	var spin := SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.value = value
	spin.step = 1
	spin.custom_arrow_step = 1
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(spin)
	return spin
