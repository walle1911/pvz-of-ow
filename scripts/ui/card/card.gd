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
## 安娜咖啡豆卡在战斗阶段可以切换为普通咖啡豆；两种形态共用同一份冷却进度。
var _is_ana_coffee_dual_card := false
var _is_ana_coffee_mode := false
var _ana_coffee_mode_toggle:TextureButton
var _ana_coffee_mode_toggle_icon:TextureRect
var _ana_coffee_mode_toggle_cool_mask:ProgressBar
var _ana_coffee_preview_root:Node2D
var _normal_coffee_preview_root:Node2D
## 双卡当前这一轮共享冷却的总时长。切换形态只改变下一次使用的配置，不改变本轮冷却池。
var _ana_coffee_shared_cool_duration := 0.0
var _ana_coffee_cool_time := 0.0
var _normal_coffee_cool_time := 0.0
const ANA_COFFEE_CARD_TEXTURE := preload("res://assets/image/ui/Character_Card/CoffeeBean_Ana_Card.png")
const NORMAL_COFFEE_CARD_TEXTURE := preload("res://assets/reanim/Coffeebean_head1.png")
const MINI_SEED_PACKET_TEXTURE := preload("res://assets/image/ui/ui_card/SeedPacket_Larger.png")
## 棋盘格正式模式翻地奖励卡：允许绕过 OW 紫卡前置规则。
var is_chessboard_reveal_reward := false
## 棋盘格翻地获得的友军僵尸卡，落地后立即走现有魅惑流程。
var is_chessboard_hypno_reward := false
## 排位奖励传送带的一次性消耗卡。保留原生阳光费用，但不进入冷却。
var is_ranked_reward_consumable := false
## 翻地后落在草坪上的待拾取奖励；点击只执行收集，不进入手持种植状态。
var is_ranked_board_pickup := false
var is_ranked_pickup_collecting := false
signal signal_ranked_pickup_clicked(card:Card)

func _ready() -> void:
	super()
	_is_ana_coffee_dual_card = card_plant_type == CharacterRegistry.PlantType.P036CoffeeBeanAna
	_is_ana_coffee_mode = _is_ana_coffee_dual_card
	if _is_ana_coffee_dual_card and is_instance_valid(character_static) and character_static.get_child_count() > 0:
		_ana_coffee_preview_root = character_static.get_child(0) as Node2D
	_apply_developer_plant_card_values()
	if _is_ana_coffee_dual_card:
		_ana_coffee_cool_time = cool_time
		_normal_coffee_cool_time = Global.character_registry.get_plant_info(
			CharacterRegistry.PlantType.P536CoffeeBean,
			CharacterRegistry.PlantInfoAttribute.CoolTime
		)
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

func _apply_developer_plant_card_values() -> void:
	if card_plant_type == CharacterRegistry.PlantType.Null:
		return
	cool_time = Global.character_registry.get_plant_info(card_plant_type, CharacterRegistry.PlantInfoAttribute.CoolTime)
	sun_cost = Global.character_registry.get_plant_info(card_plant_type, CharacterRegistry.PlantInfoAttribute.SunCost)

## 设置卡片为图鉴卡片
func set_almanac_card():
	is_almanac_card = true

## 改变卡片的冷却时间（测试时使用）
func card_change_cool_time(new_cool_time:float):
	if _is_ana_coffee_dual_card:
		var active_base_cool_time := _ana_coffee_cool_time if _is_ana_coffee_mode else _normal_coffee_cool_time
		var cooldown_scale := new_cool_time / active_base_cool_time if active_base_cool_time > 0.0 else 0.0
		_ana_coffee_cool_time *= cooldown_scale
		_normal_coffee_cool_time *= cooldown_scale
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

## 排位奖励卡初始化：与传统传送带不同，保留角色原生阳光费用。
func card_init_ranked_reward():
	is_ranked_reward_consumable = true
	_is_cooling = false
	_cool_timer = 0.0
	_cool_mask.value = 0
	_cool_mask.visible = false
	is_can_click = true
	_is_ready_state = true


