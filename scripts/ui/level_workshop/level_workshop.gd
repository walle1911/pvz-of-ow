extends Control
class_name LevelWorkshop

const Logic := preload("res://addons/pvz_level_editor/level_editor_logic.gd")
const DraftStore := preload("res://scripts/resources/level/level_draft_store.gd")
const CustomRuntime := preload("res://scripts/resources/level/level_custom_runtime.gd")
const FRONT_LAWN := preload("res://assets/image/background/background1.jpg")

const ZOMBIE_TYPE_IDS := {
	"normal": 500,
	"conehead": 502,
	"buckethead": 504,
	"football": 507,
	"digger": 517,
	"gargantuar": 523,
}
const ZOMBIE_NAMES := {
	"normal": "普通僵尸",
	"conehead": "路障僵尸",
	"buckethead": "铁桶僵尸",
	"football": "橄榄球僵尸",
	"digger": "矿工僵尸",
	"gargantuar": "巨人僵尸",
}
const HISTORY_LIMIT := 80
const PREVIEW_MAX_ZOMBIES := 20
const PREVIEW_COLUMNS := 5

var level: Dictionary = Logic.example_level()
var selected_wave := 0
var selected_zombie_key := ""
var history: Array[String] = []
var future: Array[String] = []
var preview_zombies: Array[Node2D] = []

var sidebar_content: VBoxContainer
var selected_list: VBoxContainer
var rule_editor: VBoxContainer
var preview_root: Control
var road_hint: Label
var road_title: Label
var stage_heading: Label
var wave_title: Label
var wave_summary: Label
var status_label: Label
var draft_picker: OptionButton
var draft_paths: Array[String] = []
var timeline_stages: HBoxContainer
var zombie_card_prefabs: Dictionary = {}
var zombie_card_order: Array[int] = []
var zombie_names: Dictionary = {}


func _ready() -> void:
	_apply_font()
	_refresh_zombie_catalog()
	_build_scene()
	var recovered := DraftStore.load_autosave()
	if recovered["ok"]:
		level = recovered["level"]
		status_label.text = "已恢复上次编辑。点击左侧僵尸卡片即可继续添加。"
	level = Logic.normalize_level(level)
	_force_random_lane_rules()
	_recalculate_stage_times()
	_snapshot(false)
	_refresh_draft_picker()
	_refresh_wave()


func _apply_font() -> void:
	var font := load("res://assets/fonts/NotoSansSC.ttf") as FontFile
	if font == null:
		return
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 14
	self.theme = theme


func _build_scene() -> void:
	var background := Sprite2D.new()
	background.texture = FRONT_LAWN
	background.centered = false
	background.position = Vector2(-210, 0)
	background.z_index = -100
	add_child(background)

	var shade := ColorRect.new()
	shade.position = Vector2(0, 0)
	shade.size = Vector2(370, 600)
	shade.color = Color(0.035, 0.075, 0.05, 0.94)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	preview_root = Control.new()
	preview_root.name = "ShowZombiePanel"
	preview_root.position = Vector2(745, 150)
	preview_root.size = Vector2(290, 410)
	preview_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_root.y_sort_enabled = true
	preview_root.z_index = 50
	add_child(preview_root)

	_build_top_bar()
	_build_sidebar()
	_build_road_overlay()
	_build_timeline()


func _build_top_bar() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(370, 0)
	panel.size = Vector2(696, 70)
	panel.add_theme_stylebox_override("panel", _style(Color(0.03, 0.08, 0.045, 0.93), Color("6e8b62"), 0, 1))
	add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 9)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	margin.add_child(row)
	row.add_child(_button("← 返回", _back_to_menu))
	row.add_child(_button("关卡设置", _open_level_settings))
	row.add_child(_button("上一段", func(): _switch_wave(-1)))
	wave_title = Label.new()
	wave_title.custom_minimum_size.x = 115
	wave_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_title.add_theme_font_size_override("font_size", 22)
	wave_title.add_theme_color_override("font_color", Color("f2dd75"))
	row.add_child(wave_title)
	row.add_child(_button("下一段", func(): _switch_wave(1)))
	row.add_child(_button("＋新增旗帜", _create_next_wave))
	var trial := _button("▶ 立即试玩", _playtest)
	trial.add_theme_stylebox_override("normal", _style(Color("4b7f4d"), Color("a8d47f"), 6, 2))
	row.add_child(trial)
	var save := _button("保存并命名", _open_save_dialog)
	save.add_theme_stylebox_override("normal", _style(Color("d9bd48"), Color("705b17"), 6, 2))
	save.add_theme_color_override("font_color", Color("1d2a18"))
	row.add_child(save)


