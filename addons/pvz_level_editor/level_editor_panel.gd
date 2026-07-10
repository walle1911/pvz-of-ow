@tool
extends VBoxContainer

const Logic := preload("res://addons/pvz_level_editor/level_editor_logic.gd")
const AUTOSAVE_PATH := "user://pvz_level_editor/autosave.json"
const TIMELINE_PIXELS_PER_SECOND := 10.0
const HISTORY_LIMIT := 100

var level: Dictionary = Logic.example_level()
var selected_wave := 0
var selected_group := 0
var history: Array[String] = []
var future: Array[String] = []

var resource_list: ItemList
var map_grid: GridContainer
var map_caption: Label
var wave_list: ItemList
var timeline: HBoxContainer
var inspector: VBoxContainer
var analysis: RichTextLabel
var status: Label
var id_input: LineEdit
var name_input: LineEdit
var map_type_input: OptionButton
var rows_input: SpinBox
var columns_input: SpinBox
var sun_input: SpinBox
var seed_input: SpinBox
var _ignore_ui := false


func _ready() -> void:
	name = "PvzLevelEditor"
	custom_minimum_size = Vector2(960, 650)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_font()
	_build_toolbar()
	_build_workspace()
	_build_status()
	_load_autosave()
	_snapshot(false)
	_refresh()
	set_process_unhandled_key_input(true)


func _apply_font() -> void:
	var font := load("res://assets/fonts/NotoSansSC.ttf") as FontFile
	if font == null:
		return
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 14
	self.theme = theme


func _build_toolbar() -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	add_child(bar)
	_add_button(bar, "示例", _reset_example, "恢复内置示例关卡")
	_add_button(bar, "导入 JSON", _open_import, "导入并归一化 JSON")
	_add_button(bar, "导出 JSON", _open_export, "校验通过后导出")
	_add_button(bar, "撤销", _undo, "Ctrl/Cmd + Z")
	_add_button(bar, "重做", _redo, "Ctrl/Cmd + Shift + Z")
	_add_button(bar, "模拟", _simulate, "生成确定性刷怪计划")
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	_add_button(bar, "校验配置", _refresh_analysis, "检查所有错误和警告")


func _build_workspace() -> void:
	var vertical := VSplitContainer.new()
	vertical.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vertical.split_offset = 430
	add_child(vertical)

	var body := HSplitContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.split_offset = 210
	vertical.add_child(body)
	body.add_child(_build_resources())

	var center_and_inspector := HSplitContainer.new()
	center_and_inspector.split_offset = 650
	body.add_child(center_and_inspector)
	center_and_inspector.add_child(_build_map())
	center_and_inspector.add_child(_build_inspector())
	vertical.add_child(_build_timeline())


func _build_resources() -> Control:
	var panel := VBoxContainer.new()
	panel.custom_minimum_size = Vector2(200, 0)
	var title := Label.new()
	title.text = "资源库"
	title.add_theme_font_size_override("font_size", 16)
	panel.add_child(title)
	var hint := Label.new()
	hint.text = "植物：切换可用\n僵尸：应用到当前刷怪组\n事件：追加到胜/败条件"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.modulate = Color(0.75, 0.78, 0.82)
	panel.add_child(hint)
	resource_list = ItemList.new()
	resource_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	resource_list.allow_reselect = true
	resource_list.item_selected.connect(_resource_selected)
	panel.add_child(resource_list)
	return panel


