@tool
extends Control
class_name StartMenuRoot

const RETURN_NORMAL_TEXTURE := preload("res://assets/image/ui/ui_start_menu/button_return.png")
const LEVEL_WORKSHOP_NORMAL_TEXTURE := preload("res://assets/image/ui/ui_start_menu/button_developer.png")
const OPTION_NORMAL_TEXTURE := preload("res://assets/image/ui/ui_start_menu/SelectorScreen_Options1.png")
const OPTION_HOVER_TEXTURE := preload("res://assets/image/ui/ui_start_menu/SelectorScreen_Options2.png")
const DEVELOPER_IMPORT_TEXTURE := preload("res://assets/image/ui/ui_start_menu/SelectorScreen_DeveloperImport.png")
const DEVELOPER_IMPORT_HOVER_TEXTURE := preload("res://assets/image/ui/ui_start_menu/SelectorScreen_DeveloperImportHighlight.png")
const UI_BUTTON_BACKGROUND := preload("res://assets/image/ui/ui_main_game_menu/UI_BG/button_BG.png")
const UI_THEME := preload("res://data/PVZ_theme.tres")
const UI_FONT := preload("res://assets/fonts/方正少儿_GBK.ttf")
const BUFF_BEAM_SCENE := preload("res://scenes/effects/BuffBeam2D.tscn")
const PHARAH_WEAPON_GLOW_SHADER := preload("res://shaders/ui/pharah_weapon_glow.gdshader")
const PRODUCER_NAME_COLOR := Color(1.0, 1.0, 0.62352943, 1.0)
const PRODUCER_INFO_TEXT_Y := 88.0
const CREDITS_DIALOG_WIDTH := 390.0
const CREDITS_DIALOG_BUTTON_WIDTH := 160.0

@onready var dialog: Dialog = $Dialog
@onready var modal_input_blocker: Control = $ModalInputBlocker
@onready var option_dialog: StartMenuOptionDialog = $StartMenuOptionDialog
@onready var help_dialog: Dialog = $Dialog_Help
@onready var producer_info_dialog: Dialog = $ProducerInfoDialog
@onready var producer_info_text: RichTextLabel = $ProducerInfoDialog/InfoText
@onready var producer_name_label_1: Label = $WoodSign/CreditSign/TextLine1/ProducerNameLabel1
@onready var producer_name_label_2: Label = $WoodSign/CreditSign/TextLine2/ProducerNameLabel2
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
@onready var acknowledgements_label: Label = $BG_Right/Option/TextureButton2/Label
@onready var store_button: TextureButton = $BG_Right/Item/TextureButton3
@onready var garden_button: TextureButton = $BG_Right/Item/TextureButton
@onready var gift_button: TextureButton = $BG_Right/CustomButton
@onready var overwatch_logo: TextureRect = $OverwatchLogo
@onready var flight_layer: Control = $Cloud
@onready var flight_formation: Control = $Cloud/FlightFormation
@onready var flying_cat_group: Control = $Cloud/FlightFormation/FlyingCatGroup
@onready var flying_cat: TextureRect = $Cloud/FlightFormation/FlyingCatGroup/FlyingCat
@onready var flying_cat_companion: TextureRect = $Cloud/FlightFormation/FlyingCatGroup/FlyingCat/Companion
@onready var soft_flight_group: Control = $Cloud/FlightFormation/SoftFlightGroup
@onready var soft_flight_leader: TextureRect = $Cloud/FlightFormation/SoftFlightGroup/SoftFlightLeader
@onready var soft_flight_partner: TextureRect = $Cloud/FlightFormation/SoftFlightGroup/SoftFlightPartner
@onready var pharah_beam_anchor: Marker2D = $Cloud/FlightFormation/SoftFlightGroup/SoftFlightLeader/DamageBoostTargetAnchor
@onready var mercy_beam_anchor: Marker2D = $Cloud/FlightFormation/SoftFlightGroup/SoftFlightPartner/DamageBoostSourceAnchor
@onready var mercy_beam_direction_anchor: Marker2D = $Cloud/FlightFormation/SoftFlightGroup/SoftFlightPartner/DamageBoostSourceDirection
@onready var flying_cat_companion_landing_marker: Marker2D = $OWLawnGroup/FlyingCatCompanionLandingMarker

