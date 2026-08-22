extends Zombie000Base
class_name Zombie016Jackbox

@onready var bomb_component_jackbox: BombComponentJackbox = $BombComponentJackbox

@export_group("动画状态")
@export var is_pop:=false

func ready_norm():
	super()
	## 罐子僵尸，直接爆炸
	if is_pot_zombie:
		_strigger_bomb()

## 初始化正常出战角色信号连接
func ready_norm_signal_connect():
	super()
	bomb_component_jackbox.signal_trigger_bomb.connect(_strigger_bomb)
	hp_component.signal_hp_component_death.connect(bomb_component_jackbox.disable_component.bind(ComponentNormBase.E_IsEnableFactor.Death))

	signal_update_speed.connect(bomb_component_jackbox.owner_update_speed)


## 触发爆炸
func _strigger_bomb():
	## 防止同帧 timeout/死亡竞态或重复信号把已死亡、已失去爆炸匣子的角色
	## 强行切进开匣动画。否则动画仍会删除角色，但 bomb_once() 已被禁用。
	if is_pop or is_death or hp_component.is_death:
		return
	if not bomb_component_jackbox.is_enabling:
		return
	is_pop = true
	SoundManager.play_character_SFX(&"boing")
	_stop_sfx_enter()

## 失去铁器道具
func loss_iron_item():
	super()
	bomb_component_jackbox.disable_component(ComponentNormBase.E_IsEnableFactor.Lose)
	_stop_sfx_enter()

func sfx_jack_suprise():
	SoundManager.play_character_SFX(&"jack_suprise")

## 开匣动画的爆炸与退场必须在同一方法中保持固定顺序。
## 两条 Animation 方法轨落在同一时刻时，Godot 不保证跨轨道调用顺序；若死亡
## 先执行，会禁用爆炸组件，造成僵尸直接消失却没有爆炸。
func finish_jackbox_pop() -> void:
	bomb_component_jackbox.bomb_once()
	character_death_disappear()
