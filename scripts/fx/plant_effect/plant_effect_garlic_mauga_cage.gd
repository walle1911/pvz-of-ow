extends ForceFieldCage2D
class_name PlantEffectGarlicMaugaCage

const CHAIN_WALL_PADDING := 15.0
const CAGE_CENTER_OFFSET := Vector2(-10.0, 10.0)

## 兼容旧的毛加调用入口；实际几何、材质和排序均由通用 ForceFieldCage2D 提供。
func setup(source:Node2D, ground_bounds:Rect2) -> void:
	opening_width = 0.0
	perspective_depth_scale = 0.56
	## 锁链半径以横向攻击范围为准；地面是圆，屏幕中再按草坪透视压成横向椭圆。
	## 半径两侧各加 15px，即直径增加 30px。
	setup_from_world_circle(
		source.global_position + CAGE_CENTER_OFFSET,
		ground_bounds.size.x + CHAIN_WALL_PADDING * 2.0
	)