func _build_sidebar() -> void:
	var margin := MarginContainer.new()
	margin.position = Vector2(0, 0)
	margin.size = Vector2(370, 600)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)
	sidebar_content = VBoxContainer.new()
	sidebar_content.add_theme_constant_override("separation", 7)
	margin.add_child(sidebar_content)

	var title_row := HBoxContainer.new()
	sidebar_content.add_child(title_row)
	stage_heading = Label.new()
	stage_heading.text = "当前阶段僵尸"
	stage_heading.add_theme_font_size_override("font_size", 23)
	stage_heading.add_theme_color_override("font_color", Color("f2dd75"))
	stage_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(stage_heading)
	title_row.add_child(_button("撤销", _undo))
	title_row.add_child(_button("重做", _redo))

	wave_summary = Label.new()
	wave_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wave_summary.add_theme_color_override("font_color", Color("dbe7d4"))
	sidebar_content.add_child(wave_summary)

	var instruction := Label.new()
	instruction.text = "点击僵尸卡片：当前阶段数量 +1\n试玩时会按设定时间逐只随机分排出现。"
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instruction.add_theme_color_override("font_color", Color("9fc58e"))
	sidebar_content.add_child(instruction)

	var card_scroll := ScrollContainer.new()
	card_scroll.custom_minimum_size.y = 135
	card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sidebar_content.add_child(card_scroll)
	var cards := GridContainer.new()
	cards.columns = 6
	cards.add_theme_constant_override("h_separation", 5)
	cards.add_theme_constant_override("v_separation", 5)
	card_scroll.add_child(cards)
	for zombie_type in zombie_card_order:
		cards.add_child(_make_zombie_card(zombie_type))

	var selected_title := Label.new()
	selected_title.text = "已选择（可直接增减数量）"
	selected_title.add_theme_font_size_override("font_size", 17)
	selected_title.add_theme_color_override("font_color", Color("f1d787"))
	sidebar_content.add_child(selected_title)
	var selected_scroll := ScrollContainer.new()
	selected_scroll.custom_minimum_size.y = 75
	selected_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sidebar_content.add_child(selected_scroll)
	selected_list = VBoxContainer.new()
	selected_scroll.add_child(selected_list)

	rule_editor = VBoxContainer.new()
	sidebar_content.add_child(rule_editor)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override("font_color", Color("efc18a"))
	status_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	sidebar_content.add_child(status_label)


func _build_road_overlay() -> void:
	road_title = Label.new()
	road_title.position = Vector2(725, 82)
	road_title.size = Vector2(325, 42)
	road_title.text = "当前波次 · 道路预览"
	road_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	road_title.add_theme_font_size_override("font_size", 22)
	road_title.add_theme_color_override("font_color", Color("fff0a8"))
	road_title.add_theme_color_override("font_outline_color", Color("263420"))
	road_title.add_theme_constant_override("outline_size", 5)
	add_child(road_title)
	road_hint = Label.new()
	road_hint.position = Vector2(735, 125)
	road_hint.size = Vector2(305, 55)
	road_hint.text = "这一波还没有僵尸\n请点击左侧卡片"
	road_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	road_hint.add_theme_font_size_override("font_size", 17)
	road_hint.add_theme_color_override("font_color", Color("e6efda"))
	road_hint.add_theme_color_override("font_outline_color", Color("263420"))
	road_hint.add_theme_constant_override("outline_size", 4)
	add_child(road_hint)


func _build_timeline() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(385, 482)
	panel.size = Vector2(350, 108)
	panel.add_theme_stylebox_override("panel", _style(Color(0.025, 0.06, 0.035, 0.95), Color("78936d"), 7, 1))
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	panel.add_child(box)
	var title := Label.new()
	title.text = "刷怪进度 · 点击旗帜或波间间隔进行编辑"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("e9dc8c"))
	var title_row := HBoxContainer.new()
	title_row.add_child(title)
	title_row.add_child(_button("删除波/间隔", _delete_current_stage))
	box.add_child(title_row)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 69
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	timeline_stages = HBoxContainer.new()
	timeline_stages.add_theme_constant_override("separation", 4)
	scroll.add_child(timeline_stages)


