@tool
extends Node2D
class_name ForceFieldCage2D

enum OpeningSide { TOP, RIGHT, BOTTOM, LEFT }

const WALL_MATERIAL := preload("res://resources/fx/force_field_wall_material.tres")
const MIN_SIZE := Vector2(24.0, 24.0)
const MIN_CIRCLE_SAMPLES := 32
const MAX_CIRCLE_SAMPLES := 72

@export_group("几何")
@export var cage_size := Vector2(250.0, 250.0):
	set(value):
		## 力场底面始终是水平圆；Y 只在绘制阶段由透视比例压缩。
		var diameter:float = maxf(maxf(value.x, value.y), MIN_SIZE.x)
		cage_size = Vector2(diameter, diameter)
		_request_rebuild()
@export_range(1.0, 500.0, 1.0, "or_greater") var shield_height := 145.0:
	set(value):
		shield_height = maxf(value, 1.0)
		_request_rebuild()
## 圆形底面在草坪斜俯视镜头中的纵向投影比例；几何仍表示圆柱，而不是胶囊或矩形。
@export_range(0.25, 1.0, 0.01) var perspective_depth_scale := 0.56:
	set(value):
		perspective_depth_scale = clampf(value, 0.25, 1.0)
		_request_rebuild()
@export_group("开口")
@export var opening_side:OpeningSide = OpeningSide.BOTTOM:
	set(value):
		opening_side = value
		_request_rebuild()
@export_range(0.0, 500.0, 1.0) var opening_width := 0.0:
	set(value):
		opening_width = maxf(value, 0.0)
		_request_rebuild()
@export var opening_offset := 0.0:
	set(value):
		opening_offset = value
		_request_rebuild()

@export_group("墙体")
@export var wall_color := Color(0.22, 0.58, 1.0, 1.0):
	set(value):
		wall_color = value
		_update_material_parameters()
@export_range(0.0, 1.0, 0.01) var wall_alpha := 0.42:
	set(value):
		wall_alpha = clampf(value, 0.0, 1.0)
		_update_material_parameters()
@export_range(0.0, 1.0, 0.01) var edge_strength := 0.10:
	set(value):
		edge_strength = clampf(value, 0.0, 1.0)
		_update_material_parameters()

@export_group("边缘发光")
@export var edge_color := Color(0.26, 0.68, 1.0, 1.0):
	set(value):
		edge_color = value
		_request_rebuild()
@export_range(0.1, 40.0, 0.1) var outer_glow_width := 14.0:
	set(value):
		outer_glow_width = maxf(value, 0.1)
		_request_rebuild()
@export_range(0.1, 30.0, 0.1) var main_glow_width := 6.0:
	set(value):
		main_glow_width = maxf(value, 0.1)
		_request_rebuild()
@export_range(0.1, 12.0, 0.1) var core_glow_width := 1.2:
	set(value):
		core_glow_width = maxf(value, 0.1)
		_request_rebuild()

@export_group("墙体动画")
@export_range(0.0, 10.0, 0.05) var pulse_speed := 0.70:
	set(value):
		pulse_speed = maxf(value, 0.0)
		_update_material_parameters()
@export_range(0.0, 0.5, 0.005) var pulse_amount := 0.035:
	set(value):
		pulse_amount = clampf(value, 0.0, 0.5)
		_update_material_parameters()
@export_range(-5.0, 5.0, 0.01) var scan_speed := 0.06:
	set(value):
		scan_speed = value
		_update_material_parameters()
@export_range(0.0, 0.5, 0.005) var scan_strength := 0.018:
	set(value):
		scan_strength = clampf(value, 0.0, 0.5)
		_update_material_parameters()
@export_range(0.5, 30.0, 0.1) var scan_density := 3.0:
	set(value):
		scan_density = maxf(value, 0.5)
		_update_material_parameters()

@export_group("战斗绘制顺序")
## 本项目植物通常位于 z=0，僵尸行位于 z=10；默认值使后墙在全部角色后、前墙在全部角色前。
@export var back_z_index := -1:
	set(value):
		back_z_index = value
		_update_container_z_indices()
@export var front_z_index := 11:
	set(value):
		front_z_index = value
		_update_container_z_indices()

var _back_walls:Node2D
var _front_walls:Node2D
var _wall_material:ShaderMaterial
var _line_material:CanvasItemMaterial
var _rebuild_queued := false

func _ready() -> void:
	_ensure_runtime_resources()
	_rebuild_geometry()

## 将笼子对齐到世界坐标矩形，并以能覆盖矩形的水平圆生成墙体。
func setup_from_world_bounds(bounds:Rect2, height_override:float = -1.0) -> void:
	top_level = true
	var diameter:float = maxf(bounds.size.x, bounds.size.y / perspective_depth_scale)
	cage_size = Vector2(diameter, diameter)
	if height_override > 0.0:
		shield_height = height_override
	global_position = bounds.get_center()
	if is_inside_tree():
		_rebuild_geometry()

