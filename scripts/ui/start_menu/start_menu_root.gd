@tool
extends Control
class_name StartMenuRoot

const RETURN_NORMAL_TEXTURE := preload("res://assets/image/ui/ui_start_menu/button_return.png")
const LEVEL_WORKSHOP_NORMAL_TEXTURE := preload("res://assets/image/ui/ui_start_menu/button_developer.png")

@onready var dialog: Dialog = $Dialog
@export var bgm:AudioStream
@onready var user: User = $User
@onready var menu_button_1: TextureButton = $BG_Right/Menu/Button1
@onready var menu_button_2: TextureButton = $BG_Right/Menu/Button2
@onready var menu_button_3: TextureButton = $BG_Right/Menu/Button3
@onready var menu_button_4: TextureButton = $BG_Right/Menu/Button4
@onready var developer_menu: Control = $BG_Right/Menu/DeveloperMenu
@onready var developer_button_1: TextureButton = $BG_Right/Menu/DeveloperMenu/Button1
@onready var developer_button_2: TextureButton = $BG_Right/Menu/DeveloperMenu/Button2
@onready var developer_button_3: TextureButton = $BG_Right/Menu/DeveloperMenu/Button3
@onready var developer_button_4: TextureButton = $BG_Right/Menu/DeveloperMenu/Button4
@onready var level_workshop_button: TextureButton = $BG_Right/Menu/LevelWorkshopButton
@onready var developer_mode_label: Label = $BG_Right/Menu/LevelWorkshopButton/Label
@onready var adventure_mode_dialog = $AdventureModeDialog

var developer_mode := false
var normal_level_workshop_texture: Texture2D
var developer_button_hover_tweens: Dictionary = {}
var mode_dialog_context := "adventure"

@export_group("按钮对齐预览")
@export var show_both_menus_for_alignment := false:
	set(value):
		show_both_menus_for_alignment = value
		if Engine.is_editor_hint() and is_node_ready():
			_apply_editor_menu_preview()

@export_group("开发者模式编辑器预览")
@export var preview_developer_mode := false:
	set(value):
		preview_developer_mode = value
		if Engine.is_editor_hint() and is_node_ready():
			_apply_editor_menu_preview()

@export_group("开发者模式入口 Transform")
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
	_setup_developer_buttons()
	normal_level_workshop_texture = LEVEL_WORKSHOP_NORMAL_TEXTURE
	if Engine.is_editor_hint():
		_apply_editor_menu_preview()
		return
	_apply_developer_mode(Global.return_to_developer_mode)
	Global.return_to_developer_mode = false
	$Cloud/AnimationPlayer.play("Idle")
	$BG_Right/Leaf/AnimationPlayer.play("Idle")
	$AnimationPlayer.play("Idle")

	SoundManager.setup_ui_start_menu_sound(self)
	SoundManager.play_bgm(bgm)

	Global.time_scale = 1.0
	Engine.time_scale = Global.time_scale

	## 确保回到主菜单时鼠标可见（防止从锤子关等模式返回后鼠标残隐）
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	adventure_mode_dialog.normal_mode_selected.connect(_start_normal_adventure)
	adventure_mode_dialog.chessboard_mode_selected.connect(_start_chessboard_adventure)

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


func _setup_developer_buttons() -> void:
	for button: TextureButton in [developer_button_1, developer_button_2, developer_button_3, developer_button_4]:
		_apply_texture_alpha_click_mask(button)
		button.mouse_entered.connect(_on_developer_button_hover.bind(button, true))
		button.mouse_exited.connect(_on_developer_button_hover.bind(button, false))


func _apply_texture_alpha_click_mask(button: TextureButton) -> void:
	if button.texture_normal == null:
		return
	var image := button.texture_normal.get_image()
	if image == null or image.is_empty():
		return
	var click_mask := BitMap.new()
	click_mask.create_from_image_alpha(image, 0.12)
	button.texture_click_mask = click_mask


func _on_developer_button_hover(button: TextureButton, is_hovered: bool) -> void:
	var old_tween: Tween = developer_button_hover_tweens.get(button, null)
	if is_instance_valid(old_tween):
		old_tween.kill()
	var tween := create_tween()
	developer_button_hover_tweens[button] = tween
	var target_color := Color(1.2, 1.12, 0.68, 1.0) if is_hovered else Color.WHITE
	tween.tween_property(button, "self_modulate", target_color, 0.12)


