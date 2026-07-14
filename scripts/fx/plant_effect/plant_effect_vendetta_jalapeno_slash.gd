extends Node2D
class_name VendettaJalapenoSlashEffect

## 斩仇版火爆辣椒的选区预览与释放特效。
##
## lane_polygons 的结构为：Array[lane][cell]，每个 cell 是一个已经转换到
## 本 Node2D 局部坐标系的 PackedVector2Array 四边形。脚本只负责绘制，不参与
## 种植合法性或伤害结算。

signal release_finished

@export_group("Timing")
@export_range(0.1, 2.0, 0.01) var release_duration := 0.6
@export_range(0.05, 0.5, 0.01) var sword_strike_duration := 0.16
@export_range(0.05, 0.5, 0.01) var sword_recover_duration := 0.22

@export_group("Preview")
@export var preview_fill_color := Color(0.38, 0.0, 0.022, 0.18)
@export var preview_border_color := Color(1.0, 0.025, 0.055, 0.42)
@export var preview_separator_color := Color(1.0, 0.45, 0.45, 0.10)
@export var preview_core_color := Color(1.0, 0.96, 0.90, 0.94)
@export var preview_smoke_color := Color(0.012, 0.0, 0.006, 0.58)
@export var preview_flame_color := Color(0.94, 0.0, 0.035, 0.72)
@export var indicator_offset := Vector2(0.0, 18.0)

@export_group("Release")
@export var damage_fill_color := Color(0.25, 0.0, 0.018, 0.14)
@export var slash_shadow_color := Color(0.018, 0.0, 0.008, 0.82)
@export var slash_red_color := Color(1.0, 0.015, 0.045, 0.82)
@export var slash_core_color := Color(1.0, 0.97, 0.90, 1.0)

var _all_lane_polygons: Array = []
var _target_lane := -1
var _charge_progress := 0.0
var _target_visible := false
var _indicator_position := Vector2.ZERO
var _has_indicator_position := false

var _visual_time := 0.0
var _is_releasing := false
var _release_elapsed := 0.0
var _release_origin := Vector2.ZERO
var _release_lanes: Array[int] = []

var _release_actor: Node2D
var _sword_pivot: Node2D
var _sword_tween: Tween
var _sword_base_rotation := 0.0
var _sword_base_scale := Vector2.ONE


func _ready() -> void:
	z_as_relative = false
	z_index = 240
	set_process(false)


func _exit_tree() -> void:
	if _sword_tween != null and _sword_tween.is_valid():
		_sword_tween.kill()
	_reset_sword_pivot()


func _process(delta: float) -> void:
	_visual_time += delta

	if _is_releasing:
		_release_elapsed += delta
		queue_redraw()
		if _release_elapsed >= release_duration:
			_finish_release()
		return

	if _target_visible:
		queue_redraw()
	else:
		set_process(false)


## 显示 lane 对应横向整排的预判范围。
func show_target(center_lane: int, lane_polygons: Array) -> void:
	_all_lane_polygons = lane_polygons.duplicate(true)
	_target_lane = center_lane
	_target_visible = _is_valid_lane(center_lane)
	_is_releasing = false
	_release_lanes.clear()
	set_process(_target_visible)
	queue_redraw()


func hide_target() -> void:
	_target_visible = false
	if not _is_releasing:
		set_process(false)
	queue_redraw()


## 第一档始终可瞬发；progress 只填充第二档，并同步展开三排伤害阴影。
func set_charge_progress(progress: float) -> void:
	_charge_progress = clampf(progress, 0.0, 1.0)
	queue_redraw()


## 空中火爆辣椒根节点在本特效局部坐标中的位置。
## 标志取根节点而不是 Body，避免膨胀动画令 UI 跟着缩放抖动。
func set_indicator_position(local_position: Vector2) -> void:
	_indicator_position = local_position
	_has_indicator_position = true
	queue_redraw()