func _build_map() -> Control:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var title := Label.new()
	title.text = "地图预览"
	title.add_theme_font_size_override("font_size", 16)
	box.add_child(title)
	var row_one := HBoxContainer.new()
	box.add_child(row_one)
	id_input = _line(row_one, "关卡 ID", "")
	name_input = _line(row_one, "关卡名称", "")
	name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_type_input = _option(row_one, "地图类型", Logic.MAP_TYPES)
	var row_two := HBoxContainer.new()
	box.add_child(row_two)
	rows_input = _spin(row_two, "行", 1, 8, 5, 1)
	columns_input = _spin(row_two, "列", 1, 12, 9, 1)
	sun_input = _spin(row_two, "初始阳光", 0, 99999, 150, 25)
	seed_input = _spin(row_two, "随机种子", 1, 2147483647, 1, 1)
	id_input.text_submitted.connect(func(_value): _config_changed())
	name_input.text_submitted.connect(func(_value): _config_changed())
	id_input.focus_exited.connect(_config_changed)
	name_input.focus_exited.connect(_config_changed)
	map_type_input.item_selected.connect(func(_index): _config_changed())
	for control in [rows_input, columns_input, sun_input, seed_input]:
		control.value_changed.connect(func(_value): _config_changed())
	map_caption = Label.new()
	map_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_caption.modulate = Color(0.72, 0.76, 0.82)
	box.add_child(map_caption)
	var map_scroll := ScrollContainer.new()
	map_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(map_scroll)
	map_grid = GridContainer.new()
	map_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_scroll.add_child(map_grid)
	return box


func _build_timeline() -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size.y = 190
	var header := HBoxContainer.new()
	box.add_child(header)
	var title := Label.new()
	title.text = "波次时间轴（拖动色块调整开始时间）"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 16)
	header.add_child(title)
	_add_button(header, "+ 波次", _add_wave)
	_add_button(header, "复制", _copy_wave)
	_add_button(header, "删除", _delete_wave)
	_add_button(header, "上移", _move_wave_up)
	_add_button(header, "下移", _move_wave_down)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = 76
	box.add_child(scroll)
	timeline = HBoxContainer.new()
	timeline.add_theme_constant_override("separation", 4)
	scroll.add_child(timeline)
	wave_list = ItemList.new()
	wave_list.custom_minimum_size.y = 74
	wave_list.select_mode = ItemList.SELECT_SINGLE
	wave_list.item_selected.connect(_wave_selected)
	box.add_child(wave_list)
	return box


func _build_inspector() -> Control:
	var panel := VBoxContainer.new()
	panel.custom_minimum_size = Vector2(330, 0)
	var title := Label.new()
	title.text = "当前对象属性"
	title.add_theme_font_size_override("font_size", 16)
	panel.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)
	inspector = VBoxContainer.new()
	inspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inspector)
	analysis = RichTextLabel.new()
	analysis.bbcode_enabled = true
	analysis.fit_content = false
	analysis.custom_minimum_size.y = 170
	analysis.scroll_active = true
	panel.add_child(analysis)
	return panel


func _build_status() -> void:
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.modulate = Color(0.72, 0.78, 0.84)
	add_child(status)


func _add_button(parent: Control, label: String, callback: Callable, tooltip := "") -> Button:
	var button := Button.new()
	button.text = label
	button.tooltip_text = tooltip
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _line(parent: Control, label: String, value: String) -> LineEdit:
	var box := VBoxContainer.new()
	var text := Label.new()
	text.text = label
	box.add_child(text)
	var input := LineEdit.new()
	input.text = value
	input.custom_minimum_size.x = 115
	box.add_child(input)
	parent.add_child(box)
	return input


func _spin(parent: Control, label: String, min_value: float, max_value: float, value: float, step: float = 0.1) -> SpinBox:
	var box := VBoxContainer.new()
	var text := Label.new()
	text.text = label
	box.add_child(text)
	var input := SpinBox.new()
	input.min_value = min_value
	input.max_value = max_value
	input.value = value
	input.step = step
	input.custom_minimum_size.x = 82
	box.add_child(input)
	parent.add_child(box)
	return input


func _option(parent: Control, label: String, values: Array) -> OptionButton:
	var box := VBoxContainer.new()
	var text := Label.new()
	text.text = label
	box.add_child(text)
	var input := OptionButton.new()
	for value in values:
		input.add_item(str(value))
	input.custom_minimum_size.x = 120
	box.add_child(input)
	parent.add_child(box)
	return input