func _refresh_timeline() -> void:
	_clear(timeline_stages)
	var flag_number := 0
	var interval_number := 0
	for stage_index in (level.get("waves", []) as Array).size():
		var stage: Dictionary = level["waves"][stage_index]
		var is_flag := str(stage.get("stageType", "flag")) == "flag"
		if is_flag:
			flag_number += 1
		else:
			interval_number += 1
		var text := "🚩\n第%d波" % flag_number if is_flag else "━━━━\n间隔%d" % interval_number
		var button := _button(text, func(): _select_stage(stage_index))
		button.custom_minimum_size = Vector2(57 if is_flag else 76, 58)
		button.add_theme_font_size_override("font_size", 12)
		if stage_index == selected_wave:
			button.add_theme_stylebox_override("normal", _style(Color("b18b32") if is_flag else Color("4d7654"), Color("fff1a1"), 6, 2))
		timeline_stages.add_child(button)


func _select_stage(stage_index: int) -> void:
	if stage_index < 0 or stage_index >= (level.get("waves", []) as Array).size():
		return
	DraftStore.save_autosave(level)
	_clear_preview_zombies()
	selected_wave = stage_index
	selected_zombie_key = ""
	_refresh_wave()


func _delete_current_stage() -> void:
	var stages: Array = level.get("waves", [])
	if stages.is_empty():
		return
	var stage: Dictionary = stages[selected_wave]
	var is_flag := str(stage.get("stageType", "flag")) == "flag"
	if is_flag and _count_stage_type("flag") <= 1:
		status_label.text = "至少要保留一个旗帜波"
		return
	stages.remove_at(selected_wave)
	selected_wave = clampi(selected_wave, 0, maxi(0, stages.size() - 1))
	selected_zombie_key = ""
	_recalculate_stage_times()
	_snapshot()
	DraftStore.save_autosave(level)
	_refresh_wave()
	status_label.text = "已删除当前%s，可用“撤销”恢复。" % ("旗帜波" if is_flag else "波间阶段")


func _make_zombie_card(zombie_type: int) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(52, 72)
	var prefab: Card = zombie_card_prefabs.get(zombie_type)
	if prefab == null:
		return holder
	var card := prefab.duplicate() as Card
	card.position = Vector2.ZERO
	card.tooltip_text = "添加%s" % _zombie_name(str(zombie_type))
	card.set_process(false)
	var button := card.get_node_or_null("Button") as Button
	if button != null:
		for connection in button.pressed.get_connections():
			button.pressed.disconnect(connection.callable)
		button.pressed.connect(_add_zombie.bind(str(zombie_type)))
	holder.add_child(card)
	return holder


func _refresh_wave() -> void:
	if (level["waves"] as Array).is_empty():
		level["waves"].append(Logic.make_wave("wave_1", "第 1 波", 0.0, 10.0, [], "flag"))
	selected_wave = clampi(selected_wave, 0, (level["waves"] as Array).size() - 1)
	var wave: Dictionary = level["waves"][selected_wave]
	var is_flag := str(wave.get("stageType", "flag")) == "flag"
	var stage_number := _stage_number(selected_wave, str(wave.get("stageType", "flag")))
	wave_title.text = ("🚩 第 %d 波" if is_flag else "波间隔 %d") % stage_number
	stage_heading.text = "旗帜波僵尸" if is_flag else "波间阶段僵尸"
	road_title.text = (("旗帜第 %d 波" if is_flag else "波间间隔 %d") % stage_number) + " · 道路预览"
	road_hint.text = "这个阶段还没有僵尸\n请点击左侧卡片"
	wave_summary.text = "%s｜%.1f–%.1f 秒｜持续 %.1f 秒｜共 %d 只" % [wave["name"], wave["startTime"], float(wave["startTime"]) + float(wave["duration"]), wave["duration"], _wave_total_count(wave)]
	_refresh_selected_list()
	_refresh_rule_editor()
	_refresh_road_zombies()
	_refresh_timeline()


