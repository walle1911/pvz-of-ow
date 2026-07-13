extends Zombie024Gargantuar
class_name Zombie025GargantuarBob


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