var developer_mode := false
var normal_level_workshop_texture: Texture2D
var level_workshop_notice: Control
var developer_button_hover_tweens: Dictionary = {}
var mode_dialog_context := "adventure"
var flight_formation_start_position := Vector2.ZERO
var flight_formation_horizontal_bounds := Vector2.ZERO
var flight_formation_motion_started := false
var soft_flight_damage_boost_beam: BuffBeam2D
var flying_cat_companion_start_position := Vector2.ZERO
var flying_cat_companion_start_scale := Vector2.ONE
var flying_cat_companion_swing_tween: Tween
var flying_cat_companion_drop_trigger_x := 0.0
var flying_cat_companion_dropped := false
var flying_cat_companion_landed := false
var flying_cat_companion_drop_carrier: Node2D
var flying_cat_companion_velocity := Vector2.ZERO
var flying_cat_companion_drop_pivot_global_position := Vector2.ZERO
var flying_cat_companion_drop_target_global_position := Vector2.ZERO
var flying_cat_companion_drop_start_scale := Vector2.ONE
var flying_cat_companion_drop_final_scale := Vector2.ONE
var flying_cat_companion_drop_start_rotation := 0.0
var flying_cat_companion_drop_elapsed := 0.0
var flying_cat_companion_drop_duration := 1.0

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

@export_group("飞行编队")
## 编队每秒向左移动的编辑器坐标距离。只控制整体速度，不控制成员出场时机。
@export_range(1.0, 500.0, 1.0, "suffix:px/s") var flight_formation_speed := 100.0

@export_subgroup("第一组 | 下方图片自由落体")
@export_range(0.0, 2000.0, 10.0, "suffix:px/s²") var flying_cat_companion_gravity := 520.0
## 相对于下方图片脱落瞬间的实际视觉尺寸，坠落过程中整体缩小到 90%。
@export_range(0.1, 1.5, 0.01) var flying_cat_companion_landing_scale := 0.9
## 在整体缩放之外额外横向压缩到 90%，让坠落图片稍微变瘦。
@export_range(0.1, 1.5, 0.01) var flying_cat_companion_landing_width_scale := 0.9
@export_range(-180.0, 180.0, 1.0, "suffix:°") var flying_cat_companion_landing_rotation_degrees := 90.0


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	## 两个姓名原本共用 LabelSettings；复制后悬停时可以只改变当前姓名。
	producer_name_label_1.label_settings = producer_name_label_1.label_settings.duplicate()
	producer_name_label_2.label_settings = producer_name_label_2.label_settings.duplicate()
	_apply_level_workshop_button_transform()
	_setup_developer_buttons()
	_hide_unavailable_start_menu_items()
	normal_level_workshop_texture = LEVEL_WORKSHOP_NORMAL_TEXTURE
	if Engine.is_editor_hint():
		_apply_editor_menu_preview()
		return
	_apply_credits_dialog_frame_layout()
	_setup_modal_input_blocking()
	_apply_developer_mode(Global.return_to_developer_mode)
	Global.return_to_developer_mode = false
	$Cloud/AnimationPlayer.play("Idle")
	$BG_Right/Leaf/AnimationPlayer.play("Idle")
	$AnimationPlayer.play("Idle")
	_setup_flying_decoration_motion()
	_start_flight_formation_motion()
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
	## 礼盒稍后由开发者模式状态统一控制；普通模式始终不可见、不可点击。
	gift_button.hide()
	gift_button.process_mode = Node.PROCESS_MODE_DISABLED