func _section(title_text: String) -> void:
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 15)
	title.modulate = Color(0.55, 0.78, 1.0)
	inspector.add_child(title)


func _refresh() -> void:
	if not is_node_ready():
		return
	_ignore_ui = true
	var map: Dictionary = level["mapConfig"]
	id_input.text = str(level["id"])
	name_input.text = str(level["name"])
	_select_option(map_type_input, str(map["type"]))
	rows_input.value = int(map["rows"])
	columns_input.value = int(map["columns"])
	sun_input.value = int((level["playerConfig"] as Dictionary)["initialSun"])
	seed_input.value = int(level["randomSeed"])
	_refresh_resources()
	_refresh_map()
	_refresh_waves()
	_refresh_inspector()
	_refresh_analysis()
	_ignore_ui = false
	_autosave()


func _refresh_resources() -> void:
	resource_list.clear()
	_add_resource_header("植物")
	for plant in Logic.DEFAULT_PLANTS:
		resource_list.add_item("🌱 %s%s" % [plant, "  ✓" if (level["availablePlants"] as Array).has(plant) else ""])
	_add_resource_header("僵尸")
	for zombie in Logic.DEFAULT_ZOMBIES:
		resource_list.add_item("🧟 " + zombie)
	_add_resource_header("胜利事件")
	for event_type in ["all_waves_cleared", "survive_duration", "protect_plants"]:
		resource_list.add_item("🏁 " + event_type)
	_add_resource_header("失败事件")
	for event_type in ["zombie_reaches_house", "sun_below_zero"]:
		resource_list.add_item("💀 " + event_type)


func _add_resource_header(title: String) -> void:
	var index := resource_list.add_item("── %s ──" % title)
	resource_list.set_item_disabled(index, true)


func _refresh_map() -> void:
	_clear_children(map_grid)
	var map: Dictionary = level["mapConfig"]
	var rows := int(map["rows"])
	var columns := int(map["columns"])
	var pressure := Logic.lane_pressure(level)
	var counts := Logic.lane_spawn_counts(level)
	map_grid.columns = columns
	map_caption.text = "%s · %d 路 × %d 列 · 总刷怪 %d" % [map["type"], rows, columns, _sum_ints(counts)]
	var max_pressure := 0.001
	for value in pressure:
		max_pressure = maxf(max_pressure, float(value))
	for row in rows:
		for column in columns:
			var cell := PanelContainer.new()
			cell.custom_minimum_size = Vector2(52, 48)
			var shade := 0.10 + 0.25 * float(pressure[row]) / max_pressure
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.10, 0.30 + shade, 0.17, 1.0)
			style.border_color = Color(0.25, 0.45, 0.30, 1.0)
			style.set_border_width_all(1)
			style.set_corner_radius_all(3)
			cell.add_theme_stylebox_override("panel", style)
			var label := Label.new()
			label.text = "L%d" % (row + 1) if column == 0 else ""
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			cell.tooltip_text = "第 %d 路，第 %d 列\n本路刷怪 %d，压力 %.1f" % [row + 1, column + 1, counts[row], pressure[row]]
			cell.add_child(label)
			map_grid.add_child(cell)


func _refresh_waves() -> void:
	wave_list.clear()
	_clear_children(timeline)
	var waves: Array = level["waves"]
	for index in waves.size():
		var wave: Dictionary = waves[index]
		wave_list.add_item("%02d  %s  %.1f–%.1fs  %d 组  威胁 %.1f" % [index + 1, wave["name"], wave["startTime"], float(wave["startTime"]) + float(wave["duration"]), (wave["spawnGroups"] as Array).size(), Logic.threat_for_wave(wave)])
		var gap := Control.new()
		gap.custom_minimum_size.x = maxf(0.0, float(wave["startTime"]) * TIMELINE_PIXELS_PER_SECOND - _timeline_width())
		timeline.add_child(gap)
		timeline.add_child(_make_wave_bar(index, wave))
	if not waves.is_empty():
		selected_wave = clampi(selected_wave, 0, waves.size() - 1)
		wave_list.select(selected_wave)