func _refresh_selected_list() -> void:
	_clear(selected_list)
	var wave: Dictionary = level["waves"][selected_wave]
	var has_zombie := false
	for group in wave.get("spawnGroups", []):
		var zombie_key := str(group.get("zombieType", ""))
		if int(group.get("count", 0)) <= 0:
			continue
		has_zombie = true
		var row := HBoxContainer.new()
		var choose := _button(_zombie_name(zombie_key), func(): _select_zombie(zombie_key))
		choose.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choose.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_child(choose)
		var count := Label.new()
		count.text = "× %d" % int(group["count"])
		count.custom_minimum_size.x = 48
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count.add_theme_color_override("font_color", Color("ffffff"))
		row.add_child(count)
		row.add_child(_button("－", func(): _remove_zombie(zombie_key)))
		row.add_child(_button("＋", func(): _add_zombie(zombie_key)))
		selected_list.add_child(row)
	if not has_zombie:
		var empty := Label.new()
		empty.text = "尚未选择僵尸"
		empty.add_theme_color_override("font_color", Color("93a58d"))
		selected_list.add_child(empty)


func _refresh_rule_editor() -> void:
	_clear(rule_editor)
	var stage: Dictionary = level["waves"][selected_wave]
	var stage_duration := _spin("当前阶段持续秒数", 1.0, 300.0, float(stage.get("duration", 20.0)), 1.0)
	rule_editor.add_child(stage_duration.get_parent())
	stage_duration.value_changed.connect(func(value):
		stage["duration"] = value
		_recalculate_stage_times()
		_changed("已修改当前阶段时长")
		_refresh_wave()
	)
	if selected_zombie_key.is_empty():
		var hint := Label.new()
		hint.text = "点击上方“已选择”中的僵尸名称，可调整它的路线和生成间隔。"
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.add_theme_color_override("font_color", Color("9fc58e"))
		rule_editor.add_child(hint)
		return
	var group := _find_group(level["waves"][selected_wave], selected_zombie_key)
	if group.is_empty():
		selected_zombie_key = ""
		_refresh_rule_editor()
		return
	var title := Label.new()
	title.text = "%s的刷怪规则" % _zombie_name(selected_zombie_key)
	title.add_theme_color_override("font_color", Color("f1d787"))
	rule_editor.add_child(title)
	var row := HBoxContainer.new()
	rule_editor.add_child(row)
	var quantity := _spin("数量", 1, 99, int(group["count"]), 1)
	row.add_child(quantity.get_parent())
	var start_delay := _spin("首次出现秒数", 0.0, maxf(0.0, float(stage.get("duration", 20.0)) - 0.1), float(group.get("startDelay", 0.0)), 0.1)
	row.add_child(start_delay.get_parent())
	var interval := _spin("间隔秒数", 0.1, 60, float(group["fixedInterval"]), 0.1)
	row.add_child(interval.get_parent())
	var lane_hint := Label.new()
	lane_hint.text = "出生路线：试玩时为每只僵尸随机选择可用行"
	lane_hint.add_theme_color_override("font_color", Color("9fc58e"))
	rule_editor.add_child(lane_hint)
	quantity.value_changed.connect(func(value): group["count"] = int(value); _changed_and_refresh("已修改数量"))
	start_delay.value_changed.connect(func(value): group["startDelay"] = value; _changed("已修改首次出现时间"))
	interval.value_changed.connect(func(value): group["fixedInterval"] = value; group["intervalMode"] = "fixed"; _changed("已修改生成间隔"))


func _refresh_road_zombies() -> void:
	_clear_preview_zombies()
	var wave: Dictionary = level["waves"][selected_wave]
	var total := _wave_total_count(wave)
	road_hint.visible = total == 0 or total > PREVIEW_MAX_ZOMBIES
	if total == 0:
		road_hint.text = "这个阶段还没有僵尸\n请点击左侧卡片"
		return
	if total > PREVIEW_MAX_ZOMBIES:
		road_hint.text = "已选择 %d 只，右侧预览前 %d 只\n完整数量以左侧列表为准" % [total, PREVIEW_MAX_ZOMBIES]
	var index := 0
	for group in wave.get("spawnGroups", []):
		var zombie_key := str(group.get("zombieType", ""))
		for _instance_index in int(group["count"]):
			if index >= PREVIEW_MAX_ZOMBIES:
				break
			var zombie := _create_show_zombie(zombie_key)
			if zombie == null:
				continue
			# 固定容量网格只用于数量预览，不对应实际草坪行。
			var x := 27.0 + float(index % PREVIEW_COLUMNS) * 55.0
			var y := 48.0 + float(int(index / PREVIEW_COLUMNS)) * 83.0
			zombie.position = Vector2(x, y)
			zombie.scale = Vector2.ONE * 1.65
			zombie.z_index = int(y)
			index += 1
		if index >= PREVIEW_MAX_ZOMBIES:
			break


