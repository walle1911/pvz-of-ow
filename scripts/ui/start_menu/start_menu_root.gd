@tool
extends Control
class_name StartMenuRoot

const RETURN_NORMAL_TEXTURE := preload("res://assets/image/ui/ui_start_menu/button_return.png")
const LEVEL_WORKSHOP_NORMAL_TEXTURE := preload("res://assets/image/ui/ui_start_menu/button_developer.png")
const OPTION_NORMAL_TEXTURE := preload("res://assets/image/ui/ui_start_menu/SelectorScreen_Options1.png")
const OPTION_HOVER_TEXTURE := preload("res://assets/image/ui/ui_start_menu/SelectorScreen_Options2.png")
const HELP_NORMAL_TEXTURE := preload("res://assets/image/ui/ui_start_menu/SelectorScreen_Help1.png")
const HELP_HOVER_TEXTURE := preload("res://assets/image/ui/ui_start_menu/SelectorScreen_Help2.png")
const DEVELOPER_IMPORT_TEXTURE := preload("res://assets/image/ui/ui_start_menu/SelectorScreen_DeveloperImport.png")
const DEVELOPER_IMPORT_HOVER_TEXTURE := preload("res://assets/image/ui/ui_start_menu/SelectorScreen_DeveloperImportHighlight.png")

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
@onready var option_button: TextureButton = $BG_Right/Option/TextureButton
@onready var help_button: TextureButton = $BG_Right/Option/TextureButton2
@onready var store_button: TextureButton = $BG_Right/Item/TextureButton3
@onready var garden_button: TextureButton = $BG_Right/Item/TextureButton
@onready var gift_button: TextureButton = $BG_Right/CustomButton
@onready var overwatch_logo: TextureRect = $OverwatchLogo

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
	_hide_unavailable_start_menu_items()
	normal_level_workshop_texture = LEVEL_WORKSHOP_NORMAL_TEXTURE
	if Engine.is_editor_hint():
		_apply_editor_menu_preview()
		return
	_apply_developer_mode(Global.return_to_developer_mode)
	Global.return_to_developer_mode = false
	$Cloud/AnimationPlayer.play("Idle")
	$BG_Right/Leaf/AnimationPlayer.play("Idle")
	$AnimationPlayer.play("Idle")
	_play_overwatch_logo_intro()

	SoundManager.setup_ui_start_menu_sound(self)
	SoundManager.play_bgm(bgm)

	Global.time_scale = 1.0
	Engine.time_scale = Global.time_scale

	## 确保回到主菜单时鼠标可见（防止从锤子关等模式返回后鼠标残隐）
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	adventure_mode_dialog.normal_mode_selected.connect(_start_normal_adventure)
	adventure_mode_dialog.chessboard_mode_selected.connect(_start_chessboard_adventure)


func _hide_unavailable_start_menu_items() -> void:
	## 由运行时代码统一隐藏，避免场景在编辑器中重新保存后恢复显示和点击区域。
	garden_button.hide()
	garden_button.process_mode = Node.PROCESS_MODE_DISABLED
	gift_button.hide()
	gift_button.process_mode = Node.PROCESS_MODE_DISABLED


func _play_overwatch_logo_intro() -> void:
	var rest_position := overwatch_logo.position
	overwatch_logo.pivot_offset = overwatch_logo.size * 0.5
	overwatch_logo.position = rest_position + Vector2(-190.0, 18.0)
	overwatch_logo.rotation_degrees = -8.0
	overwatch_logo.scale = Vector2(0.88, 0.88)
	overwatch_logo.modulate.a = 0.0

	var intro_tween := overwatch_logo.create_tween()
	intro_tween.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	intro_tween.tween_property(overwatch_logo, ^"position", rest_position, 1.6)
	intro_tween.parallel().tween_property(overwatch_logo, ^"rotation_degrees", 0.0, 1.4)
	intro_tween.parallel().tween_property(overwatch_logo, ^"scale", Vector2.ONE, 1.4)
	intro_tween.parallel().tween_property(overwatch_logo, ^"modulate:a", 1.0, 0.45)
	intro_tween.tween_callback(_start_overwatch_logo_idle.bind(rest_position))


