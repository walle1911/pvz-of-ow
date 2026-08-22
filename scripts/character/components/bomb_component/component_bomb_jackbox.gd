extends BombComponentBase
class_name BombComponentJackbox
## 小丑爆炸组件
## 小丑爆炸攻击所有范围内敌人

@onready var jack_bomb_timer: Timer = $JackBombTimer
@onready var bomb_effect: BombEffectBase = $BombEffect


## 早爆小丑概率
@export_range(0, 100, 1) var probability_early_bomb :int = 5
## 早爆小丑时间范围
@export var early_time_range:Vector2 = Vector2(4.4, 7.45)
## 晚爆小丑时间范围
@export var late_time_range:Vector2 = Vector2(13.22, 22.68)
## 小丑出生后爆炸时间
var wait_time_bomb :float= 0.0
## 缓存角色当前速度状态。暗影步会先停止 Timer，稍后重新启动；重新启动时仍需继承
## 冰冻、黄油等造成的暂停状态，不能因为 Timer 当时处于 stopped 而漏掉更新。
var _owner_speed_product := 1.0


## 小丑触发爆炸信号
signal signal_trigger_bomb

func _ready() -> void:
	owner = owner as Zombie000Base
	## 如果出战角色
	if owner.character_init_type == Character000Base.E_CharacterInitType.IsNorm:
		var p = randi_range(1,100)
		## 早爆小丑
		if p <= probability_early_bomb:
			wait_time_bomb = randf_range(early_time_range.x, early_time_range.y)
		else:
			wait_time_bomb = randf_range(late_time_range.x, late_time_range.y)
		start_bomb_timer(wait_time_bomb)

## 启动引信，并同步角色当前是否处于完全停止状态。
func start_bomb_timer(duration:float) -> void:
	if not is_enabling:
		return
	jack_bomb_timer.start(duration)
	jack_bomb_timer.paused = is_zero_approx(_owner_speed_product)

## 角色速度修改
func owner_update_speed(speed_product:float):
	_owner_speed_product = speed_product
	if not jack_bomb_timer.is_stopped():
		## 原版玩偶匣的开盒时间不受移动速度影响；完全停止时只暂停倒计时。
		## 不要按 speed_product 重启 Timer，否则场外 2 倍加速会直接将整段倒计时减半。
		jack_bomb_timer.paused = is_zero_approx(_owner_speed_product)

## 爆炸时间到,发射触发爆炸信号
func _on_jack_bomb_timer_timeout() -> void:
	## timeout 与死亡或失去爆炸匣子可能落在同一帧。此时信号已进入消息队列，
	## stop() 不能撤回它；若继续切换开匣动画，动画末尾会删掉僵尸却无法爆炸。
	if not is_enabling or not is_instance_valid(owner):
		return
	if owner.is_death or owner.hp_component.is_death:
		return
	signal_trigger_bomb.emit()

## 爆炸特效
func _start_bomb_fx():
	bomb_effect.activate_bomb_effect()

## 炸死所有敌人
func _bomb_all_enemy():
	var areas = area_2d_bomb.get_overlapping_areas()
	for area in areas:
		if area.owner is Character000Base:
			var character:Character000Base = area.owner
			if character.lane >= owner.lane -1 and character.lane <= owner.lane + 1:
				## 角色死亡直接消失
				if character is Plant000Base and owner is Zombie000Base:
					(character as Plant000Base).be_killed_by_zombie(owner)
				else:
					character.character_death_disappear()
		elif area.owner is ScaryPot:
			var pot:ScaryPot = area.owner
			if pot.lane >= owner.lane -1 and pot.lane <= owner.lane + 1:
				pot.open_pot_be_bomb()


## 禁用组件
func disable_component(is_enable_factor:E_IsEnableFactor):
	is_enable_factors[is_enable_factor] = false
	is_enabling = false
	jack_bomb_timer.stop()
	jack_bomb_timer.paused = false