func _apply_credits_dialog_frame_layout() -> void:
	## 实例子节点覆盖可能被 Godot 在重新保存继承场景时清除；运行时固定外框尺寸兜底。
	## 文本节点的位置和尺寸仍由 01StartMenu.tscn 控制，方便在 Inspector 中手动微调。
	for credits_dialog: Dialog in [help_dialog, producer_info_dialog]:
		credits_dialog.offset_left = -CREDITS_DIALOG_WIDTH * 0.5
		credits_dialog.offset_right = CREDITS_DIALOG_WIDTH * 0.5
		var panel := credits_dialog.get_node("Panel") as Control
		panel.offset_left = 0.0
		panel.offset_right = CREDITS_DIALOG_WIDTH
		var return_button := credits_dialog.get_node("PVZButton") as Control
		return_button.offset_left = (CREDITS_DIALOG_WIDTH - CREDITS_DIALOG_BUTTON_WIDTH) * 0.5
		return_button.offset_right = return_button.offset_left + CREDITS_DIALOG_BUTTON_WIDTH


func _setup_modal_input_blocking() -> void:
	for modal: Control in [option_dialog, help_dialog, producer_info_dialog, dialog]:
		modal.visibility_changed.connect(_sync_modal_input_blocker)
	_sync_modal_input_blocker()


func _show_modal_input_blocker() -> void:
	## 先于弹窗的短延迟启用，避免快速连续点击在同一时刻打开多个弹窗。
	modal_input_blocker.visible = true
	modal_input_blocker.mouse_filter = Control.MOUSE_FILTER_STOP


func _sync_modal_input_blocker() -> void:
	var has_visible_modal := (
		option_dialog.visible
		or help_dialog.visible
		or producer_info_dialog.visible
		or dialog.visible
	)
	modal_input_blocker.visible = has_visible_modal
	modal_input_blocker.mouse_filter = (
		Control.MOUSE_FILTER_STOP if has_visible_modal else Control.MOUSE_FILTER_IGNORE
	)


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


func _setup_flying_decoration_motion() -> void:
	flight_formation.visible = true
	flying_cat_group.visible = true
	soft_flight_group.visible = true
	var flying_cat_rest_y := flying_cat.position.y
	var bob_tween := flying_cat.create_tween().set_loops()
	bob_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob_tween.tween_property(flying_cat, ^"position:y", flying_cat_rest_y - 10.0, 1.8)
	bob_tween.tween_property(flying_cat, ^"position:y", flying_cat_rest_y + 10.0, 1.8)
	flying_cat_companion_start_position = flying_cat_companion.position
	flying_cat_companion_start_scale = flying_cat_companion.scale
	_start_flying_cat_companion_swing()
	_setup_soft_flight_pair_motion()


func _start_flying_cat_companion_swing() -> void:
	## 以上边缘中央作为钩爪抓点，让下半身像吊坠一样左右摆动。
	flying_cat_companion.pivot_offset = Vector2(
		flying_cat_companion.size.x * 0.5,
		flying_cat_companion.size.y * 0.17
	)
	flying_cat_companion.rotation_degrees = -8.0
	flying_cat_companion_swing_tween = flying_cat_companion.create_tween().set_loops()
	flying_cat_companion_swing_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	flying_cat_companion_swing_tween.tween_property(flying_cat_companion, ^"rotation_degrees", 8.0, 1.05)
	flying_cat_companion_swing_tween.tween_property(flying_cat_companion, ^"rotation_degrees", -8.0, 1.05)


