extends Control
class_name LevelWorkshop

const Logic := preload("res://addons/pvz_level_editor/level_editor_logic.gd")
const DraftStore := preload("res://scripts/resources/level/level_draft_store.gd")
const CustomRuntime := preload("res://scripts/resources/level/level_custom_runtime.gd")
const FRONT_LAWN := preload("res://assets/image/background/background1.jpg")
const ALMANAC_BACKGROUND := preload("res://assets/image/Almanac/Almanac_ZombieBack.jpg")
const ALMANAC_CLOSE_BUTTON := preload("res://assets/image/Almanac/Almanac_CloseButton.png")
const ALMANAC_CLOSE_BUTTON_HOVER := preload("res://assets/image/Almanac/Almanac_CloseButtonHighlight.png")
const DIALOG_BACKGROUND := preload("res://assets/image/ui/ui_main_game_menu/option_dialog.png")
const DIALOG_BUTTON := preload("res://assets/image/ui/ui_main_game_menu/btn_dialog_back_2.png")
const PAGE_BUTTON := preload("res://assets/image/ui/ui_level/SeedChooser_Button2.png")
const PAGE_BUTTON_HOVER := preload("res://assets/image/ui/ui_level/SeedChooser_Button2_Glow.png")
const FLAG_METER := preload("res://assets/image/ui/ui_progress_bar/FlagMeter.png")
const FLAG_PARTS := preload("res://assets/image/ui/ui_progress_bar/FlagMeterParts.png")
const WORKSHOP_FONT := preload("res://assets/fonts/方正少儿_GBK.ttf")

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
const DRAWER_WIDTH := 700.0
const TIMELINE_SCALE := 1.25
const CARDS_PER_PAGE := 28
## 原版 FlagMeter 黄色槽的逐像素内边界；旗杆和高亮分段共用这组坐标。
const FLAG_CENTER_LEFT := 8.0
const FLAG_CENTER_RIGHT := 150.0

var level: Dictionary = Logic.example_level()
var selected_wave := 0
var selected_zombie_key := ""
var history: Array[String] = []
var future: Array[String] = []
var preview_zombies: Array[Node2D] = []

var sidebar_content: Control
var preview_root: Control
var road_hint: Label
var road_title: Label
var stage_heading: Label
var wave_title: Label
var wave_summary: Label
var status_label: Label
var draft_picker: OptionButton
var draft_paths: Array[String] = []
var timeline_stages: Control
var zombie_card_prefabs: Dictionary = {}
var zombie_card_order: Array[int] = []
var zombie_names: Dictionary = {}
var drawer: Control
var card_grid: GridContainer
var card_scroll: ScrollContainer
var timeline_meter: Control
var timeline_progress_bar: TextureRect
var quantity_dialog_layer: Control
var card_page_label: Label
var current_card_page := 0


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
	var theme := Theme.new()
	theme.default_font = WORKSHOP_FONT
	theme.default_font_size = 14
	self.theme = theme


func _build_scene() -> void:
	var background := Sprite2D.new()
	background.texture = FRONT_LAWN
	background.centered = false
	background.position = Vector2(-210, 0)
	background.z_index = -100
	add_child(background)

	preview_root = Control.new()
	preview_root.name = "ShowZombiePanel"
	preview_root.position = Vector2(746, 180)
	preview_root.size = Vector2(280, 400)
	preview_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_root.y_sort_enabled = true
	preview_root.z_index = 50
	add_child(preview_root)

	_build_drawer()
	_build_road_overlay()
	_animate_drawer_in()


