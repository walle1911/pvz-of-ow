extends Control
class_name LevelWorkshop

const Logic := preload("res://addons/pvz_level_editor/level_editor_logic.gd")
const DraftStore := preload("res://scripts/resources/level/level_draft_store.gd")
const CustomRuntime := preload("res://scripts/resources/level/level_custom_runtime.gd")
const AdventurePresets := preload("res://scripts/resources/level/adventure_level_presets.gd")
const FormalLevelStore := preload("res://scripts/resources/level/adventure_level_store.gd")
const FRONT_LAWN := preload("res://assets/image/background/background1.jpg")
const NIGHT_LAWN := preload("res://assets/image/background/background2.jpg")
const POOL_LAWN := preload("res://assets/image/background/background3.jpg")
const FOG_LAWN := preload("res://assets/image/background/background4.jpg")
const ROOF_LAWN := preload("res://assets/image/background/background5.jpg")
const ALMANAC_BACKGROUND := preload("res://assets/image/Almanac/Almanac_ZombieBack.jpg")
const PLANT_ALMANAC_BACKGROUND := preload("res://assets/image/ui/ui_card/all_card/SeedChooser_AlmanacBackground.png")
const ALMANAC_CLOSE_BUTTON := preload("res://assets/image/Almanac/Almanac_CloseButton.png")
const ALMANAC_CLOSE_BUTTON_HOVER := preload("res://assets/image/Almanac/Almanac_CloseButtonHighlight.png")
const DIALOG_BACKGROUND := preload("res://assets/image/ui/ui_main_game_menu/option_dialog.png")
const DIALOG_BUTTON := preload("res://assets/image/ui/ui_main_game_menu/btn_dialog_back_2.png")
const CHECKBOX_OFF := preload("res://assets/image/ui/ui_main_game_menu/options_checkbox0.png")
const CHECKBOX_ON := preload("res://assets/image/ui/ui_main_game_menu/options_checkbox1.png")
const PAGE_BUTTON := preload("res://assets/image/ui/ui_level/SeedChooser_Button2.png")
const PAGE_BUTTON_HOVER := preload("res://assets/image/ui/ui_level/SeedChooser_Button2_Glow.png")
const SEED_PACKET_GLOW := preload("res://assets/image/particles/SeedPacketGlow.png")
const LEVEL_NAVIGATION_ARROW := preload("res://assets/image/garden/Zen_NextGarden.png")
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
const SIMPLE_MAP_TYPES := ["front_lawn", "night_lawn", "pool", "fog", "roof"]
const SIMPLE_MAP_NAMES := ["白天草坪", "夜晚草坪", "泳池", "雾夜", "屋顶"]
const SIMPLE_BASE_ZOMBIE_CANDIDATES := [
	CharacterRegistry.ZombieType.Z000NormTalon,
	CharacterRegistry.ZombieType.Z500Norm,
]
const SIMPLE_FLAG_ZOMBIE_CANDIDATES := [
	CharacterRegistry.ZombieType.Z001FlagTalon,
	CharacterRegistry.ZombieType.Z501Flag,
]
const UNSELECTED_CARD_MODULATE := Color(0.55, 0.55, 0.55, 0.72)
const ACTIVE_SOURCE_BUTTON_MODULATE := Color(0.67, 0.62, 0.56, 1.0)
const ACTIVE_SOURCE_BUTTON_OFFSET_Y := 4.0
const CARD_CONTEXT_EDIT_GLOBAL := 0

enum TimelineMode { NORMAL, PLACE_FLAG }
enum CatalogMode { SPAWN_ZOMBIES, REWARD_CARDS }
enum EditorComplexity { SIMPLE, ADVANCED }

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
var stage_heading_editor: LineEdit
var stage_heading_edit_original := ""
var previous_formal_level_button: Button
var next_formal_level_button: Button
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
var cover_dialog_layer: Control
var card_page_label: Label
var current_card_page := 0
var timeline_mode := TimelineMode.NORMAL
var undo_timeline_button: TextureButton
var add_flag_button: TextureButton
var reset_timeline_button: TextureButton
var delete_timeline_button: TextureButton
var clear_cards_button: TextureButton
var flag_cursor_preview: TextureRect
var timeline_flag_visuals: Dictionary = {}
var timeline_hovered_flag_index := -1
var catalog_mode := CatalogMode.SPAWN_ZOMBIES
var reward_card_order: Array[Dictionary] = []
var plant_card_prefabs: Dictionary = {}
var background_sprite: Sprite2D
var drawer_paper: TextureRect
var reward_mode_button: TextureButton
var background_normal_x := -334.0
var formal_preset_id := ""
## 保存分支依据编辑来源判断：空字符串表示新建/自动恢复，另外两种表示从载入入口打开。
var loaded_source_kind := ""
var loaded_draft_path := ""
var locked_available_plant_types: Array[int] = []
var new_level_button: TextureButton
var edit_level_button: TextureButton
var workshop_menu_dialog: MainGameMenuOptionDialog
var workshop_menu_fallback_dialog: Dialog
var workshop_menu_canvas_layer: CanvasLayer
var workshop_menu_host: Control
var editor_complexity := EditorComplexity.SIMPLE
var advanced_mode_button: BaseButton
var simple_pool_toggle_button: TextureButton
var card_context_menu: PopupMenu
var context_card_kind := ""
var context_card_type := -1
var saved_level_snapshot := ""
var pending_unsaved_action := Callable()
var unsaved_changes_dialog: ConfirmationDialog
var reward_conflict_dialog: ConfirmationDialog
var formal_sync_dialog_layer: Control


func _layout_control(path: String) -> Control:
	return get_node_or_null("LayoutMarkers/" + path) as Control


func _ready() -> void:
	## 工坊入口固定为普通编辑器，先设置模式再生成两类卡片目录。
	var active_mode := "normal"
	Global.level_workshop_edit_mode = active_mode
	var return_state: Dictionary = Global.level_workshop_return_state.duplicate(true)
	Global.level_workshop_return_state = {}
	_apply_font()
	_refresh_zombie_catalog()
	_build_scene()
	var developer_source: Dictionary = Global.developer_workshop_level_source
	Global.developer_workshop_level_source = {}
	if not developer_source.is_empty():
		level = developer_source.duplicate(true)
		formal_preset_id = str(level.get("formalPresetId", ""))
		loaded_source_kind = "template" if FormalLevelStore.is_formal_preset_id(formal_preset_id) else ""
		status_label.text = "已载入当前实战关卡，可直接继续编辑。"
		DraftStore.save_autosave(level)
	else:
		var recovered := DraftStore.load_autosave()
		if recovered["ok"] and str((recovered["level"] as Dictionary).get("workshopMode", "normal")) == active_mode:
			level = recovered["level"]
			formal_preset_id = str(level.get("formalPresetId", ""))
			loaded_source_kind = "template" if FormalLevelStore.is_formal_preset_id(formal_preset_id) else ""
			status_label.text = "已恢复上次编辑。点击左侧僵尸卡片即可继续添加。"
	level = Logic.normalize_level(level)
	level["workshopMode"] = active_mode
	level["forcedPlants"] = []
	level["freePlantSelection"] = true
	## 普通入口默认简易模式；从数值编辑器返回时恢复离开前的编辑状态。
	editor_complexity = int(return_state.get("editor_complexity", EditorComplexity.SIMPLE))
	level["editorMode"] = "simple" if _is_simple_mode() else "advanced"
	if FormalLevelStore.is_formal_preset_id(formal_preset_id):
		_apply_formal_map_constraints()
		_apply_formal_plant_progression()
		reward_mode_button.visible = true
	_refresh_locked_available_plants()
	_ensure_locked_plants_selected()
	_force_random_lane_rules()
	_sanitize_simple_allowed_pool()
	_refresh_zombie_catalog()
	selected_wave = clampi(int(return_state.get("selected_wave", selected_wave)), 0, maxi(0, (level.get("waves", []) as Array).size() - 1))
	catalog_mode = int(return_state.get("catalog_mode", CatalogMode.SPAWN_ZOMBIES))
	current_card_page = maxi(0, int(return_state.get("card_page", 0)))
	_update_editor_complexity_button()
	_restore_catalog_view()
	_refresh_card_page()
	_recalculate_stage_times()
	_snapshot(false)
	_refresh_draft_picker()
	_refresh_wave()
	_update_level_source_buttons()
	_mark_current_level_saved()


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


func _refresh_map_preview() -> void:
	if not is_instance_valid(background_sprite):
		return
	var map_type := str((level.get("mapConfig", {}) as Dictionary).get("type", "front_lawn"))
	background_sprite.texture = {
		"night_lawn": NIGHT_LAWN,
		"pool": POOL_LAWN,
		"fog": FOG_LAWN,
		"roof": ROOF_LAWN,
	}.get(map_type, FRONT_LAWN)


func _build_drawer() -> void:
	drawer = get_node("AlmanacDrawer") as Control
	drawer.position.x = -drawer.size.x
	drawer_paper = drawer.get_node("Paper") as TextureRect
	sidebar_content = drawer.get_node("Content") as Control
	stage_heading = sidebar_content.get_node("StageHeading") as Label
	stage_heading.mouse_filter = Control.MOUSE_FILTER_STOP
	stage_heading.mouse_default_cursor_shape = Control.CURSOR_IBEAM
	stage_heading.tooltip_text = "点击编辑关卡名称"
	stage_heading.gui_input.connect(_on_stage_heading_gui_input)
	wave_title = sidebar_content.get_node("WaveTitle") as Label
	wave_summary = sidebar_content.get_node("WaveSummary") as Label
	status_label = sidebar_content.get_node("StatusLabel") as Label
	simple_pool_toggle_button = _texture_button("本关允许僵尸", wave_summary.position, wave_summary.size, PAGE_BUTTON, PAGE_BUTTON_HOVER, _toggle_simple_stage_type, 14)
	sidebar_content.add_child(simple_pool_toggle_button)
	reward_mode_button = sidebar_content.get_node("RewardModeButton") as TextureButton
	reward_mode_button.visible = true
	reward_mode_button.pressed.connect(_toggle_reward_catalog)
	_build_formal_level_navigation()
	_build_stage_heading_editor()
	_update_catalog_button_label()
	card_scroll = sidebar_content.get_node("CardScroll") as ScrollContainer
	card_grid = card_scroll.get_node("CardGridHolder/CardGrid") as GridContainer
	card_page_label = sidebar_content.get_node("Pagination/PageLabel") as Label
	(sidebar_content.get_node("Pagination/PreviousButton") as TextureButton).pressed.connect(_change_card_page.bind(-1))
	(sidebar_content.get_node("Pagination/NextButton") as TextureButton).pressed.connect(_change_card_page.bind(1))
	_refresh_card_page()
	_build_timeline()
	_build_drawer_actions()


func _build_formal_level_navigation() -> void:
	previous_formal_level_button = _formal_level_navigation_button(true, "上一关")
	previous_formal_level_button.position = Vector2(32, 28)
	previous_formal_level_button.pressed.connect(_switch_formal_level.bind(-1))
	sidebar_content.add_child(previous_formal_level_button)

	next_formal_level_button = _formal_level_navigation_button(false, "下一关")
	next_formal_level_button.position = Vector2(331, 28)
	next_formal_level_button.pressed.connect(_switch_formal_level.bind(1))
	sidebar_content.add_child(next_formal_level_button)


func _formal_level_navigation_button(flip_h: bool, tooltip: String) -> Button:
	var button := Button.new()
	button.size = Vector2(40, 34)
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = tooltip
	var arrow := TextureRect.new()
	arrow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow.texture = LEVEL_NAVIGATION_ARROW
	arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	arrow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	arrow.flip_h = flip_h
	button.add_child(arrow)
	button.mouse_entered.connect(func():
		if not button.disabled:
			arrow.self_modulate = Color(1.18, 1.18, 1.18, 1.0)
	)
	button.mouse_exited.connect(func(): arrow.self_modulate = Color.WHITE)
	return button


func _switch_formal_level(offset: int) -> void:
	if loaded_source_kind != "template" or not FormalLevelStore.is_formal_preset_id(formal_preset_id):
		return
	if is_instance_valid(stage_heading_editor) and stage_heading_editor.visible:
		_finish_stage_heading_edit(true)
		if stage_heading_editor.visible:
			return
	var presets := AdventurePresets.list_presets("normal")
	var target_index := _formal_preset_index() + offset
	if target_index < 0 or target_index >= presets.size():
		return
	_request_leave_with_unsaved_check(_load_preset_for_edit.bind(str((presets[target_index] as Dictionary).get("id", ""))))


func _update_formal_level_navigation() -> void:
	if not is_instance_valid(previous_formal_level_button) or not is_instance_valid(next_formal_level_button):
		return
	var preset_index := _formal_preset_index()
	var formal_editing := loaded_source_kind == "template" and preset_index >= 0
	previous_formal_level_button.visible = formal_editing
	next_formal_level_button.visible = formal_editing
	if formal_editing:
		var preset_count := AdventurePresets.list_presets("normal").size()
		previous_formal_level_button.disabled = preset_index == 0
		next_formal_level_button.disabled = preset_index >= preset_count - 1
		previous_formal_level_button.modulate = Color(0.42, 0.42, 0.42, 0.7) if previous_formal_level_button.disabled else Color.WHITE
		next_formal_level_button.modulate = Color(0.42, 0.42, 0.42, 0.7) if next_formal_level_button.disabled else Color.WHITE
		stage_heading.position.x = 76.0
		stage_heading.size.x = 253.0
	else:
		stage_heading.position.x = 53.0
		stage_heading.size.x = 380.0
	if is_instance_valid(stage_heading_editor) and not stage_heading_editor.visible:
		stage_heading_editor.position = stage_heading.position
		stage_heading_editor.size.x = maxf(160.0, reward_mode_button.position.x - stage_heading.position.x - 8.0)