func _setup_soft_flight_pair_motion() -> void:
	var leader_rest_y := soft_flight_leader.position.y
	var partner_rest_y := soft_flight_partner.position.y
	soft_flight_leader.pivot_offset = soft_flight_leader.size * 0.5
	soft_flight_leader.rotation_degrees = -2.5
	var leader_bob := soft_flight_leader.create_tween().set_loops()
	leader_bob.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	leader_bob.tween_property(soft_flight_leader, ^"position:y", leader_rest_y - 12.0, 1.35)
	leader_bob.parallel().tween_property(soft_flight_leader, ^"rotation_degrees", 2.5, 1.35)
	leader_bob.tween_property(soft_flight_leader, ^"position:y", leader_rest_y + 12.0, 1.35)
	leader_bob.parallel().tween_property(soft_flight_leader, ^"rotation_degrees", -2.5, 1.35)

	soft_flight_partner.pivot_offset = soft_flight_partner.size * 0.5
	soft_flight_partner.rotation_degrees = 4.0
	var partner_bob := soft_flight_partner.create_tween().set_loops()
	partner_bob.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	partner_bob.tween_property(soft_flight_partner, ^"position:y", partner_rest_y + 17.0, 1.9)
	partner_bob.parallel().tween_property(soft_flight_partner, ^"rotation_degrees", -5.0, 1.9)
	partner_bob.tween_property(soft_flight_partner, ^"position:y", partner_rest_y - 17.0, 1.9)
	partner_bob.parallel().tween_property(soft_flight_partner, ^"rotation_degrees", 4.0, 1.9)
	_setup_soft_flight_damage_boost_effect()


func _setup_soft_flight_damage_boost_effect() -> void:
	soft_flight_damage_boost_beam = BUFF_BEAM_SCENE.instantiate()
	soft_flight_damage_boost_beam.name = "MercyPharahDamageBoostBeam"
	soft_flight_damage_boost_beam.beam_width = 7.0
	soft_flight_damage_boost_beam.curve_height = -3.0
	soft_flight_damage_boost_beam.point_count = 32
	soft_flight_damage_boost_beam.z_index_override = 0
	soft_flight_group.add_child(soft_flight_damage_boost_beam)
	soft_flight_group.move_child(soft_flight_damage_boost_beam, 0)

	var glow_overlay := TextureRect.new()
	glow_overlay.name = "PharahWeaponGlow"
	glow_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow_overlay.texture = soft_flight_leader.texture
	glow_overlay.expand_mode = soft_flight_leader.expand_mode
	glow_overlay.stretch_mode = soft_flight_leader.stretch_mode
	glow_overlay.flip_h = soft_flight_leader.flip_h
	## 保持在 Cloud 分支的默认层级，确保 BG_Right 墓碑始终遮挡整个特效。
	glow_overlay.z_index = 0
	var glow_material := ShaderMaterial.new()
	glow_material.shader = PHARAH_WEAPON_GLOW_SHADER
	glow_overlay.material = glow_material
	soft_flight_leader.add_child(glow_overlay)


func _update_soft_flight_damage_boost_effect() -> void:
	if not is_instance_valid(soft_flight_damage_boost_beam):
		return
	var source_local:Vector2 = soft_flight_damage_boost_beam.to_local(mercy_beam_anchor.global_position)
	var direction_local:Vector2 = soft_flight_damage_boost_beam.to_local(mercy_beam_direction_anchor.global_position)
	var target_local:Vector2 = soft_flight_damage_boost_beam.to_local(pharah_beam_anchor.global_position)
	var source_tangent := direction_local - source_local
	soft_flight_damage_boost_beam.set_start_tangent(source_tangent, minf(source_tangent.length(), 4.0))
	soft_flight_damage_boost_beam.set_endpoints(source_local, target_local)


func _start_flight_formation_motion() -> void:
	## 起点完全采用编辑器中 FlightFormation 的位置，不在运行时重新计算或覆盖。
	flight_formation_start_position = flight_formation.position
	flight_formation_horizontal_bounds = _get_flight_group_horizontal_bounds(flight_formation)
	_update_flying_cat_companion_drop_trigger()
	flight_formation_motion_started = true


func _update_flying_cat_companion_drop_trigger() -> void:
	## 小猫现在位于第二个出场槽位，但安娜仍需在交换前第一组经过的位置脱落。
	## 先按小猫原本位于 x=0 的第一组槽位求出旧触发点，再抵消小猫组交换后的横移量。
	var original_first_group_bounds := _get_flight_group_horizontal_bounds(flying_cat_group)
	var original_first_group_exit_x := \
		_flight_layer_x(-80.0) - original_first_group_bounds.y
	var original_drop_trigger_x := lerpf(
		flight_formation_start_position.x,
		original_first_group_exit_x,
		0.5
	)
	flying_cat_companion_drop_trigger_x = \
		original_drop_trigger_x - flying_cat_group.position.x


