@tool
extends Node2D
class_name PeashooterHead

## 可复用的豌豆射手头部单元（取自普通豌豆射手头部，朝右为默认朝向）。
## 视觉 + 头部动画(Idle/Attack)自包含；攻击时由宿主调用 play_attack()，
## 发射时机由 Head_Attack 动画的方法轨道在开火帧回调本节点 _shoot_bullet()，
## 再发出 fire_pea 信号，由宿主(僵尸)连接到自己的子弹发射逻辑。
## 这样头部与攻击逻辑解耦，可在僵尸/其它角色处复用；宿主只需把本节点镜像即可转向。

signal fire_pea

@onready var anim: AnimationPlayer = $HeadAnimPlayer

## 可选的局部变换跟随目标。用于头部不能直接作为目标子节点、但仍需在编辑器预览
## 和游戏运行时同步其位置/缩放的情况；旋转保持头部自身设置，避免随身体歪斜。
@export var follow_target_path: NodePath
## 只调整头部相对身体的位置，不改变动画使用的 Transform 基准。
@export var follow_position_offset := Vector2.ZERO

var _follow_target: Node2D
var _follow_offset_in_target_scale := Vector2.ZERO
var _follow_scale_ratio := Vector2.ONE
var _fixed_rotation := 0.0
var _is_follow_enabled := false

func _ready() -> void:
	if is_instance_valid(anim):
		if not anim.animation_finished.is_connected(_on_anim_finished):
			anim.animation_finished.connect(_on_anim_finished)
		play_idle()
	_setup_follow_target()

func _process(_delta: float) -> void:
	_update_follow_transform()

func _setup_follow_target() -> void:
	_is_follow_enabled = false
	if follow_target_path.is_empty():
		return
	_follow_target = get_node_or_null(follow_target_path) as Node2D
	if not is_instance_valid(_follow_target):
		return
	if is_zero_approx(_follow_target.scale.x) or is_zero_approx(_follow_target.scale.y):
		return
	var initial_offset := position - _follow_target.position
	_follow_offset_in_target_scale = Vector2(
		initial_offset.x / _follow_target.scale.x,
		initial_offset.y / _follow_target.scale.y
	)
	_follow_scale_ratio = Vector2(
		scale.x / _follow_target.scale.x,
		scale.y / _follow_target.scale.y
	)
	_fixed_rotation = rotation
	_is_follow_enabled = true

func _update_follow_transform() -> void:
	if not _is_follow_enabled or not is_instance_valid(_follow_target):
		return
	position = _follow_target.position + Vector2(
		_follow_offset_in_target_scale.x * _follow_target.scale.x,
		_follow_offset_in_target_scale.y * _follow_target.scale.y
	) + follow_position_offset
	scale = Vector2(
		_follow_scale_ratio.x * _follow_target.scale.x,
		_follow_scale_ratio.y * _follow_target.scale.y
	)
	rotation = _fixed_rotation

func stop_follow() -> void:
	_is_follow_enabled = false

## 待机呼吸动画
func play_idle() -> void:
	if is_instance_valid(anim) and anim.has_animation("Head_Idle"):
		anim.play("Head_Idle")

## 攻击动画(嘴张开吐豆)。高速连射宿主可传入倍率，保证方法轨道及时开火。
func play_attack(attack_speed_scale:float = 1.0) -> void:
	if not is_instance_valid(anim) or not anim.has_animation("Head_Attack"):
		return
	anim.stop()
	anim.speed_scale = maxf(attack_speed_scale, 0.01)
	anim.play("Head_Attack")

func stop() -> void:
	if is_instance_valid(anim):
		anim.stop()

## Head_Attack 方法轨道在开火帧回调此方法
func _shoot_bullet() -> void:
	if not Engine.is_editor_hint():
		fire_pea.emit()

func _on_anim_finished(anim_name: StringName) -> void:
	if anim_name == &"Head_Attack":
		anim.speed_scale = 1.0
		play_idle()