## 播放斩击。actor_origin 与 lane_polygons 一样，必须是本节点局部坐标。
## airborne_actor 在播放中不会被移动；若存在 SwordPivot，则只在释放帧做重劈。
## 播放结束后，airborne_actor 和本特效节点都会 queue_free。
func start_release(
	center_lane: int,
	is_charged: bool,
	lane_polygons: Array,
	actor_origin: Vector2,
	airborne_actor: Node2D
) -> void:
	_all_lane_polygons = lane_polygons.duplicate(true)
	_target_lane = center_lane
	_target_visible = false
	_charge_progress = 1.0 if is_charged else 0.0
	_release_origin = actor_origin
	_release_actor = airborne_actor
	_release_lanes = _get_affected_lanes(center_lane, is_charged)
	_release_elapsed = 0.0
	_visual_time = 0.0
	_is_releasing = true
	set_process(true)
	queue_redraw()

	if is_inside_tree():
		_animate_sword_pivot()
	else:
		call_deferred("_animate_sword_pivot")


func _draw() -> void:
	if _is_releasing:
		_draw_release()
	elif _target_visible:
		_draw_target_preview()


func _draw_target_preview() -> void:
	if not _is_valid_lane(_target_lane):
		return

	# 格子只铺一层低透明阴影来表达真实判定，不再描亮边或叠第二层。
	# 中心排是当前可瞬发范围；上下排随第二档蓄力展开。
	var pulse := 0.88 + sin(_visual_time * 4.8) * 0.12
	_draw_lane_area(
		_target_lane,
		_with_alpha(preview_fill_color, pulse),
		Color.TRANSPARENT,
		1.0,
		0.0
	)

	if _charge_progress > 0.001:
		var expansion := smoothstep(0.0, 1.0, _charge_progress)
		# 未满蓄时上下排只是“候选范围”，比中心有效排明显更暗；满蓄才
		# 点亮到完整三排，避免 99% 松手仍只炸一排时产生判定误导。
		var candidate_strength := lerpf(0.14, 0.58, _charge_progress)
		if _charge_progress >= 1.0:
			candidate_strength = 1.0
		var candidate_alpha := candidate_strength * expansion
		for adjacent_lane in [_target_lane - 1, _target_lane + 1]:
			if not _is_valid_lane(adjacent_lane):
				continue
			var expanded_polygons := _get_lane_expansion_polygons(
				adjacent_lane,
				_target_lane,
				expansion
			)
			_draw_polygons_area(
				expanded_polygons,
				_with_alpha(preview_fill_color, candidate_alpha),
				Color.TRANSPARENT
			)

	# 刀痕本体永远留在中心排：一档细、二档只小幅变粗。三排的真实
	# 判定宽度由上面的格子阴影表达，不拿刀光硬铺满三排。
	var center_path := _get_lane_centerline(_target_lane, 1.0, 0.0)
	var lane_height := maxf(_get_lane_bounds(_target_lane).size.y, 72.0)
	var thin_half_width := clampf(lane_height * 0.13, 10.0, 17.0)
	var charged_half_width := clampf(lane_height * 0.205, 17.0, 27.0)
	# 前半程主要由火爆辣椒自身膨胀体现蓄力；刀痕在后半程才明显加粗，
	# 避免未满蓄时看上去已经进入第二档。
	var thickness_progress := pow(_charge_progress, 3.0)
	var flame_half_width := lerpf(thin_half_width, charged_half_width, thickness_progress)
	_draw_burning_corridor(center_path, flame_half_width, pulse, 1.0, 0.0)
	_draw_charge_indicator()


func _draw_release() -> void:
	var duration := maxf(release_duration, 0.001)
	var time_ratio := clampf(_release_elapsed / duration, 0.0, 1.0)
	var area_fade := 1.0 - smoothstep(0.52, 1.0, time_ratio)
	var area_pulse := 0.88 + sin(_visual_time * 26.0) * 0.12

	# 伤害区域严格使用传入的 cell 四边形，不用包围盒代替命中范围。
	for lane in _release_lanes:
		_draw_lane_area(
			lane,
			_with_alpha(damage_fill_color, area_fade * area_pulse),
			Color.TRANSPARENT,
			1.0,
			0.0
		)

	var slash_bounds := _get_lanes_bounds(_release_lanes)
	if slash_bounds.size.x <= 0.01 or slash_bounds.size.y <= 0.01:
		_draw_wind_pressure(time_ratio, Rect2(_release_origin, Vector2.ONE))
		return

	_draw_release_slash(time_ratio, slash_bounds)
	_draw_wind_pressure(time_ratio, slash_bounds)