func _drop_flying_cat_companion() -> void:
	if flying_cat_companion_dropped:
		return
	flying_cat_companion_dropped = true
	if is_instance_valid(flying_cat_companion_swing_tween):
		flying_cat_companion_swing_tween.kill()
	var takeoff_transform := flying_cat_companion.get_global_transform()
	var takeoff_center_global:Vector2 = takeoff_transform * (flying_cat_companion.size * 0.5)

	## 独立 Node2D 载体的原点就是贴图视觉中心；后续位置、旋转和缩放不再受 Control
	## 重挂父级后的锚点/偏移影响。
	flying_cat_companion_drop_carrier = Node2D.new()
	flying_cat_companion_drop_carrier.name = "FlyingCatCompanionDropCarrier"
	add_child(flying_cat_companion_drop_carrier)
	## 保持安娜位于主界面前景，但将动态载体固定插在所有弹窗之前，避免覆盖弹窗内容。
	move_child(flying_cat_companion_drop_carrier, $StartMenuOptionDialog.get_index())
	flying_cat_companion_drop_carrier.global_position = takeoff_center_global
	flying_cat_companion_drop_carrier.global_rotation = takeoff_transform.get_rotation()
	flying_cat_companion_drop_carrier.global_scale = takeoff_transform.get_scale()
	flying_cat_companion.reparent(flying_cat_companion_drop_carrier, false)
	flying_cat_companion.position = -flying_cat_companion.size * 0.5
	flying_cat_companion.rotation = 0.0
	flying_cat_companion.scale = Vector2.ONE
	flying_cat_companion.pivot_offset = Vector2.ZERO

	flying_cat_companion_drop_pivot_global_position = \
		flying_cat_companion_drop_carrier.global_position
	flying_cat_companion_drop_target_global_position = flying_cat_companion_landing_marker.global_position
	flying_cat_companion_drop_start_scale = flying_cat_companion_drop_carrier.scale
	## 以脱离小猫瞬间的实际屏幕尺寸为基准，坠落时整体缩小并额外横向压缩。
	## 不能再使用 Companion 的局部 scale，否则父节点缩放会被重复计算，造成落地反而变小。
	flying_cat_companion_drop_final_scale = \
		flying_cat_companion_drop_start_scale \
		* flying_cat_companion_landing_scale \
		* Vector2(flying_cat_companion_landing_width_scale, 1.0)
	flying_cat_companion_drop_start_rotation = flying_cat_companion_drop_carrier.rotation
	flying_cat_companion_drop_elapsed = 0.0
	flying_cat_companion_landed = false

	## 竖直初速度为零，由落点高度反求落地时间，再反求恒定水平速度。
	var gravity := maxf(flying_cat_companion_gravity, 1.0)
	var fall_height := maxf(
		flying_cat_companion_drop_target_global_position.y \
			- flying_cat_companion_drop_pivot_global_position.y,
		1.0
	)
	flying_cat_companion_drop_duration = maxf(sqrt(2.0 * fall_height / gravity), 0.35)
	var horizontal_distance := flying_cat_companion_drop_target_global_position.x \
		- flying_cat_companion_drop_pivot_global_position.x
	flying_cat_companion_velocity = Vector2(
		horizontal_distance / flying_cat_companion_drop_duration,
		0.0
	)


