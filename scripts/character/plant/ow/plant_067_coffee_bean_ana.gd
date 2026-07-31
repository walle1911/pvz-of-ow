extends Plant000Base
class_name Plant067CoffeeBeanAna

const ANA_NANO_BOOST := preload("res://scripts/character/effects/ana_nano_boost.gd")

@export_group("纳米强化")
## 射击频率倍率：2.0 表示每秒攻击次数变为原来的 2 倍。
@export_range(1.0, 10.0, 0.05) var attack_speed_multiplier := 2.0
## 伤害倍率：2.0 表示总伤害变为原来的 2 倍。
@export_range(1.0, 10.0, 0.05) var damage_multiplier := 2.0
## 强化期间受到的伤害降低比例。
@export_range(0.0, 1.0, 0.05) var damage_reduction := 0.3
## 使用瞬间为目标恢复的血量。
@export_range(0, 10000, 1, "or_greater") var instant_heal := 50
## 强化持续时间（秒）。
@export_range(0.1, 120.0, 0.1, "suffix:s") var boost_duration := 15.0

## 唤醒植物
func awake_up_plant():
	var target_plant := plant_cell.plant_in_cell[CharacterRegistry.PlacePlantInCell.Norm] as Plant000Base
	if not is_instance_valid(target_plant):
		return
	if target_plant.is_sleeping:
		plant_cell.coffee_bean_awake_up()
	if not is_nano_boost_target_type(target_plant.plant_type):
		return
	_apply_nano_boost(target_plant)


static func is_nano_boost_target_type(target_plant_type:CharacterRegistry.PlantType) -> bool:
	return target_plant_type == CharacterRegistry.PlantType.P052BonkChoyRamattra \
			or Plant052SunflowerMercy.is_blue_line_damage_boost_target_type(target_plant_type)


func _apply_nano_boost(target_plant:Plant000Base):
	if has_active_nano_boost(target_plant):
		return
	var nano_boost:Node = target_plant.get_node_or_null(^"AnaNanoBoost")
	if not is_instance_valid(nano_boost):
		nano_boost = ANA_NANO_BOOST.new()
		nano_boost.name = "AnaNanoBoost"
		target_plant.add_child(nano_boost)
	nano_boost.start_boost(
		target_plant,
		attack_speed_multiplier,
		damage_multiplier,
		damage_reduction,
		instant_heal,
		boost_duration
	)


static func has_active_nano_boost(target_plant:Plant000Base) -> bool:
	if not is_instance_valid(target_plant):
		return false
	var nano_boost := target_plant.get_node_or_null(^"AnaNanoBoost") as AnaNanoBoost
	return is_instance_valid(nano_boost) and nano_boost.is_applied
