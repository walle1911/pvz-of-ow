extends Plant000Base
class_name Plant059JalapenoVendetta

@onready var bomb_component: BombComponentBase = %BombComponent

@export_group("斩仇蓄力伤害")
## 未蓄满的一排，以及蓄满后三排中的中心排伤害。
@export_range(1, 100000, 1, "or_greater") var center_lane_damage := 1800
## 蓄满后三排中上下两侧边缘排伤害，默认是中心排的一半。
@export_range(1, 100000, 1, "or_greater") var edge_lane_damage := 900

## 亡语
func death_language():
	bomb_component.judge_death_bomb()
