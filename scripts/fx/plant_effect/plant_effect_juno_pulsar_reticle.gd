extends Node2D

const LOCK_FILL_COLOR:= Color(1.0, 0.10, 0.24, 0.74)

var target:Zombie000Base
var lock_progress:= 0.0
var tracking_active:= true
var _visual_time:= 0.0
var _is_finishing:= false
var _target_body_anchor_local:= Vector2(0.0, -50.0)


func _ready() -> void:
	z_as_relative = false
	z_index = 4001
	scale = Vector2.ONE * 0.85
	queue_redraw()


func setup(new_target:Zombie000Base) -> void:
	target = new_target
	_target_body_anchor_local = _calculate_target_body_anchor_local()
	_update_target_position()


func _process(delta:float) -> void:
	if _is_finishing:
		return
	if not is_instance_valid(target) or target.is_death:
		queue_free()
		return
	_visual_time += delta
	_update_target_position()
	queue_redraw()


func set_lock_progress(value:float) -> void:
	lock_progress = clampf(value, 0.0, 1.0)
	queue_redraw()


func set_tracking_active(value:bool) -> void:
	tracking_active = value
	modulate.a = 1.0 if value else 0.38


func finish_and_free() -> void:
	_is_finishing = true
	lock_progress = 1.0
	queue_redraw()
	var tween:= create_tween()
	tween.tween_interval(0.12)
	tween.tween_property(self, ^"modulate:a", 0.0, 0.12)
	tween.tween_callback(queue_free)


func fade_and_free() -> void:
	_is_finishing = true
	var tween:= create_tween()
	tween.tween_property(self, ^"modulate:a", 0.0, 0.10)
	tween.tween_callback(queue_free)


func _update_target_position() -> void:
	if not is_instance_valid(target):
		return
	global_position = target.to_global(_target_body_anchor_local)


func _calculate_target_body_anchor_local() -> Vector2:
	if not is_instance_valid(target):
		return Vector2(0.0, -50.0)
	var body_root:= target.get_node_or_null("Body") as Node2D
	if not is_instance_valid(body_root):
		return Vector2(0.0, -50.0)
	var has_visible_point:= false
	var bounds_min:= Vector2(INF, INF)
	var bounds_max:= Vector2(-INF, -INF)
	for child:Node in body_root.find_children("*", "Sprite2D", true, false):
		var sprite:= child as Sprite2D
		if not is_instance_valid(sprite) or sprite.texture == null or not sprite.is_visible_in_tree():
			continue
		var sprite_rect:= sprite.get_rect()
		var corners:= [
			sprite_rect.position,
			sprite_rect.position + Vector2(sprite_rect.size.x, 0.0),
			sprite_rect.end,
			sprite_rect.position + Vector2(0.0, sprite_rect.size.y),
		]
		for corner:Vector2 in corners:
			var global_corner:= sprite.to_global(corner)
			bounds_min = bounds_min.min(global_corner)
			bounds_max = bounds_max.max(global_corner)
			has_visible_point = true
	if not has_visible_point:
		return Vector2(0.0, -50.0)
	## 锚点只在开始锁定时计算一次，随后跟随僵尸根节点，避免 idle 动画令准星晃动。
	return target.to_local((bounds_min + bounds_max) * 0.5)


func _draw() -> void:
	var pulse:= 1.0 + sin(_visual_time * 8.0) * 0.035
	if lock_progress < 1.0:
		## 搜索到完成态始终保持同一透明度，避免成功瞬间先淡出再亮回。
		var arrow_alpha:= 0.76
		var arrow_distance:= 29.0
		if lock_progress < 0.58:
			## 配合更长的二段跳上升锁定，从更外圈开始搜索收束。
			arrow_distance = lerpf(62.0, 29.0, ease(lock_progress / 0.58, 0.65))
		else:
			## 完成标记出现时从最内侧 29px 小幅回弹到 32px。
			arrow_distance = lerpf(29.0, 32.0, ease((lock_progress - 0.58) / 0.42, 0.7))
		_draw_target_glow(arrow_alpha)
		## 收缩到 29px 时停止呼吸，随后只执行一次 29→32 的位置插值。
		var pulse_weight:= clampf((0.58 - lock_progress) / 0.16, 0.0, 1.0)
		_draw_lock_frame(arrow_distance * lerpf(1.0, pulse, pulse_weight), arrow_alpha)
		if lock_progress > 0.58:
			_draw_lock_diamond((lock_progress - 0.58) / 0.42)
	else:
		## 完成锁定后保持收缩到最里面的位置，不再向外回弹。
		_draw_lock_frame(32.0, 0.76)
		_draw_lock_diamond(1.0)


