extends BulletLinear007Cactus

var target_enemy:Zombie000Base


func init_bullet(bullet_paras:Dictionary[E_InitParasAttr, Variant]):
	super(bullet_paras)
	target_enemy = bullet_paras.get(E_InitParasAttr.Enemy, null) as Zombie000Base


## 卡西迪技能弹只命中发射时锁定的僵尸，飞行方向保持不变。
func _on_area_2d_attack_area_entered(area:Area2D) -> void:
	if not is_instance_valid(target_enemy) or target_enemy.is_death:
		return
	if area.owner != target_enemy:
		return
	if not target_enemy.curr_be_attack_status & can_attack_zombie_status:
		return
	attack_once(target_enemy)
