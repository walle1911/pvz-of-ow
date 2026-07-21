extends Plant022Caltrop
class_name Plant022CaltropHazard

const CALTROP_HAZARD_DOWNPOUR := preload("res://scenes/fx/caltrop_hazard_downpour.tscn")

@export_group("千针雨")
@export_range(0.0, 3.0, 0.05, "suffix:s") var downpour_preview_time := 0.5
## 尖刺命中后，从命中帧开始计算的定身时长。
@export_range(0.0, 10.0, 0.1, "suffix:s") var downpour_immobilize_time := 3.0
## 每只僵尸在一次千针雨中只受到一次该伤害。
@export_range(0, 1800, 1, "or_greater") var downpour_damage := 40

## 正常死亡时在本行及上下相邻行发动千针雨，范围包含所在列并向前延伸。
func death_language():
	if not is_instance_valid(plant_cell) or not is_instance_valid(Global.main_game):
		return
	var downpour = CALTROP_HAZARD_DOWNPOUR.instantiate()
	downpour.setup(plant_cell, downpour_preview_time, downpour_immobilize_time, downpour_damage)
	Global.main_game.get_node(^"Bombs").add_child(downpour)