func _draw_release_slash(time_ratio: float, bounds: Rect2) -> void:
	var reveal := _ease_out_cubic(clampf(time_ratio / 0.24, 0.0, 1.0))
	var blade_fade := 1.0 - smoothstep(0.42, 1.0, time_ratio)
	## 用真实目标排的中心线做刀光路径，屋顶会沿斜面而不是固定右上倾斜。
	var final_path := _get_lane_centerline(_target_lane, 1.0, 0.0)
	if final_path.size() < 2:
		final_path = PackedVector2Array([
			Vector2(bounds.position.x, bounds.get_center().y),
			Vector2(bounds.end.x, bounds.get_center().y)
		])
	var expansion_origin := Vector2(
		clampf(_release_origin.x, bounds.position.x, bounds.end.x),
		clampf(_release_origin.y, bounds.position.y, bounds.end.y)
	)
	var slash_path := _expand_path_from_origin(final_path, expansion_origin, reveal)
	var direction := (final_path[final_path.size() - 1] - final_path[0]).normalized()
	var normal := Vector2(-direction.y, direction.x)
	var lane_height := maxf(_get_lane_bounds(_target_lane).size.y, 72.0)
	var is_charged := _release_lanes.size() > 1
	# 满蓄只比瞬发粗一档，绝不按三排总高度把刀光放大三倍。
	var blade_half_width := clampf(
		lane_height * (0.27 if is_charged else 0.18),
		14.0 if is_charged else 10.0,
		34.0 if is_charged else 23.0
	)

	# 三层破碎残焰先画，主刀痕后画；全部使用不规则 ribbon，避免直线感。
	for index in range(3):
		var trail_delay := float(index) * 0.045
		var trail_time := clampf((time_ratio - trail_delay) / 0.74, 0.0, 1.0)
		if trail_time <= 0.0:
			continue
		var trail_alpha := (1.0 - smoothstep(0.34, 1.0, trail_time)) * (0.34 - float(index) * 0.07)
		var offset := normal * (float(index) + 1.0) * (7.0 + time_ratio * 10.0)
		var trail_path := _offset_path(slash_path, offset)
		_draw_burning_corridor(
			trail_path,
			blade_half_width * (0.62 - float(index) * 0.10),
			trail_alpha,
			0.58,
			float(index) * 1.37
		)

	_draw_burning_corridor(
		slash_path,
		blade_half_width,
		blade_fade,
		1.18,
		2.4
	)


func _draw_wind_pressure(time_ratio: float, bounds: Rect2) -> void:
	var max_radius := clampf(maxf(bounds.size.y * 0.58, 62.0), 62.0, 172.0)
	for index in range(3):
		var delay := float(index) * 0.075
		var ring_progress := clampf((time_ratio - delay) / 0.78, 0.0, 1.0)
		if ring_progress <= 0.0:
			continue
		var radius := lerpf(18.0, max_radius, _ease_out_cubic(ring_progress))
		var ring_alpha := (1.0 - ring_progress) * (0.62 - float(index) * 0.12)
		_draw_elliptical_arc(
			_release_origin,
			Vector2(radius * 1.24, radius * 0.68),
			-PI * 0.92,
			PI * 0.30,
			_with_alpha(slash_core_color, ring_alpha),
			3.0 - float(index) * 0.55
		)
		_draw_elliptical_arc(
			_release_origin,
			Vector2(radius, radius * 0.54),
			PI * 0.08,
			PI * 1.18,
			_with_alpha(slash_red_color, ring_alpha * 0.62),
			1.8
		)