## 卡片冷卻
func _process(delta: float) -> void:
	_ensure_ana_coffee_toggle_in_battle()
	if _is_cooling:
		_cool_timer -= delta
		_cool_mask.value = _cool_timer
		_sync_ana_coffee_toggle_cool_mask()
		# 卡片冷却完成
		if _cool_timer <= 0:
			_is_cooling = false
			_sync_ana_coffee_toggle_cool_mask()
			_ana_coffee_shared_cool_duration = 0.0
			_restore_squash_doomfist_card_visual()
			judge_card_ready()


## 只有进入正式战斗后才创建小切换卡，避免选卡阶段改变安娜卡的身份和存档数据。
func _ensure_ana_coffee_toggle_in_battle() -> void:
	if not _is_ana_coffee_dual_card or is_instance_valid(_ana_coffee_mode_toggle):
		return
	if not is_instance_valid(Global.main_game) \
		or Global.main_game.main_game_progress != MainGameManager.E_MainGameProgress.MAIN_GAME:
		return

	_ana_coffee_mode_toggle = TextureButton.new()
	_ana_coffee_mode_toggle.name = "AnaCoffeeModeToggle"
	_ana_coffee_mode_toggle.position = Vector2(size.x - 19.0, 2.0)
	_ana_coffee_mode_toggle.size = Vector2(18.0, 23.0)
	_ana_coffee_mode_toggle.z_index = 100
	_ana_coffee_mode_toggle.mouse_filter = Control.MOUSE_FILTER_STOP
	_ana_coffee_mode_toggle.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_ana_coffee_mode_toggle.texture_normal = MINI_SEED_PACKET_TEXTURE
	_ana_coffee_mode_toggle.ignore_texture_size = true
	_ana_coffee_mode_toggle.stretch_mode = TextureButton.STRETCH_SCALE
	_ana_coffee_mode_toggle.tooltip_text = "切换为普通咖啡豆"
	_ana_coffee_mode_toggle.pressed.connect(_toggle_ana_coffee_mode)
	_ana_coffee_mode_toggle.mouse_entered.connect(
		func(): _ana_coffee_mode_toggle.self_modulate = Color(1.12, 1.12, 1.12, 1.0)
	)
	_ana_coffee_mode_toggle.mouse_exited.connect(
		func(): _ana_coffee_mode_toggle.self_modulate = Color.WHITE
	)
	add_child(_ana_coffee_mode_toggle)

	_ana_coffee_mode_toggle_icon = TextureRect.new()
	_ana_coffee_mode_toggle_icon.name = "ModeIcon"
	_ana_coffee_mode_toggle_icon.position = Vector2(2.0, 2.0)
	_ana_coffee_mode_toggle_icon.size = Vector2(14.0, 17.0)
	_ana_coffee_mode_toggle_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ana_coffee_mode_toggle_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ana_coffee_mode_toggle_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_ana_coffee_mode_toggle.add_child(_ana_coffee_mode_toggle_icon)

	_ana_coffee_mode_toggle_cool_mask = _cool_mask.duplicate() as ProgressBar
	_ana_coffee_mode_toggle_cool_mask.name = "SharedCooldownMask"
	_ana_coffee_mode_toggle_cool_mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ana_coffee_mode_toggle_cool_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ana_coffee_mode_toggle.add_child(_ana_coffee_mode_toggle_cool_mask)
	_update_ana_coffee_toggle_visual()
	_sync_ana_coffee_toggle_cool_mask()


func _toggle_ana_coffee_mode() -> void:
	if not _is_ana_coffee_dual_card or is_being_attacked_by_squash_doomfist:
		return
	_cancel_hand_if_this_card_is_selected()
	_set_ana_coffee_mode(not _is_ana_coffee_mode)
	SoundManager.play_other_SFX("tap")