func _update_flying_cat_companion_free_fall(delta:float) -> void:
	if not flying_cat_companion_dropped or flying_cat_companion_landed:
		return
	var remaining_time := flying_cat_companion_drop_duration - flying_cat_companion_drop_elapsed
	var physics_delta := minf(delta, maxf(remaining_time, 0.0))
	var gravity_step := Vector2(0.0, flying_cat_companion_gravity)
	flying_cat_companion_drop_pivot_global_position += \
		flying_cat_companion_velocity * physics_delta \
		+ gravity_step * (0.5 * physics_delta * physics_delta)
	flying_cat_companion_velocity += gravity_step * physics_delta
	flying_cat_companion_drop_elapsed += physics_delta

	var progress := clampf(
		flying_cat_companion_drop_elapsed / flying_cat_companion_drop_duration,
		0.0,
		1.0
	)
	var visual_progress := smoothstep(0.0, 1.0, progress)
	flying_cat_companion_drop_carrier.scale = flying_cat_companion_drop_start_scale.lerp(
		flying_cat_companion_drop_final_scale,
		visual_progress
	)
	flying_cat_companion_drop_carrier.rotation = lerp_angle(
		flying_cat_companion_drop_start_rotation,
		deg_to_rad(flying_cat_companion_landing_rotation_degrees),
		visual_progress
	)
	flying_cat_companion_drop_carrier.global_position = \
		flying_cat_companion_drop_pivot_global_position

	if progress >= 1.0:
		flying_cat_companion_landed = true
		flying_cat_companion_velocity = Vector2.ZERO
		flying_cat_companion_drop_pivot_global_position = \
			flying_cat_companion_landing_marker.global_position
		flying_cat_companion_drop_carrier.global_position = \
			flying_cat_companion_drop_pivot_global_position


func _reset_flying_cat_companion() -> void:
	if is_instance_valid(flying_cat_companion_swing_tween):
		flying_cat_companion_swing_tween.kill()
	if flying_cat_companion.get_parent() != flying_cat:
		flying_cat_companion.reparent(flying_cat, false)
	if is_instance_valid(flying_cat_companion_drop_carrier):
		flying_cat_companion_drop_carrier.queue_free()
	flying_cat_companion_drop_carrier = null
	flying_cat_companion.position = flying_cat_companion_start_position
	flying_cat_companion.scale = flying_cat_companion_start_scale
	flying_cat_companion.visible = true
	flying_cat_companion_dropped = false
	flying_cat_companion_landed = false
	flying_cat_companion_velocity = Vector2.ZERO
	_start_flying_cat_companion_swing()


func _process(delta:float) -> void:
	if Engine.is_editor_hint() or not flight_formation_motion_started:
		return
	_update_soft_flight_damage_boost_effect()
	flight_formation.position.x -= flight_formation_speed * delta
	if not flying_cat_companion_dropped \
	and flight_formation.position.x <= flying_cat_companion_drop_trigger_x:
		_drop_flying_cat_companion()
	_update_flying_cat_companion_free_fall(delta)
	var right_edge := flight_formation.position.x + flight_formation_horizontal_bounds.y
	if right_edge <= _flight_layer_x(-80.0):
		## 整支编队离开左侧后，直接回到编辑器保存的起点继续下一轮。
		flight_formation.position = flight_formation_start_position
		_reset_flying_cat_companion()


func _get_flight_group_horizontal_bounds(group:Control) -> Vector2:
	var left := INF
	var right := -INF
	var members := group.find_children("*", "Control", true, false)
	for member_node:Node in members:
		var member := member_node as Control
		for corner:Vector2 in [
			Vector2.ZERO,
			Vector2(member.size.x, 0.0),
			member.size,
			Vector2(0.0, member.size.y),
		]:
			var corner_global:Vector2 = member.get_global_transform() * corner
			var corner_in_group:Vector2 = group.get_global_transform().affine_inverse() * corner_global
			left = minf(left, corner_in_group.x)
			right = maxf(right, corner_in_group.x)
	if is_inf(left) or is_inf(right):
		return Vector2.ZERO
	return Vector2(left, right)