func _make_wave_bar(index: int, wave: Dictionary) -> Control:
	var bar := Button.new()
	bar.text = "%s\n%.1f–%.1fs" % [wave["name"], wave["startTime"], float(wave["startTime"]) + float(wave["duration"])]
	bar.toggle_mode = true
	bar.button_pressed = index == selected_wave
	bar.custom_minimum_size = Vector2(maxf(90.0, float(wave["duration"]) * TIMELINE_PIXELS_PER_SECOND), 58)
	bar.tooltip_text = "单击选择；按住左键水平拖动改变开始时间"
	bar.pressed.connect(func():
		selected_wave = index
		selected_group = 0
		_refresh()
	)
	bar.gui_input.connect(func(event):
		if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and index == selected_wave:
			var waves: Array = level["waves"]
			waves[index]["startTime"] = maxf(0.0, snappedf(float(waves[index]["startTime"]) + event.relative.x / TIMELINE_PIXELS_PER_SECOND, 0.5))
			_record_change("已拖动波次到 %.1fs" % waves[index]["startTime"])
	)
	return bar


func _timeline_width() -> float:
	var total := 0.0
	for child in timeline.get_children():
		total += child.custom_minimum_size.x + 4.0
	return total


func _refresh_inspector() -> void:
	_clear_children(inspector)
	_section("关卡条件")
	var wins := _line(inspector, "胜利条件（逗号分隔）", _condition_text(level["winConditions"]))
	var loses := _line(inspector, "失败条件（逗号分隔）", _condition_text(level["loseConditions"]))
	wins.text_submitted.connect(func(value): level["winConditions"] = _conditions(value); _record_change())
	loses.text_submitted.connect(func(value): level["loseConditions"] = _conditions(value); _record_change())
	wins.focus_exited.connect(func(): level["winConditions"] = _conditions(wins.text); _record_change())
	loses.focus_exited.connect(func(): level["loseConditions"] = _conditions(loses.text); _record_change())
	var waves: Array = level["waves"]
	if waves.is_empty():
		var empty := Label.new()
		empty.text = "尚无波次。请在底部新增波次。"
		inspector.add_child(empty)
		return
	selected_wave = clampi(selected_wave, 0, waves.size() - 1)
	var wave: Dictionary = waves[selected_wave]
	_section("波次")
	var wave_id := _line(inspector, "波次 ID", str(wave["id"]))
	var wave_name := _line(inspector, "波次名称", str(wave["name"]))
	var wave_times := HBoxContainer.new()
	inspector.add_child(wave_times)
	var start := _spin(wave_times, "开始时间", 0, 9999, wave["startTime"], 0.5)
	var duration := _spin(wave_times, "持续时间", 0.1, 9999, wave["duration"], 0.5)
	wave_id.text_submitted.connect(func(value): wave["id"] = value; _record_change())
	wave_name.text_submitted.connect(func(value): wave["name"] = value; _record_change())
	wave_id.focus_exited.connect(func(): wave["id"] = wave_id.text; _record_change())
	wave_name.focus_exited.connect(func(): wave["name"] = wave_name.text; _record_change())
	start.value_changed.connect(func(value): wave["startTime"] = value; _record_change())
	duration.value_changed.connect(func(value): wave["duration"] = value; _record_change())
	var group_row := HBoxContainer.new()
	inspector.add_child(group_row)
	_add_button(group_row, "+ 刷怪组", _add_group)
	_add_button(group_row, "复制组", _copy_group)
	_add_button(group_row, "删除组", _delete_group)
	var groups: Array = wave["spawnGroups"]
	if groups.is_empty():
		return
	selected_group = clampi(selected_group, 0, groups.size() - 1)
	var group: Dictionary = groups[selected_group]
	_section("刷怪组")
	var group_select := OptionButton.new()
	for index in groups.size():
		group_select.add_item("%02d · %s · %d 个" % [index + 1, groups[index]["zombieType"], groups[index]["count"]])
	group_select.select(selected_group)
	group_select.item_selected.connect(func(index): selected_group = index; _refresh())
	inspector.add_child(group_select)
	var group_id := _line(inspector, "刷怪组 ID", str(group["id"]))
	group_id.text_submitted.connect(func(value): group["id"] = value; _record_change())
	group_id.focus_exited.connect(func(): group["id"] = group_id.text; _record_change())
	var zombie := _option(inspector, "僵尸类型", Logic.DEFAULT_ZOMBIES)
	_select_option(zombie, str(group["zombieType"]))
	zombie.item_selected.connect(func(index): group["zombieType"] = Logic.DEFAULT_ZOMBIES[index]; _record_change())
	var basic := HBoxContainer.new()
	inspector.add_child(basic)
	_group_spin(basic, "数量", group, "count", 1, 999, 1)
	_group_spin(basic, "首次延迟", group, "startDelay", 0, 999, 0.1)
	var interval_mode := _option(inspector, "间隔模式", Logic.INTERVAL_MODES)
	_select_option(interval_mode, str(group["intervalMode"]))
	interval_mode.item_selected.connect(func(index): group["intervalMode"] = Logic.INTERVAL_MODES[index]; _record_change())
	var intervals := HBoxContainer.new()
	inspector.add_child(intervals)
	_group_spin(intervals, "固定间隔", group, "fixedInterval", 0.1, 999, 0.1)
	var interval_range: Dictionary = group["randomInterval"]
	_group_spin(intervals, "随机最小", interval_range, "min", 0.1, 999, 0.1)
	_group_spin(intervals, "随机最大", interval_range, "max", 0.1, 999, 0.1)
	var lane_rule := _option(inspector, "路线规则", Logic.LANE_RULES)
	_select_option(lane_rule, str(group["laneRule"]))
	lane_rule.item_selected.connect(func(index): group["laneRule"] = Logic.LANE_RULES[index]; _record_change())
	var lane_row := HBoxContainer.new()
	inspector.add_child(lane_row)
	_group_spin(lane_row, "指定路线", group, "fixedLane", 1, int(level["mapConfig"]["rows"]), 1)
	var weights := _line(inspector, "路线权重（逗号分隔）", ",".join((group["laneWeights"] as Array).map(func(value): return str(value))))
	weights.text_submitted.connect(func(value): group["laneWeights"] = _numbers(value); _record_change())
	weights.focus_exited.connect(func(): group["laneWeights"] = _numbers(weights.text); _record_change())
	var multipliers := HBoxContainer.new()
	inspector.add_child(multipliers)
	_group_spin(multipliers, "血量倍率", group, "healthMultiplier", 0.1, 99, 0.1)
	_group_spin(multipliers, "速度倍率", group, "speedMultiplier", 0.1, 99, 0.1)
	_group_spin(multipliers, "同屏上限", group, "maxAlive", 1, 999, 1)