## 以真实水平圆构建墙体；屏幕纵径由 perspective_depth_scale 唯一决定。
func setup_from_world_circle(center:Vector2, diameter:float, height_override:float = -1.0) -> void:
	top_level = true
	cage_size = Vector2(diameter, diameter)
	if height_override > 0.0:
		shield_height = height_override
	global_position = center
	if is_inside_tree():
		_rebuild_geometry()

func rebuild() -> void:
	_rebuild_geometry()

func _request_rebuild() -> void:
	if not is_inside_tree() or _rebuild_queued:
		return
	_rebuild_queued = true
	call_deferred("_rebuild_geometry")

func _ensure_runtime_resources() -> void:
	if not is_instance_valid(_back_walls):
		_back_walls = get_node_or_null(^"BackWalls")
	if not is_instance_valid(_back_walls):
		_back_walls = Node2D.new()
		_back_walls.name = "BackWalls"
		add_child(_back_walls)
	if not is_instance_valid(_front_walls):
		_front_walls = get_node_or_null(^"FrontWalls")
	if not is_instance_valid(_front_walls):
		_front_walls = Node2D.new()
		_front_walls.name = "FrontWalls"
		add_child(_front_walls)
	if not is_instance_valid(_wall_material):
		_wall_material = WALL_MATERIAL.duplicate() as ShaderMaterial
	if not is_instance_valid(_line_material):
		_line_material = CanvasItemMaterial.new()
		## 绿色草地上使用加色混合会偏成荧光绿；冰蓝边缘使用正常透明混合。
		_line_material.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
	_update_container_z_indices()
	_update_material_parameters()

func _update_container_z_indices() -> void:
	if is_instance_valid(_back_walls):
		_back_walls.z_as_relative = false
		_back_walls.z_index = back_z_index
	if is_instance_valid(_front_walls):
		_front_walls.z_as_relative = false
		_front_walls.z_index = front_z_index

func _update_material_parameters() -> void:
	if not is_instance_valid(_wall_material):
		return
	_wall_material.set_shader_parameter(&"wall_color", wall_color)
	_wall_material.set_shader_parameter(&"base_alpha", wall_alpha)
	_wall_material.set_shader_parameter(&"pulse_speed", pulse_speed)
	_wall_material.set_shader_parameter(&"pulse_amount", pulse_amount)
	_wall_material.set_shader_parameter(&"scan_speed", scan_speed)
	_wall_material.set_shader_parameter(&"scan_strength", scan_strength)
	_wall_material.set_shader_parameter(&"scan_density", scan_density)
	_wall_material.set_shader_parameter(&"edge_strength", edge_strength)

func _rebuild_geometry() -> void:
	_rebuild_queued = false
	_ensure_runtime_resources()
	_clear_generated_children(_back_walls)
	_clear_generated_children(_front_walls)
	var segments:Array[Dictionary] = _build_perimeter_segments()
	_build_wall_segments(segments)
	_build_edge_lines(segments)

func _clear_generated_children(container:Node) -> void:
	for child:Node in container.get_children():
		container.remove_child(child)
		child.queue_free()

func _build_perimeter_segments() -> Array[Dictionary]:
	var result:Array[Dictionary] = []
	var radius:float = cage_size.x * 0.5
	var projected_radius_y:float = cage_size.y * perspective_depth_scale * 0.5
	var circumference:float = TAU * maxf(radius, projected_radius_y)
	var sample_count:int = clampi(int(ceil(circumference / 14.0)), MIN_CIRCLE_SAMPLES, MAX_CIRCLE_SAMPLES)
	var opening_center_angle:float = _get_opening_center_angle(radius)
	var opening_half_angle:float = clampf(opening_width / maxf(radius * 2.0, 1.0), 0.0, PI * 0.48)
	var angles:PackedFloat32Array = PackedFloat32Array()
	for sample_index:int in range(sample_count + 1):
		angles.append(TAU * float(sample_index) / float(sample_count))
	if opening_width > 0.0:
		angles.append(fposmod(opening_center_angle - opening_half_angle, TAU))
		angles.append(fposmod(opening_center_angle + opening_half_angle, TAU))
	angles.sort()
	for angle_index:int in range(angles.size() - 1):
		_append_circle_segment(result, radius, angles[angle_index], angles[angle_index + 1], opening_center_angle, opening_half_angle)
	_append_circle_segment(result, radius, angles[angles.size() - 1], angles[0] + TAU, opening_center_angle, opening_half_angle)
	return result

func _append_circle_segment(
	result:Array[Dictionary],
	radius:float,
	angle_a:float,
	angle_b:float,
	opening_center_angle:float,
	opening_half_angle:float
) -> void:
	if angle_b - angle_a <= 0.0001:
		return
	var midpoint_angle:float = (angle_a + angle_b) * 0.5
	var angular_distance:float = absf(wrapf(midpoint_angle - opening_center_angle, -PI, PI))
	var is_opening:bool = opening_width > 0.0 and angular_distance < opening_half_angle
	var point_a:Vector2 = _project_circle_point(angle_a, radius)
	var point_b:Vector2 = _project_circle_point(angle_b, radius)
	result.append(_make_segment(point_a, point_b, is_opening))