## 守望斩仇的“长廊”材质被压进 PVZ 的中心排：黑烟外壳、燃烧红体、
## 白热核心。三层使用不同相位的动态边缘，不再依赖规整直线描边。
func _draw_burning_corridor(
	source_path: PackedVector2Array,
	half_width: float,
	alpha: float,
	intensity: float,
	phase: float
) -> void:
	if source_path.size() < 2 or half_width <= 0.01 or alpha <= 0.001:
		return

	var path := _resample_path(source_path, 64)
	if path.size() < 2:
		return
	var visible_alpha := clampf(alpha, 0.0, 1.0)
	var heat := clampf(intensity, 0.0, 1.35)
	var breath := 1.0 + sin(_visual_time * 3.7 + phase) * 0.035

	var smoke_ribbon := _build_burning_ribbon(
		path,
		half_width * 1.28 * breath,
		0.19,
		phase + 0.7
	)
	if smoke_ribbon.size() >= 3:
		draw_colored_polygon(
			smoke_ribbon,
			_with_alpha(preview_smoke_color, visible_alpha * (0.74 + heat * 0.18))
		)

	var red_ribbon := _build_burning_ribbon(
		path,
		half_width * 0.88 * breath,
		0.145,
		phase + 2.1
	)
	if red_ribbon.size() >= 3:
		draw_colored_polygon(
			red_ribbon,
			_with_alpha(preview_flame_color, visible_alpha * (0.68 + heat * 0.24))
		)

	# 暗红热层把白芯和黑壳咬合起来，避免像三条互不相干的色带。
	var hot_red_ribbon := _build_burning_ribbon(
		path,
		half_width * 0.52 * breath,
		0.18,
		phase + 4.0
	)
	if hot_red_ribbon.size() >= 3:
		draw_colored_polygon(
			hot_red_ribbon,
			Color(1.0, 0.075, 0.045, visible_alpha * (0.52 + heat * 0.20))
		)

	var core_ribbon := _build_burning_ribbon(
		path,
		half_width * 0.235,
		0.28,
		phase + 5.6
	)
	if core_ribbon.size() >= 3:
		draw_colored_polygon(
			core_ribbon,
			_with_alpha(preview_core_color, visible_alpha * (0.58 + heat * 0.28))
		)

	_draw_flowing_core_fragments(
		path,
		half_width * 0.205,
		visible_alpha * (0.68 + heat * 0.22),
		phase
	)
	_draw_burning_embers(path, half_width, visible_alpha * (0.55 + heat * 0.20), phase)


func _build_burning_ribbon(
	path: PackedVector2Array,
	half_width: float,
	roughness: float,
	phase: float
) -> PackedVector2Array:
	var upper := PackedVector2Array()
	var lower := PackedVector2Array()
	var last_index := path.size() - 1
	for index in range(path.size()):
		var ratio := float(index) / float(maxi(last_index, 1))
		var tangent := _get_path_tangent(path, index)
		var normal := Vector2(-tangent.y, tangent.x)
		# 两端收尖但不收成机械三角；不同频率分别扰动上下边缘。
		var end_mask := smoothstep(0.0, 0.075, ratio) * smoothstep(0.0, 0.075, 1.0 - ratio)
		var taper := lerpf(0.26, 1.0, end_mask)
		var upper_noise := sin(ratio * 31.0 + _visual_time * 4.1 + phase) * roughness
		upper_noise += sin(ratio * 73.0 - _visual_time * 6.3 + phase * 1.7) * roughness * 0.42
		var lower_noise := sin(ratio * 37.0 - _visual_time * 3.6 + phase * 1.3) * roughness
		lower_noise += sin(ratio * 67.0 + _visual_time * 5.7 + phase * 0.8) * roughness * 0.38
		upper.append(path[index] + normal * half_width * taper * (1.0 + upper_noise))
		lower.append(path[index] - normal * half_width * taper * (1.0 + lower_noise))

	var ribbon := PackedVector2Array()
	for point in upper:
		ribbon.append(point)
	for index in range(lower.size() - 1, -1, -1):
		ribbon.append(lower[index])
	return ribbon