func _draw_target_glow(alpha:float) -> void:
	draw_arc(Vector2.ZERO, 31.0, 0.0, TAU, 48, Color(1.0, 0.04, 0.18, 0.10 * alpha), 9.0, true)
	draw_arc(Vector2.ZERO, 30.0, 0.0, TAU, 48, Color(1.0, 0.13, 0.25, 0.34 * alpha), 2.0, true)


func _draw_chevron(axis:Vector2, distance:float, alpha:float) -> void:
	var tangent:= Vector2(-axis.y, axis.x)
	var tip:= axis * distance
	var arms:= PackedVector2Array([
		tip - axis * 9.0 + tangent * 7.5,
		tip,
		tip - axis * 9.0 - tangent * 7.5,
	])
	draw_polyline(arms, Color(0.22, 0.0, 0.05, 0.72 * alpha), 7.0, true)
	draw_polyline(arms, Color(1.0, 0.16, 0.28, 0.94 * alpha), 4.0, true)
	draw_polyline(arms, Color(1.0, 0.62, 0.68, 0.82 * alpha), 1.2, true)


func _draw_lock_frame(distance:float, alpha:float) -> void:
	_draw_chevron(Vector2.UP, distance, alpha)
	_draw_chevron(Vector2.DOWN, distance, alpha)
	_draw_chevron(Vector2.LEFT, distance, alpha)
	_draw_chevron(Vector2.RIGHT, distance, alpha)


func _draw_lock_diamond(progress:float) -> void:
	var reveal:= clampf(progress, 0.0, 1.0)
	## 原图中央标记半径约占最终四向框半径的 53%；外围框尺寸保持不变。
	var radius:= lerpf(15.0, 29.0, ease(reveal, 0.55)) * 0.585
	var fill_color:= Color(LOCK_FILL_COLOR, LOCK_FILL_COLOR.a * reveal)
	var segment_count:= 48
	var outer_roundness:= 1.14
	## 原版四芒星约占主图形一半以上，四个凹口也比较饱满。
	var star_long_radius:= radius * 0.56
	## 无重叠地连接外部圆角旋转正方形与内部四芒星，形成单一红色填充。
	## 中央四芒星区域完全不绘制，因此没有内边线、内填色或白色图案。
	for segment_index in segment_count:
		var angle_a:= -PI * 0.5 + TAU * float(segment_index) / float(segment_count)
		var angle_b:= -PI * 0.5 + TAU * float(segment_index + 1) / float(segment_count)
		var outer_a:= _get_rounded_diamond_point(angle_a, radius, outer_roundness)
		var outer_b:= _get_rounded_diamond_point(angle_b, radius, outer_roundness)
		var inner_a:= Vector2.RIGHT.rotated(angle_a) * _get_four_point_star_radius(angle_a, star_long_radius)
		var inner_b:= Vector2.RIGHT.rotated(angle_b) * _get_four_point_star_radius(angle_b, star_long_radius)
		draw_colored_polygon(PackedVector2Array([
			outer_a, outer_b, inner_b, inner_a,
		]), fill_color)


func _get_rounded_diamond_point(angle:float, radius:float, exponent:float) -> Vector2:
	## exponent=1 是尖角菱形；略大于 1 会保留直边观感并柔化四个角。
	var direction:= Vector2.RIGHT.rotated(angle)
	var denominator:= pow(
		pow(absf(direction.x), exponent) + pow(absf(direction.y), exponent),
		1.0 / exponent
	)
	return direction * radius / maxf(denominator, 0.001)


func _get_four_point_star_radius(angle:float, long_radius:float) -> float:
	## 四尖瓣星形（astroid）的极坐标形式：四个轴向端点保持锐利，边缘平滑向内凹。
	## 等价参数方程为 x=a*cos(t)^3, y=a*sin(t)^3，与原版四芒星轮廓一致。
	var direction:= Vector2.RIGHT.rotated(angle)
	var denominator:= pow(
		pow(absf(direction.x), 2.0 / 3.0) + pow(absf(direction.y), 2.0 / 3.0),
		1.5
	)
	return long_radius / maxf(denominator, 0.001)
