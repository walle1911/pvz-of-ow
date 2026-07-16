extends Control
class_name LevelWorkshop

const Logic := preload("res://addons/pvz_level_editor/level_editor_logic.gd")
const DraftStore := preload("res://scripts/resources/level/level_draft_store.gd")
const CustomRuntime := preload("res://scripts/resources/level/level_custom_runtime.gd")
const AdventurePresets := preload("res://scripts/resources/level/adventure_level_presets.gd")
const FormalLevelStore := preload("res://scripts/resources/level/adventure_level_store.gd")
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
## 按界面实际分界线收窄到约 47%，右侧完整留给马路预览。
const DRAWER_WIDTH := 500.0
const TIMELINE_SCALE := 1.25
const CARDS_PER_PAGE := 24
## 仅用于旧草稿兼容和阶段内刷怪计划；不再控制动态阶段何时推进。
const DEFAULT_INTERVAL_DURATION := 28.0
const DEFAULT_FLAG_DURATION := 10.0
const MIN_SPLIT_INTERVAL_DURATION := 1.0
## 原版 FlagMeter 黄色槽的逐像素内边界；旗杆和高亮分段共用这组坐标。
const FLAG_CENTER_LEFT := 8.0
const FLAG_CENTER_RIGHT := 150.0

enum TimelineMode { NORMAL, PLACE_FLAG }
enum CatalogMode { SPAWN_ZOMBIES, REWARD_CARDS }

var level: Dictionary = Logic.example_level()
var selected_wave := 0
var selected_zombie_key := ""
var history: Array[String] = []
var future: Array[String] = []
var preview_zombies: Array[Node2D] = []
var preview_zombie_keys: Dictionary = {}

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
var timeline_hover_bar: TextureRect
var timeline_width_ratio := 1.0
var preview_hit_layer: Control
var quantity_dialog_layer: Control
var card_page_label: Label
var current_card_page := 0
var timeline_mode := TimelineMode.NORMAL
var add_flag_button: TextureButton
var reset_timeline_button: TextureButton
var flag_cursor_preview: TextureRect
var timeline_flag_visuals: Dictionary = {}
var timeline_hovered_flag_index := -1
var catalog_mode := CatalogMode.SPAWN_ZOMBIES
var reward_card_order: Array[Dictionary] = []
var plant_card_prefabs: Dictionary = {}
var background_sprite: Sprite2D
var reward_mode_button: TextureButton
var background_normal_x := -334.0
var formal_preset_id := ""


func _layout_control(path: String) -> Control:
	return get_node_or_null("LayoutMarkers/" + path) as Control


func _ready() -> void:
	_apply_font()
	_refresh_zombie_catalog()
	_build_scene()
	## 工坊入口固定为普通编辑器，不再先进入模式或正式关卡选择页。
	var active_mode := "normal"
	Global.level_workshop_edit_mode = active_mode
	var recovered := DraftStore.load_autosave()
	if recovered["ok"] and str((recovered["level"] as Dictionary).get("workshopMode", "normal")) == active_mode:
		level = recovered["level"]
		formal_preset_id = str(level.get("formalPresetId", ""))
		status_label.text = "已恢复上次编辑。点击左侧僵尸卡片即可继续添加。"
	level = Logic.normalize_level(level)
	level["workshopMode"] = active_mode
	_force_random_lane_rules()
	_recalculate_stage_times()
	_snapshot(false)
	_refresh_draft_picker()
	_refresh_wave()


func _process(_delta: float) -> void:
	if is_instance_valid(flag_cursor_preview) and flag_cursor_preview.visible:
		flag_cursor_preview.position = get_local_mouse_position() - Vector2(4, 22)


func _exit_tree() -> void:
	_end_timeline_mode()


func _apply_font() -> void:
	var theme := Theme.new()
	theme.default_font = WORKSHOP_FONT
	theme.default_font_size = 14
	self.theme = theme


func _build_scene() -> void:
	background_sprite = get_node("BackgroundSprite") as Sprite2D
	background_normal_x = background_sprite.position.x
	preview_root = get_node("ShowZombiePanel") as Control

	_build_drawer()
	_build_road_overlay()
	_animate_drawer_in()


func _build_drawer() -> void:
	drawer = get_node("AlmanacDrawer") as Control
	drawer.position.x = -drawer.size.x
	sidebar_content = drawer.get_node("Content") as Control
	stage_heading = sidebar_content.get_node("StageHeading") as Label
	wave_title = sidebar_content.get_node("WaveTitle") as Label
	wave_summary = sidebar_content.get_node("WaveSummary") as Label
	status_label = sidebar_content.get_node("StatusLabel") as Label
	reward_mode_button = sidebar_content.get_node("RewardModeButton") as TextureButton
	reward_mode_button.visible = Global.level_workshop_edit_mode == "chessboard"
	reward_mode_button.pressed.connect(_toggle_reward_catalog)
	card_scroll = sidebar_content.get_node("CardScroll") as ScrollContainer
	card_grid = card_scroll.get_node("CardGridHolder/CardGrid") as GridContainer
	card_page_label = sidebar_content.get_node("Pagination/PageLabel") as Label
	(sidebar_content.get_node("Pagination/PreviousButton") as TextureButton).pressed.connect(_change_card_page.bind(-1))
	(sidebar_content.get_node("Pagination/NextButton") as TextureButton).pressed.connect(_change_card_page.bind(1))
	_refresh_card_page()

	_build_timeline()
	_build_drawer_actions()

func _build_drawer_actions() -> void:
	var actions := sidebar_content.get_node("BottomActions")
	## 成品关卡在编辑器内部载入；应用只写开发者模式覆盖。
	var action_names := ["BackButton", "SettingsButton", "PlaytestButton", "SaveButton"]
	for action_index in action_names.size():
		var action_button := actions.get_node(action_names[action_index]) as TextureButton
		action_button.position.x = action_index * 78.0
		action_button.size.x = 74.0
	var preset_button := _texture_button("成品关卡", Vector2(312, 0), Vector2(74, 38), ALMANAC_CLOSE_BUTTON, ALMANAC_CLOSE_BUTTON_HOVER, _open_preset_picker, 13)
	actions.add_child(preset_button)
	var apply_formal_button := _texture_button("应用预设", Vector2(390, 0), Vector2(74, 38), ALMANAC_CLOSE_BUTTON, ALMANAC_CLOSE_BUTTON_HOVER, _open_apply_formal_dialog, 13)
	actions.add_child(apply_formal_button)
	(actions.get_node("BackButton") as TextureButton).pressed.connect(_back_to_menu)
	(actions.get_node("SettingsButton") as TextureButton).pressed.connect(_open_level_settings)
	(actions.get_node("PlaytestButton") as TextureButton).pressed.connect(_playtest)
	(actions.get_node("SaveButton") as TextureButton).pressed.connect(_open_save_dialog)


