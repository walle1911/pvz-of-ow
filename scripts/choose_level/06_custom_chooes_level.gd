extends ChooseLevel
class_name CustomChooseLevel

const CHOOSE_LEVEL_BUTTON_CUSTOMIZE = preload("res://scenes/choose_level/choose_level_button_customize.tscn")
const DraftStore := preload("res://scripts/resources/level/level_draft_store.gd")
const AdventureStore := preload("res://scripts/resources/level/adventure_level_store.gd")
const DEVELOPER_GIFT_TEST_LEVELS: Array[Dictionary] = [
	{
		"id": "developer_test_day",
		"name": "白天测试",
		"resource": preload("res://resources/level_date_resource/mode_adventure/adventure_01_day_test.tres"),
	},
	{
		"id": "developer_test_pool",
		"name": "泳池测试",
		"resource": preload("res://resources/level_date_resource/mode_adventure/adventure_03_pool_test.tres"),
	},
	{
		"id": "developer_test_fog",
		"name": "雾夜测试",
		"resource": preload("res://resources/level_date_resource/mode_adventure/adventure_04_fog_test.tres"),
	},
	{
		"id": "developer_test_roof",
		"name": "屋顶测试",
		"resource": preload("res://resources/level_date_resource/mode_adventure/adventure_05_Roof_test.tres"),
	},
]

@onready var panel_help: Panel = $PanelHelp
@onready var grid_container: GridContainer = $AllPage/GridContainer

## 每一页的关卡数量
var num_level_button_every_page := 10
var classic_entries: Array[Dictionary] = []
var custom_entries: Array[Dictionary] = []
var detached_grid_template: GridContainer
var developer_list_mode := "classic"

func _ready() -> void:
	detached_grid_template = grid_container
	all_page.remove_child(detached_grid_template)
	detached_grid_template.name = "GridTemplate"
	add_child(detached_grid_template)
	if Global.developer_gift_test_levels_active:
		$ClassicLevels.hide()
		$CustomLevels.hide()
		_build_developer_gift_test_levels()
		return
	$ClassicLevels.visible = Global.developer_level_adjustments_active
	$CustomLevels.visible = Global.developer_level_adjustments_active
	_build_level_entries()
	if Global.developer_level_adjustments_active:
		_show_developer_list("classic")
	else:
		_rebuild_pages(custom_entries)


func _build_developer_gift_test_levels() -> void:
	var title := get_node_or_null("Label") as Label
	if title != null:
		title.text = "训练靶场"
	var entries: Array[Dictionary] = []
	for definition in DEVELOPER_GIFT_TEST_LEVELS:
		var source := definition["resource"] as ResourceLevelData
		entries.append({
			"game_para": source.duplicate_runtime(),
			"id": definition["id"],
			"name": definition["name"],
			"editor_source": {},
		})
	_rebuild_pages(entries)


func _build_level_entries() -> void:
	classic_entries.clear()
	custom_entries.clear()
	if Global.developer_level_adjustments_active:
		var title := get_node_or_null("Label") as Label
		if title != null:
			title.text = "开 发 者 关 卡"
		for preset in AdventurePresets.list_presets("normal"):
			var preset_id := str(preset["id"])
			var source := AdventurePresets.build_level(preset_id, true)
			var preset_built := CustomRuntime.build_game_para(source)
			if preset_built["ok"]:
				classic_entries.append({
					"game_para": preset_built["game_para"],
					"id": preset_id,
					"name": str(source.get("name", preset["name"])),
					"preset": preset,
					## 封面角色属于关卡编辑数据；未配置时仍由 ChooseLevel 自动推荐。
					"cover_source": source,
					"editor_source": source,
					"modified": AdventureStore.load_developer_level(preset_id)["ok"],
				})
	for resource_entry in load_resources_with_get_files("level_game_para"):
		custom_entries.append({
			"game_para": resource_entry[0],
			"id": str(resource_entry[1]),
			"name": str(resource_entry[1]),
			"editor_source": {},
		})
	for draft in DraftStore.list_drafts():
		var loaded := DraftStore.load_draft(draft["path"])
		if not loaded["ok"]:
			continue
		var built := CustomRuntime.build_game_para(loaded["level"])
		if built["ok"]:
			custom_entries.append({
				"game_para": built["game_para"],
				"id": str(draft["id"]),
				"name": str(draft["name"]),
				"editor_source": loaded["level"],
			})


