extends Node2D
class_name PlantEffectGarlicMaugaChain

const CHAIN_COLOR := Color(0.62, 0.88, 1.0, 0.58)
const CHAIN_HIGHLIGHT := Color(0.92, 0.98, 1.0, 0.72)
const LINK_SPACING := 11.0
const LINK_RADIUS := 5.0
const BODY_CUFF_RADIUS := 9.0

var source:Node2D
var target:Zombie000Base
var pulse_time := 0.0
var _target_body_attachment:Node2D
var _target_body_anchor:Marker2D

func setup(new_source:Node2D, new_target:Zombie000Base) -> void:
	source = new_source
	target = new_target
	top_level = true
	## 下方绘制使用世界坐标；必须把绘制节点自身归零，避免父级毛加位置被重复叠加。
	global_transform = Transform2D.IDENTITY
	z_as_relative = false
	z_index = RenderingServer.CANVAS_ITEM_Z_MAX - 1
	_bind_target_body_anchor()

func _process(delta:float) -> void:
	if not is_instance_valid(source) or not is_instance_valid(target):
		queue_free()
		return
	_sync_target_body_anchor()
	pulse_time += delta
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(source) or not is_instance_valid(target):
		return
	var start:Vector2 = source.body.global_position + Vector2(0.0, -34.0)
	var finish:Vector2 = _get_target_body_anchor()
	var chain_vector:Vector2 = finish - start
	var chain_length:float = chain_vector.length()
	if chain_length < 1.0:
		return
	var chain_angle:float = chain_vector.angle()
	var link_count:int = maxi(2, int(chain_length / LINK_SPACING))
	var pulse:float = 0.85 + sin(pulse_time * 5.0) * 0.15
	draw_line(start, finish, Color(0.72, 0.92, 1.0, 0.2), 2.0, true)
	for link_index:int in range(link_count + 1):
		var ratio:float = float(link_index) / float(link_count)
		var link_position:Vector2 = start.lerp(finish, ratio)
		var alternating_angle:float = chain_angle + (PI * 0.5 if link_index % 2 else 0.0)
		draw_set_transform(link_position, alternating_angle, Vector2(pulse, 0.55 * pulse))
		draw_arc(Vector2.ZERO, LINK_RADIUS, 0.0, TAU, 12, CHAIN_COLOR, 2.2, true)
		draw_arc(Vector2(-0.7, -0.7), LINK_RADIUS * 0.72, 0.0, PI, 8, CHAIN_HIGHLIGHT, 1.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_target_body_cuff(finish)

func _get_target_body_anchor() -> Vector2:
	if is_instance_valid(_target_body_anchor):
		return _target_body_anchor.global_position
	return target.body.global_position + Vector2(0.0, -40.0)

func _bind_target_body_anchor() -> void:
	_target_body_attachment = _find_target_torso_node()
	_target_body_anchor = Marker2D.new()
	_target_body_anchor.name = "MaugaChainBodyAnchor_%s" % source.get_instance_id()
	_target_body_attachment.add_child(_target_body_anchor)
	_sync_target_body_anchor()

func _sync_target_body_anchor() -> void:
	if not is_instance_valid(_target_body_anchor):
		if not is_instance_valid(target):
			return
		_target_body_attachment = _find_target_torso_node()
		if not is_instance_valid(_target_body_attachment):
			return
		_target_body_anchor = Marker2D.new()
		_target_body_anchor.name = "MaugaChainBodyAnchor_%s" % source.get_instance_id()
		_target_body_attachment.add_child(_target_body_anchor)
	var attachment_needs_refresh:= not is_instance_valid(_target_body_attachment)
	if _target_body_attachment is CanvasItem:
		attachment_needs_refresh = attachment_needs_refresh or not (
			_target_body_attachment as CanvasItem
		).is_visible_in_tree()
	if attachment_needs_refresh:
		var refreshed_attachment:Node2D = _find_target_torso_node()
		if is_instance_valid(refreshed_attachment) and refreshed_attachment != _target_body_attachment:
			_target_body_attachment = refreshed_attachment
			_target_body_anchor.reparent(_target_body_attachment, false)
	if _target_body_attachment is Sprite2D:
		## 每帧按当前纹理重算中心：换动画帧、掉手掉头换图后，锁扣仍贴在可见躯干上。
		var torso_sprite:= _target_body_attachment as Sprite2D
		if torso_sprite.texture != null and torso_sprite.get_rect().has_area():
			_target_body_anchor.position = torso_sprite.get_rect().get_center()
		else:
			_target_body_anchor.position = _target_body_attachment.to_local(desired_body_center())
	else:
		_target_body_anchor.position = Vector2.ZERO

func _exit_tree() -> void:
	if is_instance_valid(_target_body_anchor):
		_target_body_anchor.queue_free()

func _find_target_torso_node() -> Node2D:
	var exact_torso:= target.get_node_or_null(^"Body/BodyCorrect/Zombie_body") as Node2D
	if is_instance_valid(exact_torso) and (
		not exact_torso is CanvasItem or (exact_torso as CanvasItem).is_visible_in_tree()
	):
		return exact_torso
	var best_torso:Node2D
	var best_score := INF
	## 受击框中心更接近腰部。拆件动画需要再向上取胸口，否则伴舞僵尸会选中
	## Zombie_Jackson_body2（骨盆），锁扣看起来悬在身体侧下方。
	var desired_torso_center:Vector2 = desired_body_center() + Vector2.UP * 20.0
	for candidate_node:Node in target.body.find_children("*", "Sprite2D", true, false):
		var candidate:= candidate_node as Sprite2D
		if candidate is CanvasItem and not (candidate as CanvasItem).is_visible_in_tree():
			continue
		if candidate.texture == null or not candidate.get_rect().has_area():
			continue
		var candidate_name:String = candidate.name.to_lower()
		if not "body" in candidate_name:
			continue
		## 多部件僵尸的 Sprite2D 原点是动画关节，不是画面中心（且通常 centered=false）。
		## 必须按实际渲染矩形中心选躯干，否则会把锁扣挂到身体左侧的空白处。
		var rendered_center:Vector2 = candidate.to_global(candidate.get_rect().get_center())
		var score:float = rendered_center.distance_squared_to(desired_torso_center)
		if "overlay" in candidate_name or "charred" in candidate_name:
			score += 1000000.0
		if "lowerbody" in candidate_name:
			score += 250000.0
		if "upperbody" in candidate_name:
			score -= 100000.0
		if score < best_score:
			best_score = score
			best_torso = candidate
	if is_instance_valid(best_torso):
		return best_torso
	if is_instance_valid(exact_torso):
		return exact_torso
	var body_correct:= target.get_node_or_null(^"Body/BodyCorrect") as Node2D
	return body_correct if is_instance_valid(body_correct) else target.body

func desired_body_center() -> Vector2:
	var collision_shape:= target.get_node_or_null(^"HurtBoxComponent/HurtBoxReal/CollisionShape2D") as Node2D
	if is_instance_valid(collision_shape):
		return collision_shape.global_position
	return target.body.global_position + Vector2(0.0, -50.0)

## 返回当前整套可见身体精灵相对脚点的左右边缘；笼子每次校正都重新查询，
## 因此动画位移、旋转、缩放、掉头或掉手换图后，不会只把脚留在墙内而让身体穿出去。
func get_target_visible_body_x_offsets_from_ground() -> Vector2:
	if not is_instance_valid(target) or not is_instance_valid(target.body):
		return Vector2.ZERO
	var ground_x:float = target.shadow.global_position.x
	var min_x:float = ground_x
	var max_x:float = ground_x
	var sprite_nodes:Array[Node] = []
	sprite_nodes.append_array(target.body.find_children("*", "Sprite2D", true, false))
	for sprite_node:Node in sprite_nodes:
		var sprite:= sprite_node as Sprite2D
		if not is_instance_valid(sprite) or not sprite.is_visible_in_tree() or sprite.texture == null:
			continue
		var sprite_rect:Rect2 = sprite.get_rect()
		if not sprite_rect.has_area():
			continue
		for local_corner:Vector2 in [
			sprite_rect.position,
			Vector2(sprite_rect.end.x, sprite_rect.position.y),
			sprite_rect.end,
			Vector2(sprite_rect.position.x, sprite_rect.end.y),
		]:
			var world_corner:Vector2 = sprite.to_global(local_corner)
			min_x = minf(min_x, world_corner.x)
			max_x = maxf(max_x, world_corner.x)
	return Vector2(min_x - ground_x, max_x - ground_x)

func _draw_target_body_cuff(finish:Vector2) -> void:
	var attachment_rotation := 0.0
	var attachment_scale := Vector2.ONE
	if is_instance_valid(_target_body_anchor):
		attachment_rotation = _target_body_anchor.global_rotation
		var anchor_global_scale:Vector2 = _target_body_anchor.global_scale
		attachment_scale = Vector2(
			clampf(absf(anchor_global_scale.x), 0.4, 2.5),
			clampf(absf(anchor_global_scale.y), 0.4, 2.5)
		)
	draw_set_transform(finish, attachment_rotation, attachment_scale)
	draw_circle(Vector2.ZERO, BODY_CUFF_RADIUS, Color(0.08, 0.12, 0.15, 0.82))
	draw_arc(Vector2.ZERO, BODY_CUFF_RADIUS, 0.0, TAU, 20, CHAIN_HIGHLIGHT, 3.2, true)
	draw_arc(Vector2.ZERO, BODY_CUFF_RADIUS - 3.0, 0.0, TAU, 18, CHAIN_COLOR, 2.0, true)
	draw_circle(Vector2.ZERO, 2.3, CHAIN_HIGHLIGHT)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