func _build_drawer() -> void:
	drawer = Control.new()
	drawer.name = "AlmanacDrawer"
	drawer.position = Vector2(-DRAWER_WIDTH, 0)
	drawer.size = Vector2(DRAWER_WIDTH, 600)
	drawer.z_index = 100
	add_child(drawer)

	var paper := TextureRect.new()
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paper.texture = ALMANAC_BACKGROUND
	paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paper.stretch_mode = TextureRect.STRETCH_SCALE
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drawer.add_child(paper)

	sidebar_content = Control.new()
	sidebar_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	drawer.add_child(sidebar_content)

	stage_heading = _paper_label("旗帜波僵尸", Vector2(150, 18), Vector2(500, 42), 27, Color("e7e4d1"))
	stage_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_heading.add_theme_color_override("font_outline_color", Color("25263b"))
	stage_heading.add_theme_constant_override("outline_size", 4)
	sidebar_content.add_child(stage_heading)

	wave_title = _paper_label("", Vector2(52, 74), Vector2(210, 28), 19, Color("6d310d"))
	sidebar_content.add_child(wave_title)
	wave_summary = _paper_label("", Vector2(290, 74), Vector2(360, 28), 14, Color("6d310d"))
	wave_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sidebar_content.add_child(wave_summary)

	status_label = _paper_label("点击卡片，设置本阶段出场数量", Vector2(52, 100), Vector2(610, 25), 16, Color("7e390f"))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sidebar_content.add_child(status_label)

	card_scroll = ScrollContainer.new()
	card_scroll.position = Vector2(55, 126)
	card_scroll.size = Vector2(590, 414)
	card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card_scroll.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	sidebar_content.add_child(card_scroll)
	var card_grid_holder := Control.new()
	card_grid_holder.custom_minimum_size = Vector2(590, 420)
	card_scroll.add_child(card_grid_holder)
	card_grid = GridContainer.new()
	card_grid.position.x = 22
	card_grid.custom_minimum_size.x = 546
	card_grid.columns = 7
	card_grid.add_theme_constant_override("h_separation", 0)
	card_grid.add_theme_constant_override("v_separation", 0)
	card_grid_holder.add_child(card_grid)

	sidebar_content.add_child(_texture_button("上一页", Vector2(174, 538), Vector2(111, 26), PAGE_BUTTON, PAGE_BUTTON_HOVER, _change_card_page.bind(-1), 14))
	sidebar_content.add_child(_texture_button("下一页", Vector2(439, 538), Vector2(111, 26), PAGE_BUTTON, PAGE_BUTTON_HOVER, _change_card_page.bind(1), 14))
	card_page_label = _paper_label("", Vector2(292, 538), Vector2(140, 26), 14, Color("6d310d"))
	card_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sidebar_content.add_child(card_page_label)
	_refresh_card_page()

	_build_timeline()
	_build_drawer_actions()

func _build_drawer_actions() -> void:
	var actions := [
		{"text": "返回", "call": _back_to_menu},
		{"text": "设置", "call": _open_level_settings},
		{"text": "撤销", "call": _undo},
		{"text": "重做", "call": _redo},
		{"text": "试玩", "call": _playtest},
		{"text": "保存", "call": _open_save_dialog},
	]
	for index in actions.size():
		var item: Dictionary = actions[index]
		var button := _texture_button(str(item["text"]), Vector2(84 + index * 98, 570), Vector2(89, 26), ALMANAC_CLOSE_BUTTON, ALMANAC_CLOSE_BUTTON_HOVER, item["call"], 14)
		sidebar_content.add_child(button)


func _animate_drawer_in() -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(drawer, "position:x", 0.0, 0.48)


func _build_road_overlay() -> void:
	road_title = Label.new()
	road_title.position = Vector2(710, 70)
	road_title.size = Vector2(345, 42)
	road_title.text = "当前波次 · 道路预览"
	road_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	road_title.add_theme_font_override("font", WORKSHOP_FONT)
	road_title.add_theme_font_size_override("font_size", 21)
	road_title.add_theme_color_override("font_color", Color("fff0a8"))
	road_title.add_theme_color_override("font_outline_color", Color("263420"))
	road_title.add_theme_constant_override("outline_size", 5)
	add_child(road_title)
	road_hint = Label.new()
	road_hint.position = Vector2(720, 112)
	road_hint.size = Vector2(325, 55)
	road_hint.text = "这一波还没有僵尸\n请点击左侧卡片"
	road_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	road_hint.add_theme_font_override("font", WORKSHOP_FONT)
	road_hint.add_theme_font_size_override("font_size", 17)
	road_hint.add_theme_color_override("font_color", Color("e6efda"))
	road_hint.add_theme_color_override("font_outline_color", Color("263420"))
	road_hint.add_theme_constant_override("outline_size", 4)
	add_child(road_hint)


