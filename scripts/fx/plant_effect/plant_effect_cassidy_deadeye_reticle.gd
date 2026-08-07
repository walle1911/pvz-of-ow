extends Node2D
class_name CassidyDeadeyeReticle

const SKULL_TEXTURE:Texture2D = preload("res://resources/character_resource/cassidy_deadeye_skull.png")
const RETICLE_COLOR:= Color(0.96, 0.075, 0.055, 0.82)
const RETICLE_SHADOW_COLOR:= Color(0.16, 0.0, 0.0, 0.72)
const RETICLE_GLOW_COLOR:= Color(1.0, 0.04, 0.02, 0.14)
const RETICLE_HIGHLIGHT_COLOR:= Color(1.0, 0.58, 0.36, 0.9)

@export_range(1.0, 100.0, 1.0, "suffix:px") var fixed_radius:= 15.0
@export_range(1.0, 150.0, 1.0, "suffix:px") var outer_start_radius:= 30.0
@export_range(0.5, 10.0, 0.25, "suffix:px") var line_width:= 1.25
@export_range(0.0, 1.0, 0.01) var head_offset_ratio:= 0.28
@export_range(-200.0, 200.0, 1.0, "suffix:px") var vertical_offset:= 0.0

var target:Zombie000Base
var charge_progress:= 0.0
var _skull:Sprite2D
var _is_finishing:= false
var _skull_was_shown:= false
var _visual_time:= 0.0


func _ready() -> void:
	z_as_relative = false
	z_index = 4000
	_skull = Sprite2D.new()
	_skull.name = "ChargedSkull"
	_skull.texture = SKULL_TEXTURE
	## 原图有效红色区域约 54×60px；0.47 倍后高度约 28.2px，
	## 正好内切半径 15px、线宽 1.25px 的内圈净空间。
	_skull.scale = Vector2.ONE * 0.47
	_skull.visible = false
	add_child(_skull)
	queue_redraw()


func setup(new_target:Zombie000Base) -> void:
	target = new_target
	_update_target_position()


func _process(delta:float) -> void:
	if _is_finishing:
		return
	if not is_instance_valid(target) or target.is_death:
		queue_free()
		return
	visible = true
	_visual_time += delta
	_update_target_position()
	queue_redraw()


func set_charge_progress(value:float) -> void:
	charge_progress = clampf(value, 0.0, 1.0)
	if is_instance_valid(_skull) and charge_progress >= 1.0 and not _skull_was_shown:
		_skull_was_shown = true
		_skull.visible = true
		_skull.modulate.a = 0.0
		_skull.scale = Vector2.ONE * 0.39
		var reveal_tween:= create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		reveal_tween.tween_property(_skull, ^"scale", Vector2.ONE * 0.47, 0.14)
		reveal_tween.tween_property(_skull, ^"modulate:a", 1.0, 0.1)
	queue_redraw()


func finish_and_free(hold_time:float) -> void:
	set_charge_progress(1.0)
	fade_and_free(hold_time)


func fade_and_free(hold_time:float) -> void:
	_is_finishing = true
	var tween:= create_tween()
	tween.tween_interval(maxf(hold_time, 0.0))
	tween.tween_property(self, ^"modulate:a", 0.0, 0.12)
	tween.tween_callback(queue_free)


func _update_target_position() -> void:
	if not is_instance_valid(target):
		return
	var head_sprite:= _find_visible_head_sprite()
	if is_instance_valid(head_sprite):
		global_position = head_sprite.to_global(head_sprite.get_rect().get_center()) + Vector2(0.0, vertical_offset)
		return
	var anchor_position:= target.global_position
	if is_instance_valid(target.hurt_box_component):
		var hurt_shape:= target.hurt_box_component.get_node_or_null("HurtBoxReal/CollisionShape2D") as CollisionShape2D
		if is_instance_valid(hurt_shape):
			anchor_position = hurt_shape.global_position + Vector2(0.0, -_get_shape_height(hurt_shape.shape) * head_offset_ratio)
		else:
			anchor_position = target.hurt_box_component.global_position
	global_position = anchor_position + Vector2(0.0, vertical_offset)


func _find_visible_head_sprite() -> Sprite2D:
	var body_root:= target.get_node_or_null("Body")
	if not is_instance_valid(body_root):
		return null
	var best_head:Sprite2D
	var best_area:= 0.0
	for child:Node in body_root.find_children("*", "Sprite2D", true, false):
		var sprite:= child as Sprite2D
		if not is_instance_valid(sprite) or sprite.texture == null or not sprite.is_visible_in_tree():
			continue
		var head_identity:= (String(sprite.name) + " " + sprite.texture.resource_path.get_file()).to_lower()
		if not head_identity.contains("head"):
			continue
		var sprite_rect:= sprite.get_rect()
		var global_axis_x:= sprite.global_transform.x * sprite_rect.size.x
		var global_axis_y:= sprite.global_transform.y * sprite_rect.size.y
		var global_area:= absf(global_axis_x.cross(global_axis_y))
		if global_area > best_area:
			best_area = global_area
			best_head = sprite
	return best_head


func _get_shape_height(shape:Shape2D) -> float:
	if shape is CapsuleShape2D:
		return shape.height
	if shape is RectangleShape2D:
		return shape.size.y
	if shape is CircleShape2D:
		return shape.radius * 2.0
	return 64.0


func _draw() -> void:
	## 锁定完成后保留内圈，让它与骷髅头共同显示。
	_draw_refined_ring(fixed_radius, _visual_time * 0.8)
	if charge_progress >= 1.0:
		return
	var outer_radius:= lerpf(outer_start_radius, fixed_radius, charge_progress)
	_draw_refined_ring(outer_radius, -_visual_time * 1.05 + PI)


func _draw_refined_ring(radius:float, highlight_angle:float) -> void:
	## 宽而淡的光晕、暗红压边和细亮主线叠加，避免单色圆线的廉价感。
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 72, RETICLE_GLOW_COLOR, line_width * 4.0, true)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 72, RETICLE_SHADOW_COLOR, line_width + 1.5, true)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 72, RETICLE_COLOR, line_width, true)
	## 短高光沿圆周缓慢游走，形成金属准星的层次，但不增加整体线宽。
	draw_arc(
		Vector2.ZERO,
		radius,
		highlight_angle,
		highlight_angle + 0.58,
		12,
		RETICLE_HIGHLIGHT_COLOR,
		maxf(0.65, line_width * 0.58),
		true
	)