func _group_spin(parent: Control, label: String, target: Dictionary, key: String, min_value: float, max_value: float, step: float) -> void:
	var spin := _spin(parent, label, min_value, max_value, float(target[key]), step)
	spin.value_changed.connect(func(value):
		target[key] = int(value) if step >= 1.0 else value
		_record_change()
	)


func _refresh_analysis() -> void:
	if analysis == null:
		return
	var issues := Logic.validate_level(level)
	var pressure := Logic.lane_pressure(level)
	var counts := Logic.lane_spawn_counts(level)
	var errors := issues.filter(func(value): return value["severity"] == "error").size()
	var warnings := issues.size() - errors
	var issue_lines: Array[String] = []
	for item in issues:
		var color := "#ff7777" if item["severity"] == "error" else "#e6bd69"
		issue_lines.append("[color=%s]• %s (%s)[/color]" % [color, item["message"], item["path"]])
	if issue_lines.is_empty():
		issue_lines.append("[color=#78d49b]✓ 配置合法[/color]")
	var lane_lines: Array[String] = []
	for index in pressure.size():
		lane_lines.append("L%d  %d 个  压力 %.1f" % [index + 1, counts[index], pressure[index]])
	var wave_threats: Array[String] = []
	for wave in level["waves"]:
		wave_threats.append("%s %.1f" % [wave["name"], Logic.threat_for_wave(wave)])
	analysis.text = "[b]分析[/b]  [color=#ff7777]%d 错误[/color] / [color=#e6bd69]%d 警告[/color]\n%s\n\n[b]波次威胁[/b]\n%s\n\n[b]路线数量 / 压力[/b]\n%s" % [errors, warnings, "\n".join(issue_lines), " · ".join(wave_threats), "\n".join(lane_lines)]


