extends Node2D
class_name PeashooterHead

## 可复用的豌豆射手头部单元（取自普通豌豆射手头部，朝右为默认朝向）。
## 视觉 + 头部动画(Idle/Attack)自包含；攻击时由宿主调用 play_attack()，
## 发射时机由 Head_Attack 动画的方法轨道在开火帧回调本节点 _shoot_bullet()，
## 再发出 fire_pea 信号，由宿主(僵尸)连接到自己的子弹发射逻辑。
## 这样头部与攻击逻辑解耦，可在僵尸/其它角色处复用；宿主只需把本节点镜像即可转向。

signal fire_pea

@onready var anim: AnimationPlayer = $HeadAnimPlayer

func _ready() -> void:
	if is_instance_valid(anim):
		anim.animation_finished.connect(_on_anim_finished)
		play_idle()

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
	fire_pea.emit()

func _on_anim_finished(anim_name: StringName) -> void:
	if anim_name == &"Head_Attack":
		anim.speed_scale = 1.0
		play_idle()