func _show_developer_list(mode: String) -> void:
	developer_list_mode = mode
	var title := get_node_or_null("Label") as Label
	if title != null:
		title.text = "关 卡 模 板" if mode == "classic" else "自 制 关 卡"
	_rebuild_pages(classic_entries if mode == "classic" else custom_entries)


func _rebuild_pages(entries: Array[Dictionary]) -> void:
	for page in all_page.get_children():
		all_page.remove_child(page)
		page.queue_free()
	all_pages_array.clear()
	var curr_num_page:int = -1
	var previous_classic_source: Dictionary = {}
	for i in range(entries.size()):
		var page_i:int = int(float(i) / num_level_button_every_page)
		if curr_num_page < page_i:
			curr_num_page += 1
			var new_grid_container = detached_grid_template.duplicate()
			## 先统一隐藏，_ready_update_page() 只打开当前页，避免多页文字和封面叠放。
			new_grid_container.visible = false
			new_grid_container.process_mode = Node.PROCESS_MODE_DISABLED
			all_page.add_child(new_grid_container)
			all_pages_array.append(new_grid_container)
		## 当前页面
		var curr_grid_container = all_page.get_child(page_i)

		## 关卡按钮
		var chooes_level_button:ChooseLevelButtonCustomize = CHOOSE_LEVEL_BUTTON_CUSTOMIZE.instantiate()
		var entry := entries[i]
		chooes_level_button.init_choose_level_button_customize(entry["game_para"], str(entry["name"]))
		chooes_level_button.set_meta("developer_editor_source", entry.get("editor_source", {}))
		curr_grid_container.add_child(chooes_level_button)

		chooes_level_button.signal_choose_level_button.connect(_on_choose_level_button)
		chooes_level_button.curr_level_data_game_para.set_choose_level(game_mode, page_i, str(entry["id"]))
		chooes_level_button.update_curr_level_button_state(Global.global_game_state.curr_all_level_state_data.get(chooes_level_button.curr_level_data_game_para.save_game_name, {}))
		if entry.has("preset"):
			_configure_adventure_cover(chooes_level_button, entry["preset"], entry["cover_source"], previous_classic_source)
			previous_classic_source = entry["cover_source"]
			if bool(entry.get("modified", false)):
				## 开发者覆盖存在时，用通关奖杯直观标记这关已被编辑。
				chooes_level_button.success.visible = true

	print("当前模式关卡数量:", entries.size())

	curr_page = 0
	_ready_update_page()


func _on_classic_levels_pressed() -> void:
	_show_developer_list("classic")


func _on_custom_levels_pressed() -> void:
	_show_developer_list("custom")


func _on_choose_level_button(choose_level_button: ChooseLevelButton) -> void:
	Global.developer_workshop_level_source = (
		choose_level_button.get_meta("developer_editor_source", {}) as Dictionary
	).duplicate(true)
	super._on_choose_level_button(choose_level_button)


func get_base_path() -> String:
	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path("res://")
	else:
		return OS.get_executable_path().get_base_dir()


const RESOURCE_EXT = ["tres"]

func is_resource_file(path: String) -> bool:
	var ext = path.get_extension().to_lower()
	return RESOURCE_EXT.has(ext)


func load_resources_with_get_files(folder_path: String) -> Array:
	var base = get_base_path()
	var real_path = base + "/" + folder_path

	var dir = DirAccess.open(real_path)
	if dir == null:
		print("目录不存在:", real_path)
		return []

	var files = dir.get_files()	# ← 仅目录内文件，不含子目录
	var resources: Array = []

	for file_name in files:
		var full_path = real_path + "/" + file_name
		if is_resource_file(full_path):
			var res = ResourceLoader.load(full_path)
			if res:
				resources.append([res, file_name.get_basename()])
				print("加载游戏参数资源文件：" + file_name.get_basename())
			else:
				print("资源加载失败:", full_path)

	return resources


func _on_help_pressed() -> void:
	panel_help.visible = true

func _on_button_ok_pressed() -> void:
	panel_help.visible = false


func back_start_menu() -> void:
	if Global.developer_level_adjustments_active or Global.developer_gift_test_levels_active:
		Global.return_to_developer_mode = true
	Global.developer_gift_test_levels_active = false
	Global.developer_level_adjustments_active = false
	Global.developer_workshop_level_source = {}
	get_tree().change_scene_to_file(Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.StartMenu])