func _config_changed() -> void:
	if _ignore_ui:
		return
	var map: Dictionary = level["mapConfig"]
	level["id"] = id_input.text.strip_edges()
	level["name"] = name_input.text.strip_edges()
	map["type"] = map_type_input.get_item_text(map_type_input.selected)
	map["rows"] = int(rows_input.value)
	map["columns"] = int(columns_input.value)
	(level["playerConfig"] as Dictionary)["initialSun"] = int(sun_input.value)
	level["randomSeed"] = int(seed_input.value)
	for wave in level["waves"]:
		for group in wave["spawnGroups"]:
			group["laneWeights"] = Logic.fit_lane_weights(group.get("laneWeights", []), int(map["rows"]))
			group["fixedLane"] = clampi(int(group.get("fixedLane", 1)), 1, int(map["rows"]))
	_record_change()


func _resource_selected(index: int) -> void:
	var item_text := resource_list.get_item_text(index)
	if item_text.begins_with("🌱 "):
		var plant := item_text.trim_prefix("🌱 ").trim_suffix("  ✓")
		var plants: Array = level["availablePlants"]
		if plants.has(plant):
			plants.erase(plant)
		else:
			plants.append(plant)
		_record_change("已更新可用植物")
	elif item_text.begins_with("🧟 "):
		var group := _current_group()
		if not group.is_empty():
			group["zombieType"] = item_text.trim_prefix("🧟 ")
			_record_change("已应用僵尸类型")
	elif item_text.begins_with("🏁 "):
		_append_condition("winConditions", item_text.trim_prefix("🏁 "))
	elif item_text.begins_with("💀 "):
		_append_condition("loseConditions", item_text.trim_prefix("💀 "))


func _append_condition(key: String, condition_type: String) -> void:
	var conditions: Array = level[key]
	if not conditions.any(func(value): return str(value.get("type", "")) == condition_type):
		conditions.append({"type": condition_type})
		_record_change("已追加条件 " + condition_type)


func _add_wave() -> void:
	var waves: Array = level["waves"]
	var start := 0.0
	for wave in waves:
		start = maxf(start, float(wave["startTime"]) + float(wave["duration"]))
	var wave_id := Logic.make_unique_id("wave", _all_ids())
	var group_id := Logic.make_unique_id("group", _all_ids())
	waves.append(Logic.make_wave(wave_id, "新波次", start + 2.0, 15.0, [Logic.make_group(group_id, "normal", 5, 0.0, "fixed", 1.5, "weighted", Logic.fit_lane_weights([], int(level["mapConfig"]["rows"]))) ]))
	selected_wave = waves.size() - 1
	selected_group = 0
	_record_change("已新增波次")


func _copy_wave() -> void:
	var waves: Array = level["waves"]
	if waves.is_empty():
		return
	var copy: Dictionary = (waves[selected_wave] as Dictionary).duplicate(true)
	var reserved_ids := _all_ids()
	copy["id"] = Logic.make_unique_id("wave", reserved_ids)
	reserved_ids.append(copy["id"])
	copy["name"] = str(copy["name"]) + " 副本"
	copy["startTime"] = float(copy["startTime"]) + float(copy["duration"]) + 1.0
	for group in copy["spawnGroups"]:
		group["id"] = Logic.make_unique_id("group", reserved_ids)
		reserved_ids.append(group["id"])
	waves.insert(selected_wave + 1, copy)
	selected_wave += 1
	selected_group = 0
	_record_change("已复制波次")


