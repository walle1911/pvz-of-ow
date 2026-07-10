extends Control
class_name LevelWorkshop

const Logic := preload("res://addons/pvz_level_editor/level_editor_logic.gd")
const DraftStore := preload("res://scripts/resources/level/level_draft_store.gd")
const FRONT_LAWN := preload("res://assets/image/background/background1.jpg")
const ZOMBIE_CARD_FRAME := preload("res://assets/image/Almanac/Almanac_ZombieWindow.png")
const ZOMBIE_CARD_FRONT := preload("res://assets/image/Almanac/Almanac_ZombieWindow2.png")

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
const LANE_RULE_NAMES := {
	"random": "五条路线随机",
	"fixed": "固定一条路线",
	"weighted": "按路线权重",
}
const HISTORY_LIMIT := 80
const PREVIEW_LEFT := 0.0
const PREVIEW_RIGHT := 245.0
const PREVIEW_LANE_Y := [25.0, 105.0, 185.0, 265.0, 345.0]

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
var wave_title: Label
var wave_summary: Label
var status_label: Label
var draft_picker: OptionButton
var draft_paths: Array[String] = []


func _ready() -> void:
	_apply_font()
	_build_scene()
	var recovered := DraftStore.load_autosave()
	if recovered["ok"]:
		level = recovered["level"]
		status_label.text = "已恢复上次编辑。点击左侧僵尸卡片即可继续添加。"
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

	preview_root = Panel.new()
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
	row.add_child(_button("← 主菜单", _back_to_menu))
	row.add_child(_button("关卡设置", _open_level_settings))
	row.add_child(_button("上一波", func(): _switch_wave(-1)))
	wave_title = Label.new()
	wave_title.custom_minimum_size.x = 115
	wave_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_title.add_theme_font_size_override("font_size", 22)
	wave_title.add_theme_color_override("font_color", Color("f2dd75"))
	row.add_child(wave_title)
	row.add_child(_button("下一波", func(): _switch_wave(1)))
	row.add_child(_button("＋新建下一波", _create_next_wave))
	var save := _button("保存全部草稿", _save_draft)
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
	var title := Label.new()
	title.text = "本波次僵尸"
	title.add_theme_font_size_override("font_size", 23)
	title.add_theme_color_override("font_color", Color("f2dd75"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	title_row.add_child(_button("撤销", _undo))
	title_row.add_child(_button("重做", _redo))

	wave_summary = Label.new()
	wave_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wave_summary.add_theme_color_override("font_color", Color("dbe7d4"))
	sidebar_content.add_child(wave_summary)

	var instruction := Label.new()
	instruction.text = "点击僵尸卡片：本波数量 +1\n道路会立即出现对应的真实僵尸。"
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instruction.add_theme_color_override("font_color", Color("9fc58e"))
	sidebar_content.add_child(instruction)

	var card_scroll := ScrollContainer.new()
	card_scroll.custom_minimum_size.y = 172
	card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sidebar_content.add_child(card_scroll)
	var cards := GridContainer.new()
	cards.columns = 4
	cards.add_theme_constant_override("h_separation", 5)
	cards.add_theme_constant_override("v_separation", 5)
	card_scroll.add_child(cards)
	for zombie_key in Logic.DEFAULT_ZOMBIES:
		cards.add_child(_make_zombie_card(zombie_key))

	var selected_title := Label.new()
	selected_title.text = "已选择（可直接增减数量）"
	selected_title.add_theme_font_size_override("font_size", 17)
	selected_title.add_theme_color_override("font_color", Color("f1d787"))
	sidebar_content.add_child(selected_title)
	var selected_scroll := ScrollContainer.new()
	selected_scroll.custom_minimum_size.y = 105
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
	var road_title := Label.new()
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


func _make_zombie_card(zombie_key: String) -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(80, 105)
	var card := TextureButton.new()
	card.custom_minimum_size = Vector2(76, 76)
	card.ignore_texture_size = true
	card.stretch_mode = TextureButton.STRETCH_SCALE
	card.texture_normal = ZOMBIE_CARD_FRAME
	card.tooltip_text = "添加%s" % ZOMBIE_NAMES[zombie_key]
	card.pressed.connect(func(): _add_zombie(zombie_key))
	var all_cards := get_node_or_null("/root/AllCards")
	if all_cards != null:
		var prefabs: Dictionary = all_cards.get("all_zombie_card_prefabs")
		var zombie_type := int(ZOMBIE_TYPE_IDS[zombie_key])
		if prefabs.has(zombie_type):
			var prefab: Node = prefabs[zombie_type]
			var static_source := prefab.get_node_or_null("CardBg/CharacterStatic")
			if static_source != null:
				var character_static: Node2D = static_source.duplicate()
				character_static.scale = Vector2(1.6, 1.6)
				character_static.position = Vector2(40, 50)
				card.add_child(character_static)
	var front := TextureRect.new()
	front.texture = ZOMBIE_CARD_FRONT
	front.position = Vector2.ZERO
	front.size = Vector2(40, 40)
	front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(front)
	box.add_child(card)
	var label := Label.new()
	label.text = ZOMBIE_NAMES[zombie_key]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color("e9eee5"))
	box.add_child(label)
	return box


func _refresh_wave() -> void:
	if (level["waves"] as Array).is_empty():
		level["waves"].append(Logic.make_wave("wave_1", "第 1 波", 0.0, 20.0, []))
	selected_wave = clampi(selected_wave, 0, (level["waves"] as Array).size() - 1)
	var wave: Dictionary = level["waves"][selected_wave]
	wave_title.text = "第 %d / %d 波" % [selected_wave + 1, (level["waves"] as Array).size()]
	wave_summary.text = "%s｜%.1f 秒开始｜共 %d 只｜威胁 %.1f" % [wave["name"], wave["startTime"], _wave_total_count(wave), Logic.threat_for_wave(wave)]
	_refresh_selected_list()
	_refresh_rule_editor()
	_refresh_road_zombies()


func _refresh_selected_list() -> void:
	_clear(selected_list)
	var wave: Dictionary = level["waves"][selected_wave]
	var has_zombie := false
	for zombie_key in Logic.DEFAULT_ZOMBIES:
		var group := _find_group(wave, zombie_key)
		if group.is_empty() or int(group["count"]) <= 0:
			continue
		has_zombie = true
		var row := HBoxContainer.new()
		var choose := _button(str(ZOMBIE_NAMES[zombie_key]), func(): _select_zombie(zombie_key))
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
	title.text = "%s的刷怪规则" % ZOMBIE_NAMES[selected_zombie_key]
	title.add_theme_color_override("font_color", Color("f1d787"))
	rule_editor.add_child(title)
	var row := HBoxContainer.new()
	rule_editor.add_child(row)
	var quantity := _spin("数量", 1, 99, int(group["count"]), 1)
	row.add_child(quantity.get_parent())
	var interval := _spin("间隔秒数", 0.1, 60, float(group["fixedInterval"]), 0.1)
	row.add_child(interval.get_parent())
	var lane := OptionButton.new()
	for lane_rule in ["random", "fixed", "weighted"]:
		lane.add_item(LANE_RULE_NAMES[lane_rule])
		lane.set_item_metadata(lane.item_count - 1, lane_rule)
		if group["laneRule"] == lane_rule:
			lane.select(lane.item_count - 1)
	lane.add_theme_color_override("font_color", Color("17241a"))
	rule_editor.add_child(lane)
	quantity.value_changed.connect(func(value): group["count"] = int(value); _changed_and_refresh("已修改数量"))
	interval.value_changed.connect(func(value): group["fixedInterval"] = value; group["intervalMode"] = "fixed"; _changed("已修改生成间隔"))
	lane.item_selected.connect(func(item): group["laneRule"] = lane.get_item_metadata(item); _changed("已修改路线规则"))


func _refresh_road_zombies() -> void:
	_clear_preview_zombies()
	var wave: Dictionary = level["waves"][selected_wave]
	var total := _wave_total_count(wave)
	road_hint.visible = total == 0
	if total == 0:
		return
	var index := 0
	for zombie_key in Logic.DEFAULT_ZOMBIES:
		var group := _find_group(wave, zombie_key)
		if group.is_empty():
			continue
		for _instance_index in int(group["count"]):
			var zombie := _create_show_zombie(zombie_key)
			if zombie == null:
				continue
			var lane := index % PREVIEW_LANE_Y.size()
			var slot := int(index / PREVIEW_LANE_Y.size())
			var columns := 6
			var column := slot % columns
			var layer := int(slot / columns)
			var x := lerpf(PREVIEW_LEFT, PREVIEW_RIGHT, float(column) / float(columns - 1))
			x += float(layer % 3) * 9.0
			var y: float = float(PREVIEW_LANE_Y[lane]) + float(layer) * 4.0
			zombie.position = Vector2(x, y)
			zombie.scale = Vector2.ONE * (0.78 if total <= 30 else 0.62)
			zombie.z_index = int(y)
			index += 1


func _create_show_zombie(zombie_key: String) -> Node2D:
	var global_node := get_node_or_null("/root/Global")
	if global_node == null:
		return null
	var registry = global_node.get("character_registry")
	if registry == null:
		return null
	var zombie_scene: PackedScene = registry.get_zombie_info(int(ZOMBIE_TYPE_IDS[zombie_key]), 3)
	if zombie_scene == null:
		return null
	var zombie: Node2D = zombie_scene.instantiate()
	# E_ZInitAttr.CharacterInitType = 0，E_CharacterInitType.IsShow = 1；CurrZombieRowType Land = 0。
	zombie.init_zombie({0: 1, 2: 0})
	preview_root.add_child(zombie)
	preview_zombies.append(zombie)
	return zombie


func _add_zombie(zombie_key: String) -> void:
	var wave: Dictionary = level["waves"][selected_wave]
	var group := _find_group(wave, zombie_key)
	if group.is_empty():
		var group_id := Logic.make_unique_id("group", _all_ids())
		group = Logic.make_group(group_id, zombie_key, 1, 0.0, "fixed", 2.0, "random", Logic.fit_lane_weights([], 5))
		wave["spawnGroups"].append(group)
	else:
		group["count"] = int(group["count"]) + 1
	selected_zombie_key = zombie_key
	_changed("已添加%s，本波共 %d 只" % [ZOMBIE_NAMES[zombie_key], _wave_total_count(wave)])
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
	_changed("已减少%s数量" % ZOMBIE_NAMES[zombie_key])
	_refresh_wave()


func _select_zombie(zombie_key: String) -> void:
	selected_zombie_key = zombie_key
	_refresh_rule_editor()


func _switch_wave(delta: int) -> void:
	var target := selected_wave + delta
	if target < 0:
		status_label.text = "已经是第一波"
		return
	if target >= (level["waves"] as Array).size():
		_create_next_wave()
		return
	DraftStore.save_autosave(level)
	_clear_preview_zombies()
	selected_wave = target
	selected_zombie_key = ""
	_refresh_wave()
	status_label.text = "上一波已保存，道路已清空。现在编辑第 %d 波。" % (selected_wave + 1)


func _create_next_wave() -> void:
	var waves: Array = level["waves"]
	var start_time := 0.0
	for wave in waves:
		start_time = maxf(start_time, float(wave["startTime"]) + float(wave["duration"]))
	var wave_id := Logic.make_unique_id("wave", _all_ids())
	waves.append(Logic.make_wave(wave_id, "第 %d 波" % (waves.size() + 1), start_time + 2.0, 20.0, []))
	DraftStore.save_autosave(level)
	_clear_preview_zombies()
	selected_wave = waves.size() - 1
	selected_zombie_key = ""
	_snapshot()
	_refresh_wave()
	status_label.text = "上一波已保存，并新建了空白第 %d 波。请重新选择僵尸。" % (selected_wave + 1)


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
		if str(group.get("zombieType", "")) == zombie_key:
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


func _changed(message := "修改已自动保存") -> void:
	_snapshot()
	DraftStore.save_autosave(level)
	status_label.text = message


func _changed_and_refresh(message: String) -> void:
	_changed(message)
	var wave: Dictionary = level["waves"][selected_wave]
	wave_summary.text = "%s｜%.1f 秒开始｜共 %d 只｜威胁 %.1f" % [wave["name"], wave["startTime"], _wave_total_count(wave), Logic.threat_for_wave(wave)]
	_refresh_selected_list()
	_refresh_road_zombies()


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


func _save_draft() -> void:
	var result := DraftStore.save_draft(level)
	if result["ok"]:
		status_label.text = "全部波次已保存为待审核草稿，不会自动进入正式关卡。"
		_refresh_draft_picker()
	else:
		status_label.text = "保存失败：%s" % result["error"]


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
	get_tree().change_scene_to_file("res://scenes/main/01StartMenu.tscn")