func _open_preset_picker() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "选择要编辑的成品关卡"
	dialog.ok_button_text = "载入编辑"
	dialog.cancel_button_text = "取消"
	dialog.min_size = Vector2i(460, 210)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	dialog.add_child(box)
	var hint := Label.new()
	hint.text = "载入后可编辑；点底部“应用预设”只会覆盖开发者模式中的对应关卡。"
	box.add_child(hint)
	var picker := OptionButton.new()
	var presets := AdventurePresets.list_presets("normal")
	for preset: Dictionary in presets:
		picker.add_item(str(preset["name"]))
	box.add_child(picker)
	dialog.confirmed.connect(func():
		if picker.selected < 0 or picker.selected >= presets.size():
			return
		_load_preset_for_edit(str(presets[picker.selected]["id"]))
		dialog.queue_free()
	)
	add_child(dialog)
	_force_font_recursive(dialog)
	dialog.popup_centered()


func _load_preset_for_edit(preset_id: String) -> void:
	var preset := AdventurePresets.build_level(preset_id, true)
	if preset.is_empty():
		status_label.text = "成品关卡不存在：%s" % preset_id
		return
	level = Logic.normalize_level(preset)
	formal_preset_id = preset_id
	level["formalPresetId"] = preset_id
	## 普通“保存”仍写入 user:// 草稿；只有“应用预设”才写开发者覆盖数据。
	level["id"] = "%s_edit" % preset_id
	Global.level_workshop_edit_mode = str(level.get("workshopMode", "normal"))
	reward_mode_button.visible = Global.level_workshop_edit_mode == "chessboard"
	catalog_mode = CatalogMode.SPAWN_ZOMBIES
	background_sprite.position.x = background_normal_x
	var reward_button_label := reward_mode_button.get_child(0) as Label
	if reward_button_label != null:
		reward_button_label.text = "奖励卡槽"
	_refresh_zombie_catalog()
	_force_random_lane_rules()
	selected_wave = 0
	selected_zombie_key = ""
	history.clear()
	future.clear()
	_recalculate_stage_times()
	_snapshot(false)
	DraftStore.save_autosave(level)
	_refresh_wave()
	status_label.text = "已载入“%s”，可直接修改波次、数量和出怪间隔。" % str(level["name"])


func _open_apply_formal_dialog() -> void:
	if not FormalLevelStore.is_formal_preset_id(formal_preset_id):
		status_label.text = "请先点“成品关卡”，载入要修改的正式关卡。"
		return
	var dialog := ConfirmationDialog.new()
	dialog.title = "应用到开发者预设"
	dialog.ok_button_text = "确认覆盖"
	dialog.cancel_button_text = "取消"
	dialog.min_size = Vector2i(480, 200)
	var hint := Label.new()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.text = "当前配置将写入 %s。它只影响开发者模式“开始冒险吧”中的 %s；普通模式正式关卡不会改变。" % [FormalLevelStore.formal_level_path(formal_preset_id), formal_preset_id]
	dialog.add_child(hint)
	dialog.confirmed.connect(func():
		_recalculate_stage_times()
		level["formalPresetId"] = formal_preset_id
		var result := FormalLevelStore.save_developer_level(level, formal_preset_id)
		if result["ok"]:
			DraftStore.save_autosave(level)
			status_label.text = "已应用到开发者预设 %s；普通冒险不受影响。" % formal_preset_id
		else:
			status_label.text = "应用开发者预设失败：%s" % str(result["error"])
		dialog.queue_free()
	)
	add_child(dialog)
	_force_font_recursive(dialog)
	dialog.popup_centered()


func _animate_drawer_in() -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(drawer, "position:x", 0.0, 0.48)


func _build_road_overlay() -> void:
	road_title = get_node("RoadOverlay/RoadTitle") as Label
	road_hint = get_node("RoadOverlay/RoadHint") as Label
	preview_hit_layer = Control.new()
	preview_hit_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview_hit_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	preview_hit_layer.z_index = 4000
	preview_hit_layer.gui_input.connect(_on_preview_hit_layer_input)
	preview_root.add_child(preview_hit_layer)


func _build_timeline() -> void:
	var timeline_rect := _layout_control("TimelineRect")
	var timeline_position := timeline_rect.position if timeline_rect != null else Vector2(830, 520)
	var timeline_size := timeline_rect.size if timeline_rect != null else Vector2(158, 54)
	var timeline_actions := get_node("TimelineActions")
	(timeline_actions.get_node("UndoButton") as TextureButton).pressed.connect(_undo)
	(timeline_actions.get_node("DeleteButton") as TextureButton).pressed.connect(_open_delete_stage_dialog)
	reset_timeline_button = timeline_actions.get_node("ResetButton") as TextureButton
	reset_timeline_button.pressed.connect(_reset_timeline)
	add_flag_button = timeline_actions.get_node("AddFlagButton") as TextureButton
	add_flag_button.pressed.connect(_begin_flag_placement)
	timeline_meter = Control.new()
	timeline_meter.position = timeline_position
	var timeline_content_width := timeline_size.x / TIMELINE_SCALE
	timeline_width_ratio = timeline_content_width / 158.0
	timeline_meter.size = Vector2(timeline_content_width, 54)
	timeline_meter.scale = Vector2.ONE * TIMELINE_SCALE
	timeline_meter.z_index = 120
	add_child(timeline_meter)
	var meter_texture := AtlasTexture.new()
	meter_texture.atlas = FLAG_METER
	meter_texture.region = Rect2(0, 0, 158, 27)
	timeline_progress_bar = TextureRect.new()
	timeline_progress_bar.position = Vector2(0, 12)
	timeline_progress_bar.size = Vector2(timeline_content_width, 27)
	timeline_progress_bar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	timeline_progress_bar.stretch_mode = TextureRect.STRETCH_SCALE
	timeline_progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	timeline_hover_bar = TextureRect.new()
	timeline_hover_bar.position = Vector2(0, 12)
	timeline_hover_bar.size = Vector2(0, 27)
	timeline_hover_bar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	timeline_hover_bar.stretch_mode = TextureRect.STRETCH_SCALE
	timeline_hover_bar.modulate = Color(1.0, 1.0, 1.0, 0.55)
	timeline_hover_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	timeline_hover_bar.visible = false
	var meter := TextureRect.new()
	meter.position = Vector2(0, 12)
	meter.size = Vector2(timeline_content_width, 27)
	meter.texture = meter_texture
	meter.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	meter.stretch_mode = TextureRect.STRETCH_SCALE
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	timeline_meter.add_child(meter)
	## 黄色段使用 FlagMeter 下半行原贴图，并严格裁到旗杆像素边界。
	timeline_meter.add_child(timeline_hover_bar)
	timeline_meter.add_child(timeline_progress_bar)
	timeline_stages = Control.new()
	timeline_stages.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	timeline_stages.mouse_filter = Control.MOUSE_FILTER_STOP
	timeline_stages.gui_input.connect(_on_timeline_gui_input)
	timeline_stages.mouse_exited.connect(func():
		_hide_interval_preview()
		_set_timeline_hover_flag(-1)
	)
	timeline_meter.add_child(timeline_stages)