func _build_timeline() -> void:
	var add_flag := _texture_button("＋旗帜", Vector2(902, 486), Vector2(89, 26), ALMANAC_CLOSE_BUTTON, ALMANAC_CLOSE_BUTTON_HOVER, _create_next_wave, 14)
	add_flag.z_index = 120
	add_child(add_flag)
	timeline_meter = Control.new()
	timeline_meter.position = Vector2(830, 520)
	timeline_meter.size = Vector2(158, 54)
	timeline_meter.scale = Vector2.ONE * TIMELINE_SCALE
	timeline_meter.z_index = 120
	add_child(timeline_meter)
	var meter_texture := AtlasTexture.new()
	meter_texture.atlas = FLAG_METER
	meter_texture.region = Rect2(0, 0, 158, 27)
	timeline_progress_bar = TextureRect.new()
	timeline_progress_bar.position = Vector2(0, 12)
	timeline_progress_bar.size = Vector2(158, 27)
	timeline_progress_bar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	timeline_progress_bar.stretch_mode = TextureRect.STRETCH_KEEP
	timeline_progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var meter := TextureRect.new()
	meter.position = Vector2(0, 12)
	meter.size = Vector2(158, 27)
	meter.texture = meter_texture
	meter.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	meter.stretch_mode = TextureRect.STRETCH_KEEP
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	timeline_meter.add_child(meter)
	timeline_meter.add_child(timeline_progress_bar)
	timeline_stages = Control.new()
	timeline_stages.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	timeline_meter.add_child(timeline_stages)


func _refresh_timeline() -> void:
	_clear(timeline_stages)
	var stages: Array = level.get("waves", [])
	var flag_stage_indices: Array[int] = []
	for stage_index in stages.size():
		if str((stages[stage_index] as Dictionary).get("stageType", "flag")) == "flag":
			flag_stage_indices.append(stage_index)
	var flag_positions: Array[float] = []
	var flag_count := maxi(1, flag_stage_indices.size())
	for flag_index in flag_stage_indices.size():
		var progress_ratio := float(flag_index + 1) / float(flag_count)
		flag_positions.append(lerpf(FLAG_CENTER_RIGHT, FLAG_CENTER_LEFT, progress_ratio))

	var flag_number := 0
	var interval_number := 0
	var selected_segment_left := FLAG_CENTER_LEFT
	var selected_segment_right := FLAG_CENTER_RIGHT
	for stage_index in stages.size():
		var stage: Dictionary = level["waves"][stage_index]
		var is_flag := str(stage.get("stageType", "flag")) == "flag"
		if is_flag:
			flag_number += 1
			var flag_button := _flag_stage_button(flag_number, stage_index == selected_wave)
			flag_button.position = Vector2(flag_positions[flag_number - 1] - 8.0, 0)
			if stage_index == selected_wave:
				selected_segment_left = flag_positions[flag_number - 1]
				selected_segment_right = FLAG_CENTER_RIGHT if flag_number == 1 else flag_positions[flag_number - 2]
			flag_button.pressed.connect(_select_stage.bind(stage_index))
			timeline_stages.add_child(flag_button)
		else:
			interval_number += 1
			var segment_start := FLAG_CENTER_RIGHT if interval_number == 1 else flag_positions[mini(interval_number - 2, flag_positions.size() - 1)]
			var segment_end := flag_positions[mini(interval_number - 1, flag_positions.size() - 1)] if not flag_positions.is_empty() else FLAG_CENTER_LEFT
			var segment_left := minf(segment_start, segment_end) + 2.0
			var segment_width := maxf(4.0, absf(segment_start - segment_end) - 4.0)
			if stage_index == selected_wave:
				selected_segment_left = minf(segment_start, segment_end)
				selected_segment_right = maxf(segment_start, segment_end)
			var interval_button := Button.new()
			interval_button.position = Vector2(segment_left, 20.0)
			interval_button.size = Vector2(segment_width, 12)
			interval_button.tooltip_text = "点击编辑第 %d 个波间阶段" % interval_number
			interval_button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
			interval_button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
			interval_button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
			interval_button.pressed.connect(_select_stage.bind(stage_index))
			timeline_stages.add_child(interval_button)
	if timeline_progress_bar != null:
		selected_segment_left = clampf(selected_segment_left, 0.0, 158.0)
		selected_segment_right = clampf(selected_segment_right, selected_segment_left, 158.0)
		var selected_progress_texture := AtlasTexture.new()
		selected_progress_texture.atlas = FLAG_METER
		selected_progress_texture.region = Rect2(selected_segment_left, 27, selected_segment_right - selected_segment_left, 27)
		timeline_progress_bar.position.x = selected_segment_left
		timeline_progress_bar.size.x = selected_segment_right - selected_segment_left
		timeline_progress_bar.texture = selected_progress_texture


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
	holder.custom_minimum_size = Vector2(78, 105)
	var prefab: Card = zombie_card_prefabs.get(zombie_type)
	if prefab == null:
		return holder
	var card := prefab.duplicate() as Card
	card.position = Vector2(5, 5)
	card.scale = Vector2.ONE * 1.35
	card.is_imitater = false
	card.tooltip_text = "设置%s的数量" % _zombie_name(str(zombie_type))
	card.set_process(false)
	_force_font_recursive(card)
	var button := card.get_node_or_null("Button") as Button
	if button != null:
		for connection in button.pressed.get_connections():
			button.pressed.disconnect(connection.callable)
		button.pressed.connect(_open_zombie_quantity_dialog.bind(str(zombie_type)))
	holder.add_child(card)
	return holder