func _build_stage_heading_editor() -> void:
	stage_heading_editor = LineEdit.new()
	stage_heading_editor.position = stage_heading.position
	stage_heading_editor.size = Vector2(
		maxf(160.0, reward_mode_button.position.x - stage_heading.position.x - 8.0),
		stage_heading.size.y
	)
	stage_heading_editor.visible = false
	stage_heading_editor.alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_heading_editor.add_theme_font_override("font", WORKSHOP_FONT)
	stage_heading_editor.add_theme_font_size_override("font_size", 27)
	stage_heading_editor.add_theme_color_override("font_color", Color("e7e4d1"))
	stage_heading_editor.add_theme_color_override("caret_color", Color("e7e4d1"))
	stage_heading_editor.add_theme_color_override("selection_color", Color(0.35, 0.38, 0.55, 0.9))
	stage_heading_editor.add_theme_stylebox_override("normal", _style(Color(0.09, 0.1, 0.17, 0.92), Color(0.52, 0.54, 0.68, 1.0), 6, 1))
	stage_heading_editor.add_theme_stylebox_override("focus", _style(Color(0.09, 0.1, 0.17, 0.96), Color("e7e4d1"), 6, 2))
	stage_heading_editor.text_submitted.connect(func(_text: String): _finish_stage_heading_edit(true))
	stage_heading_editor.focus_exited.connect(_finish_stage_heading_edit.bind(true))
	stage_heading_editor.gui_input.connect(_on_stage_heading_editor_gui_input)
	sidebar_content.add_child(stage_heading_editor)
	## 输入框应位于标题上方、卡片切换按钮下方，避免编辑时遮住按钮。
	sidebar_content.move_child(stage_heading_editor, reward_mode_button.get_index())


func _on_stage_heading_gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null or mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	_begin_stage_heading_edit()
	stage_heading.accept_event()


func _begin_stage_heading_edit() -> void:
	if not is_instance_valid(stage_heading_editor) or stage_heading_editor.visible:
		return
	stage_heading_edit_original = str(level.get("name", "")).strip_edges()
	stage_heading_editor.text = stage_heading_edit_original
	stage_heading.visible = false
	stage_heading_editor.visible = true
	stage_heading_editor.grab_focus()
	stage_heading_editor.select_all()


func _on_stage_heading_editor_gui_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_ESCAPE:
		_finish_stage_heading_edit(false)
		stage_heading_editor.accept_event()


func _finish_stage_heading_edit(save_change: bool) -> void:
	if not is_instance_valid(stage_heading_editor) or not stage_heading_editor.visible:
		return
	if not save_change:
		stage_heading_editor.visible = false
		stage_heading.visible = true
		stage_heading_editor.release_focus()
		_refresh_stage_heading()
		return
	var level_name := stage_heading_editor.text.strip_edges()
	if level_name.is_empty():
		status_label.text = "修改失败：关卡名称不能为空"
		stage_heading_editor.call_deferred("grab_focus")
		return
	stage_heading_editor.visible = false
	stage_heading.visible = true
	stage_heading_editor.release_focus()
	if level_name == stage_heading_edit_original:
		_refresh_stage_heading()
		return
	level["name"] = level_name
	_changed("关卡名称已更新")


func _build_drawer_actions() -> void:
	var actions := sidebar_content.get_node("BottomActions")
	var action_names := ["SettingsButton", "NewButton", "LoadButton", "SaveButton"]
	var action_width := 109.0
	var action_gap := 9.0
	for action_index in action_names.size():
		var action_button := actions.get_node(action_names[action_index]) as TextureButton
		action_button.position.x = action_index * (action_width + action_gap)
		action_button.size.x = action_width
	(actions.get_node("SettingsButton") as TextureButton).pressed.connect(_open_level_settings)
	new_level_button = actions.get_node("NewButton") as TextureButton
	edit_level_button = actions.get_node("LoadButton") as TextureButton
	var source_button_group := ButtonGroup.new()
	new_level_button.toggle_mode = true
	new_level_button.button_group = source_button_group
	edit_level_button.toggle_mode = true
	edit_level_button.button_group = source_button_group
	new_level_button.pressed.connect(_request_create_new_level)
	edit_level_button.pressed.connect(_open_template_picker)
	var formal_edit_label := edit_level_button.get_node_or_null("Label") as Label
	if formal_edit_label != null:
		formal_edit_label.text = "编辑正式关卡"
		formal_edit_label.add_theme_font_size_override("font_size", 14)
	var custom_level_label := new_level_button.get_node_or_null("Label") as Label
	if custom_level_label != null:
		custom_level_label.text = "自制关卡"
	(actions.get_node("SaveButton") as TextureButton).pressed.connect(_open_save_dialog)
	(get_node("TopActions/PlaytestButton") as BaseButton).pressed.connect(_playtest)
	advanced_mode_button = get_node("TopActions/AdvancedModeButton") as BaseButton
	advanced_mode_button.pressed.connect(_toggle_editor_complexity)
	(get_node("TopActions/MenuButton") as BaseButton).pressed.connect(_open_workshop_menu)
	_update_editor_complexity_button()
	_update_level_source_buttons()


