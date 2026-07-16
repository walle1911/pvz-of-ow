extends Zombie024Gargantuar
class_name Zombie025GargantuarBob

## Bob 是屋顶终盘 Boss。普通巨人只在半血时投掷一次小鬼，Bob 会在两个血量阶段各投掷一次。
@export var boss_throw_thresholds: Array[int] = [6000, 3000]
var boss_throw_count := 0


func jugde_throw_imp_form_hp_change(curr_hp: int, _is_drop := true):
	if is_throw or boss_throw_count >= boss_throw_thresholds.size():
		return
	if global_position.x <= MinXThrowGargantuar:
		return
	if curr_hp <= boss_throw_thresholds[boss_throw_count]:
		boss_throw_count += 1
		is_throw = true


## 创建 Bob 携带的艾什版本专属小鬼，避免与莱因哈特及原版巨人共用外观场景。
func create_imp():
	var zombie_init_para:Dictionary = {
		Zombie000Base.E_ZInitAttr.CharacterInitType:Character000Base.E_CharacterInitType.IsNorm,
		Zombie000Base.E_ZInitAttr.Lane:lane,
		Zombie000Base.E_ZInitAttr.IsMiniZombie: is_mini_zombie,
		Zombie000Base.E_ZInitAttr.IsPotZombie: is_pot_zombie,
	}
	Global.main_game.zombie_manager.create_norm_zombie(
		CharacterRegistry.ZombieType.Z028ImpAshe,
		Global.main_game.zombie_manager.all_zombie_rows[lane],
		zombie_init_para,
		_get_imp_throw_glo_pos(),
		update_imp_throw_pos
	)