func _apply_editor_menu_preview() -> void:
	if show_both_menus_for_alignment:
		developer_mode = false
		for button in [menu_button_1, menu_button_2, menu_button_3, menu_button_4]:
			button.visible = true
		developer_menu.visible = true
		developer_menu.modulate = Color(1, 1, 1, 0.65)
		level_workshop_button.texture_normal = normal_level_workshop_texture
		level_workshop_button.tooltip_text = "进入开发者模式"
		developer_mode_label.visible = false
	else:
		developer_menu.modulate = Color.WHITE
		_apply_developer_mode(preview_developer_mode)


func _apply_developer_mode(enabled: bool) -> void:
	developer_mode = enabled
	## 开发者菜单本身不是关卡；只有从对应入口真正进关时才开启数值覆盖。
	Global.developer_level_adjustments_active = false
	developer_menu.modulate = Color.WHITE
	for button in [menu_button_1, menu_button_2, menu_button_3, menu_button_4]:
		button.visible = not developer_mode
	developer_menu.visible = developer_mode
	if developer_mode:
		level_workshop_button.texture_normal = RETURN_NORMAL_TEXTURE
		level_workshop_button.tooltip_text = "返回正常模式"
		developer_mode_label.visible = false
		developer_button_1.tooltip_text = "选择并游玩已保存的自定义关卡"
		developer_button_2.tooltip_text = "打开地图工坊"
		developer_button_3.tooltip_text = "调整植物与僵尸数值"
		developer_button_4.tooltip_text = "保存与导出（暂未开放）"
	else:
		level_workshop_button.texture_normal = normal_level_workshop_texture
		level_workshop_button.tooltip_text = "进入开发者模式"
		developer_mode_label.visible = false

## 花园需要浇水
var garden_need_water:=true

## 功能未实现
func _unrealized():
	dialog.appear_dialog()

## 开始游戏
func _on_button_1_pressed() -> void:
	Global.game_para = null
	Global.developer_level_adjustments_active = developer_mode
	if developer_mode:
		get_tree().change_scene_to_file(Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.ChooseLevelCustom])
		return
	mode_dialog_context = "adventure"
	adventure_mode_dialog.configure("请选择冒险模式", "普通模式", "棋盘格模式")
	adventure_mode_dialog.appear()


func _start_normal_adventure() -> void:
	if mode_dialog_context == "workshop":
		Global.level_workshop_edit_mode = "normal"
		get_tree().change_scene_to_file(Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.LevelWorkshop])
		return
	get_tree().change_scene_to_file(Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.ChooseLevelAdventure])


func _start_chessboard_adventure() -> void:
	if mode_dialog_context == "workshop":
		Global.level_workshop_edit_mode = "chessboard"
		get_tree().change_scene_to_file(Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.LevelWorkshop])
		return
	get_tree().change_scene_to_file(Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.MainGameChessboardFront])


## 迷你游戏
func _on_button_2_pressed() -> void:
	Global.game_para = null
	Global.developer_level_adjustments_active = false
	if developer_mode:
		mode_dialog_context = "workshop"
		adventure_mode_dialog.configure("请选择地图工坊", "编辑普通模式", "编辑棋盘格模式")
		adventure_mode_dialog.appear()
		return
	get_tree().change_scene_to_file(Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.ChooseLevelMiniGame])

## 解密模式
func _on_button_3_pressed() -> void:
	if developer_mode:
		Global.game_para = null
		get_tree().change_scene_to_file(Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.NumericalEditor])
		return
	Global.game_para = null
	get_tree().change_scene_to_file(Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.ChooseLevelPuzzle])

## 生存模式
func _on_button_4_pressed() -> void:
	if developer_mode:
		_unrealized()
		return
	Global.game_para = null
	get_tree().change_scene_to_file(Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.ChooseLevelSurvival])

## 自定义关卡
func _on_custom_button_pressed() -> void:
	Global.game_para = null
	Global.developer_level_adjustments_active = false
	get_tree().change_scene_to_file(Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.ChooseLevelCustom])

## 切换开发者模式/正常模式
func _on_level_workshop_button_pressed() -> void:
	_apply_developer_mode(not developer_mode)

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
