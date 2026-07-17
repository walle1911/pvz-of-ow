extends Panel
class_name PanelCreateNewUser

const StreamerIdLibrary := preload("res://scripts/start_menu/overwatch_streamer_id_library.gd")

@onready var line_edit: LineEdit = $Panel/LineEdit
@onready var dialog_error: DialogError = $DialogError

@onready var button_ok: PVZButtonBase = $HBoxContainer/ButtonOK
@onready var button_random_id: PVZButtonBase = $HBoxContainer/ButtonRandomID
@onready var button_cancel: PVZButtonBase = $HBoxContainer/ButtonCancel

func _ready() -> void:
	button_ok.pressed.connect(_on_button_ok_pressed)
	button_random_id.pressed.connect(_on_button_random_id_pressed)
	button_cancel.pressed.connect(_on_button_cancel_pressed)

## 当按下ok按钮时
func _on_button_ok_pressed():
	var new_user_name = line_edit.text
	var add_user_res = Global.user_manager.add_user(new_user_name)
	if add_user_res.is_empty():
		_disappear_create_new_user_panel()
	else:
		dialog_error.update_text(add_user_res)
		dialog_error.visible = true


## 从《守望先锋》简体中文客户端主播模式 ID 库中填写一个未使用的名字
func _on_button_random_id_pressed() -> void:
	var unavailable_ids: Array[String] = Global.user_manager.all_user_name.duplicate()
	if not line_edit.text.is_empty():
		unavailable_ids.append(line_edit.text)
	var random_id: String = StreamerIdLibrary.pick_available(unavailable_ids)
	if random_id.is_empty():
		dialog_error.update_text("随机ID已全部使用")
		dialog_error.visible = true
		return
	line_edit.text = random_id
	line_edit.caret_column = random_id.length()
	line_edit.grab_focus()


## 当按下取消按钮时
func _on_button_cancel_pressed():
	_disappear_create_new_user_panel()

func _disappear_create_new_user_panel():
	line_edit.text = ""
	visible = false
