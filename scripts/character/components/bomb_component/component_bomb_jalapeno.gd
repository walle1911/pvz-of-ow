extends BombComponentBase
class_name BombComponentJalapeno

var owner_plant:Plant000Base

func _ready() -> void:
	owner_plant = owner as Plant000Base

## 爆炸特效\冰道\梯子
func _start_bomb_fx():
	for lane in _get_affected_lanes():
		EventBus.push_event("jalapeno_bomb_effect", [lane])

## 炸死所有敌人
func _bomb_all_enemy():
	var center_lane := owner_plant.row_col.x
	for lane in _get_affected_lanes():
		if owner_plant is Plant059JalapenoVendetta:
			var vendetta := owner_plant as Plant059JalapenoVendetta
			var lane_damage: int = vendetta.center_lane_damage if lane == center_lane else vendetta.edge_lane_damage
			EventBus.push_event("jalapeno_bomb_lane_zombie", [lane, lane_damage])
		else:
			## 保留原版辣椒的单参数单行事件。
			EventBus.push_event("jalapeno_bomb_lane_zombie", [lane])
		## 销毁爆炸行道具[冰道和梯子]
		EventBus.push_event("jalapeno_bomb_item_lane", [lane])


## 原版辣椒只返回当前行；只有斩仇扩展为上下相邻行。
func _get_affected_lanes() -> Array[int]:
	var center_lane := owner_plant.row_col.x
	var affected_lanes: Array[int] = [center_lane]
	if not owner_plant is Plant059JalapenoVendetta:
		return affected_lanes
	if not is_instance_valid(Global.main_game)\
		or not is_instance_valid(Global.main_game.plant_cell_manager):
		return affected_lanes
	var lane_count: int = Global.main_game.plant_cell_manager.all_plant_cells.size()
	affected_lanes.clear()
	for lane in range(maxi(0, center_lane - 1), mini(lane_count, center_lane + 2)):
		affected_lanes.append(lane)
	return affected_lanes