func _delete_wave() -> void:
	var waves: Array = level["waves"]
	if waves.is_empty():
		return
	waves.remove_at(selected_wave)
	selected_wave = clampi(selected_wave, 0, maxi(0, waves.size() - 1))
	selected_group = 0
	_record_change("已删除波次")


func _move_wave_up() -> void:
	_move_wave(-1)


func _move_wave_down() -> void:
	_move_wave(1)


func _move_wave(delta: int) -> void:
	var waves: Array = level["waves"]
	var target := selected_wave + delta
	if target < 0 or target >= waves.size():
		return
	var value = waves.pop_at(selected_wave)
	waves.insert(target, value)
	selected_wave = target
	_record_change("已调整波次排序")


func _add_group() -> void:
	var waves: Array = level["waves"]
	if waves.is_empty():
		_add_wave()
		return
	var groups: Array = waves[selected_wave]["spawnGroups"]
	var group_id := Logic.make_unique_id("group", _all_ids())
	groups.append(Logic.make_group(group_id, "normal", 5, 0.0, "fixed", 1.5, "weighted", Logic.fit_lane_weights([], int(level["mapConfig"]["rows"]))))
	selected_group = groups.size() - 1
	_record_change("已新增刷怪组")


func _copy_group() -> void:
	var group := _current_group()
	if group.is_empty():
		return
	var groups: Array = level["waves"][selected_wave]["spawnGroups"]
	var copy: Dictionary = group.duplicate(true)
	copy["id"] = Logic.make_unique_id("group", _all_ids())
	groups.insert(selected_group + 1, copy)
	selected_group += 1
	_record_change("已复制刷怪组")


func _delete_group() -> void:
	var waves: Array = level["waves"]
	if waves.is_empty():
		return
	var groups: Array = waves[selected_wave]["spawnGroups"]
	if groups.is_empty():
		return
	groups.remove_at(selected_group)
	selected_group = clampi(selected_group, 0, maxi(0, groups.size() - 1))
	_record_change("已删除刷怪组")


func _wave_selected(index: int) -> void:
	selected_wave = index
	selected_group = 0
	_refresh()


func _record_change(message := "已自动保存") -> void:
	if _ignore_ui:
		return
	_snapshot()
	_refresh()
	status.text = message


func _snapshot(clear_future := true) -> void:
	var text := JSON.stringify(level)
	if history.is_empty() or history.back() != text:
		history.append(text)
		if history.size() > HISTORY_LIMIT:
			history.pop_front()
	if clear_future:
		future.clear()


func _undo() -> void:
	if history.size() < 2:
		status.text = "没有可撤销的操作"
		return
	future.append(history.pop_back())
	level = Logic.normalize_level(JSON.parse_string(history.back()) as Dictionary)
	_refresh()
	status.text = "已撤销"


func _redo() -> void:
	if future.is_empty():
		status.text = "没有可重做的操作"
		return
	var text := future.pop_back()
	history.append(text)
	level = Logic.normalize_level(JSON.parse_string(text) as Dictionary)
	_refresh()
	status.text = "已重做"


func _autosave() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://pvz_level_editor"))
	var file := FileAccess.open(AUTOSAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(level, "\t"))
		file.close()


func _load_autosave() -> void:
	if not FileAccess.file_exists(AUTOSAVE_PATH):
		return
	var file := FileAccess.open(AUTOSAVE_PATH, FileAccess.READ)
	var loaded = JSON.parse_string(file.get_as_text())
	file.close()
	if loaded is Dictionary:
		level = Logic.normalize_level(loaded)
		status.text = "已恢复本地自动保存"


func _reset_example() -> void:
	level = Logic.example_level()
	selected_wave = 0
	selected_group = 0
	_record_change("已载入示例关卡")