func _refresh_timeline() -> void:
	_clear(timeline_stages)
	timeline_flag_visuals.clear()
	timeline_hovered_flag_index = -1
	var stages: Array = level.get("waves", [])
	var total_interval_duration := 0.0
	for stage in stages:
		if str((stage as Dictionary).get("stageType", "flag")) == "interval":
			total_interval_duration += 1.0
	total_interval_duration = maxf(MIN_SPLIT_INTERVAL_DURATION, total_interval_duration)

	var flag_number := 0
	var interval_number := 0
	var elapsed_interval_duration := 0.0
	var selected_segment_left := FLAG_CENTER_LEFT
	var selected_segment_right := FLAG_CENTER_RIGHT
	for stage_index in stages.size():
		var stage: Dictionary = level["waves"][stage_index]
		var is_flag := str(stage.get("stageType", "flag")) == "flag"
		if is_flag:
			flag_number += 1
			var flag_ratio := elapsed_interval_duration / total_interval_duration
			var flag_position := lerpf(FLAG_CENTER_RIGHT, FLAG_CENTER_LEFT, flag_ratio)
			var flag_button := _flag_stage_button(flag_number, stage_index == selected_wave)
			flag_button.position = Vector2(flag_position * timeline_width_ratio - 8.0, 0)
			## 所有输入统一由时间轴根节点判定，视觉控件不再互相抢鼠标事件。
			flag_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if stage_index == selected_wave:
				selected_segment_left = flag_position
				selected_segment_right = flag_position
			timeline_stages.add_child(flag_button)
			timeline_flag_visuals[stage_index] = flag_button.get_node("Flag")
		else:
			interval_number += 1
			var interval_duration := 1.0
			## 旗帜是时间点；黄色段严格从一根旗杆像素延伸到下一根旗杆像素。
			var segment_start := lerpf(FLAG_CENTER_RIGHT, FLAG_CENTER_LEFT, elapsed_interval_duration / total_interval_duration)
			elapsed_interval_duration += interval_duration
			var segment_end := lerpf(FLAG_CENTER_RIGHT, FLAG_CENTER_LEFT, elapsed_interval_duration / total_interval_duration)
			var segment_left := minf(segment_start, segment_end) * timeline_width_ratio
			var segment_width := maxf(1.0, absf(segment_start - segment_end) * timeline_width_ratio)
			if stage_index == selected_wave:
				selected_segment_left = minf(segment_start, segment_end)
				selected_segment_right = maxf(segment_start, segment_end)
	if timeline_progress_bar != null:
		selected_segment_left = clampf(selected_segment_left, 0.0, 158.0)
		selected_segment_right = clampf(selected_segment_right, selected_segment_left, 158.0)
		if is_equal_approx(selected_segment_left, selected_segment_right):
			timeline_progress_bar.texture = null
			return
		timeline_progress_bar.visible = true
		var selected_progress_texture := AtlasTexture.new()
		selected_progress_texture.atlas = FLAG_METER
		selected_progress_texture.region = Rect2(selected_segment_left, 27, selected_segment_right - selected_segment_left, 27)
		timeline_progress_bar.position.x = selected_segment_left * timeline_width_ratio
		timeline_progress_bar.size.x = (selected_segment_right - selected_segment_left) * timeline_width_ratio
		timeline_progress_bar.texture = selected_progress_texture


func _select_stage(stage_index: int) -> void:
	if stage_index < 0 or stage_index >= (level.get("waves", []) as Array).size():
		return
	DraftStore.save_autosave(level)
	_clear_preview_zombies()
	selected_wave = stage_index
	selected_zombie_key = ""
	_refresh_wave()


func _on_timeline_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mouse_position := (event as InputEventMouseMotion).position
		var interval_index := _timeline_interval_at_position(mouse_position)
		if interval_index >= 0:
			var interval_rect := _timeline_interval_rect(interval_index)
			_show_interval_preview(interval_rect.position.x, interval_rect.size.x)
			_set_timeline_hover_flag(-1)
			timeline_stages.tooltip_text = "旗帜前动态阶段：清空可提前推进，否则等待 40～46 秒" \
				if _is_stage_before_flag(interval_index) else "动态阶段：按剩余血量提前推进，25～31 秒自然刷新"
		else:
			_hide_interval_preview()
			var flag_index := _timeline_flag_at_position(mouse_position)
			_set_timeline_hover_flag(flag_index)
			timeline_stages.tooltip_text = "点击编辑旗帜波" if flag_index >= 0 else ""
		return
	if not event is InputEventMouseButton:
		return
	var mouse_button := event as InputEventMouseButton
	if mouse_button.button_index != MOUSE_BUTTON_LEFT or not mouse_button.pressed:
		return
	var interval_index := _timeline_interval_at_position(mouse_button.position)
	var endpoint_ratio := -1.0
	if interval_index < 0 and timeline_mode == TimelineMode.PLACE_FLAG:
		var endpoint_hit := _timeline_endpoint_interval_at_position(mouse_button.position)
		interval_index = int(endpoint_hit.get("stage_index", -1))
		endpoint_ratio = float(endpoint_hit.get("visual_ratio", -1.0))
	if interval_index >= 0:
		var interval_rect := _timeline_interval_rect(interval_index)
		var click_ratio := endpoint_ratio if endpoint_ratio >= 0.0 else clampf((mouse_button.position.x - interval_rect.position.x) / maxf(1.0, interval_rect.size.x), 0.0, 1.0)
		_on_interval_pressed(interval_index, click_ratio)
		timeline_stages.accept_event()
		return
	var flag_index := _timeline_flag_at_position(mouse_button.position)
	if flag_index >= 0 and timeline_mode == TimelineMode.NORMAL:
		_select_stage(flag_index)
		timeline_stages.accept_event()


func _timeline_interval_at_position(local_position: Vector2) -> int:
	## 旗帜头部和进度槽下半部是两条固定交互带；再短的波间也不会被旗帜覆盖。
	if local_position.y < 24.0 or local_position.y > 39.0:
		return -1
	for stage_index in (level.get("waves", []) as Array).size():
		if str(level["waves"][stage_index].get("stageType", "flag")) != "interval":
			continue
		if _timeline_interval_rect(stage_index).has_point(local_position):
			return stage_index
	return -1


func _timeline_interval_rect(stage_index: int) -> Rect2:
	var total_duration := _timeline_total_interval_duration()
	var elapsed_duration := 0.0
	for index in (level.get("waves", []) as Array).size():
		var stage: Dictionary = level["waves"][index]
		if str(stage.get("stageType", "flag")) != "interval":
			continue
		var duration := 1.0
		var segment_start := lerpf(FLAG_CENTER_RIGHT, FLAG_CENTER_LEFT, elapsed_duration / total_duration) * timeline_width_ratio
		elapsed_duration += duration
		var segment_end := lerpf(FLAG_CENTER_RIGHT, FLAG_CENTER_LEFT, elapsed_duration / total_duration) * timeline_width_ratio
		if index == stage_index:
			return Rect2(minf(segment_start, segment_end), 24.0, maxf(1.0, absf(segment_start - segment_end)), 15.0)
	return Rect2()


func _timeline_endpoint_interval_at_position(local_position: Vector2) -> Dictionary:
	## 插旗时终点的旗头区也可点击，不要强制玩家只点黄色槽下半部。
	if local_position.y < 0.0 or local_position.y > timeline_stages.size.y:
		return {}
	var left_x := FLAG_CENTER_LEFT * timeline_width_ratio
	var right_x := FLAG_CENTER_RIGHT * timeline_width_ratio
	if absf(local_position.x - left_x) <= 10.0:
		for stage_index in range((level.get("waves", []) as Array).size() - 1, -1, -1):
			if str(level["waves"][stage_index].get("stageType", "flag")) == "interval":
				return {"stage_index": stage_index, "visual_ratio": 0.0}
	if absf(local_position.x - right_x) <= 10.0:
		for stage_index in (level.get("waves", []) as Array).size():
			if str(level["waves"][stage_index].get("stageType", "flag")) == "interval":
				return {"stage_index": stage_index, "visual_ratio": 1.0}
	return {}


