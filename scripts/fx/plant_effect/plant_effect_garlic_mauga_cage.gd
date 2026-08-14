@tool
extends ForceFieldCage2D
class_name PlantEffectGarlicMaugaCage

const CHAIN_WALL_PADDING := 15.0
const CAGE_CENTER_OFFSET := Vector2(-10.0, 10.0)

var _ground_size := Vector2(240.0, 288.0)

## 底部闭合椭圆就是唯一玩法边界；墙体只从这条边界向上升起。
## 保留通用 ForceFieldCage2D 的透明扫描墙、材质和三层蓝色发光。
func setup_pvz_region(ground_bounds:Rect2, first_lane:int, last_lane:int) -> void:
	top_level = true
	opening_width = 0.0
	scale = Vector2.ONE
	## 恢复通用力场原本的墙高；此前为配合低矮版本临时降到了 58px。
	shield_height = 145.0
	_ground_size = Vector2(
		maxf(ground_bounds.size.x, 24.0),
		maxf(ground_bounds.size.y, 24.0)
	)
	## cage_size 仅为通用采样器提供足够密度；实际 X/Y 半径由 _ground_size 决定。
	cage_size = Vector2(maxf(_ground_size.x, _ground_size.y), maxf(_ground_size.x, _ground_size.y))
	perspective_depth_scale = 1.0
	back_z_index = first_lane * 50 + 9
	front_z_index = last_lane * 50 + 49
	global_position = ground_bounds.get_center()
	if is_inside_tree():
		rebuild()

func _project_circle_point(angle:float, _radius:float) -> Vector2:
	return Vector2(
		cos(angle) * _ground_size.x * 0.5,
		sin(angle) * _ground_size.y * 0.5
	)

func _build_wall_segments(segments:Array[Dictionary]) -> void:
	var height_offset:= Vector2(0.0, -shield_height)
	for segment:Dictionary in segments:
		if segment["opening"]:
			continue
		var point_a:Vector2 = segment["a"]
		var point_b:Vector2 = segment["b"]
		var wall:= Polygon2D.new()
		wall.name = "WallSegment"
		wall.polygon = PackedVector2Array([point_a, point_b, point_b + height_offset, point_a + height_offset])
		wall.uv = PackedVector2Array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
		## 底圈保持完整透明墙强度，上沿淡出，避免视觉上出现第二个困敌范围。
		wall.vertex_colors = PackedColorArray([
			Color.WHITE,
			Color.WHITE,
			Color(1, 1, 1, 0.0),
			Color(1, 1, 1, 0.0),
		])
		wall.material = _wall_material
		_get_segment_container(segment).add_child(wall)

func _build_side_silhouette_lines() -> void:
	## 左右切线柱严格立在底圈的最左、最右点。
	for side_sign:float in [-1.0, 1.0]:
		var base_point:= Vector2(side_sign * _ground_size.x * 0.5, 0.0)
		var points:= PackedVector2Array([base_point, base_point + Vector2(0.0, -shield_height)])
		_create_glow_line(_front_walls, points, maxf(7.0, outer_glow_width * 0.72), Color(edge_color, 0.055))
		_create_glow_line(_front_walls, points, maxf(3.0, main_glow_width * 0.60), Color(edge_color, 0.16))
		_create_glow_line(_front_walls, points, maxf(0.8, core_glow_width * 0.60), Color(0.68, 0.88, 1.0, 0.42))

func _flush_line_path(points:PackedVector2Array, is_front:bool) -> void:
	if points.size() < 2:
		return
	var container:Node2D = _front_walls if is_front else _back_walls
	## 底圈是实际边界，因此保留原力场的完整三层辉光。
	_create_glow_line(container, points, outer_glow_width, Color(edge_color, 0.035))
	_create_glow_line(container, points, main_glow_width, Color(edge_color, 0.12))
	_create_glow_line(container, points, core_glow_width, Color(0.60, 0.78, 0.94, 0.28))
	## 上沿完全渐隐：画面中只保留一个具有玩法含义的底圈。

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