func _open_export() -> void:
	var issues := Logic.validate_level(level)
	if issues.any(func(value): return value["severity"] == "error"):
		status.text = "导出已阻止：请先修复配置错误"
		_refresh_analysis()
		return
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.current_file = str(level["id"]) + ".json"
	dialog.filters = ["*.json ; PVZ level JSON"]
	dialog.file_selected.connect(func(path):
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			status.text = "导出失败，错误码：%s" % str(FileAccess.get_open_error())
		else:
			file.store_string(JSON.stringify(level, "\t"))
			file.close()
			status.text = "已导出 " + path
		dialog.queue_free()
	)
	add_child(dialog)
	dialog.popup_centered_ratio(0.7)


func _open_import() -> void:
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = ["*.json ; PVZ level JSON"]
	dialog.file_selected.connect(func(path):
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			status.text = "导入失败：无法读取文件"
			dialog.queue_free()
			return
		var json := JSON.new()
		var parse_error := json.parse(file.get_as_text())
		file.close()
		if parse_error != OK:
			status.text = "导入失败：第 %d 行 %s" % [json.get_error_line(), json.get_error_message()]
		elif json.data is not Dictionary:
			status.text = "导入失败：JSON 根节点必须是对象"
		else:
			level = Logic.normalize_level(json.data)
			selected_wave = 0
			selected_group = 0
			_record_change("已导入 " + path)
		dialog.queue_free()
	)
	add_child(dialog)
	dialog.popup_centered_ratio(0.7)


func _simulate() -> void:
	var issues := Logic.validate_level(level)
	if issues.any(func(value): return value["severity"] == "error"):
		status.text = "模拟已阻止：请先修复配置错误"
		return
	var events := Logic.simulate_level(level)
	var preview: Array[String] = []
	for event in events.slice(0, mini(10, events.size())):
		preview.append("%.2fs L%d %s" % [event["time"], event["lane"], event["zombieType"]])
	status.text = "确定性模拟 %d 个刷怪：%s%s" % [events.size(), "；".join(preview), "……" if events.size() > 10 else ""]


func _unhandled_key_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo:
		return
	var command: bool = event.ctrl_pressed or event.meta_pressed
	if command and event.keycode == KEY_Z:
		if event.shift_pressed:
			_redo()
		else:
			_undo()
		get_viewport().set_input_as_handled()
	elif command and event.keycode == KEY_D:
		_copy_wave()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_DELETE:
		_delete_group()
		get_viewport().set_input_as_handled()


func _current_group() -> Dictionary:
	var waves: Array = level.get("waves", [])
	if waves.is_empty() or selected_wave < 0 or selected_wave >= waves.size():
		return {}
	var groups: Array = waves[selected_wave].get("spawnGroups", [])
	if groups.is_empty() or selected_group < 0 or selected_group >= groups.size():
		return {}
	return groups[selected_group]


func _all_ids() -> Array[String]:
	var ids: Array[String] = [str(level.get("id", ""))]
	for wave in level.get("waves", []):
		ids.append(str(wave.get("id", "")))
		for group in wave.get("spawnGroups", []):
			ids.append(str(group.get("id", "")))
	return ids


func _condition_text(values: Array) -> String:
	return ",".join(values.map(func(value): return str(value.get("type", ""))))


func _conditions(text: String) -> Array:
	var result: Array = []
	for item in text.split(",", false):
		var value := item.strip_edges()
		if not value.is_empty():
			result.append({"type": value})
	return result


func _numbers(text: String) -> Array:
	var result: Array = []
	for item in text.split(",", false):
		result.append(maxf(0.0, float(item.strip_edges())))
	return result


func _select_option(option: OptionButton, value: String) -> void:
	for index in option.item_count:
		if option.get_item_text(index) == value:
			option.select(index)
			return
	option.select(0)


func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _sum_ints(values: Array[int]) -> int:
	var total := 0
	for value in values:
		total += value
	return total