func _draw_flowing_core_fragments(
	path: PackedVector2Array,
	half_width: float,
	alpha: float,
	phase: float
) -> void:
	for fragment_index in range(6):
		var drift := _visual_time * (0.115 + float(fragment_index % 2) * 0.025)
		var start_ratio := fposmod(
			float(fragment_index) * 0.205 + drift + phase * 0.017,
			1.16
		) - 0.08
		var fragment_length := 0.065 + float(fragment_index % 3) * 0.018
		var fragment_path := _get_path_section(path, start_ratio, start_ratio + fragment_length)
		if fragment_path.size() < 2:
			continue
		var fragment_ribbon := _build_burning_ribbon(
			fragment_path,
			half_width * (0.72 + float(fragment_index % 2) * 0.22),
			0.31,
			phase + float(fragment_index) * 1.9
		)
		if fragment_ribbon.size() >= 3:
			draw_colored_polygon(
				fragment_ribbon,
				Color(1.0, 0.99, 0.92, alpha * (0.66 + float(fragment_index % 2) * 0.22))
			)


func _draw_burning_embers(
	path: PackedVector2Array,
	half_width: float,
	alpha: float,
	phase: float
) -> void:
	if path.size() < 5:
		return
	for ember_index in range(7):
		var travel := _visual_time * (0.07 + float(ember_index % 3) * 0.012)
		var ratio := fposmod(float(ember_index) * 0.157 + travel + phase * 0.011, 0.92) + 0.04
		var path_index := clampi(roundi(ratio * float(path.size() - 1)), 1, path.size() - 2)
		var tangent := _get_path_tangent(path, path_index)
		var normal := Vector2(-tangent.y, tangent.x)
		var side := -1.0 if ember_index % 2 == 0 else 1.0
		var edge := path[path_index] + normal * half_width * side * (0.82 + sin(_visual_time * 5.0 + ember_index) * 0.08)
		var length := 5.0 + float(ember_index % 3) * 2.2
		var outer_tip := edge + normal * side * length + tangent * (3.0 + float(ember_index % 2) * 2.0)
		var shadow_triangle := PackedVector2Array([
			edge - tangent * 3.2,
			edge + tangent * 3.8,
			outer_tip + normal * side * 2.0,
		])
		draw_colored_polygon(shadow_triangle, Color(0.015, 0.0, 0.006, alpha * 0.52))
		var flame_triangle := PackedVector2Array([
			edge - tangent * 1.7,
			edge + tangent * 2.3,
			outer_tip,
		])
		draw_colored_polygon(flame_triangle, Color(1.0, 0.02, 0.045, alpha * 0.72))


func _resample_path(path: PackedVector2Array, sample_count: int) -> PackedVector2Array:
	if path.size() < 2 or sample_count < 2:
		return path
	var segment_lengths: Array[float] = []
	var total_length := 0.0
	for index in range(path.size() - 1):
		var segment_length := path[index].distance_to(path[index + 1])
		segment_lengths.append(segment_length)
		total_length += segment_length
	if total_length <= 0.001:
		return path

	var result := PackedVector2Array()
	var segment_index := 0
	var distance_before_segment := 0.0
	for sample_index in range(sample_count):
		var target_distance := total_length * float(sample_index) / float(sample_count - 1)
		while segment_index < segment_lengths.size() - 1\
			and distance_before_segment + segment_lengths[segment_index] < target_distance:
			distance_before_segment += segment_lengths[segment_index]
			segment_index += 1
		var segment_length := maxf(segment_lengths[segment_index], 0.001)
		var local_ratio := clampf(
			(target_distance - distance_before_segment) / segment_length,
			0.0,
			1.0
		)
		result.append(path[segment_index].lerp(path[segment_index + 1], local_ratio))
	return result