func _create_show_zombie(zombie_key: String) -> Node2D:
	var prefab: Card = zombie_card_prefabs.get(_zombie_type_id(zombie_key))
	if prefab == null:
		return null
	var static_source := prefab.get_node_or_null("CardBg/CharacterStatic") as Node2D
	if static_source == null:
		return null
	var preview := static_source.duplicate() as Node2D
	_hide_preview_shadows(preview)
	preview_root.add_child(preview)
	preview_zombies.append(preview)
	return preview


func _hide_preview_shadows(root: Node) -> void:
	for child in root.get_children():
		if child is CanvasItem and str(child.name).to_lower().contains("shadow"):
			(child as CanvasItem).visible = false
		_hide_preview_shadows(child)


func _add_zombie(zombie_key: String) -> void:
	var wave: Dictionary = level["waves"][selected_wave]
	var group := _find_group(wave, zombie_key)
	if group.is_empty():
		var group_id := Logic.make_unique_id("group", _all_ids())
		group = Logic.make_group(group_id, str(_zombie_type_id(zombie_key)), 1, 0.0, "fixed", 2.0, "random", Logic.fit_lane_weights([], 5))
		wave["spawnGroups"].append(group)
	else:
		group["count"] = int(group["count"]) + 1
	selected_zombie_key = zombie_key
	_changed("已添加%s，当前阶段共 %d 只" % [_zombie_name(zombie_key), _wave_total_count(wave)])
	_refresh_wave()


func _remove_zombie(zombie_key: String) -> void:
	var wave: Dictionary = level["waves"][selected_wave]
	var group := _find_group(wave, zombie_key)
	if group.is_empty():
		return
	group["count"] = int(group["count"]) - 1
	if int(group["count"]) <= 0:
		wave["spawnGroups"].erase(group)
		if selected_zombie_key == zombie_key:
			selected_zombie_key = ""
	_changed("已减少%s数量" % _zombie_name(zombie_key))
	_refresh_wave()


func _select_zombie(zombie_key: String) -> void:
	selected_zombie_key = zombie_key
	_refresh_rule_editor()


func _switch_wave(delta: int) -> void:
	var target := selected_wave + delta
	if target < 0:
		status_label.text = "已经是第一个阶段"
		return
	if target >= (level["waves"] as Array).size():
		_create_next_wave()
		return
	DraftStore.save_autosave(level)
	_clear_preview_zombies()
	selected_wave = target
	selected_zombie_key = ""
	_refresh_wave()
	status_label.text = "上一阶段已保存。现在可编辑选中的旗帜或波间阶段。"


func _create_next_wave() -> void:
	var waves: Array = level["waves"]
	var start_time := 0.0
	for wave in waves:
		start_time = maxf(start_time, float(wave["startTime"]) + float(wave["duration"]))
	var interval_id := Logic.make_unique_id("interval", _all_ids())
	var interval_number := _count_stage_type("interval") + 1
	waves.append(Logic.make_wave(interval_id, "第 %d 个波间间隔" % interval_number, start_time, 20.0, [], "interval"))
	var wave_id := Logic.make_unique_id("wave", _all_ids())
	var flag_number := _count_stage_type("flag") + 1
	waves.append(Logic.make_wave(wave_id, "第 %d 波" % flag_number, start_time + 20.0, 10.0, [], "flag"))
	DraftStore.save_autosave(level)
	_clear_preview_zombies()
	selected_wave = waves.size() - 1
	selected_zombie_key = ""
	_snapshot()
	_refresh_wave()
	status_label.text = "已新增波间阶段和第 %d 个旗帜波；可在下方进度条分别选择编辑。" % flag_number


func _open_level_settings() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "关卡基础设置"
	dialog.ok_button_text = "保存设置"
	dialog.min_size = Vector2i(470, 380)
	var box := VBoxContainer.new()
	dialog.add_child(box)
	var name_input := _line_field(box, "关卡名称", str(level["name"]))
	var id_input := _line_field(box, "草稿编号", str(level["id"]))
	var sun := _spin("开局阳光", 0, 9999, int(level["playerConfig"]["initialSun"]), 25)
	box.add_child(sun.get_parent())
	var seed := _spin("随机种子", 1, 2147483647, int(level["randomSeed"]), 1)
	box.add_child(seed.get_parent())
	dialog.confirmed.connect(func():
		level["name"] = name_input.text
		level["id"] = id_input.text.strip_edges()
		level["playerConfig"]["initialSun"] = int(sun.value)
		level["randomSeed"] = int(seed.value)
		_changed("关卡设置已保存")
		dialog.queue_free()
	)
	add_child(dialog)
	dialog.popup_centered()