func _set_ana_coffee_mode(use_ana:bool) -> void:
	if not _is_ana_coffee_dual_card or _is_ana_coffee_mode == use_ana:
		return
	if not use_ana and not _ensure_normal_coffee_preview():
		return

	_is_ana_coffee_mode = use_ana
	var next_plant_type := CharacterRegistry.PlantType.P036CoffeeBeanAna \
		if use_ana else CharacterRegistry.PlantType.P536CoffeeBean
	card_plant_type = next_plant_type
	plant_condition = Global.character_registry.get_plant_info(
		next_plant_type,
		CharacterRegistry.PlantInfoAttribute.PlantConditionResource
	)
	sun_cost = Global.character_registry.get_plant_info(
		next_plant_type,
		CharacterRegistry.PlantInfoAttribute.SunCost
	)
	cool_time = _ana_coffee_cool_time if use_ana else _normal_coffee_cool_time
	_sync_ana_coffee_preview()
	_update_ana_coffee_toggle_visual()

	if _is_cooling:
		# 正在进行的冷却属于双卡共享池，切换形态不得改变剩余时间或总时长。
		_cool_mask.max_value = _ana_coffee_shared_cool_duration
		_cool_mask.value = _cool_timer
	_sync_ana_coffee_toggle_cool_mask()
	_refresh_sun_and_ready_state_after_mode_switch()


func _ensure_normal_coffee_preview() -> bool:
	if is_instance_valid(_normal_coffee_preview_root):
		return true
	if not AllCards.all_plant_card_prefabs.has(CharacterRegistry.PlantType.P536CoffeeBean):
		return false
	var normal_card := AllCards.all_plant_card_prefabs[CharacterRegistry.PlantType.P536CoffeeBean] as Card
	if not is_instance_valid(normal_card) or not is_instance_valid(normal_card.character_static) \
		or normal_card.character_static.get_child_count() == 0:
		return false
	_normal_coffee_preview_root = normal_card.character_static.get_child(0).duplicate() as Node2D
	if not is_instance_valid(_normal_coffee_preview_root):
		return false
	_normal_coffee_preview_root.name = "Plant536CoffeeBeanCardMode"
	_normal_coffee_preview_root.visible = false
	character_static.add_child(_normal_coffee_preview_root)
	return true


func _sync_ana_coffee_preview() -> void:
	if is_instance_valid(_ana_coffee_preview_root):
		_ana_coffee_preview_root.visible = _is_ana_coffee_mode
		if _is_ana_coffee_mode:
			character_static.move_child(_ana_coffee_preview_root, 0)
	if is_instance_valid(_normal_coffee_preview_root):
		_normal_coffee_preview_root.visible = not _is_ana_coffee_mode
		if not _is_ana_coffee_mode:
			character_static.move_child(_normal_coffee_preview_root, 0)


func _update_ana_coffee_toggle_visual() -> void:
	if not is_instance_valid(_ana_coffee_mode_toggle):
		return
	if is_instance_valid(_ana_coffee_mode_toggle_icon):
		_ana_coffee_mode_toggle_icon.texture = NORMAL_COFFEE_CARD_TEXTURE if _is_ana_coffee_mode else ANA_COFFEE_CARD_TEXTURE
	_ana_coffee_mode_toggle.tooltip_text = "切换为普通咖啡豆" if _is_ana_coffee_mode else "切换为安娜咖啡豆"


func _sync_ana_coffee_toggle_cool_mask() -> void:
	if not is_instance_valid(_ana_coffee_mode_toggle_cool_mask):
		return
	_ana_coffee_mode_toggle_cool_mask.visible = _is_cooling
	if not _is_cooling:
		_ana_coffee_mode_toggle_cool_mask.value = 0.0
		return
	_ana_coffee_mode_toggle_cool_mask.max_value = maxf(_ana_coffee_shared_cool_duration, 0.001)
	_ana_coffee_mode_toggle_cool_mask.value = maxf(_cool_timer, 0.0)


