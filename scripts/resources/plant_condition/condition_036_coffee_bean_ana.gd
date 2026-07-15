extends ResourcePlantCondition
class_name ResourcePlantConditionCoffeeBeanAna


## 安娜咖啡豆保留唤醒睡眠植物的用途，同时可种在天使默认可强化的射手上。
func _judge_special_plants_condition(plant_cell:PlantCell) -> bool:
	var target_plant := plant_cell.plant_in_cell[CharacterRegistry.PlacePlantInCell.Norm] as Plant000Base
	if not is_instance_valid(target_plant):
		return false
	return target_plant.is_sleeping \
		or Plant052SunflowerMercy.is_default_damage_boost_target_type(target_plant.plant_type)
