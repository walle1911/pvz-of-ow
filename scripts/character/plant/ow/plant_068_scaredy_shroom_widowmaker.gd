extends Plant000Base
class_name Plant068ScaredyShroomWidowmaker

@onready var scaredy_component: ScaredyComponent = $ScaredyComponent

@export_group("动画状态")
@export var is_scared := false

@export_group("狙击攻击")
## 两次致命射击之间的基础间隔（秒）。会沿用项目现有的攻速倍率规则。
@export_range(0.1, 60.0, 0.1, "or_greater") var shot_interval := 5.0

@onready var attack_component: AttackComponentBulletBase = $AttackComponent



func ready_norm_signal_connect():
	super()
	attack_component.attack_cd = shot_interval
	attack_component.bullet_attack_cd_timer.wait_time = shot_interval
	scaredy_component.signal_scaredy_start.connect(change_is_scared.bind(true))
	scaredy_component.signal_scaredy_end.connect(change_is_scared.bind(false))

	for component:ComponentNormBase in scaredy_component.scaredy_influence_components:
		scaredy_component.signal_scaredy_start.connect(component.disable_component.bind(ComponentNormBase.E_IsEnableFactor.Scaredy))
		scaredy_component.signal_scaredy_end.connect(component.enable_component.bind(ComponentNormBase.E_IsEnableFactor.Scaredy))
	signal_update_speed.connect(attack_component.owner_update_speed)

## 害怕组件信号发射改变植物害怕状态
func change_is_scared(curr_is_scared:bool):
	self.is_scared = curr_is_scared