func _get_path_section(
	path: PackedVector2Array,
	start_ratio: float,
	end_ratio: float
) -> PackedVector2Array:
	var result := PackedVector2Array()
	if path.size() < 2:
		return result
	var last_index := path.size() - 1
	for index in range(path.size()):
		var ratio := float(index) / float(last_index)
		if ratio >= start_ratio and ratio <= end_ratio:
			result.append(path[index])
	return result


func _get_path_tangent(path: PackedVector2Array, index: int) -> Vector2:
	var previous_index := maxi(index - 1, 0)
	var next_index := mini(index + 1, path.size() - 1)
	var tangent := path[next_index] - path[previous_index]
	if tangent.length_squared() <= 0.0001:
		return Vector2.RIGHT
	return tangent.normalized()


func _draw_charge_indicator() -> void:
	if not _has_indicator_position:
		return
	var origin := _indicator_position + indicator_offset
	# 严格只画两格：下方短格是一段瞬发，上方宽格是二段蓄力。
	# 未完成区域完全透明，只留下细描边；不再叠加白芯或深红底。
	_draw_charge_bar(origin + Vector2(0.0, -6.5), 46.0, _charge_progress)
	_draw_charge_bar(origin + Vector2(0.0, 6.5), 30.0, 1.0)


func _draw_charge_bar(center: Vector2, width: float, fill: float) -> void:
	var clamped_fill := clampf(fill, 0.0, 1.0)
	var half_width := width * 0.5
	var bar := PackedVector2Array([
		center + Vector2(-half_width + 3.5, -4.0),
		center + Vector2(half_width - 3.5, -4.0),
		center + Vector2(half_width, 0.0),
		center + Vector2(half_width - 3.5, 4.0),
		center + Vector2(-half_width + 3.5, 4.0),
		center + Vector2(-half_width, 0.0),
	])
	draw_polyline(_close_polygon(bar), Color(1.0, 0.035, 0.07, 0.58), 1.5, true)
	if clamped_fill <= 0.001:
		return

	var fill_scale := 0.86 * smoothstep(0.0, 1.0, clamped_fill)
	var filled_bar := _scale_polygon(bar, center, Vector2(fill_scale, 0.68))
	draw_colored_polygon(
		filled_bar,
		Color(1.0, 0.018, 0.055, 0.42 + clamped_fill * 0.54)
	)


func _scale_polygon(
	polygon: PackedVector2Array,
	center: Vector2,
	scale_value: Vector2
) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in polygon:
		result.append(center + (point - center) * scale_value)
	return result


func _draw_lane_area(
	lane: int,
	fill_color: Color,
	separator_color: Color,
	vertical_progress: float,
	anchor_y: float
) -> void:
	var cells := _get_lane_polygons(lane)
	for polygon in cells:
		var visible_polygon := _transform_polygon_vertical(polygon, vertical_progress, anchor_y)
		if visible_polygon.size() < 3:
			continue
		draw_colored_polygon(visible_polygon, fill_color)
		if separator_color.a > 0.001:
			draw_polyline(_close_polygon(visible_polygon), separator_color, 1.15, true)


func _draw_polygons_area(
	polygons:Array[PackedVector2Array],
	fill_color:Color,
	separator_color:Color
) -> void:
	for polygon in polygons:
		if polygon.size() < 3:
			continue
		draw_colored_polygon(polygon, fill_color)
		if separator_color.a > 0.001:
			draw_polyline(_close_polygon(polygon), separator_color, 1.15, true)


## 相邻排按每一列对应格的真实边缘展开，保留屋顶斜面几何。
func _get_lane_expansion_polygons(
	lane:int,
	center_lane:int,
	progress:float
) -> Array[PackedVector2Array]:
	var result:Array[PackedVector2Array] = []
	var target_cells := _get_lane_polygons(lane)
	var center_cells := _get_lane_polygons(center_lane)
	var expansion_progress := clampf(progress, 0.0, 1.0)
	for cell_index in range(target_cells.size()):
		var target_polygon := target_cells[cell_index]
		if target_polygon.size() < 4 or center_cells.is_empty():
			result.append(target_polygon)
			continue
		var center_polygon := center_cells[mini(cell_index, center_cells.size() - 1)]
		if center_polygon.size() < 4:
			result.append(target_polygon)
			continue
		var edge_left := center_polygon[0] if lane < center_lane else center_polygon[3]
		var edge_right := center_polygon[1] if lane < center_lane else center_polygon[2]
		var collapsed := PackedVector2Array([edge_left, edge_right, edge_right, edge_left])
		var expanded := PackedVector2Array()
		for point_index in range(4):
			expanded.append(collapsed[point_index].lerp(target_polygon[point_index], expansion_progress))
		result.append(expanded)
	return result


