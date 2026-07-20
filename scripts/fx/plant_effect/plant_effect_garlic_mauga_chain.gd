extends Node2D
class_name PlantEffectGarlicMaugaChain

const CHAIN_COLOR := Color(0.62, 0.88, 1.0, 0.58)
const CHAIN_HIGHLIGHT := Color(0.92, 0.98, 1.0, 0.72)
const LINK_SPACING := 11.0
const LINK_RADIUS := 5.0

var source:Node2D
var target:Zombie000Base
var pulse_time := 0.0

func setup(new_source:Node2D, new_target:Zombie000Base) -> void:
	source = new_source
	target = new_target
	top_level = true
	z_as_relative = false
	z_index = RenderingServer.CANVAS_ITEM_Z_MAX - 1

func _process(delta:float) -> void:
	if not is_instance_valid(source) or not is_instance_valid(target):
		queue_free()
		return
	pulse_time += delta
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(source) or not is_instance_valid(target):
		return
	var start:Vector2 = source.global_position + Vector2(0.0, -34.0)
	var finish:Vector2 = target.shadow.global_position + Vector2(0.0, -24.0)
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