func _timeline_flag_at_position(local_position: Vector2) -> int:
	if local_position.y >= 24.0 and local_position.y <= 39.0:
		return -1
	var total_duration := _timeline_total_interval_duration()
	var elapsed_duration := 0.0
	var nearest_index := -1
	var nearest_distance := 15.0
	for stage_index in (level.get("waves", []) as Array).size():
		var stage: Dictionary = level["waves"][stage_index]
		if str(stage.get("stageType", "flag")) == "interval":
			elapsed_duration += 1.0
			continue
		var flag_x := lerpf(FLAG_CENTER_RIGHT, FLAG_CENTER_LEFT, elapsed_duration / total_duration) * timeline_width_ratio
		var distance := absf(local_position.x - flag_x)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_index = stage_index
	return nearest_index


func _timeline_total_interval_duration() -> float:
	var total_duration := 0.0
	for stage in level.get("waves", []):
		if str((stage as Dictionary).get("stageType", "flag")) == "interval":
			total_duration += 1.0
	return maxf(MIN_SPLIT_INTERVAL_DURATION, total_duration)


func _set_timeline_hover_flag(stage_index: int) -> void:
	if stage_index == timeline_hovered_flag_index:
		return
	if timeline_flag_visuals.has(timeline_hovered_flag_index):
		var previous_flag: TextureRect = timeline_flag_visuals[timeline_hovered_flag_index] as TextureRect
		previous_flag.position.y = -3.0 if timeline_hovered_flag_index == selected_wave else 7.0
	timeline_hovered_flag_index = stage_index
	if timeline_flag_visuals.has(stage_index):
		var hovered_flag: TextureRect = timeline_flag_visuals[stage_index] as TextureRect
		hovered_flag.position.y = -3.0


func _show_interval_preview(segment_left: float, segment_width: float) -> void:
	if timeline_hover_bar == null:
		return
	var preview_texture := AtlasTexture.new()
	preview_texture.atlas = FLAG_METER
	preview_texture.region = Rect2(segment_left / timeline_width_ratio, 27, segment_width / timeline_width_ratio, 27)
	timeline_hover_bar.position.x = segment_left
	timeline_hover_bar.size.x = segment_width
	timeline_hover_bar.texture = preview_texture
	timeline_hover_bar.visible = true


func _hide_interval_preview() -> void:
	if timeline_hover_bar != null:
		timeline_hover_bar.visible = false


func _on_interval_pressed(stage_index: int, click_ratio: float) -> void:
	if timeline_mode == TimelineMode.PLACE_FLAG:
		_insert_flag_in_interval(stage_index, click_ratio)
		return
	if selected_wave != stage_index:
		_select_stage(stage_index)
		status_label.text = "已选中旗帜前动态阶段：至少 6 秒且本阶段僵尸清空后提前推进，否则等待 40～46 秒。" \
			if _is_stage_before_flag(stage_index) else "已选中动态阶段：至少 6 秒后按本阶段剩余血量决定是否提前推进。"
		return
	_select_stage(stage_index)
	status_label.text = "旗帜前阶段需清空本阶段僵尸才会提前推进，否则等待 40～46 秒。" \
		if _is_stage_before_flag(stage_index) else "普通动态阶段 25～31 秒自然推进，也可在最低 6 秒后按血量提前推进。"


func _is_stage_before_flag(stage_index: int) -> bool:
	var stages: Array = level.get("waves", [])
	return stage_index >= 0 and stage_index + 1 < stages.size() \
		and str((stages[stage_index + 1] as Dictionary).get("stageType", "flag")) == "flag"


func _begin_flag_placement() -> void:
	if _count_stage_type("interval") == 0:
		_create_next_wave()
		status_label.text = "已建立动态波间并在末端插入旗帜。"
		return
	if timeline_mode == TimelineMode.PLACE_FLAG:
		_end_timeline_mode()
		status_label.text = "已取消插旗。"
	else:
		_end_timeline_mode()
		timeline_mode = TimelineMode.PLACE_FLAG
		_set_flag_cursor()
		status_label.text = "插旗模式：请在右下角任意波间段上点击插入，再点“＋旗帜”取消。"
	_refresh_timeline()


func _reset_timeline() -> void:
	_end_timeline_mode()
	level["waves"] = [
		Logic.make_wave("interval_1", "第 1 个波间间隔", 0.0, DEFAULT_INTERVAL_DURATION, [], "interval"),
		Logic.make_wave("wave_1", "第 1 波", 0.0, DEFAULT_FLAG_DURATION, [], "flag"),
		Logic.make_wave("interval_2", "第 2 个波间间隔", 0.0, DEFAULT_INTERVAL_DURATION, [], "interval"),
		Logic.make_wave("wave_2", "第 2 波", 0.0, DEFAULT_FLAG_DURATION, [], "flag"),
	]
	selected_wave = 0
	selected_zombie_key = ""
	_clear_preview_zombies()
	_recalculate_stage_times()
	_snapshot()
	DraftStore.save_autosave(level)
	_refresh_wave()
	status_label.text = "已重置为两个动态波间和两面旗帜；可用“撤销”恢复。"


func _set_flag_cursor() -> void:
	if not is_instance_valid(flag_cursor_preview):
		var flag_cursor_texture := AtlasTexture.new()
		flag_cursor_texture.atlas = FLAG_PARTS
		flag_cursor_texture.region = Rect2(50, 1, 25, 25)
		flag_cursor_preview = TextureRect.new()
		flag_cursor_preview.size = Vector2(25, 25)
		flag_cursor_preview.texture = flag_cursor_texture
		flag_cursor_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flag_cursor_preview.z_index = 1000
		add_child(flag_cursor_preview)
	flag_cursor_preview.visible = true


func _end_timeline_mode() -> void:
	timeline_mode = TimelineMode.NORMAL
	if is_instance_valid(flag_cursor_preview):
		flag_cursor_preview.visible = false
	_hide_interval_preview()