func _get_lane_polygons(lane: int) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	if lane < 0 or lane >= _all_lane_polygons.size():
		return result

	var lane_data = _all_lane_polygons[lane]
	if not (lane_data is Array):
		return result

	for cell_data in lane_data:
		if cell_data is PackedVector2Array and cell_data.size() >= 3:
			result.append(cell_data)
	return result


func _is_valid_lane(lane: int) -> bool:
	return not _get_lane_polygons(lane).is_empty()


func _get_affected_lanes(lane: int, charged: bool) -> Array[int]:
	var result: Array[int] = []
	if not charged:
		if _is_valid_lane(lane):
			result.append(lane)
		return result

	for candidate in range(lane - 1, lane + 2):
		if _is_valid_lane(candidate):
			result.append(candidate)
	return result


func _get_lane_centerline(
	lane: int,
	vertical_progress: float,
	anchor_y: float
) -> PackedVector2Array:
	var cells := _get_lane_polygons(lane)
	var centers: Array[Vector2] = []
	for polygon in cells:
		var visible_polygon := _transform_polygon_vertical(polygon, vertical_progress, anchor_y)
		if visible_polygon.size() >= 3:
			centers.append(_polygon_center(visible_polygon))

	_sort_points_left_to_right(centers)
	if centers.is_empty():
		return PackedVector2Array()

	var lane_bounds := _get_transformed_lane_bounds(lane, vertical_progress, anchor_y)
	if centers.size() == 1:
		return PackedVector2Array([
			Vector2(lane_bounds.position.x, centers[0].y),
			Vector2(lane_bounds.end.x, centers[0].y)
		])

	var first := centers[0]
	first.x = lane_bounds.position.x
	centers[0] = first
	var last_index := centers.size() - 1
	var last := centers[last_index]
	last.x = lane_bounds.end.x
	centers[last_index] = last
	return PackedVector2Array(centers)


func _sort_points_left_to_right(points: Array[Vector2]) -> void:
	for index in range(1, points.size()):
		var key := points[index]
		var previous := index - 1
		while previous >= 0 and points[previous].x > key.x:
			points[previous + 1] = points[previous]
			previous -= 1
		points[previous + 1] = key


func _transform_polygon_vertical(
	polygon: PackedVector2Array,
	vertical_progress: float,
	anchor_y: float
) -> PackedVector2Array:
	var progress := clampf(vertical_progress, 0.0, 1.0)
	if progress >= 0.9999:
		return polygon
	if progress <= 0.0001:
		return PackedVector2Array()

	var result := PackedVector2Array()
	for point in polygon:
		result.append(Vector2(point.x, lerpf(anchor_y, point.y, progress)))
	return result


func _get_lane_bounds(lane: int) -> Rect2:
	return _get_polygons_bounds(_get_lane_polygons(lane))


func _get_transformed_lane_bounds(
	lane: int,
	vertical_progress: float,
	anchor_y: float
) -> Rect2:
	var transformed: Array[PackedVector2Array] = []
	for polygon in _get_lane_polygons(lane):
		var visible_polygon := _transform_polygon_vertical(polygon, vertical_progress, anchor_y)
		if visible_polygon.size() >= 3:
			transformed.append(visible_polygon)
	return _get_polygons_bounds(transformed)


func _get_lanes_bounds(lanes: Array[int]) -> Rect2:
	var polygons: Array[PackedVector2Array] = []
	for lane in lanes:
		polygons.append_array(_get_lane_polygons(lane))
	return _get_polygons_bounds(polygons)


