extends TextureRect
class_name MainGameMenuOptionDialog

@onready var dialog: Dialog = $"../Dialog"

@onready var sound_h_slider: HSlider = $Option/VBoxContainer/Sound/HSlider
@onready var difficulty_h_slider: HSlider = $Option/VBoxContainer/Difficulty/HSlider
@onready var difficulty_label: Label = $Option/VBoxContainer/Difficulty/Label
@onready var time_scale_h_slider: HSlider = $Option/VBoxContainer/TimeScale/HSlider
@onready var time_sacle_label: Label = $Option/VBoxContainer/TimeScale/Label
@onready var canvas_layer_console: CanvasLayerConsole = %CanvasLayerConsole
## 图鉴场景所在的画布层
@onready var canvas_layer_almanac: CanvasLayer = %CanvasLayerAlmanac


func _ready() -> void:
	## 为按钮添加音效
	SoundManager.setup_ui_main_game_sound(self)
	## 连接滑轨信号
	music_sound_signal(sound_h_slider, AudioServer.get_bus_index("Master"))
	difficulty_signal(difficulty_h_slider)
	time_sacle_signal(time_scale_h_slider)
	time_sacle_label.text = "倍速 " + str(Global.time_scale) + " 倍"


func music_sound_signal(h_slider: HSlider, bus_index):
	h_slider.value = SoundManager.get_volum(bus_index)
	h_slider.value_changed.connect(func (v:float):
		SoundManager.set_volume(bus_index, v)
		Global.config_service.save_config()
	)

func difficulty_signal(h_slider: HSlider) -> void:
	h_slider.set_value_no_signal(Global.config_service.game_difficulty)
	_update_difficulty_label(int(h_slider.value))
	h_slider.value_changed.connect(func(value: float):
		Global.config_service.game_difficulty = int(value) as ConfigService.GameDifficulty
		_update_difficulty_label(int(value))
		Global.config_service.save_config()
	)

func _update_difficulty_label(difficulty: int) -> void:
	var names := ["简单", "中等", "困难"]
	difficulty_label.text = "难度 " + names[clampi(difficulty, 0, names.size() - 1)]


func time_sacle_signal(h_slider: HSlider):
	h_slider.value_changed.connect(func (v:float):
		Global.time_scale = v
		time_sacle_label.text = "倍速 " + str(Global.time_scale) + " 倍"
		Engine.time_scale = Global.time_scale
		)

## 出现菜单
func appear_menu():
	await get_tree().create_timer(0.1).timeout
	# 游戏暂停

	TreePauseManager.start_tree_pause(TreePauseManager.E_PauseFactor.Menu)
	SoundManager.play_other_SFX("pause")

	visible = true
	#mouse_filter = Control.MOUSE_FILTER_STOP

## 关闭菜单
func return_button_pressed():
	await get_tree().create_timer(0.1).timeout
	SoundManager.play_other_SFX("pause")
	visible = false

	TreePauseManager.end_tree_pause(TreePauseManager.E_PauseFactor.Menu)
	#mouse_filter = Control.MOUSE_FILTER_IGNORE

## 图鉴
func encyclopedia():
	var almance_node = load(Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.Almanac]).instantiate()
	canvas_layer_almanac.add_child(almance_node)


## 重新开始
func resume_game():
	EventBus.push_event("change_is_mouse_visibel_on_hammer", true)

	var recording_director := Global.main_game.get_node_or_null(^"RecordingDebugController")
	if is_instance_valid(recording_director) and recording_director.has_method("prepare_restart_clear"):
		recording_director.call("prepare_restart_clear")

	Global.main_game.re_main_game()

	TreePauseManager.end_tree_pause_clear_all_pause_factors()
	Global.time_scale = 1.0
	Engine.time_scale = Global.time_scale
	get_tree().reload_current_scene()


## 返回主菜单
func return_main_menu():
	EventBus.push_event("change_is_mouse_visibel_on_hammer", true)
	TreePauseManager.end_tree_pause_clear_all_pause_factors()
	Global.time_scale = 1.0
	Engine.time_scale = Global.time_scale
	if Global.developer_level_adjustments_active:
		Global.return_to_developer_mode = true
	Global.developer_level_adjustments_active = false
	Global.developer_workshop_level_source = {}
	get_tree().change_scene_to_file(Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.StartMenu])

## 功能未实现
func _unrealized():
	dialog.appear_dialog()

## 出现控制台
func _on_button_console_pressed() -> void:
	canvas_layer_console.appear_canvas_layer_control()