func _flight_layer_x(root_x: float) -> float:
	var global_point := get_global_transform() * Vector2(root_x, 0.0)
	return (flight_layer.get_global_transform().affine_inverse() * global_point).x


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
	if not enabled and not Engine.is_editor_hint():
		Global.developer_gift_test_levels_active = false
	## 开发者菜单本身不是关卡；只有从对应入口真正进关时才开启数值覆盖。
	## @tool 的 Inspector 预览也会调用本方法；编辑器预览不能修改运行时 Global 状态。
	if not Engine.is_editor_hint():
		Global.developer_level_adjustments_active = false
		Global.developer_workshop_level_source = {}
	developer_menu.modulate = Color.WHITE
	for button in [menu_button_1, menu_button_2, menu_button_3, menu_button_4]:
		button.visible = not developer_mode
	developer_menu.visible = developer_mode
	gift_button.visible = developer_mode
	gift_button.process_mode = Node.PROCESS_MODE_INHERIT if developer_mode else Node.PROCESS_MODE_DISABLED
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
	help_button.texture_normal = null
	help_button.texture_pressed = null
	help_button.texture_hover = null
	help_button.tooltip_text = "鸣谢"
	acknowledgements_label.label_settings.font_color = Color.BLACK

## 花园需要浇水
var garden_need_water:=true

## 功能未实现
func _unrealized():
	_show_modal_input_blocker()
	dialog.appear_dialog()

## 开始游戏
func _on_button_1_pressed() -> void:
	Global.game_para = null
	Global.developer_gift_test_levels_active = false
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
		_show_level_workshop_notice()
		return
	get_tree().change_scene_to_file(Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.ChooseLevelMiniGame])


func _show_level_workshop_notice() -> void:
	if is_instance_valid(level_workshop_notice):
		return
	## 使用既有主题、字体和按钮底图；操作区固定在弹窗底部，不会被长说明文本挤出。
	level_workshop_notice = Control.new()
	level_workshop_notice.name = "LevelWorkshopNotice"
	level_workshop_notice.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	level_workshop_notice.mouse_filter = Control.MOUSE_FILTER_STOP
	level_workshop_notice.theme = UI_THEME
	level_workshop_notice.z_index = 100
	add_child(level_workshop_notice)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.52)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	level_workshop_notice.add_child(dim)

	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -330.0
	panel.offset_top = -220.0
	panel.offset_right = 330.0
	panel.offset_bottom = 220.0
	panel.theme_type_variation = &"PanelDialogBG"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	level_workshop_notice.add_child(panel)

	var title := Label.new()
	title.position = Vector2(50.0, 34.0)
	title.size = Vector2(560.0, 42.0)
	title.text = "关卡工坊说明"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", UI_FONT)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("f7eccb"))
	panel.add_child(title)

	var content := RichTextLabel.new()
	content.position = Vector2(66.0, 92.0)
	content.size = Vector2(528.0, 224.0)
	content.bbcode_enabled = true
	content.fit_content = false
	content.scroll_active = true
	content.add_theme_font_override("normal_font", UI_FONT)
	content.add_theme_font_size_override("normal_font_size", 18)
	content.add_theme_color_override("default_color", Color("f4f0dc"))
	content.add_theme_constant_override("line_separation", 7)
	content.text = "[center]进阶编辑模式仍在持续完善；若想快速搭建关卡，建议优先使用简易编辑模式。[/center]\n\n[b]简易编辑模式[/b]：系统会根据你选定的僵尸阵容，自动计算并分配各波次的出怪组合。可通过“刷怪次数”控制整体压力，并通过“后期刷怪曲线”调节后期波次的强度爬升。\n\n[b]进阶编辑模式[/b]：可逐波手动设置登场僵尸，并细致编排每一波的刷怪节奏，适合需要高度自定义关卡流程与难度节奏的设计。"
	panel.add_child(content)

	var footer := Control.new()
	footer.position = Vector2(0.0, 342.0)
	footer.size = Vector2(660.0, 74.0)
	footer.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_child(footer)
	footer.add_child(_make_level_workshop_notice_button("取消", Vector2(165.0, 14.0), func(): _close_level_workshop_notice()))
	footer.add_child(_make_level_workshop_notice_button("确认进入", Vector2(350.0, 14.0), _enter_level_workshop))


