extends Control
class_name ChooseLevel

const AdventurePresets := preload("res://scripts/resources/level/adventure_level_presets.gd")
const CustomRuntime := preload("res://scripts/resources/level/level_custom_runtime.gd")
const CHOOSE_LEVEL_BUTTON := preload("res://scenes/choose_level/choose_level_button.tscn")

## 用于生成关卡 ID 的计数
var next_level_number: int = 1
var configured_level_count := 0

@onready var all_page: Control = $AllPage
@onready var label_page: Label = get_node_or_null("LabelPage")

## 游戏模式,用于管理关卡存档
@export var game_mode:MainSceneRegistry.MainScenes = MainSceneRegistry.MainScenes.Null
## 开放关卡数量，冒险默认为1，其余模式为3，若打开控制台开放所有关卡为-1
var open_level_num:int = -1
var all_pages_array : Array[GridContainer]
@export var curr_page := 0

## 选卡bgm
var bgm_choose_card: AudioStream = preload("res://assets/audio/BGM/choose_card.mp3")

func _ready() -> void:
	if game_mode == MainSceneRegistry.MainScenes.ChooseLevelAdventure:
		_build_adventure_preset_buttons()
	## 如果没有开放所有关卡
	if not Global.config_service.open_all_level:
		if game_mode == MainSceneRegistry.MainScenes.ChooseLevelAdventure:
			open_level_num = 1
		## 自定义关卡全开放
		elif game_mode == MainSceneRegistry.MainScenes.ChooseLevelCustom:
			open_level_num = -1
		else:
			open_level_num = 3
	else:
		open_level_num = -1

	for page_i in all_page.get_child_count():
		var page = all_page.get_child(page_i)
		all_pages_array.append(page)
		page.visible = false
		for node in page.get_children():
			## 如果是选关按钮
			if node is ChooseLevelButton:
				var level_id: String = node.preset_level_id if not node.preset_level_id.is_empty() else generate_level_id()
				if node.curr_level_data_game_para == null:
					continue
				configured_level_count += 1
				node.signal_choose_level_button.connect(_on_choose_level_button)
				## 初始化游戏数据的选关数据
				node.curr_level_data_game_para.set_choose_level(game_mode, page_i, level_id)
				var curr_level_state_data:Dictionary = Global.global_game_state.curr_all_level_state_data.get(node.curr_level_data_game_para.save_game_name, {})
				node.update_curr_level_button_state(curr_level_state_data)
				update_lock_level(node, curr_level_state_data)

	print("当前模式关卡数量:", configured_level_count)

	_ready_update_page()

## 更新关卡是否锁住 无尽模式默认开放，不占用开放名额
func update_lock_level(choose_level_button:ChooseLevelButton, curr_level_state_data:Dictionary):
	## 如果开放名额为-1，即所有关卡都开发
	if open_level_num == -1:
		return
	## 无尽模式
	if choose_level_button.curr_level_data_game_para.game_round == -1:
		return
	## 如果当前关卡通关
	if curr_level_state_data.get("IsSuccess", false):
		return
	## 还有开发关卡名额
	if open_level_num > 0:
		open_level_num -= 1
		return
	else:
		choose_level_button.lock_choose_level_button()

func _ready_update_page():
	## 如果从游戏中退出
	if Global.game_para != null and Global.game_para.game_mode == game_mode:
		curr_page = Global.game_para.level_page

	if curr_page > all_pages_array.size():
		curr_page = 0
	if not all_pages_array.is_empty():
		all_pages_array[curr_page].visible = true
		if is_instance_valid(label_page):
			_update_page(curr_page)

	SoundManager.play_bgm(bgm_choose_card)

## 获取关卡id
func generate_level_id() -> String:
	# 用格式化字符串，让数字变成 4 位，前面补 0
	# GDScript 支持类似 C 风格字符串格式化
	var id_str = "%04d" % next_level_number  # 例如 0 -> "0000", 12 -> "0012"
	next_level_number += 1
	return id_str

func _on_choose_level_button(choose_level_button:ChooseLevelButton):
	if not choose_level_button.preset_level_id.is_empty():
		var source := AdventurePresets.build_level(choose_level_button.preset_level_id)
		var built := CustomRuntime.build_game_para(source)
		if not built["ok"]:
			push_error("成品冒险关卡无法载入：%s" % str(built["error"]))
			return
		var preset_para: ResourceLevelData = built["game_para"]
		preset_para.set_choose_level(game_mode, curr_page, choose_level_button.preset_level_id)
		choose_level_button.curr_level_data_game_para = preset_para
	Global.game_para = choose_level_button.curr_level_data_game_para
	choose_level_start_game(choose_level_button.curr_level_data_game_para.game_sences)


func _build_adventure_preset_buttons() -> void:
	var page := all_page.get_child(0) as GridContainer
	var mainline_mode := str(Global.adventure_mainline_mode)
	var title := get_node_or_null("Label") as Label
	if title != null:
		title.text = "棋 盘 格 主 线" if mainline_mode == "chessboard" else "冒 险 模 式"
	var existing_buttons: Array[ChooseLevelButton] = []
	for child in page.get_children():
		if child is ChooseLevelButton:
			existing_buttons.append(child as ChooseLevelButton)
	var presets: Array[Dictionary] = AdventurePresets.list_presets(mainline_mode)
	for preset_index in presets.size():
		var preset: Dictionary = presets[preset_index]
		var button: ChooseLevelButton
		if preset_index < existing_buttons.size():
			button = existing_buttons[preset_index]
		else:
			button = CHOOSE_LEVEL_BUTTON.instantiate() as ChooseLevelButton
			page.add_child(button)
		button.visible = true
		button.preset_level_id = str(preset["id"])
		var built := CustomRuntime.build_game_para(AdventurePresets.build_level(button.preset_level_id))
		if built["ok"]:
			button.curr_level_data_game_para = built["game_para"]
		(button.get_node("TextureButton/Label") as Label).text = str(preset["name"])
	for button_index in range(presets.size(), existing_buttons.size()):
		existing_buttons[button_index].visible = false

## 进入游戏关卡
func choose_level_start_game(game_scense:MainSceneRegistry.MainScenes):
	get_tree().change_scene_to_file(Global.main_scene_registry.MainScenesMap[game_scense])

## 返回开始菜单
func back_start_menu():
	get_tree().change_scene_to_file(Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.StartMenu])


func _on_last_pressed() -> void:
	_update_page(curr_page - 1)

func _on_next_pressed() -> void:
	_update_page(curr_page + 1)


func _update_page(new_page:int):
	new_page = posmod(new_page, all_pages_array.size())
	all_pages_array[curr_page].visible = false
	curr_page = new_page
	all_pages_array[curr_page].visible = true
	label_page.text = "当前页数:" + str(curr_page + 1) + "/" + str(all_pages_array.size())