func _get_polygons_bounds(polygons: Array[PackedVector2Array]) -> Rect2:
	var has_point := false
	var minimum := Vector2.ZERO
	var maximum := Vector2.ZERO
	for polygon in polygons:
		for point in polygon:
			if not has_point:
				minimum = point
				maximum = point
				has_point = true
			else:
				minimum.x = minf(minimum.x, point.x)
				minimum.y = minf(minimum.y, point.y)
				maximum.x = maxf(maximum.x, point.x)
				maximum.y = maxf(maximum.y, point.y)

	if not has_point:
		return Rect2()
	return Rect2(minimum, maximum - minimum)


func _polygon_center(polygon: PackedVector2Array) -> Vector2:
	var center := Vector2.ZERO
	for point in polygon:
		center += point
	return center / float(polygon.size())


func _close_polygon(polygon: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in polygon:
		result.append(point)
	if not polygon.is_empty():
		result.append(polygon[0])
	return result


func _expand_path_from_origin(
	path: PackedVector2Array,
	origin: Vector2,
	progress: float
) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in path:
		result.append(origin.lerp(point, progress))
	return result


func _offset_path(path: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in path:
		result.append(point + offset)
	return result


func _draw_elliptical_arc(
	center: Vector2,
	radius: Vector2,
	start_angle: float,
	end_angle: float,
	color: Color,
	width: float
) -> void:
	var points := PackedVector2Array()
	var point_count := 42
	for index in range(point_count):
		var ratio := float(index) / float(point_count - 1)
		var angle := lerpf(start_angle, end_angle, ratio)
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_polyline(points, color, width, true)


func _animate_sword_pivot() -> void:
	if not _is_releasing or not is_instance_valid(_release_actor):
		return

	var pivot_node := _release_actor.get_node_or_null("SwordPivot")
	if pivot_node == null:
		pivot_node = _release_actor.find_child("SwordPivot", true, false)
	if not (pivot_node is Node2D):
		return

	_sword_pivot = pivot_node as Node2D
	_sword_base_rotation = _sword_pivot.rotation
	_sword_base_scale = _sword_pivot.scale

	if _sword_tween != null and _sword_tween.is_valid():
		_sword_tween.kill()
	_sword_tween = create_tween()
	_sword_tween.set_pause_mode(Tween.TWEEN_PAUSE_BOUND)
	## 蓄力阶段只是火爆辣椒自身膨胀；释放帧才立即重劈。
	_sword_tween.tween_property(
		_sword_pivot,
		"rotation",
		_sword_base_rotation + deg_to_rad(118.0),
		sword_strike_duration
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	_sword_tween.parallel().tween_property(
		_sword_pivot,
		"scale",
		_sword_base_scale * 1.14,
		sword_strike_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_sword_tween.tween_property(
		_sword_pivot,
		"rotation",
		_sword_base_rotation,
		sword_recover_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_sword_tween.parallel().tween_property(
		_sword_pivot,
		"scale",
		_sword_base_scale,
		sword_recover_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_sword_tween.tween_callback(_reset_sword_pivot)


func _reset_sword_pivot() -> void:
	if not is_instance_valid(_sword_pivot):
		_sword_pivot = null
		return
	_sword_pivot.rotation = _sword_base_rotation
	_sword_pivot.scale = _sword_base_scale
	_sword_pivot = null


func _finish_release() -> void:
	if not _is_releasing:
		return
	_is_releasing = false
	set_process(false)
	_reset_sword_pivot()
	release_finished.emit()
	if is_instance_valid(_release_actor) and _release_actor != self:
		_release_actor.queue_free()
	_release_actor = null
	queue_free()


func _with_alpha(color: Color, multiplier: float) -> Color:
	var result := color
	result.a *= clampf(multiplier, 0.0, 1.0)
	return result


func _ease_out_cubic(value: float) -> float:
	var clamped := clampf(value, 0.0, 1.0)
	return 1.0 - pow(1.0 - clamped, 3.0)