func _line_field(parent: Control, label_text: String, value: String) -> LineEdit:
	var label := Label.new()
	label.text = label_text
	parent.add_child(label)
	var input := LineEdit.new()
	input.text = value
	parent.add_child(input)
	return input


func _spin(label_text: String, min_value: float, max_value: float, value: float, step: float) -> SpinBox:
	var box := VBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.add_theme_color_override("font_color", Color("dbe7d4"))
	box.add_child(label)
	var input := SpinBox.new()
	input.min_value = min_value
	input.max_value = max_value
	input.value = value
	input.step = step
	input.add_theme_color_override("font_color", Color("17241a"))
	box.add_child(input)
	return input


func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_stylebox_override("normal", _style(Color("3c5a42"), Color("79906e"), 5, 1))
	button.add_theme_stylebox_override("hover", _style(Color("567c5c"), Color("b3d29c"), 5, 2))
	button.add_theme_stylebox_override("pressed", _style(Color("2d4633"), Color("d0de9d"), 5, 2))
	button.pressed.connect(callback)
	return button


func _style(fill: Color, border: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 7
	style.content_margin_right = 7
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style


func _find_group(wave: Dictionary, zombie_key: String) -> Dictionary:
	for group in wave.get("spawnGroups", []):
		if _zombie_type_id(group.get("zombieType", "")) == _zombie_type_id(zombie_key):
			return group
	return {}


func _wave_total_count(wave: Dictionary) -> int:
	var total := 0
	for group in wave.get("spawnGroups", []):
		total += maxi(0, int(group.get("count", 0)))
	return total


func _all_ids() -> Array[String]:
	var result: Array[String] = [str(level.get("id", ""))]
	for wave in level.get("waves", []):
		result.append(str(wave.get("id", "")))
		for group in wave.get("spawnGroups", []):
			result.append(str(group.get("id", "")))
	return result


func _refresh_zombie_catalog() -> void:
	zombie_card_prefabs.clear()
	zombie_card_order.clear()
	zombie_names.clear()
	var all_cards := get_node_or_null("/root/AllCards") as AllCardsClass
	if all_cards == null:
		return
	zombie_card_prefabs = all_cards.all_zombie_card_prefabs
	for zombie_type in zombie_card_prefabs.keys():
		zombie_card_order.append(int(zombie_type))
	zombie_card_order.sort_custom(func(left, right):
		return int(all_cards.zombie_card_ids.get(left, 999999)) < int(all_cards.zombie_card_ids.get(right, 999999))
	)
	var registry := get_node_or_null("/root/Global/Registry/CharacterRegistry") as CharacterRegistry
	if registry != null:
		for zombie_type in zombie_card_order:
			zombie_names[zombie_type] = str(registry.get_zombie_info(zombie_type as CharacterRegistry.ZombieType, CharacterRegistry.ZombieInfoAttribute.ZombieName))


func _zombie_type_id(value) -> int:
	var text := str(value)
	if text.is_valid_int():
		return int(text)
	return int(ZOMBIE_TYPE_IDS.get(text, 500))


func _zombie_name(zombie_key: String) -> String:
	var zombie_type := _zombie_type_id(zombie_key)
	if zombie_names.has(zombie_type):
		return str(zombie_names[zombie_type])
	return str(ZOMBIE_NAMES.get(zombie_key, "僵尸 %d" % zombie_type))


func _force_random_lane_rules() -> void:
	for stage in level.get("waves", []):
		for group in stage.get("spawnGroups", []):
			group["zombieType"] = str(_zombie_type_id(group.get("zombieType", "500")))
			group["laneRule"] = "random"


func _count_stage_type(stage_type: String) -> int:
	var count := 0
	for stage in level.get("waves", []):
		if str(stage.get("stageType", "flag")) == stage_type:
			count += 1
	return count


func _stage_number(stage_index: int, stage_type: String) -> int:
	var number := 0
	for index in mini(stage_index + 1, (level.get("waves", []) as Array).size()):
		if str(level["waves"][index].get("stageType", "flag")) == stage_type:
			number += 1
	return maxi(1, number)


func _recalculate_stage_times() -> void:
	var cursor := 0.0
	for stage in level.get("waves", []):
		stage["startTime"] = cursor
		cursor += maxf(1.0, float(stage.get("duration", 1.0)))


func _changed(message := "修改已自动保存") -> void:
	_snapshot()
	DraftStore.save_autosave(level)
	status_label.text = message


func _changed_and_refresh(message: String) -> void:
	_changed(message)
	_refresh_wave()


func _snapshot(clear_future := true) -> void:
	var serialized := JSON.stringify(level)
	if history.is_empty() or history.back() != serialized:
		history.append(serialized)
		if history.size() > HISTORY_LIMIT:
			history.pop_front()
	if clear_future:
		future.clear()


func _undo() -> void:
	if history.size() < 2:
		status_label.text = "没有可以撤销的操作"
		return
	future.append(history.pop_back())
	level = Logic.normalize_level(JSON.parse_string(history.back()) as Dictionary)
	selected_wave = clampi(selected_wave, 0, maxi(0, (level["waves"] as Array).size() - 1))
	selected_zombie_key = ""
	DraftStore.save_autosave(level)
	_refresh_wave()
	status_label.text = "已撤销"


func _redo() -> void:
	if future.is_empty():
		status_label.text = "没有可以重做的操作"
		return
	var serialized: String = future.pop_back()
	history.append(serialized)
	level = Logic.normalize_level(JSON.parse_string(serialized) as Dictionary)
	selected_zombie_key = ""
	DraftStore.save_autosave(level)
	_refresh_wave()
	status_label.text = "已重做"


func _open_save_dialog() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "保存自定义关卡"
	dialog.ok_button_text = "保存"
	dialog.min_size = Vector2i(420, 180)
	var box := VBoxContainer.new()
	dialog.add_child(box)
	var name_input := _line_field(box, "关卡名称", str(level.get("name", "")))
	dialog.confirmed.connect(func():
		var new_name := name_input.text.strip_edges()
		if new_name.is_empty():
			status_label.text = "保存失败：关卡名称不能为空"
			dialog.queue_free()
			return
		level["name"] = new_name
		if str(level.get("id", "")).is_empty() or str(level.get("id", "")) == "example_front_lawn":
			level["id"] = "custom_%d" % int(Time.get_unix_time_from_system())
		_changed("关卡名称已更新")
		_save_draft()
		dialog.queue_free()
	)
	add_child(dialog)
	dialog.popup_centered()
	name_input.grab_focus()
	name_input.select_all()


func _save_draft() -> void:
	var built := CustomRuntime.build_game_para(level)
	if not built["ok"]:
		status_label.text = "保存失败：%s" % built["error"]
		return
	var result := DraftStore.save_draft(level)
	if result["ok"]:
		status_label.text = "已保存“%s”，下次可从“自定义关卡”继续游玩。" % str(level["name"])
		_refresh_draft_picker()
	else:
		status_label.text = "保存失败：%s" % result["error"]


func _playtest() -> void:
	DraftStore.save_autosave(level)
	var built := CustomRuntime.build_game_para(level)
	if not built["ok"]:
		status_label.text = "无法试玩：%s" % built["error"]
		return
	var game_para: ResourceLevelData = built["game_para"]
	game_para.set_choose_level(MainSceneRegistry.MainScenes.LevelWorkshop, 0, "trial_%s" % str(level.get("id", "level")))
	Global.game_para = game_para
	Global.developer_level_adjustments_active = true
	_clear_preview_zombies()
	get_tree().change_scene_to_file(Global.main_scene_registry.MainScenesMap[game_para.game_sences])


func _refresh_draft_picker() -> void:
	# 草稿选择入口保留在数据层；当前草坪界面优先保证波次编排空间。
	draft_paths.clear()
	for draft in DraftStore.list_drafts():
		draft_paths.append(draft["path"])


func _clear_preview_zombies() -> void:
	for zombie in preview_zombies:
		if is_instance_valid(zombie):
			preview_root.remove_child(zombie)
			zombie.queue_free()
	preview_zombies.clear()


func _clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _back_to_menu() -> void:
	DraftStore.save_autosave(level)
	_clear_preview_zombies()
	Global.developer_level_adjustments_active = false
	Global.return_to_developer_mode = true
	get_tree().change_scene_to_file("res://scenes/main/01StartMenu.tscn")
