extends CardBase
class_name Card

@onready var character_static: Node2D = $CardBg/CharacterStatic
@onready var short_cut: Label = $ShortCut
@onready var button: Button = $Button

## 是否为图鉴卡片
var is_almanac_card:bool= false

var _is_cooling : bool = false		# 是否正在冷却
var is_sun_enough: bool = true		# 阳光是否足够
var _cool_timer : float				# 冷却计时器
var is_can_click := true		## 是否可以点击
var tween_blink:Tween
var _is_ready_state := false
#region 开局选卡相关
## 开局选择卡片时 是否被选中
var is_choosed_pre_card := false
var card_candidate_container:CardCandidateContainer
#endregion
## 模仿者材质
const IMITATER = preload("res://shader_material/imitater.tres")

## 模仿者叠加颜色（在 inspector 中直接调整）
@export_group("模仿者染色", "imitater_")
@export var imitater_tint_color: Color = Color(0.427, 0.757, 0.992, 1.0)  # 天蓝色
@export var imitater_whiteness: float = 0.5   # 染色强度 (0 = 原图, 1 = 纯色)
@export var imitater_gray_strength: float = 0.0  # 灰度强度 (0 = 保留原色, 1 = 全灰)

## 点击信号,选卡时使用该信号(种植点击使用时间总线)
signal signal_card_click(card:Card)
## 卡片种植完成后信号，生成卡片所在卡槽连接该信号
@warning_ignore("unused_signal")
signal signal_card_use_end(card:Card)
## 卡片变为可用时发射
signal signal_card_ready(card:Card)

var is_hidden_by_squash_doomfist := false
var is_being_attacked_by_squash_doomfist := false
var _original_cool_time: float

func _ready() -> void:
	super()
	_original_cool_time = cool_time
	_cool_mask.value = 0
	if is_imitater:
		var mat := IMITATER.duplicate()
		mat.set_shader_parameter(&"tint_color", imitater_tint_color)
		mat.set_shader_parameter(&"whiteness", imitater_whiteness)
		mat.set_shader_parameter(&"gray_strength", imitater_gray_strength)
		character_static.material = mat
		for child in character_static.get_children():
			GlobalUtils.node_use_parent_material(child)

## 设置卡片为图鉴卡片
func set_almanac_card():
	is_almanac_card = true

## 改变卡片的冷却时间（测试时使用）
func card_change_cool_time(new_cool_time:float):
	self.cool_time = new_cool_time
	_cool_mask.value = 0

## 设置卡片冷却时间并开始冷却
func set_card_cool_time_start_cool(new_cool_time:float):
	self.cool_time = new_cool_time
	_cool_mask.value = cool_time
	card_cool()

## 设置卡片禁用(不冷却)
func set_card_disable():
	self.cool_time = 1
	_cool_mask.value = cool_time
	_is_cooling = false
	_cool_mask.visible = true
	is_can_click = false

## 传送带卡槽初始化卡片
func card_init_conveyor_belt():
	_cool_mask.value = 0
	sun_cost = 0


## 卡片冷卻
func _process(delta: float) -> void:
	if _is_cooling:
		_cool_timer -= delta
		_cool_mask.value = _cool_timer
		# 卡片冷却完成
		if _cool_timer <= 0:
			_is_cooling = false
			_restore_squash_doomfist_card_visual()
			judge_card_ready()

## 修改阳光时会调用
func judge_sun_enough(curr_sun_value):
	# 判断阳光是否足够
	is_sun_enough = curr_sun_value >= sun_cost
	judge_card_ready()

## 判断卡片是否可以点击
func judge_card_ready():
	# 阳光充足 且 卡片冷却完成
	if is_sun_enough and not _is_cooling:
		## 紫卡并且不能种植
		if is_purple_card and not plant_condition.judge_purple_card_can_plant(Global.main_game.plant_cell_manager.all_plant_cells, card_plant_type):
			card_not_can_click()
		else:
			card_ready()
	else:
		card_not_can_click()

func set_card_cool_end():
	_cool_timer = 0
	_cool_mask.value = _cool_timer
	_is_cooling = false
	_restore_squash_doomfist_card_visual()

## 卡片可以点击
func card_ready():
	if is_being_attacked_by_squash_doomfist:
		_cool_mask.visible = false
		is_can_click = false
		return
	if _is_cooling:
		return

	var should_emit_ready := not _is_ready_state
	if is_hidden_by_squash_doomfist:
		_restore_squash_doomfist_card_visual()
		should_emit_ready = true
	_cool_mask.visible = false
	is_can_click = true
	_is_ready_state = true
	if should_emit_ready:
		signal_card_ready.emit(self)

