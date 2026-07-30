extends TextureRect
class_name StartMenuOptionDialog


@onready var sound_h_slider: HSlider = $Option/Sound/HSlider
@onready var difficulty_h_slider: HSlider = $Option/Difficulty/HSlider
@onready var difficulty_label: Label = $Option/Difficulty/Label

## 全屏按钮
@onready var check_button: CheckButton = $Option/FullScreen/CheckButton


func _ready() -> void:
	## 为按钮添加音效
	SoundManager.setup_ui_main_game_sound(self)
	music_sound_signal(sound_h_slider, AudioServer.get_bus_index("Master"))
	difficulty_signal(difficulty_h_slider)

	check_button.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN

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


## 出现菜单
func appear_menu():
	await get_tree().create_timer(0.1).timeout

	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP


## 关闭菜单
func return_button_pressed():
	await get_tree().create_timer(0.1).timeout

	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
