extends Plant000Base
class_name Plant053CherryBombJunkrat

@onready var bomb_component: BombComponentBase = %BombComponent

@export var tire_bullet_scene: PackedScene

const TIRE_LAUNCH_OFFSET := Vector2(25.0, 9.0)

var _is_tire_launched := false

## 亡语
func death_language():
	bomb_component.judge_death_bomb()
	## 爆炸动画会先直接引爆组件，再调用角色死亡。
	## 因此这里以“已经完成首爆”作为轮胎生成条件。
	if bomb_component.is_bomb and not _is_tire_launched:
		_is_tire_launched = true
		_launch_tire()


## 右侧樱桃在首次爆炸后化为轮胎，沿当前行向右滚动
func _launch_tire():
	if tire_bullet_scene == null or not is_instance_valid(Global.main_game):
		return
	var bullets: Node2D = Global.main_game.bullets
	if not is_instance_valid(bullets):
		return
	var tire_bullet: Bullet000NormBase = tire_bullet_scene.instantiate()
	var bullet_paras := {
		Bullet000NormBase.E_InitParasAttr.BulletLane: lane,
		Bullet000NormBase.E_InitParasAttr.Position: bullets.to_local(global_position + TIRE_LAUNCH_OFFSET),
		Bullet000NormBase.E_InitParasAttr.Direction: Vector2.RIGHT,
	}
	tire_bullet.init_bullet(bullet_paras)
	bullets.add_child(tire_bullet)