func _project_circle_point(angle:float, radius:float) -> Vector2:
	var projected_radius_y:float = cage_size.y * perspective_depth_scale * 0.5
	return Vector2(cos(angle) * radius, sin(angle) * projected_radius_y)

func _get_opening_center_angle(radius:float) -> float:
	var base_angle:float
	match opening_side:
		OpeningSide.TOP:
			base_angle = -PI * 0.5
		OpeningSide.RIGHT:
			base_angle = 0.0
		OpeningSide.BOTTOM:
			base_angle = PI * 0.5
		OpeningSide.LEFT:
			base_angle = PI
		_:
			base_angle = PI * 0.5
	return fposmod(base_angle + opening_offset / maxf(radius, 1.0), TAU)

func _make_segment(point_a:Vector2, point_b:Vector2, is_opening:bool) -> Dictionary:
	return {"a": point_a, "b": point_b, "opening": is_opening, "front": ((point_a.y + point_b.y) * 0.5) >= 0.0}

func _build_wall_segments(segments:Array[Dictionary]) -> void:
	var height_offset := Vector2(0.0, -shield_height)
	for segment:Dictionary in segments:
		if segment["opening"]:
			continue
		var point_a:Vector2 = segment["a"]
		var point_b:Vector2 = segment["b"]
		var wall := Polygon2D.new()
		wall.name = "WallSegment"
		wall.polygon = PackedVector2Array([point_a, point_b, point_b + height_offset, point_a + height_offset])
		wall.uv = PackedVector2Array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
		wall.vertex_colors = PackedColorArray([Color.WHITE, Color.WHITE, Color(1, 1, 1, 0.82), Color(1, 1, 1, 0.82)])
		wall.material = _wall_material
		_get_segment_container(segment).add_child(wall)

func _build_edge_lines(segments:Array[Dictionary]) -> void:
	var current_points := PackedVector2Array()
	var current_front := false
	var has_current_side := false
	for segment:Dictionary in segments:
		if segment["opening"]:
			_flush_line_path(current_points, current_front)
			current_points = PackedVector2Array()
			has_current_side = false
			continue
		var segment_front:bool = segment["front"]
		if has_current_side and segment_front != current_front:
			_flush_line_path(current_points, current_front)
			current_points = PackedVector2Array()
			has_current_side = false
		if not has_current_side:
			current_front = segment_front
			current_points.append(segment["a"])
			has_current_side = true
		current_points.append(segment["b"])
	_flush_line_path(current_points, current_front)
	_build_side_silhouette_lines()

func _build_side_silhouette_lines() -> void:
	## 圆柱左右切线是参考效果中最清晰的墙体轮廓；它们不封顶，只强调透明侧壁的高度。
	var radius:float = cage_size.x * 0.5
	for side_sign:float in [-1.0, 1.0]:
		var base_point := Vector2(side_sign * radius, 0.0)
		var points := PackedVector2Array([base_point, base_point + Vector2(0.0, -shield_height)])
		_create_glow_line(_front_walls, points, maxf(7.0, outer_glow_width * 0.72), Color(edge_color, 0.055))
		_create_glow_line(_front_walls, points, maxf(3.0, main_glow_width * 0.60), Color(edge_color, 0.16))
		_create_glow_line(_front_walls, points, maxf(0.8, core_glow_width * 0.60), Color(0.68, 0.88, 1.0, 0.42))

func _flush_line_path(points:PackedVector2Array, is_front:bool) -> void:
	if points.size() < 2:
		return
	var container:Node2D = _front_walls if is_front else _back_walls
	_create_glow_line(container, points, outer_glow_width, Color(edge_color, 0.035))
	_create_glow_line(container, points, main_glow_width, Color(edge_color, 0.12))
	_create_glow_line(container, points, core_glow_width, Color(0.60, 0.78, 0.94, 0.28))
	## 顶沿前后半圈都保留柔和轮廓，让整面墙的高度和闭合范围始终可辨。
	var top_points := PackedVector2Array()
	for point:Vector2 in points:
		top_points.append(point + Vector2(0.0, -shield_height))
	_create_glow_line(container, top_points, maxf(6.0, outer_glow_width * 0.55), Color(edge_color, 0.045))
	_create_glow_line(container, top_points, maxf(1.0, core_glow_width * 0.80), Color(0.68, 0.88, 1.0, 0.24))

func _create_glow_line(container:Node2D, points:PackedVector2Array, line_width:float, line_color:Color) -> void:
	var line := Line2D.new()
	line.name = "EnergyEdge"
	line.points = points
	line.width = line_width
	line.default_color = line_color
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.antialiased = true
	line.material = _line_material
	container.add_child(line)

func _get_segment_container(segment:Dictionary) -> Node2D:
	return _front_walls if segment["front"] else _back_walls