func _insert_flag_in_interval(stage_index: int, visual_click_ratio: float) -> void:
	var stages: Array = level.get("waves", [])
	if stage_index < 0 or stage_index >= stages.size():
		return
	var interval: Dictionary = stages[stage_index]
	if str(interval.get("stageType", "flag")) != "interval":
		return
	## 时间轴是从右向左推进，而 Rect 内的点击比例是从左向右。
	var progress_ratio := 1.0 - clampf(visual_click_ratio, 0.0, 1.0)
	var insert_at := stage_index + 1
	var split_interval := progress_ratio > 0.001 and progress_ratio < 0.999
	if progress_ratio <= 0.001:
		insert_at = stage_index
		if stage_index > 0 and str((stages[stage_index - 1] as Dictionary).get("stageType", "interval")) == "flag":
			status_label.text = "该端点已有旗帜。"
			return
	elif progress_ratio >= 0.999 and stage_index + 1 < stages.size() \
	and str((stages[stage_index + 1] as Dictionary).get("stageType", "interval")) == "flag":
		status_label.text = "该端点已有旗帜。"
		return

	var original_duration := maxf(2.0, float(interval.get("duration", DEFAULT_INTERVAL_DURATION)))
	var flag_number := _count_stage_type("flag") + 1
	var flag_id := Logic.make_unique_id("wave", _all_ids())
	var inserted_flag := Logic.make_wave(flag_id, "第 %d 波" % flag_number, 0.0, DEFAULT_FLAG_DURATION, [], "flag")
	if split_interval:
		interval["duration"] = maxf(MIN_SPLIT_INTERVAL_DURATION, original_duration * progress_ratio)
		var interval_id := Logic.make_unique_id("interval", _all_ids())
		var following_duration := maxf(MIN_SPLIT_INTERVAL_DURATION, original_duration * (1.0 - progress_ratio))
		var inserted_interval := Logic.make_wave(interval_id, "新波间", 0.0, following_duration, [], "interval")
		stages.insert(stage_index + 1, inserted_flag)
		stages.insert(stage_index + 2, inserted_interval)
		selected_wave = stage_index + 1
	else:
		interval["duration"] = original_duration
		stages.insert(insert_at, inserted_flag)
		selected_wave = insert_at
	selected_zombie_key = ""
	_recalculate_stage_times()
	_end_timeline_mode()
	_snapshot()
	DraftStore.save_autosave(level)
	_refresh_wave()
	status_label.text = "已在左侧终点插入旗帜。" if progress_ratio >= 0.999 else ("已在右侧起点插入旗帜。" if progress_ratio <= 0.001 else "已在目标动态波间插入一面旗帜，并拆分前后波间。")


func _unhandled_input(event: InputEvent) -> void:
	if timeline_mode != TimelineMode.NORMAL and event.is_action_pressed("ui_cancel"):
		_end_timeline_mode()
		_refresh_timeline()
		status_label.text = "已取消时间轴操作。"
		get_viewport().set_input_as_handled()


func _delete_current_stage() -> void:
	var stages: Array = level.get("waves", [])
	if stages.is_empty():
		return
	var stage: Dictionary = stages[selected_wave]
	var is_flag := str(stage.get("stageType", "flag")) == "flag"
	if is_flag and _count_stage_type("flag") <= 1:
		status_label.text = "至少要保留一个旗帜波"
		return
	if not is_flag and _is_interval_between_flags(selected_wave):
		status_label.text = "两面旗帜之间必须保留一个波间，不能单独删除"
		return
	if is_flag and selected_wave > 0 and selected_wave + 1 < stages.size():
		var previous: Dictionary = stages[selected_wave - 1]
		var following: Dictionary = stages[selected_wave + 1]
		if str(previous.get("stageType", "flag")) == "interval" and str(following.get("stageType", "flag")) == "interval":
			previous["duration"] = float(previous.get("duration", DEFAULT_INTERVAL_DURATION)) + float(following.get("duration", DEFAULT_INTERVAL_DURATION))
			(previous.get("spawnGroups", []) as Array).append_array((following.get("spawnGroups", []) as Array).duplicate(true))
			stages.remove_at(selected_wave + 1)
	stages.remove_at(selected_wave)
	selected_wave = clampi(selected_wave, 0, maxi(0, stages.size() - 1))
	selected_zombie_key = ""
	_recalculate_stage_times()
	_snapshot()
	DraftStore.save_autosave(level)
	_refresh_wave()
	status_label.text = "已删除当前%s，可用“撤销”恢复。" % ("旗帜波" if is_flag else "波间阶段")


func _is_interval_between_flags(stage_index: int) -> bool:
	var stages: Array = level.get("waves", [])
	if stage_index <= 0 or stage_index + 1 >= stages.size():
		return false
	return str((stages[stage_index - 1] as Dictionary).get("stageType", "flag")) == "flag" \
		and str((stages[stage_index + 1] as Dictionary).get("stageType", "flag")) == "flag"