func _start_overwatch_logo_idle(rest_position: Vector2) -> void:
	var idle_tween := overwatch_logo.create_tween().set_loops()
	idle_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	idle_tween.tween_property(overwatch_logo, ^"position", rest_position + Vector2(0.0, -6.0), 2.2)
	idle_tween.parallel().tween_property(overwatch_logo, ^"rotation_degrees", 1.5, 2.2)
	idle_tween.tween_property(overwatch_logo, ^"position", rest_position + Vector2(0.0, 4.0), 2.2)
	idle_tween.parallel().tween_property(overwatch_logo, ^"rotation_degrees", -1.0, 2.2)

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
	## @tool 的 Inspector 预览也会调用本方法；编辑器预览不能修改运行时 Global 状态。
	if not Engine.is_editor_hint():
		Global.developer_level_adjustments_active = false
		Global.developer_workshop_level_source = {}
	developer_menu.modulate = Color.WHITE
	for button in [menu_button_1, menu_button_2, menu_button_3, menu_button_4]:
		button.visible = not developer_mode
	developer_menu.visible = developer_mode
	_apply_normal_option_buttons()
	_apply_developer_store_button(developer_mode)
	if developer_mode:
		level_workshop_button.texture_normal = RETURN_NORMAL_TEXTURE
		level_workshop_button.tooltip_text = "返回正常模式"
		developer_mode_label.visible = false
		developer_button_1.tooltip_text = "选择关卡模板或自制关卡"
		developer_button_2.tooltip_text = "打开地图工坊"
		developer_button_3.tooltip_text = "调整植物与僵尸数值"
		developer_button_4.tooltip_text = "保存当前开发者数据并导出开发者包"
	else:
		level_workshop_button.texture_normal = normal_level_workshop_texture
		level_workshop_button.tooltip_text = "进入开发者模式"
		developer_mode_label.visible = false


func _apply_developer_store_button(enabled: bool) -> void:
	store_button.visible = enabled
	store_button.texture_normal = DEVELOPER_IMPORT_TEXTURE
	store_button.texture_pressed = DEVELOPER_IMPORT_HOVER_TEXTURE
	store_button.texture_hover = DEVELOPER_IMPORT_HOVER_TEXTURE
	_apply_texture_alpha_click_mask(store_button)
	store_button.tooltip_text = "导入开发者包" if enabled else ""


func _apply_normal_option_buttons() -> void:
	option_button.texture_normal = OPTION_NORMAL_TEXTURE
	option_button.texture_pressed = OPTION_HOVER_TEXTURE
	option_button.texture_hover = OPTION_HOVER_TEXTURE
	option_button.tooltip_text = "选项"
	help_button.position = Vector2(100, 98)
	help_button.size = Vector2(49, 26)
	help_button.texture_normal = HELP_NORMAL_TEXTURE
	help_button.texture_pressed = HELP_HOVER_TEXTURE
	help_button.texture_hover = HELP_HOVER_TEXTURE
	help_button.tooltip_text = "帮助"

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
	Global.adventure_mainline_mode = "normal"
	Global.change_scene_to_cached(Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.ChooseLevelAdventure])


func _start_normal_adventure() -> void:
	Global.adventure_mainline_mode = "normal"
	Global.change_scene_to_cached(Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.ChooseLevelAdventure])


func _start_chessboard_adventure() -> void:
	Global.adventure_mainline_mode = "chessboard"
	Global.change_scene_to_cached(Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.ChooseLevelAdventure])


## 迷你游戏
func _on_button_2_pressed() -> void:
	Global.game_para = null
	Global.developer_level_adjustments_active = false
	if developer_mode:
		Global.level_workshop_edit_mode = "normal"
		get_tree().change_scene_to_file(Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.LevelWorkshop])
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
		_save_and_export_developer_package()
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


func _save_and_export_developer_package() -> void:
	var backup := DeveloperPackageStore.save_backup()
	if not backup["ok"]:
		_show_developer_package_message("保存失败：%s" % str(backup["error"]))
		return
	var file_dialog := FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.current_file = "pvz_of_ow_developer_package.json"
	file_dialog.filters = ["*.json ; PVZ-of-OW 开发者包"]
	file_dialog.file_selected.connect(func(path: String):
		var result := DeveloperPackageStore.write_package(path, DeveloperPackageStore.build_package())
		_show_developer_package_message("保存并导出成功：%s" % path if result["ok"] else "导出失败：%s" % str(result["error"]))
		file_dialog.queue_free()
	)
	add_child(file_dialog)
	file_dialog.popup_centered_ratio(0.72)


func _open_developer_package_import() -> void:
	var file_dialog := FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = ["*.json ; PVZ-of-OW 开发者包"]
	file_dialog.file_selected.connect(func(path: String):
		var result := DeveloperPackageStore.import_package(path)
		if result["ok"]:
			_show_developer_package_message("导入成功：%d 个关卡模板，%d 个自制关卡。" % [result["classic_count"], result["custom_count"]])
		else:
			_show_developer_package_message("导入失败：%s" % str(result["error"]))
		file_dialog.queue_free()
	)
	add_child(file_dialog)
	file_dialog.popup_centered_ratio(0.72)


func _show_developer_package_message(message: String) -> void:
	$Dialog/Label.text = message
	$Dialog.appear_dialog()

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
	if developer_mode:
		_open_developer_package_import()
		return
	get_tree().change_scene_to_file(Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.Store])

## 点击用户更新时
func _on_button_update_user_pressed() -> void:
	user.visible = true