func _cancel_hand_if_this_card_is_selected() -> void:
	if not is_instance_valid(Global.main_game) or not is_instance_valid(Global.main_game.hand_manager):
		return
	var hand_manager:HandManager = Global.main_game.hand_manager
	if hand_manager.curr_hm_status == HandManager.E_HandManagerStatus.Character \
		and hand_manager.hm_character.curr_card == self:
		hand_manager.curr_hm_status = HandManager.E_HandManagerStatus.Null


func _refresh_sun_and_ready_state_after_mode_switch() -> void:
	if is_instance_valid(Global.main_game) and is_instance_valid(Global.main_game.card_manager) \
		and is_instance_valid(Global.main_game.card_manager.card_slot_battle):
		judge_sun_enough(Global.main_game.card_manager.card_slot_battle.sun_value)
	else:
		judge_card_ready()


func is_ana_coffee_mode_active() -> bool:
	return _is_ana_coffee_dual_card and _is_ana_coffee_mode


## 双形态切换只改变本次种植内容；关卡解锁检查仍按玩家实际选入卡槽的安娜卡判断。
func get_availability_plant_type() -> CharacterRegistry.PlantType:
	if _is_ana_coffee_dual_card:
		return CharacterRegistry.PlantType.P036CoffeeBeanAna
	return card_plant_type

## 修改阳光时会调用
func judge_sun_enough(curr_sun_value):
	# 判断阳光是否足够
	is_sun_enough = curr_sun_value >= sun_cost
	judge_card_ready()

## 判断卡片是否可以点击
func judge_card_ready():
	# 阳光充足 且 卡片冷却完成
	if is_sun_enough and not _is_cooling:
		if not _is_reward_card_allowed_in_current_level():
			card_not_can_click()
			return
		## 紫卡并且不能种植
		if is_purple_card and not is_chessboard_reveal_reward and not plant_condition.judge_purple_card_can_plant(Global.main_game.plant_cell_manager.all_plant_cells, card_plant_type):
			card_not_can_click()
		else:
			card_ready()
	else:
		card_not_can_click()

func set_card_cool_end():
	_cool_timer = 0
	_cool_mask.value = _cool_timer
	_is_cooling = false
	_ana_coffee_shared_cool_duration = 0.0
	_sync_ana_coffee_toggle_cool_mask()
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
	if _is_ana_coffee_dual_card:
		_ana_coffee_shared_cool_duration = cool_time
		_cool_mask.max_value = _ana_coffee_shared_cool_duration
	_cool_mask.value = cool_time
	is_can_click = false
	_is_ready_state = false
	_sync_ana_coffee_toggle_cool_mask()

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
	if _is_ana_coffee_dual_card:
		_ana_coffee_shared_cool_duration = _original_cool_time
		_sync_ana_coffee_toggle_cool_mask()
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
	if is_ranked_board_pickup:
		if not is_ranked_pickup_collecting:
			signal_ranked_pickup_clicked.emit(self)
		return
	## 如果为图鉴卡片
	if is_almanac_card:
		signal_card_click.emit()
		return

	## 如果时主游戏场景,并且游戏中
	if is_instance_valid(Global.main_game) and Global.main_game.main_game_progress == MainGameManager.E_MainGameProgress.MAIN_GAME:
		if not _is_reward_card_allowed_in_current_level():
			SoundManager.play_other_SFX("buzzer")
			return
		## 可以点击
		if is_can_click:
			EventBus.push_event("main_game_click_card", [self])
		else:
			SoundManager.play_other_SFX("buzzer")
	else:
		signal_card_click.emit()


func _is_reward_card_allowed_in_current_level() -> bool:
	var availability_plant_type := get_availability_plant_type()
	if availability_plant_type == CharacterRegistry.PlantType.Null:
		return true
	if not is_instance_valid(Global.main_game) or not is_instance_valid(Global.main_game.game_para):
		return true
	if not Global.main_game.game_para.adventure_card_lock_active:
		return true
	return RewardCardRuntime.is_plant_available_in_level(
		int(availability_plant_type),
		Global.main_game.game_para.level_id,
		Global.main_game.game_para.available_plant_types.has(availability_plant_type),
		Global.main_game.game_para.special_reward_card_source_dir
	)

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
