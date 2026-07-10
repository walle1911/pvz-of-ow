@tool
extends Control
class_name StartMenuRoot

@onready var dialog: Dialog = $Dialog
@export var bgm:AudioStream
@onready var user: User = $User
@onready var level_workshop_button: TextureButton = $BG_Right/Menu/LevelWorkshopButton

@export_group("关卡工坊入口 Transform")
@export var level_workshop_button_position := Vector2(20, 318):
	set(value):
		level_workshop_button_position = value
		if is_node_ready():
			_apply_level_workshop_button_transform()
@export_range(-180.0, 180.0, 0.1) var level_workshop_button_rotation_degrees := -4.0:
	set(value):
		level_workshop_button_rotation_degrees = value
		if is_node_ready():
			_apply_level_workshop_button_transform()
@export var level_workshop_button_scale := Vector2.ONE:
	set(value):
		level_workshop_button_scale = value
		if is_node_ready():
			_apply_level_workshop_button_transform()


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_apply_level_workshop_button_transform()
	if Engine.is_editor_hint():
		return
	$Cloud/AnimationPlayer.play("Idle")
	$BG_Right/Leaf/AnimationPlayer.play("Idle")
	$AnimationPlayer.play("Idle")

	SoundManager.setup_ui_start_menu_sound(self)
	SoundManager.play_bgm(bgm)

	Global.time_scale = 1.0
	Engine.time_scale = Global.time_scale

	## 确保回到主菜单时鼠标可见（防止从锤子关等模式返回后鼠标残隐）
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _apply_level_workshop_button_transform() -> void:
	level_workshop_button.position = level_workshop_button_position
	level_workshop_button.rotation_degrees = level_workshop_button_rotation_degrees
	level_workshop_button.scale = level_workshop_button_scale
	level_workshop_button.pivot_offset = level_workshop_button.size * 0.5
	if not level_workshop_button.mouse_entered.is_connected(_on_level_workshop_button_mouse_entered):
		level_workshop_button.mouse_entered.connect(_on_level_workshop_button_mouse_entered)
	if not level_workshop_button.mouse_exited.is_connected(_on_level_workshop_button_mouse_exited):
		level_workshop_button.mouse_exited.connect(_on_level_workshop_button_mouse_exited)


func _on_level_workshop_button_mouse_entered() -> void:
	level_workshop_button.self_modulate = Color(1.2, 1.18, 1.08, 1.0)


func _on_level_workshop_button_mouse_exited() -> void:
	level_workshop_button.self_modulate = Color.WHITE

## 花园需要浇水
var garden_need_water:=true

## 功能未实现
func _unrealized():
	dialog.appear_dialog()

## 开始游戏
func _on_button_1_pressed() -> void:
	Global.game_para = null
	get_tree().change_scene_to_file(Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.ChooseLevelAdventure])


## 迷你游戏
func _on_button_2_pressed() -> void:
	Global.game_para = null
	get_tree().change_scene_to_file(Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.ChooseLevelMiniGame])

## 解密模式
func _on_button_3_pressed() -> void:
	Global.game_para = null
	get_tree().change_scene_to_file(Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.ChooseLevelPuzzle])

## 生存模式
func _on_button_4_pressed() -> void:
	Global.game_para = null
	get_tree().change_scene_to_file(Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.ChooseLevelSurvival])

## 自定义关卡
func _on_custom_button_pressed() -> void:
	Global.game_para = null
	get_tree().change_scene_to_file(Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.ChooseLevelCustom])

## 关卡工坊：运行时编辑并保存待审核 JSON 草稿
func _on_level_workshop_button_pressed() -> void:
	Global.game_para = null
	get_tree().change_scene_to_file(Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.LevelWorkshop])

#region 选项
func _on_option_button_1_pressed() -> void:
	$StartMenuOptionDialog.appear_menu()


func _on_option_button_2_pressed() -> void:
	$Dialog_Help.appear_dialog()

## 退出游戏
func _on_option_button_3_pressed() -> void:
	get_tree().quit()


func _on_full_screen_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
#endregion


## 花园
func _on_item_button_1_pressed() -> void:
	get_tree().change_scene_to_file(Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.Garden])

## 图鉴
func _on_item_button_2_pressed() -> void:
	get_tree().change_scene_to_file(Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.Almanac])

## 商店
func _on_item_button_3_pressed() -> void:
	get_tree().change_scene_to_file(Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.Store])

## 点击用户更新时
func _on_button_update_user_pressed() -> void:
	user.visible = true