func _open_cover_characters_dialog(settings_button: TextureButton = null) -> void:
	_close_cover_characters_dialog()
	cover_dialog_layer = Control.new()
	cover_dialog_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover_dialog_layer.z_index = 700
	add_child(cover_dialog_layer)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.62)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	cover_dialog_layer.add_child(shade)
	var dialog := TextureRect.new()
	dialog.position = Vector2(259, 75)
	dialog.size = Vector2(548, 450)
	dialog.texture = DIALOG_BACKGROUND
	dialog.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dialog.stretch_mode = TextureRect.STRETCH_SCALE
	dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	cover_dialog_layer.add_child(dialog)
	var title := _paper_label("自定义选关封面角色", Vector2(44, 28), Vector2(460, 42), 27, Color("f3e7ba"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", Color("25263b"))
	title.add_theme_constant_override("outline_size", 4)
	dialog.add_child(title)
	var hint := _paper_label("依次选择最多 3 个角色；位置顺序对应封面从左到右。", Vector2(44, 76), Vector2(460, 32), 15, Color("d7bd80"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialog.add_child(hint)
	var recommended := _recommended_cover_characters()
	var current: Array = level.get("coverCharacters", []) if level.has("coverCharacters") else recommended
	var pickers: Array[OptionButton] = []
	for slot in 3:
		var row_y := 120.0 + slot * 58.0
		var label := _paper_label("位置 %d" % (slot + 1), Vector2(46, row_y), Vector2(82, 40), 18, Color("e9d28a"))
		dialog.add_child(label)
		var picker := OptionButton.new()
		picker.position = Vector2(128, row_y)
		picker.size = Vector2(372, 40)
		picker.add_theme_font_override("font", WORKSHOP_FONT)
		picker.add_theme_font_size_override("font_size", 16)
		picker.add_item("空位（不显示）")
		picker.set_item_metadata(0, {})
		_add_cover_character_options(picker)
		if slot < current.size() and current[slot] is Dictionary:
			_select_cover_character_option(picker, current[slot] as Dictionary)
		dialog.add_child(picker)
		pickers.append(picker)
	var mode_hint := _paper_label(
		"当前：%s" % ("自定义" if level.has("coverCharacters") else "自动推荐"),
		Vector2(46, 300), Vector2(454, 30), 16, Color("d7bd80")
	)
	mode_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialog.add_child(mode_hint)
	for picker in pickers:
		picker.item_selected.connect(func(_index: int): mode_hint.text = "当前：自定义（点击“应用封面”写入）")
	var auto_callback := func():
		_apply_cover_entries_to_pickers(pickers, recommended)
		mode_hint.text = "当前：自动推荐结果（可继续修改）"
	var save_callback := func():
		var selected: Array = []
		for picker in pickers:
			var entry = picker.get_item_metadata(picker.selected)
			if entry is Dictionary and not (entry as Dictionary).is_empty() and not selected.has(entry):
				selected.append((entry as Dictionary).duplicate())
		level["coverCharacters"] = selected
		_changed("选关封面已设置 %d 个角色" % selected.size())
		_update_cover_settings_button(settings_button)
		_close_cover_characters_dialog()
	dialog.add_child(_texture_button("恢复自动", Vector2(38, 360), Vector2(142, 42), DIALOG_BUTTON, DIALOG_BUTTON, auto_callback, 16))
	dialog.add_child(_texture_button("取消", Vector2(203, 360), Vector2(142, 42), DIALOG_BUTTON, DIALOG_BUTTON, _close_cover_characters_dialog, 17))
	dialog.add_child(_texture_button("应用封面", Vector2(368, 360), Vector2(142, 42), DIALOG_BUTTON, DIALOG_BUTTON, save_callback, 17))


func _recommended_cover_characters() -> Array[Dictionary]:
	var previous_level: Dictionary = {}
	var preset_index := _formal_preset_index()
	if preset_index > 0:
		var presets := AdventurePresets.list_presets("normal")
		var previous_id := str((presets[preset_index - 1] as Dictionary).get("id", ""))
		previous_level = AdventurePresets.build_level(previous_id, true)
	return Logic.recommended_cover_characters(level, previous_level)


func _apply_cover_entries_to_pickers(pickers: Array[OptionButton], entries: Array) -> void:
	for slot in pickers.size():
		pickers[slot].select(0)
		if slot < entries.size() and entries[slot] is Dictionary:
			_select_cover_character_option(pickers[slot], entries[slot] as Dictionary)


func _close_cover_characters_dialog() -> void:
	if is_instance_valid(cover_dialog_layer):
		cover_dialog_layer.queue_free()
	cover_dialog_layer = null


func _add_cover_settings_button(dialog: Control) -> void:
	var button := _texture_button("", Vector2(76, 464), Vector2(468, 38), DIALOG_BUTTON, DIALOG_BUTTON, func(): pass, 16)
	button.pressed.connect(_open_cover_characters_dialog.bind(button))
	dialog.add_child(button)
	_update_cover_settings_button(button)


func _update_cover_settings_button(button: TextureButton) -> void:
	if not is_instance_valid(button):
		return
	var label := button.get_child(0) as Label if button.get_child_count() > 0 else null
	if label == null:
		return
	var mode_text := "自动推荐"
	if level.has("coverCharacters"):
		mode_text = "自定义 %d 个" % (level.get("coverCharacters", []) as Array).size()
	label.text = "选关封面角色 · %s" % mode_text


func _add_cover_character_options(picker: OptionButton) -> void:
	picker.add_separator("植物")
	var plant_types: Array = CharacterRegistry.PlantInfo.keys()
	plant_types.sort()
	for value in plant_types:
		var type_id := int(value)
		if type_id <= 0:
			continue
		picker.add_item("植物 · %s（%d）" % [_plant_name(type_id), type_id])
		picker.set_item_metadata(picker.item_count - 1, {"kind": "plant", "type": type_id})
	picker.add_separator("僵尸")
	var zombie_types: Array = CharacterRegistry.ZombieInfo.keys()
	zombie_types.sort()
	for value in zombie_types:
		var type_id := int(value)
		if type_id <= 0:
			continue
		picker.add_item("僵尸 · %s（%d）" % [_zombie_name(str(type_id)), type_id])
		picker.set_item_metadata(picker.item_count - 1, {"kind": "zombie", "type": type_id})


func _select_cover_character_option(picker: OptionButton, selected_entry: Dictionary) -> void:
	for index in picker.item_count:
		var metadata = picker.get_item_metadata(index)
		if metadata is Dictionary and metadata == selected_entry:
			picker.select(index)
			return


func _update_level_source_buttons() -> void:
	if not is_instance_valid(new_level_button) or not is_instance_valid(edit_level_button):
		return
	var editing_existing := loaded_source_kind == "template" or loaded_source_kind == "custom"
	new_level_button.set_pressed_no_signal(not editing_existing)
	edit_level_button.set_pressed_no_signal(editing_existing)
	_apply_source_button_visual(new_level_button, not editing_existing)
	_apply_source_button_visual(edit_level_button, editing_existing)
	new_level_button.tooltip_text = "当前正在编辑自制关卡" if not editing_existing else "新建自制关卡并选择地图"
	edit_level_button.tooltip_text = "当前正在编辑已有关卡" if editing_existing else "选择要编辑的正式关卡"


func _apply_source_button_visual(button: TextureButton, selected: bool) -> void:
	## 持续使用 pressed 贴图，并通过下沉和压暗表现实体按钮被按住。
	button.position.y = ACTIVE_SOURCE_BUTTON_OFFSET_Y if selected else 0.0
	button.self_modulate = ACTIVE_SOURCE_BUTTON_MODULATE if selected else Color.WHITE


func _is_simple_mode() -> bool:
	return editor_complexity == EditorComplexity.SIMPLE


func _toggle_editor_complexity() -> void:
	_close_quantity_dialog()
	_end_timeline_mode()
	editor_complexity = EditorComplexity.ADVANCED if _is_simple_mode() else EditorComplexity.SIMPLE
	level["editorMode"] = "simple" if _is_simple_mode() else "advanced"
	if _is_simple_mode():
		_normalize_simple_timeline_spacing()
		_sanitize_simple_allowed_pool()
	_update_editor_complexity_button()
	_update_timeline_editability()
	_refresh_card_page()
	_refresh_wave()
	_changed("已切换到%s；%s" % [
		"简易模式" if _is_simple_mode() else "进阶模式",
		"只需选择僵尸种类，数量与节奏由系统决定" if _is_simple_mode() else "可以继续精确设置每种僵尸的数量",
	])


func _update_editor_complexity_button() -> void:
	if not is_instance_valid(advanced_mode_button):
		return
	var label := advanced_mode_button.get_node_or_null("Label") as Label
	if label != null:
		label.text = "进阶模式" if _is_simple_mode() else "简易模式"
	advanced_mode_button.tooltip_text = "切换到精确数量编辑" if _is_simple_mode() else "返回原版式简易编辑"
	_refresh_simple_pool_toggle()


func _toggle_simple_stage_type() -> void:
	## 保留回调以兼容旧场景连接；PvZ1 简易模式只有一份 mZombieAllowed。
	return


func _selected_stage_type() -> String:
	var stages: Array = level.get("waves", [])
	if selected_wave < 0 or selected_wave >= stages.size():
		return "interval"
	return str((stages[selected_wave] as Dictionary).get("stageType", "interval"))


func _refresh_simple_pool_toggle() -> void:
	if not is_instance_valid(simple_pool_toggle_button):
		return
	## PvZ1 原版每关只有一份 mZombieAllowed，不存在普通波/旗帜波独立池。
	simple_pool_toggle_button.visible = false
	wave_summary.visible = not _is_simple_mode() and catalog_mode == CatalogMode.SPAWN_ZOMBIES


func _open_preset_picker() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "载入关卡"
	dialog.cancel_button_text = "取消"
	dialog.get_ok_button().visible = false
	dialog.min_size = Vector2i(460, 230)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	dialog.add_child(box)
	var hint := Label.new()
	hint.text = "请选择要载入的关卡类型："
	box.add_child(hint)
	var template_button := Button.new()
	template_button.text = "关卡模板"
	template_button.custom_minimum_size = Vector2(400, 44)
	box.add_child(template_button)
	var custom_button := Button.new()
	custom_button.text = "自制关卡"
	custom_button.custom_minimum_size = Vector2(400, 44)
	box.add_child(custom_button)
	template_button.pressed.connect(func():
		dialog.queue_free()
		_open_template_picker()
	)
	custom_button.pressed.connect(func():
		dialog.queue_free()
		_open_custom_level_picker()
	)
	add_child(dialog)
	_force_font_recursive(dialog)
	dialog.popup_centered()


func _open_template_picker() -> void:
	## 打开选择框不等于切换编辑来源；取消后仍应保持原来的模式按钮。
	_update_level_source_buttons()
	var presets := AdventurePresets.list_presets("normal")
	var dialog := ConfirmationDialog.new()
	dialog.title = "编辑正式冒险关卡"
	dialog.ok_button_text = "载入编辑"
	dialog.cancel_button_text = "取消"
	dialog.min_size = Vector2i(480, 250)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	dialog.add_child(box)
	var picker := OptionButton.new()
	for preset: Dictionary in presets:
		picker.add_item(_formal_preset_display_name(preset))
	box.add_child(picker)
	var sync_button := Button.new()
	sync_button.text = "批量同步到正式模式"
	sync_button.custom_minimum_size = Vector2(420, 44)
	sync_button.tooltip_text = "勾选并发布已保存的开发者关卡"
	box.add_child(sync_button)
	sync_button.pressed.connect(func():
		dialog.queue_free()
		_request_leave_with_unsaved_check(_open_formal_sync_dialog)
	)
	dialog.confirmed.connect(func():
		if picker.selected < 0 or picker.selected >= presets.size():
			return
		dialog.queue_free()
		_request_leave_with_unsaved_check(_load_preset_for_edit.bind(str(presets[picker.selected]["id"])))
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	add_child(dialog)
	_force_font_recursive(dialog)
	dialog.popup_centered()


func _open_formal_sync_dialog() -> void:
	_close_formal_sync_dialog()
	var presets := AdventurePresets.list_formal_presets("normal")
	formal_sync_dialog_layer = Control.new()
	formal_sync_dialog_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	formal_sync_dialog_layer.z_index = 750
	add_child(formal_sync_dialog_layer)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.68)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	formal_sync_dialog_layer.add_child(shade)
	var dialog := TextureRect.new()
	dialog.position = Vector2(153, 25)
	dialog.size = Vector2(760, 550)
	dialog.texture = DIALOG_BACKGROUND
	dialog.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dialog.stretch_mode = TextureRect.STRETCH_SCALE
	dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	formal_sync_dialog_layer.add_child(dialog)
	var title := _paper_label("同步关卡到正式模式", Vector2(80, 18), Vector2(600, 44), 27, Color("f3e7ba"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", Color("25263b"))
	title.add_theme_constant_override("outline_size", 4)
	dialog.add_child(title)
	var hint := _paper_label("勾选需要发布的关卡。名称末尾的 * 表示开发者版本尚未同步到正式模式。", Vector2(40, 65), Vector2(680, 34), 15, Color("d7bd80"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog.add_child(hint)
	var quick_actions := HBoxContainer.new()
	quick_actions.position = Vector2(40, 103)
	quick_actions.size = Vector2(680, 36)
	quick_actions.add_theme_constant_override("separation", 8)
	dialog.add_child(quick_actions)
	var select_all_button := Button.new()
	select_all_button.text = "全选"
	select_all_button.custom_minimum_size = Vector2(72, 34)
	quick_actions.add_child(select_all_button)
	var clear_button := Button.new()
	clear_button.text = "清空"
	clear_button.custom_minimum_size = Vector2(72, 34)
	quick_actions.add_child(clear_button)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(40, 142)
	scroll.size = Vector2(680, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dialog.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 7)
	scroll.add_child(grid)
	var checkboxes: Dictionary = {}
	for preset: Dictionary in presets:
		var preset_id := str(preset.get("id", ""))
		var is_synced := FormalLevelStore.is_developer_level_synced(preset_id)
		var checkbox := CheckBox.new()
		checkbox.text = _formal_preset_display_name(preset) + ("" if is_synced else "*")
		checkbox.custom_minimum_size = Vector2(210, 34)
		checkbox.button_pressed = preset_id == formal_preset_id
		checkbox.tooltip_text = "%s（%s）" % [preset_id, "已同步" if is_synced else "未同步"]
		grid.add_child(checkbox)
		checkboxes[preset_id] = checkbox
	select_all_button.pressed.connect(func():
		for checkbox in checkboxes.values():
			(checkbox as CheckBox).button_pressed = true
	)
	clear_button.pressed.connect(func():
		for checkbox in checkboxes.values():
			(checkbox as CheckBox).button_pressed = false
	)
	var error_label := _paper_label("", Vector2(40, 446), Vector2(680, 30), 14, Color("ffb49d"))
	error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialog.add_child(error_label)
	var sync_callback := func():
		var selected_ids: Array[String] = []
		for preset: Dictionary in presets:
			var preset_id := str(preset.get("id", ""))
			var checkbox := checkboxes.get(preset_id) as CheckBox
			if is_instance_valid(checkbox) and checkbox.button_pressed:
				selected_ids.append(preset_id)
		var result := FormalLevelStore.sync_developer_levels_to_formal(selected_ids)
		if result["ok"]:
			status_label.text = "已同步 %d 个关卡到正式模式。" % (result["synced"] as Array).size()
			_close_formal_sync_dialog()
		else:
			status_label.text = "同步失败：%s" % str(result["error"])
			error_label.text = "同步失败：%s" % str(result["error"])
	dialog.add_child(_texture_button("取消", Vector2(205, 485), Vector2(150, 42), DIALOG_BUTTON, DIALOG_BUTTON, _close_formal_sync_dialog, 17))
	dialog.add_child(_texture_button("同步所选关卡", Vector2(405, 485), Vector2(150, 42), DIALOG_BUTTON, DIALOG_BUTTON, sync_callback, 16))
	_force_font_recursive(formal_sync_dialog_layer)


func _close_formal_sync_dialog() -> void:
	if is_instance_valid(formal_sync_dialog_layer):
		formal_sync_dialog_layer.queue_free()
	formal_sync_dialog_layer = null


func _formal_preset_display_name(preset: Dictionary) -> String:
	var preset_id := str(preset.get("id", ""))
	## 当前关卡尚未保存时也立即同步名称；其余关卡读取已经落盘的开发者覆盖。
	if loaded_source_kind == "template" and preset_id == formal_preset_id:
		var current_name := str(level.get("name", "")).strip_edges()
		if not current_name.is_empty():
			return current_name
	var developer_level := AdventurePresets.build_level(preset_id, true)
	return str(developer_level.get("name", preset.get("name", preset_id)))


func _open_custom_level_picker() -> void:
	var drafts := DraftStore.list_drafts()
	if drafts.is_empty():
		status_label.text = "还没有自制关卡，请先新建并保存一个关卡。"
		return
	var dialog := ConfirmationDialog.new()
	dialog.title = "载入自制关卡"
	dialog.ok_button_text = "载入编辑"
	dialog.cancel_button_text = "返回上一级"
	dialog.min_size = Vector2i(480, 190)
	var box := VBoxContainer.new()
	dialog.add_child(box)
	var picker := OptionButton.new()
	for draft: Dictionary in drafts:
		picker.add_item(str(draft["name"]))
	box.add_child(picker)
	dialog.confirmed.connect(func():
		if picker.selected < 0 or picker.selected >= drafts.size():
			return
		dialog.queue_free()
		_request_leave_with_unsaved_check(_load_custom_level_for_edit.bind(str(drafts[picker.selected]["path"])))
	)
	dialog.canceled.connect(_return_to_load_category.bind(dialog))
	add_child(dialog)
	_force_font_recursive(dialog)
	dialog.popup_centered()


func _return_to_load_category(dialog: ConfirmationDialog) -> void:
	dialog.queue_free()
	call_deferred("_open_preset_picker")


func _load_preset_for_edit(preset_id: String) -> void:
	var previous_catalog_mode := catalog_mode
	var preset := AdventurePresets.build_level(preset_id, true)
	if preset.is_empty():
		status_label.text = "关卡不存在：%s" % preset_id
		return
	level = Logic.normalize_level(preset)
	## 正式关卡切换后要继承当前编辑器模式。预设/旧覆盖文件可能没有 editorMode，
	## 若保留 normalize_level 的默认 advanced，界面虽然显示简易模式，试玩却会走进阶时间轴。
	level["editorMode"] = "simple" if _is_simple_mode() else "advanced"
	formal_preset_id = preset_id
	loaded_source_kind = "template"
	loaded_draft_path = ""
	level["formalPresetId"] = preset_id
	level["id"] = "%s_edit" % preset_id
	_apply_formal_map_constraints()
	_apply_formal_plant_progression()
	var inherited_reward_cleared := _clear_inherited_formal_reward()
	Global.level_workshop_edit_mode = str(level.get("workshopMode", "normal"))
	## 正式关卡始终通过植物卡界面选择本关奖励。
	reward_mode_button.visible = true
	catalog_mode = previous_catalog_mode
	_update_catalog_background(catalog_mode == CatalogMode.REWARD_CARDS)
	_refresh_map_preview()
	background_sprite.position.x = background_normal_x + 334.0 if catalog_mode == CatalogMode.REWARD_CARDS else background_normal_x
	_update_catalog_button_label()
	_refresh_locked_available_plants()
	_ensure_locked_plants_selected()
	_force_random_lane_rules()
	_sanitize_simple_allowed_pool()
	_refresh_zombie_catalog()
	_refresh_card_page()
	selected_wave = 0
	selected_zombie_key = ""
	history.clear()
	future.clear()
	_recalculate_stage_times()
	_snapshot(false)
	DraftStore.save_autosave(level)
	_update_timeline_catalog_visibility()
	_refresh_wave()
	_update_level_source_buttons()
	_mark_current_level_saved()
	status_label.text = ("已载入“%s”。原奖励已提前获得，请新增本关奖励。" if inherited_reward_cleared else "已载入“%s”。此前已有卡不能取消；点击新卡添加奖励。") % str(level["name"])


func _formal_preset_index(preset_id: String = formal_preset_id) -> int:
	var presets := AdventurePresets.list_presets("normal")
	for index in presets.size():
		if str((presets[index] as Dictionary).get("id", "")) == preset_id:
			return index
	return -1


func _is_first_formal_level() -> bool:
	return _formal_preset_index() == 0


func _apply_formal_map_constraints() -> void:
	## 正式 1-1 只固定开场僵尸演出和中间三行，其余关卡参数仍可编辑。
	if formal_preset_id != "adventure_1_1":
		return
	level["openingFirstZombieAdvanceCells"] = 7.5
	level["activeLawnRows"] = [1, 2, 3]


func _formal_progression_available_plants() -> Array[int]:
	var presets := AdventurePresets.list_presets("normal")
	var target_index := _formal_preset_index()
	var result: Array[int] = []
	if target_index < 0:
		return result
	if target_index == 0:
		return _selected_available_plants()
	var first_level := AdventurePresets.build_level(str((presets[0] as Dictionary)["id"]), true)
	for value in first_level.get("availablePlants", []):
		var plant_type := int(value)
		if CharacterRegistry.PlantInfo.has(plant_type) and not result.has(plant_type):
			result.append(plant_type)
	for prior_index in target_index:
		var prior_level := AdventurePresets.build_level(str((presets[prior_index] as Dictionary)["id"]), true)
		for reward_plant in Logic.reward_plant_types(prior_level):
			if CharacterRegistry.PlantInfo.has(reward_plant) and not result.has(reward_plant):
				result.append(reward_plant)
	return result


func _apply_formal_plant_progression() -> void:
	if not FormalLevelStore.is_formal_preset_id(formal_preset_id) or _formal_preset_index() < 0 or _is_first_formal_level():
		return
	var inherited_plants := _formal_progression_available_plants()
	level["availablePlants"] = inherited_plants
	level["plantSelectionEnabled"] = true
	level["forcedPlants"] = []
	level["freePlantSelection"] = true


func _clear_inherited_formal_reward() -> bool:
	var rewards := _formal_reward_plants()
	var retained: Array[int] = []
	for reward_plant in rewards:
		if not (level.get("availablePlants", []) as Array).has(reward_plant):
			retained.append(reward_plant)
	if retained.size() == rewards.size():
		return false
	_set_formal_reward_plants(retained)
	return true


func _load_custom_level_for_edit(path: String) -> void:
	var loaded := DraftStore.load_draft(path)
	if not loaded["ok"]:
		status_label.text = "载入自制关卡失败：%s" % str(loaded["error"])
		return
	level = Logic.normalize_level(loaded["level"])
	level.erase("formalPresetId")
	formal_preset_id = ""
	loaded_source_kind = "custom"
	loaded_draft_path = path
	_refresh_after_level_replaced()
	_mark_current_level_saved()
	status_label.text = "已载入自制关卡“%s”，可直接继续修改。" % str(level["name"])


func _request_create_new_level() -> void:
	_request_leave_with_unsaved_check(_create_new_level_and_open_settings)


func _create_new_level_and_open_settings() -> void:
	_create_new_level()
	call_deferred("_open_level_settings")


func _create_new_level() -> void:
	level = Logic.normalize_level(Logic.example_level())
	level["id"] = "example_front_lawn"
	level["name"] = "未命名关卡"
	level.erase("formalPresetId")
	formal_preset_id = ""
	loaded_source_kind = ""
	loaded_draft_path = ""
	_refresh_after_level_replaced()
	_mark_current_level_saved()
	status_label.text = "已新建关卡。编辑完成后点击“保存”并命名。"


func _refresh_after_level_replaced() -> void:
	Global.level_workshop_edit_mode = "normal"
	level["editorMode"] = "simple" if _is_simple_mode() else "advanced"
	level["forcedPlants"] = []
	level["freePlantSelection"] = true
	reward_mode_button.visible = true
	catalog_mode = CatalogMode.SPAWN_ZOMBIES
	_update_catalog_background(false)
	_refresh_map_preview()
	background_sprite.position.x = background_normal_x
	_update_catalog_button_label()
	_refresh_locked_available_plants()
	_ensure_locked_plants_selected()
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
	_update_level_source_buttons()


func _refresh_locked_available_plants() -> void:
	locked_available_plant_types.clear()
	if not FormalLevelStore.is_formal_preset_id(formal_preset_id):
		return
	if _formal_preset_index() < 0:
		return
	## 第一关的预设初始卡和后续关卡的前序奖励都属于已有卡，必定可选且不能取消。
	if _is_first_formal_level():
		for value in _selected_available_plants():
			var initial_plant_type := int(value)
			if not locked_available_plant_types.has(initial_plant_type):
				locked_available_plant_types.append(initial_plant_type)
		return
	for value in _formal_progression_available_plants():
		var plant_type := int(value)
		if CharacterRegistry.PlantInfo.has(plant_type) and not locked_available_plant_types.has(plant_type):
			locked_available_plant_types.append(plant_type)


func _ensure_locked_plants_selected() -> void:
	var selected := _selected_available_plants()
	for plant_type in locked_available_plant_types:
		if not selected.has(plant_type):
			selected.append(plant_type)
	level["availablePlants"] = selected
	if not locked_available_plant_types.is_empty():
		level["plantSelectionEnabled"] = true


func _selected_available_plants() -> Array[int]:
	var result: Array[int] = []
	for value in level.get("availablePlants", []):
		var plant_type := int(value)
		if plant_type > 0 and CharacterRegistry.PlantInfo.has(plant_type) and not result.has(plant_type):
			result.append(plant_type)
	return result


func _update_catalog_button_label() -> void:
	if not is_instance_valid(reward_mode_button):
		return
	var button_label := reward_mode_button.get_child(0) as Label
	if button_label == null:
		return
	if catalog_mode == CatalogMode.REWARD_CARDS:
		button_label.text = "登场僵尸"
	else:
		button_label.text = "奖励卡槽" if Global.level_workshop_edit_mode == "chessboard" else "植物卡片"


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
	undo_timeline_button = timeline_actions.get_node("UndoButton") as TextureButton
	undo_timeline_button.pressed.connect(_undo)
	delete_timeline_button = timeline_actions.get_node("DeleteButton") as TextureButton
	delete_timeline_button.pressed.connect(_on_remove_or_delete_timeline_pressed)
	reset_timeline_button = timeline_actions.get_node("ResetButton") as TextureButton
	reset_timeline_button.pressed.connect(_reset_timeline)
	add_flag_button = timeline_actions.get_node("AddFlagButton") as TextureButton
	add_flag_button.pressed.connect(_on_add_flag_pressed)
	clear_cards_button = _texture_button("清空卡片", Vector2(170, 0), Vector2(142, 32), DIALOG_BUTTON, DIALOG_BUTTON, _clear_all_cards, 14)
	clear_cards_button.visible = false
	timeline_actions.add_child(clear_cards_button)
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
	_update_timeline_editability()


func _update_timeline_editability() -> void:
	var simple := _is_simple_mode()
	if is_instance_valid(timeline_stages):
		timeline_stages.mouse_filter = Control.MOUSE_FILTER_IGNORE if simple else Control.MOUSE_FILTER_STOP
		timeline_stages.tooltip_text = ""
	if simple:
		_hide_interval_preview()
		_set_timeline_hover_flag(-1)
	if is_instance_valid(delete_timeline_button):
		delete_timeline_button.disabled = false
		delete_timeline_button.tooltip_text = "设置旗帜数量；每面旗帜固定包含 10 波" if simple else "删除当前阶段"
		var delete_label := delete_timeline_button.get_node_or_null("Label") as Label
		if delete_label != null:
			delete_label.text = "旗帜数" if simple else "删除"
	if is_instance_valid(reset_timeline_button):
		reset_timeline_button.disabled = simple
		reset_timeline_button.tooltip_text = "简易模式不单独编辑旗帜" if simple else "重置时间轴"
	if is_instance_valid(add_flag_button):
		add_flag_button.disabled = simple
		add_flag_button.tooltip_text = "" if simple else "在时间轴上放置旗帜"
	_update_timeline_catalog_visibility()


func _update_timeline_catalog_visibility() -> void:
	var showing_cards := catalog_mode == CatalogMode.REWARD_CARDS
	if is_instance_valid(timeline_meter):
		timeline_meter.visible = not showing_cards
	for button in [undo_timeline_button, reset_timeline_button, delete_timeline_button, add_flag_button]:
		if is_instance_valid(button):
			button.visible = not showing_cards and (button != add_flag_button or not _is_simple_mode())
	if is_instance_valid(clear_cards_button):
		clear_cards_button.visible = showing_cards


func _on_remove_or_delete_timeline_pressed() -> void:
	if _is_simple_mode():
		_open_simple_flag_count_dialog()
	else:
		_open_delete_stage_dialog()


func _open_simple_flag_count_dialog() -> void:
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
	var title := _paper_label("设置旗帜数量", Vector2(48, 58), Vector2(316, 44), 25, Color("e7e4d1"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialog.add_child(title)
	var flag_count := _settings_spin(dialog, "旗帜数量（每旗 10 波）", Vector2(101, 118), 1, 10, int(level.get("simpleFlagCount", 2)), 1)
	dialog.add_child(_texture_button("取消", Vector2(63, 238), Vector2(132, 42), DIALOG_BUTTON, DIALOG_BUTTON, _close_quantity_dialog, 17))
	dialog.add_child(_texture_button("确认", Vector2(217, 238), Vector2(132, 42), DIALOG_BUTTON, DIALOG_BUTTON, func():
		_apply_simple_flag_count(int(flag_count.value))
		_close_quantity_dialog()
	, 17))


func _apply_simple_flag_count(flag_count: int) -> void:
	flag_count = clampi(flag_count, 1, 10)
	level["simpleFlagCount"] = flag_count
	level["simpleWaveCount"] = flag_count * 10
	_set_simple_flag_count(flag_count)
	_changed("旗帜数量已设为 %d（共 %d 波）" % [flag_count, flag_count * 10])
	_refresh_wave()


func _on_remove_flag_pressed() -> void:
	if _is_simple_mode():
		_open_simple_flag_count_dialog()
		return
	var flag_count := _count_stage_type("flag")
	if flag_count <= 1:
		status_label.text = "简易模式至少需要保留一面旗帜"
		_update_timeline_editability()
		return
	var previous_selection := selected_wave
	_set_simple_flag_count(flag_count - 1)
	selected_wave = clampi(previous_selection, 0, maxi(0, (level.get("waves", []) as Array).size() - 1))
	selected_zombie_key = ""
	_changed("已减少一面旗帜，并自动调整全部旗帜间距")
	_update_timeline_editability()
	_refresh_wave()


func _on_add_flag_pressed() -> void:
	if _is_simple_mode():
		return
	_begin_flag_placement()


func _refresh_timeline() -> void:
	_clear(timeline_stages)
	timeline_flag_visuals.clear()
	timeline_hovered_flag_index = -1
	if _is_simple_mode():
		var simple_flag_count := clampi(int(level.get("simpleFlagCount", 1)), 1, 10)
		for flag_number in range(1, simple_flag_count + 1):
			var flag_ratio := simple_flag_progress_ratio(flag_number, simple_flag_count)
			var flag_position := lerpf(FLAG_CENTER_RIGHT, FLAG_CENTER_LEFT, flag_ratio)
			var flag_button := _flag_stage_button(flag_number, false)
			flag_button.position = Vector2(flag_position * timeline_width_ratio - 8.0, 0)
			flag_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
			timeline_stages.add_child(flag_button)
			timeline_flag_visuals[flag_number - 1] = flag_button.get_node("Flag")
		if timeline_progress_bar != null:
			timeline_progress_bar.visible = false
			timeline_progress_bar.texture = null
		return
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
			var flag_button := _flag_stage_button(flag_number, not _is_simple_mode() and stage_index == selected_wave)
			flag_button.position = Vector2(flag_position * timeline_width_ratio - 8.0, 0)
			## 所有输入统一由时间轴根节点判定，视觉控件不再互相抢鼠标事件。
			flag_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if not _is_simple_mode() and stage_index == selected_wave:
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
			if not _is_simple_mode() and stage_index == selected_wave:
				selected_segment_left = minf(segment_start, segment_end)
				selected_segment_right = maxf(segment_start, segment_end)
	if timeline_progress_bar != null:
		timeline_progress_bar.visible = true
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


static func simple_flag_progress_ratio(flag_number: int, flag_count: int) -> float:
	## 与游戏内 FlagProgressBar.create_flag 一致：旗帜对应每个 10 波段的最后一波。
	flag_count = maxi(1, flag_count)
	return clampf(float(flag_number * 10 - 1) / float(flag_count * 10 - 1), 0.0, 1.0)


func _select_stage(stage_index: int) -> void:
	if stage_index < 0 or stage_index >= (level.get("waves", []) as Array).size():
		return
	DraftStore.save_autosave(level)
	_clear_preview_zombies()
	selected_wave = stage_index
	selected_zombie_key = ""
	_refresh_wave()


func _on_timeline_gui_input(event: InputEvent) -> void:
	if _is_simple_mode():
		return
	if event is InputEventMouseMotion:
		var mouse_position := (event as InputEventMouseMotion).position
		var interval_index := _timeline_interval_at_position(mouse_position)
		if interval_index >= 0:
			var interval_rect := _timeline_interval_rect(interval_index)
			_show_interval_preview(interval_rect.position.x, interval_rect.size.x)
			_set_timeline_hover_flag(-1)
			timeline_stages.tooltip_text = "点击选择该波间阶段" if _is_simple_mode() else ("旗帜前动态阶段：清空可提前推进，否则等待 40～46 秒" \
				if _is_stage_before_flag(interval_index) else "动态阶段：按剩余血量提前推进，25～31 秒自然刷新")
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
	if _is_simple_mode():
		_select_stage(stage_index)
		status_label.text = "已选中波间阶段，可设置允许出现的僵尸种类。"
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
	if _is_simple_mode():
		_on_add_flag_pressed()
		return
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
	if _is_simple_mode():
		status_label.text = "简易模式不编辑时间轴；波次由 PvZ1 原版管理器生成"
		return
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
	if _is_simple_mode():
		return
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
	if _is_simple_mode():
		_open_simple_flag_count_dialog()
		return
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
	var cost_label := card.get_node_or_null("CardBg/Cost") as Label
	if cost_label != null:
		cost_label.visible = false
	var required_simple_zombie := _is_simple_mode() and (
		zombie_type == _simple_base_zombie_type() or zombie_type == _simple_flag_zombie_type()
	)
	var simple_supported := not _is_simple_mode() or required_simple_zombie or _has_original_pick_weight(zombie_type)
	var simple_role := _simple_zombie_role(zombie_type) if _is_simple_mode() else ""
	var pool_map_required := _is_simple_mode() \
		and AdventurePresets.POOL_ONLY_ZOMBIES.has(zombie_type) \
		and not ["pool", "fog"].has(str((level.get("mapConfig", {}) as Dictionary).get("type", "front_lawn")))
	card.tooltip_text = (
		"当前基础僵尸，固定参与刷怪" if required_simple_zombie
		else "该僵尸只能用于泳池或雾夜地图" if pool_map_required
		else "简易自然波次暂不支持该僵尸" if not simple_supported
		else "选择%s（在旗帜波按蹦极机制登场）" % _zombie_name(str(zombie_type)) \
			if _is_simple_mode() and zombie_type == int(CharacterRegistry.ZombieType.Z520Bungi)
		else ("选择%s" if _is_simple_mode() else "设置%s的数量") % _zombie_name(str(zombie_type))
	)
	card.set_process(false)
	var selected := required_simple_zombie or (
		_simple_zombie_pool().has(zombie_type) if _is_simple_mode()
		else not _find_group(level["waves"][selected_wave], str(zombie_type)).is_empty()
	)
	card.modulate = Color.WHITE if selected else UNSELECTED_CARD_MODULATE
	_force_font_recursive(card)
	var button := card.get_node_or_null("Button") as Button
	if button != null:
		for connection in button.pressed.get_connections():
			button.pressed.disconnect(connection.callable)
		button.disabled = not simple_supported
		button.pressed.connect((_select_simple_zombie if _is_simple_mode() else _open_zombie_quantity_dialog).bind(str(zombie_type)))
		button.gui_input.connect(_on_workshop_card_gui_input.bind("zombie", zombie_type))
	holder.add_child(card)
	if _is_formal_first_appearance_zombie(zombie_type):
		_add_card_state_badge(holder, "新", Color("d77835"))
	if not simple_role.is_empty():
		_add_simple_role_checkbox(holder, zombie_type, simple_role)
	if required_simple_zombie:
		_add_card_state_glow(holder, Color("d77835"))
	return holder


func _is_formal_first_appearance_zombie(zombie_type: int) -> bool:
	if not FormalLevelStore.is_formal_preset_id(formal_preset_id):
		return false
	var preset_index := _formal_preset_index()
	if preset_index < 0:
		return false
	var current_zombies := Logic._cover_zombie_types(level)
	if not current_zombies.has(zombie_type):
		return false
	if preset_index == 0:
		return not [101, 501].has(zombie_type)
	var presets := AdventurePresets.list_presets("normal")
	for previous_index in preset_index:
		var previous_id := str((presets[previous_index] as Dictionary).get("id", ""))
		var previous_level := AdventurePresets.build_level(previous_id, true)
		if Logic._cover_zombie_types(previous_level).has(zombie_type):
			return false
	return not [101, 501].has(zombie_type)


func _add_simple_role_checkbox(holder: Control, zombie_type: int, role: String) -> void:
	var checked := zombie_type == (_simple_base_zombie_type() if role == "base" else _simple_flag_zombie_type())
	var checkbox := TextureButton.new()
	checkbox.position = Vector2(36, 2)
	checkbox.size = Vector2(24, 24)
	checkbox.z_index = 40
	checkbox.ignore_texture_size = true
	checkbox.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	checkbox.texture_normal = CHECKBOX_ON if checked else CHECKBOX_OFF
	checkbox.texture_hover = CHECKBOX_ON
	checkbox.tooltip_text = ("当前基础僵尸单位" if role == "base" else "当前旗帜波固定僵尸") if checked else \
		("设为基础僵尸单位" if role == "base" else "设为旗帜波固定僵尸")
	checkbox.pressed.connect(_set_simple_zombie_role.bind(zombie_type, role))
	holder.add_child(checkbox)


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
	var normal_available_mode: bool = Global.level_workshop_edit_mode == "normal"
	var formal_reward_mode := normal_available_mode and FormalLevelStore.is_formal_preset_id(formal_preset_id)
	var is_current_reward := formal_reward_mode and _formal_reward_plants().has(type_id)
	var selected := (_selected_available_plants().has(type_id) or is_current_reward) if normal_available_mode else \
		(level["chessboardConfig"].get("plantCardPool" if is_plant else "zombieCardPool", []) as Array).has(type_id)
	var locked: bool = normal_available_mode and locked_available_plant_types.has(type_id)
	card.modulate = Color.WHITE if selected else UNSELECTED_CARD_MODULATE
	if locked:
		card.tooltip_text = "此前已获得的植物；本关必定可选且不能取消"
	elif is_current_reward:
		card.tooltip_text = "本关通关奖励；点击取消"
	elif formal_reward_mode:
		card.tooltip_text = "添加为本关通关奖励"
	elif normal_available_mode:
		card.tooltip_text = "%s本关可选卡片" % ("移出" if selected else "加入")
	else:
		card.tooltip_text = "%s奖励%s" % ["移除" if selected else "加入", "植物卡槽" if is_plant else "友军僵尸卡槽"]
	_force_font_recursive(card)
	var button := card.get_node_or_null("Button") as Button
	if button != null:
		for connection in button.pressed.get_connections():
			button.pressed.disconnect(connection.callable)
		button.pressed.connect(_toggle_reward_card.bind(type_id, is_plant))
		button.gui_input.connect(_on_workshop_card_gui_input.bind("plant" if is_plant else "zombie", type_id))
	holder.add_child(card)
	if is_current_reward:
		_add_card_state_glow(holder, Color("ffd34e"), 0.95)
	elif locked:
		_add_card_state_glow(holder, Color("69a956"))
	if is_current_reward:
		_add_card_state_badge(holder, "奖", Color("e69a16"))
	return holder


func _add_card_state_glow(holder: Control, color: Color, opacity: float = 0.72) -> void:
	var glow := TextureRect.new()
	glow.name = "CardStateGlow"
	glow.position = Vector2(-5, -4)
	glow.size = Vector2(72, 95)
	glow.texture = SEED_PACKET_GLOW
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.modulate = Color(color.r, color.g, color.b, opacity)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	## 负 z_index 会把光效压到卡片列表背景之后。让卡片自身高一层，
	## 光效留在当前画布层，才能稳定显示在卡片背后。
	glow.z_index = 0
	holder.add_child(glow)
	if opacity > 0.72:
		var pulse := glow.create_tween().set_loops()
		pulse.tween_property(glow, "modulate:a", 0.62, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse.tween_property(glow, "modulate:a", opacity, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var card := holder.get_child(0) as Control
	if card != null:
		card.z_index = 1


func _add_card_state_badge(holder: Control, text: String, color: Color) -> void:
	var badge := TextureRect.new()
	badge.name = "CardStateBadge"
	badge.position = Vector2(20, 0)
	badge.size = Vector2(42, 25)
	badge.texture = PAGE_BUTTON
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.stretch_mode = TextureRect.STRETCH_SCALE
	badge.modulate = color
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.z_index = 20
	holder.add_child(badge)
	var label := Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", WORKSHOP_FONT)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color("fffbd1"))
	label.add_theme_color_override("font_outline_color", Color("6c3600"))
	label.add_theme_constant_override("outline_size", 3)
	badge.add_child(label)


func _on_workshop_card_gui_input(event: InputEvent, kind: String, type_id: int) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null or mouse_event.button_index != MOUSE_BUTTON_RIGHT or not mouse_event.pressed:
		return
	context_card_kind = kind
	context_card_type = type_id
	if not is_instance_valid(card_context_menu):
		card_context_menu = PopupMenu.new()
		card_context_menu.id_pressed.connect(_on_card_context_menu_pressed)
		add_child(card_context_menu)
		_force_font_recursive(card_context_menu)
	card_context_menu.clear()
	card_context_menu.add_item("编辑全局数值", CARD_CONTEXT_EDIT_GLOBAL)
	card_context_menu.position = Vector2i(get_viewport().get_mouse_position())
	card_context_menu.popup()
	get_viewport().set_input_as_handled()


func _on_card_context_menu_pressed(item_id: int) -> void:
	if context_card_type < 0:
		return
	if item_id != CARD_CONTEXT_EDIT_GLOBAL:
		return
	DraftStore.save_autosave(level)
	Global.developer_workshop_level_source = level.duplicate(true)
	Global.level_workshop_return_state = {
		"catalog_mode": catalog_mode,
		"card_page": current_card_page,
		"selected_wave": selected_wave,
		"editor_complexity": editor_complexity,
	}
	Global.numerical_editor_context = {
		"origin": "level_workshop",
		"kind": context_card_kind,
		"id": context_card_type,
	}
	get_tree().change_scene_to_file(Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.NumericalEditor])


func _toggle_reward_card(type_id: int, is_plant: bool) -> void:
	if Global.level_workshop_edit_mode == "normal":
		if FormalLevelStore.is_formal_preset_id(formal_preset_id):
			if locked_available_plant_types.has(type_id):
				status_label.text = "这张卡此前已获得，本关必定可选，不能取消"
				return
			if _formal_reward_plants().has(type_id):
				var rewards := _formal_reward_plants()
				rewards.erase(type_id)
				_set_formal_reward_plants(rewards)
				_changed("已取消本关通关奖励")
			else:
				var conflicts := _later_formal_reward_conflicts(type_id)
				if not conflicts.is_empty():
					_open_reward_conflict_dialog(type_id, conflicts)
					return
				_set_formal_reward_plant(type_id)
			_refresh_card_page()
			_update_catalog_button_label()
			return
		var selected := _selected_available_plants()
		if selected.has(type_id):
			if locked_available_plant_types.has(type_id):
				status_label.text = "这张卡来自冒险进度基础卡池，不能取消"
				return
			selected.erase(type_id)
			var forced: Array = level.get("forcedPlants", [])
			forced.erase(type_id)
			level["forcedPlants"] = forced
		else:
			selected.append(type_id)
		level["availablePlants"] = selected
		level["plantSelectionEnabled"] = true
		_changed("本关可选植物 %d 张" % selected.size())
		_refresh_card_page()
		return
	var pool_key := "plantCardPool" if is_plant else "zombieCardPool"
	var pool: Array = level["chessboardConfig"].get(pool_key, [])
	if pool.has(type_id):
		pool.erase(type_id)
	else:
		pool.append(type_id)
	level["chessboardConfig"][pool_key] = pool
	_changed("奖励植物 %d 张" % (level["chessboardConfig"]["plantCardPool"] as Array).size())
	_refresh_card_page()


func _set_formal_reward_plant(type_id: int) -> void:
	var rewards := _formal_reward_plants()
	if not rewards.has(type_id):
		rewards.append(type_id)
	_set_formal_reward_plants(rewards)
	_changed("本关通关奖励：%s（共 %d 张）" % [_plant_name(type_id), rewards.size()])
	_refresh_card_page()
	_update_catalog_button_label()


func _formal_reward_plants() -> Array[int]:
	return Logic.reward_plant_types(level)


func _set_formal_reward_plants(rewards: Array[int]) -> void:
	level["rewardPlants"] = rewards.duplicate()
	level["rewardPlant"] = rewards[0] if not rewards.is_empty() else -1


func _later_formal_reward_conflicts(type_id: int) -> Array[Dictionary]:
	var conflicts: Array[Dictionary] = []
	var presets := AdventurePresets.list_presets("normal")
	var current_index := _formal_preset_index()
	if current_index < 0:
		return conflicts
	for index in range(current_index + 1, presets.size()):
		var preset: Dictionary = presets[index]
		var preset_id := str(preset.get("id", ""))
		var later_level := AdventurePresets.build_level(preset_id, true)
		if Logic.reward_plant_types(later_level).has(type_id):
			conflicts.append({"id": preset_id, "name": str(later_level.get("name", preset_id))})
	return conflicts


func _clear_later_duplicate_formal_rewards(type_id: int) -> Dictionary:
	var cleared_names: Array[String] = []
	var failed_names: Array[String] = []
	if type_id < 0:
		return {"cleared": cleared_names, "failed": failed_names}
	for conflict in _later_formal_reward_conflicts(type_id):
		var preset_id := str(conflict.get("id", ""))
		var later_level := AdventurePresets.build_level(preset_id, true)
		if later_level.is_empty():
			failed_names.append(str(conflict.get("name", preset_id)))
			continue
		var later_rewards := Logic.reward_plant_types(later_level)
		later_rewards.erase(type_id)
		later_level["rewardPlants"] = later_rewards
		later_level["rewardPlant"] = later_rewards[0] if not later_rewards.is_empty() else -1
		var result := FormalLevelStore.save_developer_level(later_level, preset_id)
		if result["ok"]:
			cleared_names.append(str(conflict.get("name", preset_id)))
		else:
			failed_names.append(str(conflict.get("name", preset_id)))
	return {"cleared": cleared_names, "failed": failed_names}


func _open_reward_conflict_dialog(type_id: int, conflicts: Array[Dictionary]) -> void:
	if is_instance_valid(reward_conflict_dialog):
		reward_conflict_dialog.queue_free()
	var conflict_names: Array[String] = []
	for conflict in conflicts:
		conflict_names.append(str(conflict.get("name", conflict.get("id", "后续关卡"))))
	reward_conflict_dialog = ConfirmationDialog.new()
	reward_conflict_dialog.title = "奖励植物重复"
	reward_conflict_dialog.ok_button_text = "仍添加为本关奖励"
	reward_conflict_dialog.cancel_button_text = "取消"
	reward_conflict_dialog.dialog_text = "%s 已是后续关卡（%s）的奖励。\n仍要提前奖励吗？后续关卡将需要新增奖励植物。" % [
		_plant_name(type_id),
		"、".join(conflict_names),
	]
	reward_conflict_dialog.min_size = Vector2i(560, 210)
	reward_conflict_dialog.confirmed.connect(func():
		_set_formal_reward_plant(type_id)
		reward_conflict_dialog.queue_free()
	)
	reward_conflict_dialog.canceled.connect(func(): reward_conflict_dialog.queue_free())
	reward_conflict_dialog.tree_exited.connect(func(): reward_conflict_dialog = null)
	add_child(reward_conflict_dialog)
	_force_font_recursive(reward_conflict_dialog)
	reward_conflict_dialog.popup_centered(Vector2i(560, 210))


func _clear_all_cards() -> void:
	if catalog_mode != CatalogMode.REWARD_CARDS:
		return
	if Global.level_workshop_edit_mode == "normal":
		var retained: Array[int] = locked_available_plant_types.duplicate()
		var retained_forced: Array = []
		for plant_type in level.get("forcedPlants", []):
			if retained.has(int(plant_type)):
				retained_forced.append(int(plant_type))
		level["availablePlants"] = retained
		level["forcedPlants"] = retained_forced
		level["plantSelectionEnabled"] = true
		if FormalLevelStore.is_formal_preset_id(formal_preset_id):
			_set_formal_reward_plants([])
		_changed("已清空所有可移除的植物卡" if not retained.is_empty() else "已清空所有植物卡")
		_update_catalog_button_label()
	else:
		level["chessboardConfig"]["plantCardPool"] = []
		_changed("已清空奖励植物卡槽")
	_refresh_card_page()


func _toggle_reward_catalog() -> void:
	catalog_mode = CatalogMode.REWARD_CARDS if catalog_mode == CatalogMode.SPAWN_ZOMBIES else CatalogMode.SPAWN_ZOMBIES
	current_card_page = 0
	var show_rewards := catalog_mode == CatalogMode.REWARD_CARDS
	_update_catalog_background(show_rewards)
	_refresh_stage_heading()
	_update_catalog_button_label()
	wave_title.visible = not show_rewards
	wave_summary.visible = not show_rewards and not _is_simple_mode()
	_refresh_simple_pool_toggle()
	road_title.visible = not show_rewards
	road_hint.visible = not show_rewards
	preview_root.visible = not show_rewards
	_update_timeline_catalog_visibility()
	## 奖励池编辑时把草坪主体移入右侧可视区，退出后恢复道路预览视角。
	var target_x := background_normal_x + 334.0 if show_rewards else background_normal_x
	create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT).tween_property(background_sprite, "position:x", target_x, 0.3)
	if show_rewards:
		if Global.level_workshop_edit_mode == "normal" and FormalLevelStore.is_formal_preset_id(formal_preset_id):
			status_label.text = "此前已有的植物必定选择且不能取消；可点击多张新卡添加本关奖励"
		else:
			status_label.text = ("点击植物加入本关卡池；亮色为已选，再次点击取消" if _is_simple_mode() else "点击植物卡设置本关卡池；亮色为已选，冒险基础卡不可取消") if Global.level_workshop_edit_mode == "normal" else "点击原版植物卡加入或移出奖励卡槽；亮色为已选择"
	else:
		status_label.text = "点击卡片选择本阶段允许出现的僵尸；亮色为已选" if _is_simple_mode() else "点击卡片，设置本阶段出场数量；亮色为已设置"
	_refresh_card_page()


func _restore_catalog_view() -> void:
	var show_rewards := catalog_mode == CatalogMode.REWARD_CARDS
	_refresh_map_preview()
	_update_catalog_background(show_rewards)
	_refresh_stage_heading()
	_update_catalog_button_label()
	wave_title.visible = not show_rewards
	wave_summary.visible = not show_rewards and not _is_simple_mode()
	_refresh_simple_pool_toggle()
	road_title.visible = not show_rewards
	road_hint.visible = not show_rewards
	preview_root.visible = not show_rewards
	background_sprite.position.x = background_normal_x + 334.0 if show_rewards else background_normal_x
	_update_timeline_editability()
	_update_timeline_catalog_visibility()


func _update_catalog_background(show_plant_cards: bool) -> void:
	if not is_instance_valid(drawer_paper):
		return
	drawer_paper.texture = PLANT_ALMANAC_BACKGROUND if show_plant_cards else ALMANAC_BACKGROUND


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


func _select_simple_zombie(zombie_key: String) -> void:
	var zombie_type := _zombie_type_id(zombie_key)
	if not _has_original_pick_weight(zombie_type) \
	and zombie_type != _simple_base_zombie_type() \
	and zombie_type != _simple_flag_zombie_type():
		status_label.text = "%s不支持简易自然波次，请改用进阶模式" % _zombie_name(zombie_key)
		return
	if zombie_type == _simple_base_zombie_type() or zombie_type == _simple_flag_zombie_type():
		_sanitize_simple_allowed_pool()
		_sync_all_simple_stage_type_pools()
		status_label.text = "%s是本关固定僵尸；请先勾选另一个同类单位再取消" % _zombie_name(zombie_key)
		_refresh_card_page()
		_refresh_wave()
		return
	var simple_pool := _simple_zombie_pool()
	if simple_pool.has(zombie_type):
		_delete_simple_zombie(zombie_key)
		return
	simple_pool.append(zombie_type)
	level["simpleZombiePool"] = simple_pool
	_sync_all_simple_stage_type_pools()
	_changed("已将%s加入本关允许僵尸表" % _zombie_name(zombie_key))
	_refresh_card_page()
	_refresh_wave()


func _open_simple_zombie_dialog(zombie_key: String) -> void:
	var zombie_type := _zombie_type_id(zombie_key)
	if not _simple_zombie_pool().has(zombie_type):
		return
	_close_quantity_dialog()
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
	dialog.position = Vector2(327, 105)
	dialog.size = Vector2(412, 390)
	dialog.texture = DIALOG_BACKGROUND
	dialog.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dialog.stretch_mode = TextureRect.STRETCH_SCALE
	dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	quantity_dialog_layer.add_child(dialog)
	var title := _paper_label(_zombie_name(zombie_key), Vector2(48, 42), Vector2(316, 44), 27, Color("e7e4d1"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", Color("25263b"))
	title.add_theme_constant_override("outline_size", 4)
	dialog.add_child(title)
	var hint := _paper_label("首次登场由系统对比此前冒险关卡自动判断；\n最终波会补齐本关全部自然僵尸种类。", Vector2(50, 91), Vector2(312, 66), 14, Color("d7bd80"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog.add_child(hint)
	var fixed_zombie := zombie_type == _simple_base_zombie_type() \
		or zombie_type == _simple_flag_zombie_type()
	var delete_button := _texture_button("删除僵尸", Vector2(53, 234), Vector2(142, 38), DIALOG_BUTTON, DIALOG_BUTTON, func():
		_close_quantity_dialog()
		_delete_simple_zombie(zombie_key)
	, 16)
	delete_button.disabled = fixed_zombie
	delete_button.tooltip_text = "本关固定僵尸必然登场；请先勾选另一个同类单位" if fixed_zombie else ""
	(delete_button.get_child(0) as Label).add_theme_color_override("font_color", Color("6f2118"))
	dialog.add_child(delete_button)
	dialog.add_child(_texture_button("取消", Vector2(217, 234), Vector2(142, 38), DIALOG_BUTTON, DIALOG_BUTTON, _close_quantity_dialog, 16))


func _delete_simple_zombie(zombie_key: String) -> void:
	var zombie_type := _zombie_type_id(zombie_key)
	if zombie_type == _simple_base_zombie_type() or zombie_type == _simple_flag_zombie_type():
		_sanitize_simple_allowed_pool()
		_sync_all_simple_stage_type_pools()
		status_label.text = "%s是本关固定僵尸；请先勾选另一个同类单位再删除" % _zombie_name(zombie_key)
		_refresh_card_page()
		_refresh_wave()
		return
	var simple_pool := _simple_zombie_pool()
	if not simple_pool.has(zombie_type):
		return
	simple_pool.erase(zombie_type)
	level["simpleZombiePool"] = simple_pool
	_sync_all_simple_stage_type_pools()
	_changed("已将%s移出本关允许僵尸表" % _zombie_name(zombie_key))
	_refresh_card_page()
	_refresh_wave()


func _sync_simple_stage_type_pool() -> void:
	if not _is_simple_mode():
		return
	var stages: Array = level.get("waves", [])
	if stages.is_empty():
		return
	var source_groups: Array = []
	for zombie_type in _simple_zombie_pool():
		source_groups.append(Logic.make_group(
			"simple_pool_%d" % zombie_type,
			str(zombie_type), 1, 0.0, "fixed", 2.0, "random", Logic.fit_lane_weights([], 5)
		))
	for stage_index in stages.size():
		var stage: Dictionary = stages[stage_index]
		var copied_groups: Array = source_groups.duplicate(true)
		for group_index in copied_groups.size():
			var zombie_type := _zombie_type_id((copied_groups[group_index] as Dictionary).get("zombieType", "500"))
			copied_groups[group_index]["id"] = "simple_%d_%d_%d" % [stage_index, zombie_type, group_index]
		stage["spawnGroups"] = copied_groups


func _sync_all_simple_stage_type_pools() -> void:
	_sync_simple_stage_type_pool()


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
	_close_cover_characters_dialog()
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
	wave_title.text = "本关允许僵尸" if _is_simple_mode() else (("第 %d 面旗帜" if is_flag else "旗帜间隔 %d") % stage_number)
	_refresh_stage_heading()
	if catalog_mode == CatalogMode.REWARD_CARDS:
		_refresh_timeline()
		return
	road_title.text = ("本关允许僵尸" if _is_simple_mode() else (("旗帜第 %d 波" if is_flag else "波间间隔 %d") % stage_number)) + " · 道路预览"
	road_hint.text = "这个阶段还没有僵尸\n请点击左侧卡片"
	wave_summary.text = ("PvZ1 原版权重抽取　%d 种" if _is_simple_mode() else "%s　共 %d 只") % ([_wave_zombie_type_count(wave)] if _is_simple_mode() else ["旗帜前动态推进" if not is_flag else "旗帜波动态推进", _wave_total_count(wave)])
	_refresh_road_zombies()
	_refresh_timeline()
	_refresh_simple_pool_toggle()


func _refresh_stage_heading() -> void:
	if not is_instance_valid(stage_heading):
		return
	_update_formal_level_navigation()
	var level_name := str(level.get("name", "")).strip_edges()
	stage_heading.text = level_name if not level_name.is_empty() else "未命名关卡"


func _refresh_road_zombies() -> void:
	_clear_preview_zombies()
	var wave: Dictionary = level["waves"][selected_wave]
	var total := _wave_zombie_type_count(wave) if _is_simple_mode() else _wave_total_count(wave)
	road_title.text = ("本关允许僵尸 · 马路预览 · %d 种" % total) if _is_simple_mode() else ("当前阶段 · 马路预览 · 共 %d 只" % total)
	road_hint.visible = total == 0 or total > PREVIEW_MAX_ZOMBIES
	if total == 0:
		road_hint.text = "这个阶段还没有僵尸\n请点击左侧卡片"
		return
	if total > PREVIEW_MAX_ZOMBIES:
		road_hint.text = "当前阶段共 %d 只\n马路随机展示前 %d 只" % [total, PREVIEW_MAX_ZOMBIES]
	var random := RandomNumberGenerator.new()
	random.seed = int(level.get("randomSeed", 1)) + selected_wave * 7919
	var index := 0
	var shown_types: Dictionary = {}
	for group in wave.get("spawnGroups", []):
		var zombie_key := str(group.get("zombieType", "500"))
		if _is_simple_mode() and shown_types.has(_zombie_type_id(zombie_key)):
			continue
		shown_types[_zombie_type_id(zombie_key)] = true
		var preview_count := 1 if _is_simple_mode() else int(group["count"])
		for _instance_index in preview_count:
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
		preview_hit_layer.tooltip_text = "" if hovered_zombie == null else (("点击设置%s" if _is_simple_mode() else "点击删除一个%s") % _zombie_name(str(preview_zombie_keys.get(hovered_zombie.get_instance_id(), "500"))))
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
	if _is_simple_mode():
		_open_simple_zombie_dialog(zombie_key)
	else:
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
	## 顶部标题与主界面的“菜单”基线对齐，同时仍让弹窗完整落在 600 高的画布内。
	dialog.position = Vector2(223, 20)
	dialog.size = Vector2(620, 580)
	dialog.texture = DIALOG_BACKGROUND
	dialog.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dialog.stretch_mode = TextureRect.STRETCH_SCALE
	dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	quantity_dialog_layer.add_child(dialog)
	var title := _paper_label("简易关卡设置" if _is_simple_mode() else "进阶关卡设置", Vector2(90, 28), Vector2(440, 48), 29, Color("f3e7ba"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", Color("25263b"))
	title.add_theme_constant_override("outline_size", 4)
	dialog.add_child(title)
	if loaded_source_kind == "template" and FormalLevelStore.is_formal_preset_id(formal_preset_id):
		title.position.x = 48.0
		title.size.x = 374.0
		var sync_callback := func():
			_close_quantity_dialog()
			_request_leave_with_unsaved_check(_open_formal_sync_dialog)
		dialog.add_child(_texture_button("批量同步", Vector2(438, 34), Vector2(132, 38), DIALOG_BUTTON, DIALOG_BUTTON, sync_callback, 15))
	var name_input := _settings_line(dialog, "关卡名称", Vector2(76, 78), str(level["name"]))
	name_input.size.x = 456
	_add_cover_settings_button(dialog)
	if _is_simple_mode():
		_build_simple_level_settings(dialog, name_input)
		return
	var sun := _settings_spin(dialog, "开局阳光", Vector2(76, 150), 0, 9999, int(level["playerConfig"]["initialSun"]), 25)
	var sun_speed := _settings_spin(dialog, "天降阳光速度倍率", Vector2(322, 150), 0.1, 10.0, float(level["playerConfig"].get("sunDropSpeed", 1.0)), 0.1)
	var cooldown := _settings_spin(dialog, "冷却时长倍率", Vector2(76, 222), 0.0, 10.0, float(level["playerConfig"].get("cooldownMultiplier", 1.0)), 0.05)
	var chessboard: Dictionary = level.get("chessboardConfig", {})
	var mine_count: SpinBox
	var plant_probability: SpinBox
	var enemy_probability: SpinBox
	if str(level.get("workshopMode", "normal")) == "chessboard":
		var chess_title := _paper_label("棋盘格专属", Vector2(76, 294), Vector2(468, 30), 20, Color("e9d28a"))
		chess_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dialog.add_child(chess_title)
		mine_count = _settings_spin(dialog, "地雷数量上限", Vector2(76, 330), 0, 45, int(chessboard.get("mineCount", 8)), 1)
		plant_probability = _settings_spin(dialog, "植物卡概率", Vector2(322, 330), 0.0, 1.0, float(chessboard.get("plantCardProbability", 0.25)), 0.01)
		enemy_probability = _settings_spin(dialog, "敌对僵尸概率", Vector2(322, 402), 0.0, 1.0, float(chessboard.get("enemyZombieProbability", 0.30)), 0.01)
	var save_callback := func():
		_save_level_settings(name_input, sun, sun_speed, cooldown, chessboard, mine_count, plant_probability, enemy_probability)
	dialog.add_child(_texture_button("取消", Vector2(145, 510), Vector2(142, 42), DIALOG_BUTTON, DIALOG_BUTTON, _close_quantity_dialog, 17))
	dialog.add_child(_texture_button("确认", Vector2(333, 510), Vector2(142, 42), DIALOG_BUTTON, DIALOG_BUTTON, save_callback, 17))


func _build_simple_level_settings(dialog: Control, name_input: LineEdit) -> void:
	var map_picker := _settings_option(dialog, "地图", Vector2(76, 150))
	for map_name in SIMPLE_MAP_NAMES:
		map_picker.add_item(map_name)
	var current_map := str((level.get("mapConfig", {}) as Dictionary).get("type", "front_lawn"))
	map_picker.select(maxi(0, SIMPLE_MAP_TYPES.find(current_map)))
	var refresh_speed := _settings_spin(dialog, "僵尸刷新速度倍率", Vector2(322, 150), 0.1, 5.0, float(level.get("zombieRefreshSpeedMultiplier", 1.0)), 0.05)
	var sun := _settings_spin(dialog, "开局阳光", Vector2(76, 222), 0, 9999, int(level["playerConfig"]["initialSun"]), 25)
	var plant_hint := _paper_label("刷新倍率 1.0 为原速，越大换波越快。\n正式关卡的通关奖励请在左侧“可选卡片”中选择", Vector2(76, 292), Vector2(468, 72), 14, Color("d7bd80"))
	plant_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialog.add_child(plant_hint)
	var special_title := _paper_label("地图特殊设定", Vector2(76, 374), Vector2(468, 28), 20, Color("e9d28a"))
	special_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialog.add_child(special_title)
	var environment: Dictionary = level.get("environmentConfig", {})
	var tombstones_enabled := bool(environment.get("tombstoneSpawns", false))
	var tombstone_checkbox := _settings_checkbox(dialog, "启用墓碑", Vector2(76, 410), tombstones_enabled)
	var tombstone_count := _settings_spin(dialog, "初始墓碑数量", Vector2(322, 402), 0, 45, int(environment.get("initialTombstones", 0)), 1)
	var bungee_enabled := bool(environment.get("bungee", false))
	var bungee_checkbox := _settings_checkbox(dialog, "启用蹦极大波", Vector2(76, 410), bungee_enabled)
	tombstone_checkbox.toggled.connect(func(checked: bool):
		_set_checkbox_texture(tombstone_checkbox, checked)
		tombstone_count.editable = checked
	)
	bungee_checkbox.toggled.connect(func(checked: bool):
		_set_checkbox_texture(bungee_checkbox, checked)
	)
	var no_special := _paper_label("该地图没有需要手动启用的原版特殊机制", Vector2(76, 410), Vector2(468, 34), 15, Color("d7bd80"))
	no_special.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialog.add_child(no_special)
	var refresh_special_visibility := func(index: int):
		var map_type: String = SIMPLE_MAP_TYPES[clampi(index, 0, SIMPLE_MAP_TYPES.size() - 1)]
		var is_night := map_type == "night_lawn"
		var is_roof := map_type == "roof"
		tombstone_checkbox.visible = is_night
		_set_settings_field_visible(tombstone_count, is_night)
		bungee_checkbox.visible = is_roof
		no_special.visible = not is_night and not is_roof
		tombstone_count.editable = tombstone_checkbox.button_pressed
	map_picker.item_selected.connect(refresh_special_visibility)
	refresh_special_visibility.call(map_picker.selected)
	var save_callback := func():
		var level_name := name_input.text.strip_edges()
		if level_name.is_empty():
			status_label.text = "设置失败：关卡名称不能为空"
			return
		var map_type: String = SIMPLE_MAP_TYPES[clampi(map_picker.selected, 0, SIMPLE_MAP_TYPES.size() - 1)]
		level["name"] = level_name
		level["mapConfig"] = {"type": map_type, "rows": 6 if map_type == "pool" or map_type == "fog" else 5, "columns": 9}
		level["activeLawnRows"] = range(6 if map_type == "pool" or map_type == "fog" else 5)
		level["playerConfig"]["initialSun"] = int(sun.value)
		level["playerConfig"]["sunDropSpeed"] = 1.0
		level["playerConfig"]["cooldownMultiplier"] = 1.0
		level["zombieRefreshSpeedMultiplier"] = float(refresh_speed.value)
		level["plantSelectionEnabled"] = true
		level["forcedPlants"] = []
		level["freePlantSelection"] = true
		level["environmentConfig"] = {
			"initialTombstones": int(tombstone_count.value) if map_type == "night_lawn" and tombstone_checkbox.button_pressed else 0,
			"tombstoneSpawns": map_type == "night_lawn" and tombstone_checkbox.button_pressed,
			"bungee": map_type == "roof" and bungee_checkbox.button_pressed,
		}
		_apply_formal_map_constraints()
		_refresh_map_preview()
		_sanitize_simple_allowed_pool()
		_refresh_zombie_catalog()
		_refresh_card_page()
		_close_quantity_dialog()
		_changed("简易关卡设置已保存")
		_refresh_wave()
	dialog.add_child(_texture_button("取消", Vector2(145, 510), Vector2(142, 42), DIALOG_BUTTON, DIALOG_BUTTON, _close_quantity_dialog, 17))
	dialog.add_child(_texture_button("确认", Vector2(333, 510), Vector2(142, 42), DIALOG_BUTTON, DIALOG_BUTTON, save_callback, 17))


func _save_level_settings(name_input: LineEdit, sun: SpinBox, sun_speed: SpinBox, cooldown: SpinBox, chessboard: Dictionary, mine_count: SpinBox, plant_probability: SpinBox, enemy_probability: SpinBox) -> void:
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
	level["name"] = level_name
	level["playerConfig"]["initialSun"] = int(sun.value)
	level["playerConfig"]["sunDropSpeed"] = float(sun_speed.value)
	level["playerConfig"]["cooldownMultiplier"] = float(cooldown.value)
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


func _settings_option(parent: Control, label_text: String, pos: Vector2) -> OptionButton:
	var label := _paper_label(label_text, pos, Vector2(210, 25), 16, Color("e9d28a"))
	parent.add_child(label)
	var input := OptionButton.new()
	input.position = pos + Vector2(0, 27)
	input.size = Vector2(210, 34)
	input.add_theme_font_override("font", WORKSHOP_FONT)
	input.add_theme_font_size_override("font_size", 16)
	input.add_theme_color_override("font_color", Color("f5edcf"))
	input.set_meta("settings_label", label)
	parent.add_child(input)
	return input


func _settings_checkbox(parent: Control, label_text: String, pos: Vector2, checked: bool) -> TextureButton:
	var checkbox := TextureButton.new()
	checkbox.position = pos
	checkbox.size = Vector2(235, 42)
	checkbox.toggle_mode = true
	checkbox.button_pressed = checked
	checkbox.set_meta("settings_checkbox_label", label_text)
	checkbox.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	parent.add_child(checkbox)
	var icon := TextureRect.new()
	icon.position = Vector2.ZERO
	icon.size = Vector2(42, 42)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	checkbox.add_child(icon)
	checkbox.set_meta("checkbox_icon", icon)
	var label := _paper_label(label_text, Vector2(50, 0), Vector2(185, 42), 20, Color("e9d28a"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	checkbox.add_child(label)
	_set_checkbox_texture(checkbox, checked)
	return checkbox


func _set_checkbox_texture(checkbox: TextureButton, checked: bool) -> void:
	checkbox.button_pressed = checked
	var icon = checkbox.get_meta("checkbox_icon", null)
	if icon is TextureRect:
		(icon as TextureRect).texture = CHECKBOX_ON if checked else CHECKBOX_OFF


func _settings_spin(parent: Control, label_text: String, pos: Vector2, min_value: float, max_value: float, value: float, step: float) -> SpinBox:
	var label := _paper_label(label_text, pos, Vector2(210, 25), 16, Color("e9d28a"))
	parent.add_child(label)
	var input := SpinBox.new()
	input.position = pos + Vector2(0, 27)
	input.size = Vector2(210, 34)
	input.min_value = min_value
	input.max_value = max_value
	input.step = step
	## 先设定小数步长再赋值，避免按 SpinBox 默认的整数步长吸附。
	input.value = value
	input.add_theme_font_override("font", WORKSHOP_FONT)
	input.add_theme_font_size_override("font_size", 16)
	input.add_theme_color_override("font_color", Color("f5edcf"))
	input.set_meta("settings_label", label)
	parent.add_child(input)
	return input


func _set_settings_field_visible(input: Control, is_visible: bool) -> void:
	input.visible = is_visible
	var label = input.get_meta("settings_label", null)
	if label is Control:
		(label as Control).visible = is_visible


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


func _wave_zombie_type_count(wave: Dictionary) -> int:
	var types: Dictionary = {}
	for group in wave.get("spawnGroups", []):
		types[_zombie_type_id((group as Dictionary).get("zombieType", "500"))] = true
	return types.size()


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
	## 使用副本；后续刷新会 clear 本地缓存，不能连带清空 AllCards 权威注册表。
	zombie_card_prefabs = all_cards.all_zombie_card_prefabs.duplicate()
	for zombie_type in zombie_card_prefabs.keys():
		var zombie_id := int(zombie_type)
		## 普通工坊与植物卡池一致：所有已制作且已注册的僵尸卡都可见。
		if Global.level_workshop_edit_mode == "normal" and zombie_id != int(CharacterRegistry.ZombieType.Null) \
		and CharacterRegistry.ZombieInfo.has(zombie_id):
			zombie_card_order.append(zombie_id)
		elif Global.level_workshop_edit_mode == "chessboard" and zombie_id >= 500 and zombie_id < 1000:
			zombie_card_order.append(zombie_id)
	plant_card_prefabs = all_cards.all_plant_card_prefabs.duplicate()
	for plant_type in plant_card_prefabs.keys():
		var plant_id := int(plant_type)
		if Global.level_workshop_edit_mode == "chessboard" and plant_id >= 500 and plant_id < 1000:
			reward_card_order.append({"id": plant_id, "is_plant": true})
		elif Global.level_workshop_edit_mode == "normal" and plant_id > 0 and plant_id < 1000 \
		and CharacterRegistry.PlantInfo.has(plant_id):
			reward_card_order.append({"id": plant_id, "is_plant": true})
	zombie_card_order.sort_custom(func(left, right):
		return int(all_cards.zombie_card_ids.get(left, 999999)) < int(all_cards.zombie_card_ids.get(right, 999999))
	)
	reward_card_order.sort_custom(func(left: Dictionary, right: Dictionary):
		return int(all_cards.plant_card_ids.get(int(left["id"]), 999999)) \
			< int(all_cards.plant_card_ids.get(int(right["id"]), 999999))
	)
	var registry := get_node_or_null("/root/Global/Registry/CharacterRegistry") as CharacterRegistry
	if registry != null:
		for zombie_type in zombie_card_order:
			zombie_names[zombie_type] = str(registry.get_zombie_info(zombie_type as CharacterRegistry.ZombieType, CharacterRegistry.ZombieInfoAttribute.ZombieName))


func _has_original_pick_weight(zombie_type: int) -> bool:
	if int(ZombieWaveCreateManager.zombie_weights_ori.get(zombie_type, AdventurePresets.ZOMBIE_WEIGHTS.get(zombie_type, 0))) <= 0:
		return false
	var map_type := str((level.get("mapConfig", {}) as Dictionary).get("type", "front_lawn"))
	return not AdventurePresets.POOL_ONLY_ZOMBIES.has(zombie_type) or ["pool", "fog"].has(map_type)


func _sanitize_simple_allowed_pool() -> void:
	if not _is_simple_mode():
		return
	var required_zombie := _simple_base_zombie_type()
	var source_pool: Array = level.get("simpleZombiePool", [])
	if source_pool.is_empty():
		for stage in level.get("waves", []):
			for group in (stage as Dictionary).get("spawnGroups", []):
				source_pool.append(_zombie_type_id((group as Dictionary).get("zombieType", "500")))
	var once_final: Array = level.get("simpleOnceFinalZombies", [])
	var filtered_pool: Array[int] = []
	for value in source_pool:
		var zombie_type := int(value)
		var allow := (zombie_type == required_zombie or _has_original_pick_weight(zombie_type)) \
		or once_final.has(zombie_type)
		if allow and not filtered_pool.has(zombie_type):
			filtered_pool.append(zombie_type)
	## 一次性终局 Boss 未在池中时自动补入，避免保存后丢失。
	for boss_type in once_final:
		if int(boss_type) > 0 and not filtered_pool.has(int(boss_type)):
			filtered_pool.append(int(boss_type))
	if not filtered_pool.has(required_zombie):
		filtered_pool.push_front(required_zombie)
	level["simpleZombiePool"] = filtered_pool
	_sync_all_simple_stage_type_pools()


func _simple_zombie_pool() -> Array[int]:
	var result: Array[int] = []
	for value in level.get("simpleZombiePool", []):
		var zombie_type := int(value)
		if zombie_type > 0 and not result.has(zombie_type):
			result.append(zombie_type)
	var required_zombie := _simple_base_zombie_type()
	if not result.has(required_zombie):
		result.push_front(required_zombie)
	return result


func _simple_base_zombie_type() -> int:
	var zombie_type := int(level.get("simpleBaseZombieType", CharacterRegistry.ZombieType.Z000NormTalon))
	return zombie_type if SIMPLE_BASE_ZOMBIE_CANDIDATES.has(zombie_type) else int(CharacterRegistry.ZombieType.Z000NormTalon)


func _simple_flag_zombie_type() -> int:
	var zombie_type := int(level.get("simpleFlagZombieType", CharacterRegistry.ZombieType.Z001FlagTalon))
	return zombie_type if SIMPLE_FLAG_ZOMBIE_CANDIDATES.has(zombie_type) else int(CharacterRegistry.ZombieType.Z001FlagTalon)


func _simple_zombie_role(zombie_type: int) -> String:
	if SIMPLE_BASE_ZOMBIE_CANDIDATES.has(zombie_type):
		return "base"
	if SIMPLE_FLAG_ZOMBIE_CANDIDATES.has(zombie_type):
		return "flag"
	return ""


func _set_simple_zombie_role(zombie_type: int, role: String) -> void:
	if role == "base" and SIMPLE_BASE_ZOMBIE_CANDIDATES.has(zombie_type):
		level["simpleBaseZombieType"] = zombie_type
		_sanitize_simple_allowed_pool()
		_sync_all_simple_stage_type_pools()
		_changed("已将%s设为本关基础僵尸单位" % _zombie_name(str(zombie_type)))
	elif role == "flag" and SIMPLE_FLAG_ZOMBIE_CANDIDATES.has(zombie_type):
		level["simpleFlagZombieType"] = zombie_type
		_sanitize_simple_allowed_pool()
		_sync_all_simple_stage_type_pools()
		_changed("已将%s设为旗帜波固定僵尸" % _zombie_name(str(zombie_type)))
	else:
		return
	_refresh_card_page()
	_refresh_wave()


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


func _plant_name(plant_type: int) -> String:
	var registry := get_node_or_null("/root/Global/Registry/CharacterRegistry") as CharacterRegistry
	if registry != null and CharacterRegistry.PlantInfo.has(plant_type):
		return str(registry.get_plant_info(plant_type as CharacterRegistry.PlantType, CharacterRegistry.PlantInfoAttribute.PlantName))
	return "植物 %d" % plant_type


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


func _normalize_simple_timeline_spacing() -> void:
	## 简易时间轴按阶段数量等分显示，不改写进阶模式保存的精确持续时间。
	_end_timeline_mode()


func _set_simple_flag_count(target_count: int) -> void:
	target_count = clampi(target_count, 1, 20)
	var stages: Array = level.get("waves", [])
	while _count_stage_type("flag") < target_count:
		if stages.is_empty() or str((stages.back() as Dictionary).get("stageType", "flag")) != "interval":
			var interval_id := Logic.make_unique_id("interval", _all_ids())
			stages.append(Logic.make_wave(interval_id, "波间阶段", 0.0, DEFAULT_INTERVAL_DURATION, [], "interval"))
		var flag_id := Logic.make_unique_id("wave", _all_ids())
		stages.append(Logic.make_wave(flag_id, "旗帜波", 0.0, DEFAULT_FLAG_DURATION, [], "flag"))
	while _count_stage_type("flag") > target_count:
		var last_flag_index := -1
		for stage_index in range(stages.size() - 1, -1, -1):
			if str((stages[stage_index] as Dictionary).get("stageType", "flag")) == "flag":
				last_flag_index = stage_index
				break
		if last_flag_index < 0:
			break
		stages.remove_at(last_flag_index)
		if last_flag_index - 1 >= 0 and str((stages[last_flag_index - 1] as Dictionary).get("stageType", "flag")) == "interval":
			stages.remove_at(last_flag_index - 1)
	var interval_number := 0
	var flag_number := 0
	for stage in stages:
		if str((stage as Dictionary).get("stageType", "flag")) == "flag":
			flag_number += 1
			stage["name"] = "第 %d 波" % flag_number
			stage["duration"] = DEFAULT_FLAG_DURATION
		else:
			interval_number += 1
			stage["name"] = "第 %d 个波间间隔" % interval_number
			stage["duration"] = DEFAULT_INTERVAL_DURATION
	level["waves"] = stages
	selected_wave = clampi(selected_wave, 0, maxi(0, stages.size() - 1))
	_sync_all_simple_stage_type_pools()
	_recalculate_stage_times()


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
	_refresh_stage_heading()
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
	_sync_editor_complexity_from_level()
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
	_sync_editor_complexity_from_level()
	_recalculate_stage_times()
	selected_zombie_key = ""
	DraftStore.save_autosave(level)
	_refresh_wave()
	status_label.text = "已重做"


func _sync_editor_complexity_from_level() -> void:
	editor_complexity = EditorComplexity.SIMPLE if str(level.get("editorMode", "simple")) == "simple" else EditorComplexity.ADVANCED
	if _is_simple_mode():
		_end_timeline_mode()
	_update_editor_complexity_button()
	_update_timeline_editability()
	_refresh_card_page()


func _mark_current_level_saved() -> void:
	saved_level_snapshot = JSON.stringify(level)


func _has_unsaved_changes() -> bool:
	return not saved_level_snapshot.is_empty() and JSON.stringify(level) != saved_level_snapshot


func _request_leave_with_unsaved_check(action: Callable) -> void:
	if not action.is_valid():
		return
	if is_instance_valid(stage_heading_editor) and stage_heading_editor.visible:
		_finish_stage_heading_edit(true)
		if stage_heading_editor.visible:
			_update_level_source_buttons()
			return
	if not _has_unsaved_changes():
		action.call()
		return
	pending_unsaved_action = action
	if is_instance_valid(unsaved_changes_dialog):
		unsaved_changes_dialog.popup_centered(Vector2i(540, 200))
		return
	unsaved_changes_dialog = ConfirmationDialog.new()
	unsaved_changes_dialog.title = "未保存的关卡修改"
	unsaved_changes_dialog.ok_button_text = "保存并继续"
	unsaved_changes_dialog.cancel_button_text = "取消"
	unsaved_changes_dialog.dialog_text = "当前关卡有尚未保存的修改。是否先保存，再离开当前关卡？"
	unsaved_changes_dialog.min_size = Vector2i(540, 200)
	unsaved_changes_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	unsaved_changes_dialog.add_button("不保存", true, "discard_changes")
	unsaved_changes_dialog.confirmed.connect(_save_before_pending_action)
	unsaved_changes_dialog.custom_action.connect(_on_unsaved_dialog_custom_action)
	unsaved_changes_dialog.canceled.connect(_cancel_pending_unsaved_action)
	unsaved_changes_dialog.tree_exited.connect(func(): unsaved_changes_dialog = null)
	add_child(unsaved_changes_dialog)
	_force_font_recursive(unsaved_changes_dialog)
	unsaved_changes_dialog.popup_centered(Vector2i(540, 200))


func _on_unsaved_dialog_custom_action(action: StringName) -> void:
	if action != &"discard_changes":
		return
	if is_instance_valid(unsaved_changes_dialog):
		unsaved_changes_dialog.queue_free()
	_continue_pending_unsaved_action()


func _cancel_pending_unsaved_action() -> void:
	pending_unsaved_action = Callable()
	_update_level_source_buttons()
	if is_instance_valid(unsaved_changes_dialog):
		unsaved_changes_dialog.queue_free()


func _save_before_pending_action() -> void:
	if is_instance_valid(unsaved_changes_dialog):
		unsaved_changes_dialog.queue_free()
	if loaded_source_kind == "template":
		if _save_formal_level():
			_continue_pending_unsaved_action()
		else:
			pending_unsaved_action = Callable()
		return
	if loaded_source_kind == "custom":
		if _save_loaded_custom_level():
			_continue_pending_unsaved_action()
		else:
			pending_unsaved_action = Callable()
		return
	_open_custom_name_dialog(false, _continue_pending_unsaved_action)


func _continue_pending_unsaved_action() -> void:
	var action := pending_unsaved_action
	pending_unsaved_action = Callable()
	if action.is_valid():
		action.call()


func _open_save_dialog() -> void:
	if loaded_source_kind == "template":
		_open_formal_save_dialog()
		return
	if loaded_source_kind == "custom":
		_open_loaded_level_save_dialog()
		return
	_open_custom_name_dialog(false)


func _open_formal_save_dialog() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "保存正式关卡"
	dialog.ok_button_text = "覆盖正式关卡"
	dialog.cancel_button_text = "取消"
	dialog.dialog_text = "确认覆盖当前开发者正式冒险关卡？"
	dialog.confirmed.connect(func():
		_save_formal_level()
		dialog.queue_free()
	)
	add_child(dialog)
	_force_font_recursive(dialog)
	dialog.popup_centered(Vector2i(480, 180))


func _open_loaded_level_save_dialog() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "保存关卡"
	dialog.ok_button_text = "覆盖原有关卡"
	dialog.cancel_button_text = "取消"
	dialog.dialog_text = "要覆盖当前载入的关卡，还是另存到“开始冒险吧”的“自制关卡”中？"
	dialog.min_size = Vector2i(560, 190)
	dialog.add_button("保存至自制关卡", true, "save_as_custom")
	dialog.confirmed.connect(func():
		if loaded_source_kind == "template":
			_save_formal_level()
		else:
			_save_loaded_custom_level()
		dialog.queue_free()
	)
	dialog.custom_action.connect(func(action: StringName):
		if action != &"save_as_custom":
			return
		dialog.queue_free()
		_open_custom_name_dialog(true)
	)
	add_child(dialog)
	_force_font_recursive(dialog)
	dialog.popup_centered(Vector2i(560, 190))


func _open_custom_name_dialog(force_new_copy: bool, after_save: Callable = Callable()) -> void:
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
			if after_save.is_valid():
				_cancel_pending_unsaved_action()
			return
		var custom_level := level.duplicate(true)
		custom_level["name"] = new_name
		if force_new_copy or str(custom_level.get("id", "")).is_empty() or str(custom_level.get("id", "")) == "example_front_lawn":
			custom_level["id"] = "custom_%d" % int(Time.get_unix_time_from_system() * 1000.0)
		custom_level.erase("formalPresetId")
		var saved := _save_custom_level(custom_level)
		dialog.queue_free()
		if saved and after_save.is_valid():
			after_save.call()
		elif not saved and after_save.is_valid():
			_cancel_pending_unsaved_action()
	)
	dialog.canceled.connect(func():
		if after_save.is_valid():
			_cancel_pending_unsaved_action()
	)
	dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(dialog)
	dialog.popup_centered()
	name_input.grab_focus()
	name_input.select_all()


func _save_formal_level() -> bool:
	_apply_formal_plant_progression()
	_recalculate_stage_times()
	level["formalPresetId"] = formal_preset_id
	var result := FormalLevelStore.save_developer_level(level, formal_preset_id)
	if result["ok"]:
		var cleared_cleanup: Array[String] = []
		var failed_cleanup: Array[String] = []
		for reward_plant in _formal_reward_plants():
			var duplicate_cleanup := _clear_later_duplicate_formal_rewards(reward_plant)
			for cleared_name in duplicate_cleanup["cleared"]:
				if not cleared_cleanup.has(str(cleared_name)):
					cleared_cleanup.append(str(cleared_name))
			for failed_name in duplicate_cleanup["failed"]:
				if not failed_cleanup.has(str(failed_name)):
					failed_cleanup.append(str(failed_name))
		if not failed_cleanup.is_empty():
			status_label.text = "本关已保存，但未能清空后续重复奖励：%s" % "、".join(failed_cleanup)
			return false
		DraftStore.save_autosave(level)
		_mark_current_level_saved()
		status_label.text = ("已保存；%s 需要新增奖励植物。" % "、".join(cleared_cleanup)) if not cleared_cleanup.is_empty() else "已保存开发者关卡 %s；同步后才会更新正式模式。" % formal_preset_id
		return true
	else:
		status_label.text = "保存关卡模板失败：%s" % str(result["error"])
		return false


func _save_loaded_custom_level() -> bool:
	var built := CustomRuntime.build_game_para(level)
	if not built["ok"]:
		status_label.text = "保存失败：%s" % str(built["error"])
		return false
	var result := DraftStore.save_draft(level)
	if result["ok"]:
		loaded_draft_path = str(result["path"])
		DraftStore.save_autosave(level)
		_mark_current_level_saved()
		status_label.text = "已覆盖自制关卡“%s”。" % str(level["name"])
		_refresh_draft_picker()
		return true
	else:
		status_label.text = "保存失败：%s" % str(result["error"])
		return false


func _save_custom_level(custom_level: Dictionary) -> bool:
	var built := CustomRuntime.build_game_para(custom_level)
	if not built["ok"]:
		status_label.text = "保存失败：%s" % built["error"]
		return false
	var result := DraftStore.save_draft(custom_level)
	if result["ok"]:
		level = Logic.normalize_level(custom_level)
		formal_preset_id = ""
		loaded_source_kind = "custom"
		loaded_draft_path = str(result["path"])
		_snapshot()
		DraftStore.save_autosave(level)
		_mark_current_level_saved()
		status_label.text = "已保存“%s”，可从“开始冒险吧”中的“自制关卡”游玩。" % str(level["name"])
		_refresh_draft_picker()
		return true
	else:
		status_label.text = "保存失败：%s" % result["error"]
		return false


func _playtest() -> void:
	_end_timeline_mode()
	## 以当前界面模式为权威，避免旧草稿或正式关卡覆盖中的 editorMode 与按钮状态不同步。
	level["editorMode"] = "simple" if _is_simple_mode() else "advanced"
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


func _open_workshop_menu() -> void:
	_end_timeline_mode()
	DraftStore.save_autosave(level)
	if not is_instance_valid(workshop_menu_dialog):
		_build_workshop_main_game_menu()
	if is_instance_valid(workshop_menu_dialog):
		workshop_menu_dialog.appear_menu()


func _build_workshop_main_game_menu() -> void:
	## 从主游戏权威场景取出菜单本体，保证纹理、字号、滑轨和各功能按钮完全一致。
	var main_game_scene := load("res://scenes/main/MainGame00Base.tscn") as PackedScene
	if main_game_scene == null:
		return
	var template_root := main_game_scene.instantiate()
	var template_all_ui := template_root.get_node_or_null("CanvasLayerUI/All_UI")
	if template_all_ui == null:
		template_root.free()
		return
	workshop_menu_fallback_dialog = template_all_ui.get_node_or_null("Dialog") as Dialog
	workshop_menu_dialog = template_all_ui.get_node_or_null("MainGameMenuOptionDialog") as MainGameMenuOptionDialog
	if not is_instance_valid(workshop_menu_dialog) or not is_instance_valid(workshop_menu_fallback_dialog):
		template_root.free()
		workshop_menu_dialog = null
		workshop_menu_fallback_dialog = null
		return
	template_all_ui.remove_child(workshop_menu_fallback_dialog)
	template_all_ui.remove_child(workshop_menu_dialog)
	template_root.free()
	workshop_menu_host = Control.new()
	workshop_menu_host.name = "WorkshopMainGameMenu"
	workshop_menu_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	workshop_menu_host.process_mode = Node.PROCESS_MODE_ALWAYS
	workshop_menu_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	workshop_menu_host.theme = load("res://data/PVZ_theme.tres") as Theme
	workshop_menu_fallback_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	workshop_menu_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	workshop_menu_host.add_child(workshop_menu_fallback_dialog)
	workshop_menu_host.add_child(workshop_menu_dialog)
	_assign_runtime_owner(workshop_menu_fallback_dialog, workshop_menu_host)
	_assign_runtime_owner(workshop_menu_dialog, workshop_menu_host)
	## 工坊抽屉含高 z_index 的卡片与命中层；菜单放到独立高层画布，确保始终完整显示在最前面。
	workshop_menu_canvas_layer = CanvasLayer.new()
	workshop_menu_canvas_layer.name = "WorkshopMainGameMenuLayer"
	workshop_menu_canvas_layer.layer = 100
	workshop_menu_canvas_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(workshop_menu_canvas_layer)
	workshop_menu_canvas_layer.add_child(workshop_menu_host)
	## 菜单内的图鉴和控制台各自也是 CanvasLayer，需要排在菜单画布之上。
	var almanac_layer := workshop_menu_dialog.get_node_or_null("Option/Button1/CanvasLayerAlmanac") as CanvasLayer
	if almanac_layer != null:
		almanac_layer.layer = 101
	var console_layer := workshop_menu_dialog.get_node_or_null("Option/Button4/CanvasLayerConsole") as CanvasLayer
	if console_layer != null:
		console_layer.layer = 101
	var return_label := workshop_menu_dialog.get_node_or_null("Return/Label") as Label
	if return_label != null:
		return_label.text = "返回工坊"
	var restart_button := workshop_menu_dialog.get_node_or_null("Option/Button2") as BaseButton
	if restart_button != null:
		for connection in restart_button.pressed.get_connections():
			restart_button.pressed.disconnect(connection.callable)
		restart_button.pressed.connect(_restart_workshop)
	var main_menu_button := workshop_menu_dialog.get_node_or_null("Option/Button3") as BaseButton
	if main_menu_button != null:
		for connection in main_menu_button.pressed.get_connections():
			main_menu_button.pressed.disconnect(connection.callable)
		main_menu_button.pressed.connect(_back_to_menu)


func _assign_runtime_owner(node: Node, scene_owner: Node) -> void:
	node.owner = scene_owner
	for child in node.get_children():
		_assign_runtime_owner(child, scene_owner)


func _restart_workshop() -> void:
	DraftStore.save_autosave(level)
	TreePauseManager.end_tree_pause_clear_all_pause_factors()
	Global.time_scale = 1.0
	Engine.time_scale = Global.time_scale
	get_tree().reload_current_scene()


func _back_to_menu() -> void:
	_request_leave_with_unsaved_check(_perform_back_to_menu)


func _perform_back_to_menu() -> void:
	_end_timeline_mode()
	DraftStore.save_autosave(level)
	_clear_preview_zombies()
	TreePauseManager.end_tree_pause_clear_all_pause_factors()
	Global.time_scale = 1.0
	Engine.time_scale = Global.time_scale
	var global := get_node("/root/Global")
	global.developer_level_adjustments_active = false
	global.return_to_developer_mode = true
	get_tree().change_scene_to_file("res://scenes/main/01StartMenu.tscn")