## 卡片不可以点击
func card_not_can_click():
	_cool_mask.visible = true
	is_can_click = false
	_is_ready_state = false

## 卡片开始冷却
func card_cool():
	_is_cooling = true
	_cool_mask.visible = true
	_cool_timer = cool_time
	_cool_mask.value = cool_time
	is_can_click = false
	_is_ready_state = false

func start_squash_doomfist_card_attack():
	is_being_attacked_by_squash_doomfist = true
	is_can_click = false
	_cool_mask.visible = false

func get_squash_doomfist_attack_screen_position() -> Vector2:
	return get_global_transform_with_canvas() * (size * 0.5 + Vector2(0, 24))

func hide_by_squash_doomfist():
	is_being_attacked_by_squash_doomfist = false
	is_hidden_by_squash_doomfist = true
	if not _set_squash_doomfist_ana_visual(true):
		if is_instance_valid(character_static):
			character_static.visible = false
	_cool_mask.max_value = _original_cool_time
	_is_cooling = true
	_cool_mask.visible = true
	_cool_timer = _original_cool_time
	_cool_mask.value = _original_cool_time
	is_can_click = false
	_is_ready_state = false

func _restore_squash_doomfist_card_visual():
	if not is_hidden_by_squash_doomfist:
		return

	is_hidden_by_squash_doomfist = false
	if not _set_squash_doomfist_ana_visual(false):
		if is_instance_valid(character_static):
			character_static.visible = true

func _set_squash_doomfist_ana_visual(is_hidden:bool) -> bool:
	if card_plant_type != CharacterRegistry.PlantType.P036CoffeeBeanAna:
		return false

	var ana_card_root := _get_squash_doomfist_ana_card_root()
	if not is_instance_valid(ana_card_root):
		return false

	var normal_card_sprite := _get_canvas_item_child(ana_card_root, ["card", "Card"])
	var hi_sprite := _get_canvas_item_child(ana_card_root, ["Hi", "hi"])
	if not is_instance_valid(normal_card_sprite) or not is_instance_valid(hi_sprite):
		return false

	if is_instance_valid(character_static):
		character_static.visible = true
	normal_card_sprite.visible = not is_hidden
	hi_sprite.visible = is_hidden
	return true

func _get_squash_doomfist_ana_card_root() -> Node:
	if not is_instance_valid(character_static):
		return null

	var ana_card_root := character_static.get_node_or_null(^"Plant067CoffeeBeanAna")
	if is_instance_valid(ana_card_root):
		return ana_card_root
	return character_static.get_node_or_null(^"Plant036CoffeeBeanAna")

func _get_canvas_item_child(parent_node:Node, node_names:Array[String]) -> CanvasItem:
	for node_name in node_names:
		var node := parent_node.get_node_or_null(NodePath(node_name))
		if node is CanvasItem:
			return node as CanvasItem
	return null

## 点击卡片时
func _on_button_pressed() -> void:
	## 如果为图鉴卡片
	if is_almanac_card:
		signal_card_click.emit()
		return

	## 如果时主游戏场景,并且游戏中
	if is_instance_valid(Global.main_game) and Global.main_game.main_game_progress == MainGameManager.E_MainGameProgress.MAIN_GAME:
		## 可以点击
		if is_can_click:
			EventBus.push_event("main_game_click_card", [self])
		else:
			SoundManager.play_other_SFX("buzzer")
	else:
		signal_card_click.emit()

## 快捷键设置
func set_shortcut(i:int):
	short_cut.text = str(i)
	short_cut.visible = true

func set_shortcut_disappear():
	short_cut.visible = false

#region 卡片闪烁
## 开始
func card_blink_start():
	# 如果已存在 tween，就先 kill 掉
	if tween_blink and tween_blink.is_valid():
		tween_blink.kill()
	tween_blink = create_tween()
	# 无限循环
	tween_blink.set_loops()  # 不传参数就是无限循环 :contentReference[oaicite:0]{index=0}

	# 淡出（透明度变为 0）
	tween_blink.tween_property(card_bg, "modulate:a", 0.5, 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# 淡入（透明度变为 1）
	tween_blink.tween_property(card_bg, "modulate:a", 1.0, 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
## 暂停
func card_blink_pause():
	if tween_blink and tween_blink.is_running():
		tween_blink.pause()

## 重新启动
func card_blink_resume():
	if tween_blink and not tween_blink.is_running():
		tween_blink.play()
## 停止
func card_blink_completely_stop():
	if tween_blink and tween_blink.is_valid():
		tween_blink.kill()
		tween_blink = null
#endregion

#region 鼠标检测
func mouse_filter_start():
	button.mouse_filter = Control.MOUSE_FILTER_PASS

func mouse_filter_stop():
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE

#endregion
