extends Plant000Base
class_name Plant054SquashDoomfist

@onready var area_2d_squash_attack: Area2D = $Area2DSquashAttack
@onready var detect_component: DetectComponentSquash = $DetectComponent
@onready var animation_tree: AnimationTree = $AnimationTree

## 倭瓜压击伤害；卡牌处决仍使用原有卡牌专属流程。
@export var squash_attack_value:int = 1800

## 可以攻击的敌人状态
@export_flags("1 正常", "2 悬浮", "4 地刺", "8 低矮") var can_attack_plant_status:int = 13
@export_flags("1 正常", "2 跳跃", "4 水下", "8 空中", "16 地下") var can_attack_zombie_status:int = 1

@export_group("动画状态")
@export var is_attack: bool = false
@export var is_right:bool = true
var target_x
var is_attack_card := false
var attack_card_target_screen_position := Vector2.ZERO
var attack_card_target:Card
var attack_card_parent:Node2D
## 新种下时要等待物理区域完成首次同步，期间禁止抢先锁定安娜卡牌。
var is_card_attack_detection_ready := false

func ready_norm():
	super()
	animation_tree.active = true
	_wait_for_card_attack_detection_ready()

func _wait_for_card_attack_detection_ready() -> void:
	## Area2D 的重叠列表在物理帧末更新；等待两帧覆盖“种进僵尸所在格”的情况。
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_inside_tree() or is_attack:
		return
	if detect_component.is_enabling and detect_component.judge_is_have_enemy():
		return
	is_card_attack_detection_ready = true

func ready_norm_signal_connect():
	super()
	detect_component.signal_can_attack.connect(attack_start)

## 开始攻击
func attack_start():
	if not is_attack:
		SoundManager.play_character_SFX("SquashHmm")
		is_attack = true
		target_x = detect_component.enemy_can_be_attacked.shadow.global_position.x
		is_right = target_x > global_position.x
		animation_tree.active = true
		hurt_box_component.disable_component(ComponentNormBase.E_IsEnableFactor.Character)

func attack_card(card:Card) -> bool:
	if is_attack or not is_card_attack_detection_ready or not is_instance_valid(card):
		return false
	## 卡槽检查和物理检测可能发生在同一帧；扑向安娜前主动刷新一次近身索敌，
	## 确保只要附近存在可攻击僵尸，就立即走原有僵尸攻击流程。
	if detect_component.is_enabling and detect_component.judge_is_have_enemy():
		return false

	attack_card_target = card
	attack_card_target.start_squash_doomfist_card_attack()
	is_attack_card = true
	attack_card_target_screen_position = attack_card_target.get_squash_doomfist_attack_screen_position()
	attack_card_parent = _get_card_attack_parent()

	SoundManager.play_character_SFX("SquashHmm")
	is_attack = true
	target_x = attack_card_target_screen_position.x
	is_right = target_x > get_global_transform_with_canvas().origin.x
	animation_tree.active = true
	hurt_box_component.disable_component(ComponentNormBase.E_IsEnableFactor.Character)
	return true

func _get_card_attack_parent() -> Node2D:
	if is_instance_valid(Global.main_game):
		var temp_parent:Node = Global.main_game.canvas_layer_temp.get_node_or_null(^"TemporaryCharacter")
		if temp_parent is Node2D:
			return temp_parent as Node2D
	return get_parent() as Node2D

func _screen_position_to_parent_local(screen_position:Vector2, parent_node:CanvasItem) -> Vector2:
	return parent_node.get_global_transform_with_canvas().affine_inverse() * screen_position

## 开始跳跃
func jump_up_start():
	z_index += 50
	## 如果地形为睡莲或者水
	if plant_cell.curr_condition & 8 or  plant_cell.curr_condition & 16:
		shadow.visible = false

	var tween:Tween = create_tween()
	if is_attack_card:
		if is_instance_valid(attack_card_parent):
			var start_position := _screen_position_to_parent_local(get_global_transform_with_canvas().origin, attack_card_parent)
			var target_position := _screen_position_to_parent_local(attack_card_target_screen_position, attack_card_parent)
			## 跨 CanvasLayer 时显式换算屏幕坐标，避免 keep_global_transform 产生一帧闪现。
			reparent(attack_card_parent, false)
			position = start_position
			z_as_relative = false
			z_index = 10000
			tween.tween_property(self, "position", target_position, 0.3).set_ease(Tween.EASE_IN)
	elif is_instance_valid(detect_component.enemy_can_be_attacked):
		tween.tween_property(self, "global_position:x", detect_component.enemy_can_be_attacked.shadow.global_position.x, 0.3).set_ease(Tween.EASE_IN)
	else:
		tween.tween_property(self, "global_position:x", target_x, 0.3).set_ease(Tween.EASE_IN)

## 压扁所有范围内可攻击僵尸
func squash_all_area_zombie():
	if is_attack_card:
		if is_instance_valid(attack_card_target):
			attack_card_target.hide_by_squash_doomfist()
		return

	var areas = area_2d_squash_attack.get_overlapping_areas()
	for area in areas:
		var zombie:Zombie000Base = area.owner
		## 如果为同一行僵尸
		if zombie.lane == row_col.x:
			if zombie.curr_be_attack_status & can_attack_zombie_status:
				zombie.be_squash(squash_attack_value)

## 跳入水中判断
func judge_jump_pool():
	if is_attack_card:
		SoundManager.play_character_SFX(&"gargantuar_thump")
		return

	## 如果地形为睡莲或者水
	if plant_cell.curr_condition & 8 or  plant_cell.curr_condition & 16:
		## 水花
		var splash:Splash = SceneRegistry.SPLASH.instantiate()
		plant_cell.add_child(splash)
		splash.global_position = Vector2(global_position.x,plant_cell.global_position.y + plant_cell.size.y)
		splash.z_as_relative = z_as_relative
		splash.z_index = z_index
		character_death()
	else:
		SoundManager.play_character_SFX(&"gargantuar_thump")