func _change_card_page(offset: int) -> void:
	var page_count := maxi(1, ceili(float(zombie_card_order.size()) / CARDS_PER_PAGE))
	current_card_page = posmod(current_card_page + offset, page_count)
	_refresh_card_page()


func _refresh_card_page() -> void:
	if card_grid == null:
		return
	_clear(card_grid)
	var page_count := maxi(1, ceili(float(zombie_card_order.size()) / CARDS_PER_PAGE))
	current_card_page = clampi(current_card_page, 0, page_count - 1)
	var begin := current_card_page * CARDS_PER_PAGE
	var end := mini(begin + CARDS_PER_PAGE, zombie_card_order.size())
	for index in range(begin, end):
		card_grid.add_child(_make_zombie_card(zombie_card_order[index]))
	if card_page_label != null:
		card_page_label.text = "%d / %d" % [current_card_page + 1, page_count]


func _open_zombie_quantity_dialog(zombie_key: String) -> void:
	if is_instance_valid(quantity_dialog_layer):
		quantity_dialog_layer.queue_free()
	quantity_dialog_layer = Control.new()
	quantity_dialog_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	quantity_dialog_layer.z_index = 500
	add_child(quantity_dialog_layer)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.48)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	quantity_dialog_layer.add_child(shade)

	var dialog := TextureRect.new()
	dialog.position = Vector2(327, 58)
	dialog.size = Vector2(412, 483)
	dialog.texture = DIALOG_BACKGROUND
	dialog.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dialog.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	quantity_dialog_layer.add_child(dialog)

	var title := _paper_label("设置出场数量", Vector2(48, 69), Vector2(316, 44), 27, Color("e7e4d1"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", Color("25263b"))
	title.add_theme_constant_override("outline_size", 4)
	dialog.add_child(title)
	var zombie_name := _paper_label(_zombie_name(zombie_key), Vector2(48, 120), Vector2(316, 30), 20, Color("e9d28a"))
	zombie_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialog.add_child(zombie_name)

	var prefab: Card = zombie_card_prefabs.get(_zombie_type_id(zombie_key))
	if prefab != null:
		var card := prefab.duplicate() as Card
		card.position = Vector2(181, 156)
		card.is_imitater = false
		card.set_process(false)
		var card_button := card.get_node_or_null("Button") as Button
		if card_button != null:
			card_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_force_font_recursive(card)
		dialog.add_child(card)

	var wave: Dictionary = level["waves"][selected_wave]
	var existing_group := _find_group(wave, zombie_key)
	var current_quantity := 1 if existing_group.is_empty() else int(existing_group.get("count", 1))
	var quantity_label := _paper_label("本阶段出场数量", Vector2(86, 245), Vector2(240, 32), 19, Color("e9d28a"))
	quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialog.add_child(quantity_label)
	var quantity := SpinBox.new()
	quantity.position = Vector2(126, 286)
	quantity.size = Vector2(160, 42)
	quantity.min_value = 0
	quantity.max_value = 99
	quantity.step = 1
	quantity.value = current_quantity
	quantity.add_theme_font_override("font", WORKSHOP_FONT)
	quantity.add_theme_font_size_override("font_size", 20)
	dialog.add_child(quantity)
	var confirm := _texture_button("确定加入", Vector2(126, 350), Vector2(160, 44), DIALOG_BUTTON, DIALOG_BUTTON, func(): _set_zombie_quantity(zombie_key, int(quantity.value)), 18)
	dialog.add_child(confirm)

	var close := _texture_button("取消", Vector2(162, 425), Vector2(89, 26), ALMANAC_CLOSE_BUTTON, ALMANAC_CLOSE_BUTTON_HOVER, _close_quantity_dialog, 14)
	dialog.add_child(close)


func _set_zombie_quantity(zombie_key: String, quantity: int) -> void:
	_close_quantity_dialog()
	var wave: Dictionary = level["waves"][selected_wave]
	var group := _find_group(wave, zombie_key)
	if quantity <= 0:
		if not group.is_empty():
			wave["spawnGroups"].erase(group)
		_changed("已从当前阶段移除%s" % _zombie_name(zombie_key))
		_refresh_wave()
		return
	if group.is_empty():
		var group_id := Logic.make_unique_id("group", _all_ids())
		group = Logic.make_group(group_id, str(_zombie_type_id(zombie_key)), quantity, 0.0, "fixed", 2.0, "random", Logic.fit_lane_weights([], 5))
		wave["spawnGroups"].append(group)
	else:
		group["count"] = quantity
	_changed("%s在当前阶段设置为 %d 只" % [_zombie_name(zombie_key), quantity])
	_refresh_wave()


func _close_quantity_dialog() -> void:
	if is_instance_valid(quantity_dialog_layer):
		quantity_dialog_layer.queue_free()
	quantity_dialog_layer = null


func _refresh_wave() -> void:
	if (level["waves"] as Array).is_empty():
		level["waves"].append(Logic.make_wave("wave_1", "第 1 波", 0.0, 10.0, [], "flag"))
	selected_wave = clampi(selected_wave, 0, (level["waves"] as Array).size() - 1)
	var wave: Dictionary = level["waves"][selected_wave]
	var is_flag := str(wave.get("stageType", "flag")) == "flag"
	var stage_number := _stage_number(selected_wave, str(wave.get("stageType", "flag")))
	wave_title.text = ("第 %d 面旗帜" if is_flag else "旗帜间隔 %d") % stage_number
	stage_heading.text = "旗帜波僵尸" if is_flag else "波间阶段僵尸"
	road_title.text = (("旗帜第 %d 波" if is_flag else "波间间隔 %d") % stage_number) + " · 道路预览"
	road_hint.text = "这个阶段还没有僵尸\n请点击左侧卡片"
	wave_summary.text = "持续 %.0f 秒　共 %d 只" % [wave["duration"], _wave_total_count(wave)]
	_refresh_road_zombies()
	_refresh_timeline()


func _refresh_road_zombies() -> void:
	_clear_preview_zombies()
	var wave: Dictionary = level["waves"][selected_wave]
	var total := _wave_total_count(wave)
	road_title.text = "当前阶段 · 马路预览 · 共 %d 只" % total
	road_hint.visible = total == 0 or total > PREVIEW_MAX_ZOMBIES
	if total == 0:
		road_hint.text = "这个阶段还没有僵尸\n请点击左侧卡片"
		return
	if total > PREVIEW_MAX_ZOMBIES:
		road_hint.text = "当前阶段共 %d 只\n马路随机展示前 %d 只" % [total, PREVIEW_MAX_ZOMBIES]
	var random := RandomNumberGenerator.new()
	random.seed = int(level.get("randomSeed", 1)) + selected_wave * 7919
	var index := 0
	for group in wave.get("spawnGroups", []):
		var zombie_key := str(group.get("zombieType", "500"))
		for _instance_index in int(group["count"]):
			if index >= PREVIEW_MAX_ZOMBIES:
				break
			var zombie := _create_show_zombie(zombie_key)
			if zombie == null:
				continue
			zombie.position = Vector2(random.randf_range(0.0, preview_root.size.x), random.randf_range(0.0, preview_root.size.y))
			index += 1
		if index >= PREVIEW_MAX_ZOMBIES:
			break


func _create_show_zombie(zombie_key: String) -> Node2D:
	var registry := get_node_or_null("/root/Global/Registry/CharacterRegistry") as CharacterRegistry
	if registry == null:
		return null
	var zombie_type := _zombie_type_id(zombie_key) as CharacterRegistry.ZombieType
	var zombie_scene: PackedScene = registry.get_zombie_info(zombie_type, CharacterRegistry.ZombieInfoAttribute.ZombieScenes)
	if zombie_scene == null:
		return null
	var preview := zombie_scene.instantiate() as Zombie000Base
	var zombie_init_para: Dictionary = {
		Zombie000Base.E_ZInitAttr.CharacterInitType: Character000Base.E_CharacterInitType.IsShow,
		Zombie000Base.E_ZInitAttr.CurrZombieRowType: CharacterRegistry.ZombieRowType.Land,
		Zombie000Base.E_ZInitAttr.IsMiniZombie: false,
	}
	preview.init_zombie(zombie_init_para)
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
	label.add_theme_font_override("font", WORKSHOP_FONT)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color("6d310d"))
	box.add_child(label)
	var input := SpinBox.new()
	input.custom_minimum_size = Vector2(84, 24)
	input.min_value = min_value
	input.max_value = max_value
	input.value = value
	input.step = step
	input.add_theme_font_override("font", WORKSHOP_FONT)
	input.add_theme_font_size_override("font_size", 12)
	input.add_theme_color_override("font_color", Color("41210d"))
	box.add_child(input)
	return input


func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", WORKSHOP_FONT)
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_stylebox_override("normal", _style(Color("e9bb78"), Color("8a4f20"), 5, 1))
	button.add_theme_stylebox_override("hover", _style(Color("ffd79b"), Color("6d310d"), 5, 2))
	button.add_theme_stylebox_override("pressed", _style(Color("c98e4f"), Color("5b2c0b"), 5, 2))
	button.pressed.connect(callback)
	return button


func _paper_label(text_value: String, pos: Vector2, label_size: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = label_size
	label.text = text_value
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", WORKSHOP_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _texture_button(text_value: String, pos: Vector2, button_size: Vector2, normal: Texture2D, hover: Texture2D, callback: Callable, font_size: int) -> TextureButton:
	var button := TextureButton.new()
	button.position = pos
	button.size = button_size
	button.texture_normal = normal
	button.texture_hover = hover
	button.texture_pressed = hover
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var label := _paper_label(text_value, Vector2.ZERO, button_size, font_size, Color("2c1c0b"))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(label)
	button.pressed.connect(callback)
	return button


func _flag_stage_button(flag_number: int, selected: bool) -> Button:
	var button := Button.new()
	button.size = Vector2(40, 42)
	button.tooltip_text = "点击编辑第 %d 面旗帜" % flag_number
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	var pole_texture := AtlasTexture.new()
	pole_texture.atlas = FLAG_PARTS
	pole_texture.region = Rect2(25, 4, 25, 25)
	var flag_texture := AtlasTexture.new()
	flag_texture.atlas = FLAG_PARTS
	flag_texture.region = Rect2(50, 1, 25, 25)
	var pole := TextureRect.new()
	## Pole 切片的竖杆位于局部 x=4.5；配合按钮 x=边界-8，竖杆中心严格落在边界上。
	pole.position = Vector2(3.5, 7)
	pole.size = Vector2(25, 25)
	pole.texture = pole_texture
	pole.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(pole)
	var flag := TextureRect.new()
	flag.position = Vector2(3.5, -3 if selected else 7)
	flag.size = Vector2(25, 25)
	flag.texture = flag_texture
	flag.modulate = Color("fff2a1") if selected else Color.WHITE
	flag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(flag)
	var number := _paper_label(str(flag_number), Vector2(0, 27), Vector2(40, 15), 11, Color("5b2c0b"))
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(number)
	return button


func _force_font_recursive(node: Node) -> void:
	if node is Label:
		(node as Label).add_theme_font_override("font", WORKSHOP_FONT)
	elif node is Button:
		(node as Button).add_theme_font_override("font", WORKSHOP_FONT)
	elif node is LineEdit:
		(node as LineEdit).add_theme_font_override("font", WORKSHOP_FONT)
	for child in node.get_children():
		_force_font_recursive(child)


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


func _segment_style(fill: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(4)
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
	var global := get_node("/root/Global")
	global.game_para = game_para
	global.developer_level_adjustments_active = true
	_clear_preview_zombies()
	get_tree().change_scene_to_file(global.main_scene_registry.MainScenesMap[game_para.game_sences])


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
	var global := get_node("/root/Global")
	global.developer_level_adjustments_active = false
	global.return_to_developer_mode = true
	get_tree().change_scene_to_file("res://scenes/main/01StartMenu.tscn")
