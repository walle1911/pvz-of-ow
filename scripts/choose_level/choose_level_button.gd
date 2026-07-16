extends TextureRect
class_name ChooseLevelButton

@onready var texture_button: TextureButton = $TextureButton
@onready var success: TextureRect = $success
@onready var round_num: Label = $RoundNum
@onready var lock: TextureRect = $Lock


## 当前关卡游戏参数
@export var curr_level_data_game_para :ResourceLevelData
## 冒险成品关卡使用工坊同源字典动态生成，确保选关游玩与工坊编辑是同一份设计。
@export var preset_level_id := ""


## 选关按钮信号信号
signal signal_choose_level_button(choose_level_button:ChooseLevelButton)


func _ready() -> void:
	if curr_level_data_game_para != null:
		activate_runtime_level(curr_level_data_game_para)
	else:
		texture_button.visible= false
		success.visible= false
		round_num.visible= false


func activate_runtime_level(level_data: ResourceLevelData) -> void:
	curr_level_data_game_para = level_data
	texture_button.visible = true
	if not texture_button.pressed.is_connected(_on_pressed):
		texture_button.pressed.connect(_on_pressed)
	set_mouse_filter_recursive(self, Control.MOUSE_FILTER_IGNORE)
	texture_button.mouse_filter = Control.MOUSE_FILTER_STOP

func set_mouse_filter_recursive(root: Node, filter_value: int) -> void:
	# root 是你想从这个节点开始，递归设置 mouse_filter 的根节点
	for child in root.get_children():
		# 递归先对子节点做
		set_mouse_filter_recursive(child, filter_value)
		# 如果是 Control 类型，就设置 mouse_filter
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _on_pressed() -> void:
	signal_choose_level_button.emit(self)

## 更新当前关卡状态 (已通关, 多轮关卡轮数)
func update_curr_level_button_state(curr_level_state_data:Dictionary):
	success.visible = curr_level_state_data.get("IsSuccess", false)
	round_num.visible = curr_level_state_data.get("IsHaveMultiRoundSaveGameData", false)
	round_num.text = str(int(curr_level_state_data.get("CurrGameRound", 1))) + "轮"

## 锁住当前关卡选择按钮
func lock_choose_level_button():
	lock.visible = true
	texture_button.disabled = true
	modulate = Color(0.687, 0.687, 0.687, 1.0)
	mouse_default_cursor_shape = Control.CURSOR_ARROW