func _make_level_workshop_notice_button(text: String, position_value: Vector2, callback: Callable) -> Button:
	var button := Button.new()
	button.position = position_value
	button.size = Vector2(145.0, 46.0)
	button.flat = true
	button.tooltip_text = text
	button.pressed.connect(callback)
	var background := NinePatchRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.texture = UI_BUTTON_BACKGROUND
	background.patch_margin_left = 16
	background.patch_margin_top = 16
	background.patch_margin_right = 16
	background.patch_margin_bottom = 20
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(background)
	var label := Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", 19)
	label.add_theme_color_override("font_color", Color("2d331e"))
	button.add_child(label)
	return button


func _close_level_workshop_notice() -> void:
	if is_instance_valid(level_workshop_notice):
		level_workshop_notice.queue_free()
	level_workshop_notice = null


func _enter_level_workshop() -> void:
	_close_level_workshop_notice()
	Global.level_workshop_edit_mode = "normal"
	get_tree().change_scene_to_file(Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.LevelWorkshop])

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
	Global.developer_gift_test_levels_active = true
	Global.developer_level_adjustments_active = true
	get_tree().change_scene_to_file(Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.ChooseLevelCustom])

## 切换开发者模式/正常模式
func _on_level_workshop_button_pressed() -> void:
	_apply_developer_mode(not developer_mode)

#region 选项
func _on_option_button_1_pressed() -> void:
	_show_modal_input_blocker()
	option_dialog.appear_menu()


func _on_option_button_2_pressed() -> void:
	_show_modal_input_blocker()
	help_dialog.appear_dialog()


func _on_acknowledgements_button_mouse_entered() -> void:
	acknowledgements_label.label_settings.font_color = Color(0, 1, 0, 1)


func _on_acknowledgements_button_mouse_exited() -> void:
	acknowledgements_label.label_settings.font_color = Color.BLACK


func _on_producer_name_label_1_pressed() -> void:
	_show_producer_info(
		"[center][color=#ffffff]bilibili：[/color][color=#ffff9f]瓦尔泽亚1582[/color]"
		+ "\n\n[color=#ffffff]后续我将在该频道开源所有代码"
		+ "\n并发布快速制作pvz改版游戏的教程。[/color][/center]"
	)


func _on_producer_name_label_2_pressed() -> void:
	_show_producer_info(
		"[center][color=#ffffff]抖音：[/color][color=#ffff9f]无敌霹雳大战锤[/color]"
		+ "\n[color=#ffffff]小红书：[/color][color=#ffff9f]阿伍不爱喝咖啡[/color]"
		+ "\n[color=#ffffff]小黑盒：[/color][color=#ffff9f]爱玩游戏的男孩57[/color][/center]",
		8,
		15.0
	)


func _show_producer_info(info: String, line_separation: int = 0, vertical_offset: float = 0.0) -> void:
	_show_modal_input_blocker()
	producer_info_text.text = info
	producer_info_text.position.y = PRODUCER_INFO_TEXT_Y + vertical_offset
	if line_separation > 0:
		producer_info_text.add_theme_constant_override("line_separation", line_separation)
	else:
		producer_info_text.remove_theme_constant_override("line_separation")
	producer_info_dialog.appear_dialog()


func _on_producer_name_button_1_mouse_entered() -> void:
	_set_producer_name_hovered(producer_name_label_1, true)


func _on_producer_name_button_1_mouse_exited() -> void:
	_set_producer_name_hovered(producer_name_label_1, false)


func _on_producer_name_button_2_mouse_entered() -> void:
	_set_producer_name_hovered(producer_name_label_2, true)


func _on_producer_name_button_2_mouse_exited() -> void:
	_set_producer_name_hovered(producer_name_label_2, false)


func _set_producer_name_hovered(label: Label, hovered: bool) -> void:
	label.label_settings.font_color = Color.WHITE if hovered else PRODUCER_NAME_COLOR


func _save_and_export_developer_package() -> void:
	var backup := DeveloperPackageStore.save_backup()
	if not backup["ok"]:
		_show_developer_package_message("保存失败：%s" % str(backup["error"]))
		return
	var file_dialog := FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.current_dir = ProjectSettings.globalize_path(DeveloperPackageStore.package_directory())
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
	file_dialog.current_dir = ProjectSettings.globalize_path(DeveloperPackageStore.package_directory())
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