func _open_delete_stage_dialog() -> void:
	var stages: Array = level.get("waves", [])
	if stages.is_empty() or selected_wave < 0 or selected_wave >= stages.size():
		status_label.text = "当前没有可删除的阶段"
		return
	var stage: Dictionary = stages[selected_wave]
	var is_flag := str(stage.get("stageType", "flag")) == "flag"
	if is_flag and _count_stage_type("flag") <= 1:
		status_label.text = "至少要保留一个旗帜波"
		return
	if not is_flag and _is_interval_between_flags(selected_wave):
		status_label.text = "两面旗帜之间必须严格保留一个波间，不能单独删除"
		return
	_close_quantity_dialog()
	quantity_dialog_layer = Control.new()
	quantity_dialog_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	quantity_dialog_layer.z_index = 500
	add_child(quantity_dialog_layer)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.5)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	quantity_dialog_layer.add_child(shade)
	var dialog := TextureRect.new()
	dialog.position = Vector2(327, 138)
	dialog.size = Vector2(412, 324)
	dialog.texture = DIALOG_BACKGROUND
	dialog.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dialog.stretch_mode = TextureRect.STRETCH_SCALE
	dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	quantity_dialog_layer.add_child(dialog)
	var title := _paper_label("确认删除", Vector2(48, 65), Vector2(316, 44), 27, Color("e7e4d1"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", Color("25263b"))
	title.add_theme_constant_override("outline_size", 4)
	dialog.add_child(title)
	var stage_type_text := "旗帜波" if is_flag else "波间阶段"
	var hint := _paper_label("确定删除当前%s吗？\n删除后可以使用“撤销”恢复。" % stage_type_text, Vector2(48, 120), Vector2(316, 82), 19, Color("e9d28a"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog.add_child(hint)
	var confirm := _texture_button("确定删除", Vector2(56, 224), Vector2(142, 42), DIALOG_BUTTON, DIALOG_BUTTON, func():
		_close_quantity_dialog()
		_delete_current_stage()
	, 17)
	dialog.add_child(confirm)
	var cancel := _texture_button("取消", Vector2(214, 224), Vector2(142, 42), DIALOG_BUTTON, DIALOG_BUTTON, _close_quantity_dialog, 17)
	dialog.add_child(cancel)


func _make_zombie_card(zombie_type: int) -> Control:
	var holder := Control.new()
	## 原始卡片为 50×70；当前缩放 1.235 是上一版 0.95 的 130%。
	holder.custom_minimum_size = Vector2(62, 87)
	var prefab: Card = zombie_card_prefabs.get(zombie_type)
	if prefab == null:
		return holder
	var card := prefab.duplicate() as Card
	card.position = Vector2.ZERO
	card.scale = Vector2.ONE * 1.235
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


func _make_reward_card(entry: Dictionary) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(62, 87)
	var type_id := int(entry["id"])
	var is_plant := bool(entry["is_plant"])
	var prefab: Card = plant_card_prefabs.get(type_id) if is_plant else zombie_card_prefabs.get(type_id)
	if prefab == null:
		return holder
	var card := prefab.duplicate() as Card
	card.position = Vector2.ZERO
	card.scale = Vector2.ONE * 1.235
	card.is_imitater = false
	card.set_process(false)
	var pool_key := "plantCardPool" if is_plant else "zombieCardPool"
	var selected_pool: Array = level["chessboardConfig"].get(pool_key, [])
	var selected := selected_pool.has(type_id)
	card.modulate = Color.WHITE if selected else Color(0.55, 0.55, 0.55, 0.72)
	card.tooltip_text = "%s奖励%s" % ["移除" if selected else "加入", "植物卡槽" if is_plant else "友军僵尸卡槽"]
	_force_font_recursive(card)
	var button := card.get_node_or_null("Button") as Button
	if button != null:
		for connection in button.pressed.get_connections():
			button.pressed.disconnect(connection.callable)
		button.pressed.connect(_toggle_reward_card.bind(type_id, is_plant))
	holder.add_child(card)
	return holder


func _toggle_reward_card(type_id: int, is_plant: bool) -> void:
	var pool_key := "plantCardPool" if is_plant else "zombieCardPool"
	var pool: Array = level["chessboardConfig"].get(pool_key, [])
	if pool.has(type_id):
		pool.erase(type_id)
	else:
		pool.append(type_id)
	level["chessboardConfig"][pool_key] = pool
	_changed("奖励植物 %d 张" % (level["chessboardConfig"]["plantCardPool"] as Array).size())
	_refresh_card_page()


func _toggle_reward_catalog() -> void:
	catalog_mode = CatalogMode.REWARD_CARDS if catalog_mode == CatalogMode.SPAWN_ZOMBIES else CatalogMode.SPAWN_ZOMBIES
	current_card_page = 0
	var show_rewards := catalog_mode == CatalogMode.REWARD_CARDS
	stage_heading.text = "奖励原版植物卡" if show_rewards else "旗帜波僵尸"
	var reward_button_label := reward_mode_button.get_child(0) as Label
	if reward_button_label != null:
		reward_button_label.text = "返回刷怪" if show_rewards else "奖励卡槽"
	wave_title.visible = not show_rewards
	wave_summary.visible = not show_rewards
	road_title.visible = not show_rewards
	road_hint.visible = not show_rewards
	preview_root.visible = not show_rewards
	## 奖励池编辑时把草坪主体移入右侧可视区，退出后恢复道路预览视角。
	var target_x := background_normal_x + 334.0 if show_rewards else background_normal_x
	create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT).tween_property(background_sprite, "position:x", target_x, 0.3)
	status_label.text = "点击原版植物卡加入或移出奖励卡槽；亮色为已选择" if show_rewards else "点击卡片，设置本阶段出场数量"
	_refresh_card_page()


func _change_card_page(offset: int) -> void:
	var item_count := reward_card_order.size() if catalog_mode == CatalogMode.REWARD_CARDS else zombie_card_order.size()
	var page_count := maxi(1, ceili(float(item_count) / CARDS_PER_PAGE))
	current_card_page = posmod(current_card_page + offset, page_count)
	_refresh_card_page()


func _refresh_card_page() -> void:
	if card_grid == null:
		return
	_clear(card_grid)
	var item_count := reward_card_order.size() if catalog_mode == CatalogMode.REWARD_CARDS else zombie_card_order.size()
	var page_count := maxi(1, ceili(float(item_count) / CARDS_PER_PAGE))
	current_card_page = clampi(current_card_page, 0, page_count - 1)
	var begin := current_card_page * CARDS_PER_PAGE
	var end := mini(begin + CARDS_PER_PAGE, item_count)
	for index in range(begin, end):
		if catalog_mode == CatalogMode.REWARD_CARDS:
			card_grid.add_child(_make_reward_card(reward_card_order[index]))
		else:
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
	if catalog_mode == CatalogMode.REWARD_CARDS:
		stage_heading.text = "奖励原版植物卡"
		_refresh_timeline()
		return
	stage_heading.text = "旗帜波僵尸" if is_flag else "波间阶段僵尸"
	road_title.text = (("旗帜第 %d 波" if is_flag else "波间间隔 %d") % stage_number) + " · 道路预览"
	road_hint.text = "这个阶段还没有僵尸\n请点击左侧卡片"
	wave_summary.text = "%s　共 %d 只" % ["旗帜前动态推进" if not is_flag else "旗帜波动态推进", _wave_total_count(wave)]
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
			preview_zombie_keys[zombie.get_instance_id()] = zombie_key
			index += 1
		if index >= PREVIEW_MAX_ZOMBIES:
			break


func _on_preview_hit_layer_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var hovered_zombie := _preview_zombie_at((event as InputEventMouseMotion).position)
		preview_hit_layer.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hovered_zombie != null else Control.CURSOR_ARROW
		preview_hit_layer.tooltip_text = "" if hovered_zombie == null else "点击删除一个%s" % _zombie_name(str(preview_zombie_keys.get(hovered_zombie.get_instance_id(), "500")))
		return
	if not event is InputEventMouseButton:
		return
	var mouse_button := event as InputEventMouseButton
	if mouse_button.button_index != MOUSE_BUTTON_LEFT or not mouse_button.pressed:
		return
	var clicked_zombie := _preview_zombie_at(mouse_button.position)
	if clicked_zombie == null:
		return
	var zombie_key := str(preview_zombie_keys.get(clicked_zombie.get_instance_id(), ""))
	if zombie_key.is_empty():
		return
	_remove_zombie(zombie_key, clicked_zombie)
	preview_hit_layer.accept_event()


func _preview_zombie_at(local_position: Vector2) -> Node2D:
	var canvas_position: Vector2 = preview_hit_layer.get_global_transform() * local_position
	var hit_zombie: Node2D
	for zombie in preview_zombies:
		if not is_instance_valid(zombie) or not _is_visible_zombie_pixel(zombie, canvas_position):
			continue
		if hit_zombie == null or zombie.z_index > hit_zombie.z_index \
			or zombie.z_index == hit_zombie.z_index and zombie.global_position.y > hit_zombie.global_position.y:
			hit_zombie = zombie
	return hit_zombie


func _is_visible_zombie_pixel(root: Node, canvas_position: Vector2) -> bool:
	if root is CanvasItem and not (root as CanvasItem).is_visible_in_tree():
		return false
	if root is Sprite2D:
		var sprite := root as Sprite2D
		var sprite_name := str(sprite.name).to_lower()
		if sprite.texture != null and not sprite_name.contains("shadow") and not sprite_name.contains("ground"):
			var sprite_position: Vector2 = sprite.to_local(canvas_position)
			if sprite.get_rect().has_point(sprite_position) and sprite.is_pixel_opaque(sprite_position):
				return true
	for child in root.get_children():
		if _is_visible_zombie_pixel(child, canvas_position):
			return true
	return false


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


func _remove_zombie(zombie_key: String, clicked_preview: Node2D = null) -> void:
	var wave: Dictionary = level["waves"][selected_wave]
	var group := _find_group(wave, zombie_key)
	if group.is_empty():
		return
	group["count"] = int(group["count"]) - 1
	if int(group["count"]) <= 0:
		wave["spawnGroups"].erase(group)
		if selected_zombie_key == zombie_key:
			selected_zombie_key = ""
	if is_instance_valid(clicked_preview):
		## 道路点击删除必须是所见即所得：只移除命中的这个实例，
		## 不重建整个随机布局，否则视觉上会像是随机删除了另一只。
		preview_zombie_keys.erase(clicked_preview.get_instance_id())
		preview_zombies.erase(clicked_preview)
		if clicked_preview.get_parent() != null:
			clicked_preview.get_parent().remove_child(clicked_preview)
		clicked_preview.queue_free()
		_update_road_labels_after_exact_delete(wave)
		_changed("已删除点中的%s" % _zombie_name(zombie_key))
		_refresh_timeline()
		preview_hit_layer.tooltip_text = ""
		preview_hit_layer.mouse_default_cursor_shape = Control.CURSOR_ARROW
		return
	_changed("已减少%s数量" % _zombie_name(zombie_key))
	_refresh_wave()


func _update_road_labels_after_exact_delete(wave: Dictionary) -> void:
	var total := _wave_total_count(wave)
	var is_flag := str(wave.get("stageType", "flag")) == "flag"
	road_title.text = "当前阶段 · 马路预览 · 共 %d 只" % total
	wave_summary.text = "%s　共 %d 只" % ["旗帜前动态推进" if not is_flag else "旗帜波动态推进", total]
	road_hint.visible = total == 0 or total > PREVIEW_MAX_ZOMBIES
	if total == 0:
		road_hint.text = "这个阶段还没有僵尸\n请点击左侧卡片"
	elif total > PREVIEW_MAX_ZOMBIES:
		road_hint.text = "当前阶段共 %d 只\n当前展示 %d 只" % [total, preview_zombies.size()]


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
	waves.append(Logic.make_wave(interval_id, "第 %d 个波间间隔" % interval_number, start_time, DEFAULT_INTERVAL_DURATION, [], "interval"))
	var wave_id := Logic.make_unique_id("wave", _all_ids())
	var flag_number := _count_stage_type("flag") + 1
	waves.append(Logic.make_wave(wave_id, "第 %d 波" % flag_number, start_time + DEFAULT_INTERVAL_DURATION, DEFAULT_FLAG_DURATION, [], "flag"))
	DraftStore.save_autosave(level)
	_clear_preview_zombies()
	selected_wave = waves.size() - 1
	selected_zombie_key = ""
	_snapshot()
	_refresh_wave()
	status_label.text = "已新增波间阶段和第 %d 个旗帜波；可在下方进度条分别选择编辑。" % flag_number


func _open_level_settings() -> void:
	_close_quantity_dialog()
	quantity_dialog_layer = Control.new()
	quantity_dialog_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	quantity_dialog_layer.z_index = 500
	add_child(quantity_dialog_layer)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.5)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	quantity_dialog_layer.add_child(shade)
	var dialog := TextureRect.new()
	dialog.position = Vector2(223, 24)
	dialog.size = Vector2(620, 548)
	dialog.texture = DIALOG_BACKGROUND
	dialog.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dialog.stretch_mode = TextureRect.STRETCH_SCALE
	dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	quantity_dialog_layer.add_child(dialog)
	var title := _paper_label("关卡基础设置", Vector2(90, 45), Vector2(440, 48), 29, Color("f3e7ba"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", Color("25263b"))
	title.add_theme_constant_override("outline_size", 4)
	dialog.add_child(title)
	var name_input := _settings_line(dialog, "关卡名称", Vector2(76, 108), str(level["name"]))
	var id_input := _settings_line(dialog, "草稿编号", Vector2(322, 108), str(level["id"]))
	var sun := _settings_spin(dialog, "开局阳光", Vector2(76, 180), 0, 9999, int(level["playerConfig"]["initialSun"]), 25)
	var sun_speed := _settings_spin(dialog, "天降阳光速度倍率", Vector2(322, 180), 0.1, 10.0, float(level["playerConfig"].get("sunDropSpeed", 1.0)), 0.1)
	var cooldown := _settings_spin(dialog, "冷却时长倍率", Vector2(76, 252), 0.0, 10.0, float(level["playerConfig"].get("cooldownMultiplier", 1.0)), 0.05)
	var seed := _settings_spin(dialog, "随机种子", Vector2(322, 252), 1, 2147483647, int(level["randomSeed"]), 1)
	var reward_plant_picker: OptionButton
	var chessboard: Dictionary = level.get("chessboardConfig", {})
	var mine_count: SpinBox
	var plant_probability: SpinBox
	var zombie_card_probability: SpinBox
	var enemy_probability: SpinBox
	if str(level.get("workshopMode", "normal")) == "chessboard":
		var chess_title := _paper_label("棋盘格专属", Vector2(76, 322), Vector2(468, 30), 20, Color("e9d28a"))
		chess_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dialog.add_child(chess_title)
		mine_count = _settings_spin(dialog, "地雷数量上限", Vector2(76, 360), 0, 45, int(chessboard.get("mineCount", 8)), 1)
		plant_probability = _settings_spin(dialog, "植物卡概率", Vector2(322, 360), 0.0, 1.0, float(chessboard.get("plantCardProbability", 0.25)), 0.01)
		enemy_probability = _settings_spin(dialog, "敌对僵尸概率", Vector2(322, 360), 0.0, 1.0, float(chessboard.get("enemyZombieProbability", 0.30)), 0.01)
	else:
		reward_plant_picker = _settings_reward_picker(dialog, Vector2(322, 322), int(level.get("rewardPlant", -1)))
	var save_callback := func():
		_save_level_settings(name_input, id_input, sun, sun_speed, cooldown, seed, reward_plant_picker, chessboard, mine_count, plant_probability, zombie_card_probability, enemy_probability)
	dialog.add_child(_texture_button("保存设置", Vector2(205, 487), Vector2(210, 42), DIALOG_BUTTON, DIALOG_BUTTON, save_callback, 18))
	dialog.add_child(_texture_button("取消", Vector2(265, 454 if str(level.get("workshopMode", "normal")) != "chessboard" else 522), Vector2(90, 26), ALMANAC_CLOSE_BUTTON, ALMANAC_CLOSE_BUTTON_HOVER, _close_quantity_dialog, 14))


func _save_level_settings(name_input: LineEdit, id_input: LineEdit, sun: SpinBox, sun_speed: SpinBox, cooldown: SpinBox, seed: SpinBox, reward_plant_picker: OptionButton, chessboard: Dictionary, mine_count: SpinBox, plant_probability: SpinBox, zombie_card_probability: SpinBox, enemy_probability: SpinBox) -> void:
	var level_name := name_input.text.strip_edges()
	if level_name.is_empty():
		status_label.text = "设置失败：关卡名称不能为空"
		return
	if str(level.get("workshopMode", "normal")) == "chessboard":
		var probability_sum := float(plant_probability.value + enemy_probability.value)
		if probability_sum > 1.0:
			status_label.text = "设置失败：两项概率总和不能超过 1，剩余概率用于生成地雷"
			return
		chessboard["mineCount"] = int(mine_count.value)
		chessboard["plantCardProbability"] = float(plant_probability.value)
		chessboard["zombieCardProbability"] = 0.0
		chessboard["enemyZombieProbability"] = float(enemy_probability.value)
		level["chessboardConfig"] = chessboard
	elif is_instance_valid(reward_plant_picker):
		level["rewardPlant"] = int(reward_plant_picker.get_item_metadata(reward_plant_picker.selected))
	level["name"] = level_name
	level["id"] = id_input.text.strip_edges()
	level["playerConfig"]["initialSun"] = int(sun.value)
	level["playerConfig"]["sunDropSpeed"] = float(sun_speed.value)
	level["playerConfig"]["cooldownMultiplier"] = float(cooldown.value)
	level["randomSeed"] = int(seed.value)
	_close_quantity_dialog()
	_changed("关卡设置已保存")


func _settings_line(parent: Control, label_text: String, pos: Vector2, value: String) -> LineEdit:
	var label := _paper_label(label_text, pos, Vector2(210, 25), 16, Color("e9d28a"))
	parent.add_child(label)
	var input := LineEdit.new()
	input.position = pos + Vector2(0, 27)
	input.size = Vector2(210, 34)
	input.text = value
	input.add_theme_font_override("font", WORKSHOP_FONT)
	input.add_theme_font_size_override("font_size", 16)
	input.add_theme_color_override("font_color", Color("f5edcf"))
	input.add_theme_color_override("caret_color", Color("fff2a1"))
	parent.add_child(input)
	return input


func _settings_reward_picker(parent: Control, pos: Vector2, selected_type: int) -> OptionButton:
	var label := _paper_label("通关掉落新卡", pos, Vector2(210, 25), 16, Color("e9d28a"))
	parent.add_child(label)
	var picker := OptionButton.new()
	picker.position = pos + Vector2(0, 27)
	picker.size = Vector2(210, 34)
	picker.add_theme_font_override("font", WORKSHOP_FONT)
	picker.add_item("无卡牌掉落")
	picker.set_item_metadata(0, -1)
	var plant_types: Array = AllCards.all_plant_card_prefabs.keys()
	plant_types.sort()
	for value in plant_types:
		var plant_type := int(value)
		if plant_type <= 0 or plant_type >= 1000 or not CharacterRegistry.PlantInfo.has(plant_type):
			continue
		var plant_name := str(Global.character_registry.get_plant_info(
			plant_type as CharacterRegistry.PlantType,
			CharacterRegistry.PlantInfoAttribute.PlantName
		))
		picker.add_item("%s（%d）" % [plant_name, plant_type])
		var item_index := picker.item_count - 1
		picker.set_item_metadata(item_index, plant_type)
		if plant_type == selected_type:
			picker.select(item_index)
	parent.add_child(picker)
	return picker


func _settings_spin(parent: Control, label_text: String, pos: Vector2, min_value: float, max_value: float, value: float, step: float) -> SpinBox:
	var label := _paper_label(label_text, pos, Vector2(210, 25), 16, Color("e9d28a"))
	parent.add_child(label)
	var input := SpinBox.new()
	input.position = pos + Vector2(0, 27)
	input.size = Vector2(210, 34)
	input.min_value = min_value
	input.max_value = max_value
	input.value = value
	input.step = step
	input.add_theme_font_override("font", WORKSHOP_FONT)
	input.add_theme_font_size_override("font_size", 16)
	input.add_theme_color_override("font_color", Color("f5edcf"))
	parent.add_child(input)
	return input


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
	## 点击范围贴合旗帜图形，避免透明的 40px 宽按钮吞掉相邻波间。
	button.size = Vector2(29, 42)
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
	flag.name = "Flag"
	flag.position = Vector2(3.5, -3 if selected else 7)
	flag.size = Vector2(25, 25)
	flag.texture = flag_texture
	flag.modulate = Color("fff2a1") if selected else Color.WHITE
	flag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(flag)
	button.mouse_entered.connect(func():
		var tween := button.create_tween()
		tween.tween_property(flag, "position:y", -3.0, 0.12)
	)
	button.mouse_exited.connect(func():
		var tween := button.create_tween()
		tween.tween_property(flag, "position:y", -3.0 if selected else 7.0, 0.12)
	)
	var number := _paper_label(str(flag_number), Vector2(0, 27), Vector2(29, 15), 11, Color("5b2c0b"))
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
	reward_card_order.clear()
	plant_card_prefabs.clear()
	var all_cards := get_node_or_null("/root/AllCards") as AllCardsClass
	if all_cards == null:
		return
	zombie_card_prefabs = all_cards.all_zombie_card_prefabs
	for zombie_type in zombie_card_prefabs.keys():
		var zombie_id := int(zombie_type)
		if Global.level_workshop_edit_mode == "normal" and zombie_id > 0 \
		and (zombie_id < 500 or AdventurePresets.NORMAL_SUPPORT_ZOMBIES.has(zombie_id)):
			zombie_card_order.append(zombie_id)
		elif Global.level_workshop_edit_mode == "chessboard" and zombie_id >= 500 and zombie_id < 1000:
			zombie_card_order.append(zombie_id)
	plant_card_prefabs = all_cards.all_plant_card_prefabs
	if Global.level_workshop_edit_mode == "chessboard":
		for plant_type in plant_card_prefabs.keys():
			var plant_id := int(plant_type)
			if plant_id >= 500 and plant_id < 1000:
				reward_card_order.append({"id": plant_id, "is_plant": true})
	zombie_card_order.sort_custom(func(left, right):
		return int(all_cards.zombie_card_ids.get(left, 999999)) < int(all_cards.zombie_card_ids.get(right, 999999))
	)
	reward_card_order.sort_custom(func(left: Dictionary, right: Dictionary):
		if bool(left["is_plant"]) != bool(right["is_plant"]):
			return bool(left["is_plant"])
		return int(left["id"]) < int(right["id"])
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
	_normalize_timeline_structure()
	var cursor := 0.0
	for stage in level.get("waves", []):
		stage["startTime"] = cursor
		cursor += maxf(1.0, float(stage.get("duration", 1.0)))


func _normalize_timeline_structure() -> void:
	var stages: Array = level.get("waves", [])
	var index := 0
	while index + 1 < stages.size():
		var current: Dictionary = stages[index]
		var following: Dictionary = stages[index + 1]
		var current_type := str(current.get("stageType", "flag"))
		var following_type := str(following.get("stageType", "flag"))
		## 连续普通波是正式关卡的独立波次，不能合并；否则各波从 0 秒同时刷怪，
		## 进度条也会丢失大量普通波。只修复不合法的“旗帜紧贴旗帜”结构。
		if current_type == "flag" and following_type == "flag":
			var interval_id := Logic.make_unique_id("interval", _all_ids())
			stages.insert(index + 1, Logic.make_wave(interval_id, "旗帜间隔", 0.0, DEFAULT_INTERVAL_DURATION, [], "interval"))
			index += 2
			continue
		index += 1


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
	_recalculate_stage_times()
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
	_recalculate_stage_times()
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
	_end_timeline_mode()
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
	preview_zombie_keys.clear()


func _clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _back_to_menu() -> void:
	_end_timeline_mode()
	DraftStore.save_autosave(level)
	_clear_preview_zombies()
	var global := get_node("/root/Global")
	global.developer_level_adjustments_active = false
	global.return_to_developer_mode = true
	get_tree().change_scene_to_file("res://scenes/main/01StartMenu.tscn")
