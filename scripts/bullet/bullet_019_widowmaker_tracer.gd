extends Bullet000Base
## 无可见弹体的即时命中弹。多层 Line2D 模拟发光边缘，Shader 负责噪声溶解。
class_name Bullet019WidowmakerTracer

@export_group("即时命中")
@export var attack_value := 250
@export var bullet_mode := BulletRegistry.AttackMode.Norm
@export var extend_after_target := 36.0

@export_group("弹道视觉")
@export_range(0.0, 1.0, 0.01, "or_greater") var hold_time := 0.12
@export_range(0.05, 2.0, 0.01, "or_greater") var dissolve_duration := 0.75
@export var outer_width := 34.0
@export var glow_width := 15.0
@export var core_width := 5.0
@export_subgroup("弹道颜色")
@export var haze_color := Color(0.95, 0.006, 0.002, 0.035)
@export var outer_color := Color(1.0, 0.015, 0.004, 0.085)
@export var glow_color := Color(1.0, 0.035, 0.009, 0.2)
@export var core_color := Color(1.0, 0.07, 0.02, 0.42)

const TRACER_SHADER := preload("res://scripts/bullet/bullet_019_widowmaker_tracer.gdshader")

var _targets:Array[Character000Base] = []
var _lane := -1
var _materials:Array[ShaderMaterial] = []
var _tracer_lines:Array[Line2D] = []
var _base_widths:Array[float] = []
var _wind_offsets:Array[float] = []


func init_bullet(bullet_paras:Dictionary):
	_lane = bullet_paras.get(Bullet000NormBase.E_InitParasAttr.BulletLane, -1)
	position = bullet_paras.get(Bullet000NormBase.E_InitParasAttr.Position, Vector2.ZERO)
	var target_data:Variant = bullet_paras.get(Bullet000NormBase.E_InitParasAttr.Enemy)
	if target_data is Array:
		for candidate:Variant in target_data:
			if candidate is Character000Base and is_instance_valid(candidate):
				_targets.append(candidate)
	elif target_data is Character000Base and is_instance_valid(target_data):
		_targets.append(target_data)
	var new_attack_value:int = bullet_paras.get(Bullet000NormBase.E_InitParasAttr.AttackValue, -1)
	if new_attack_value > 0:
		attack_value = new_attack_value


func _ready() -> void:
	bullet_shadow.hide()
	body.hide()
	z_index = _lane * 50 + 45
	var valid_targets:Array[Character000Base] = []
	for candidate:Character000Base in _targets:
		if is_instance_valid(candidate) and not candidate.is_death:
			valid_targets.append(candidate)
	_targets = valid_targets
	if _targets.is_empty():
		queue_free()
		return

	var end_target:Character000Base = _targets[0]
	for candidate:Character000Base in _targets:
		if global_position.distance_squared_to(candidate.global_position) \
		> global_position.distance_squared_to(end_target.global_position):
			end_target = candidate
	var target_local_position := to_local(end_target.hurt_box_component.global_position)
	var horizontal_direction := signf(target_local_position.x)
	if is_zero_approx(horizontal_direction):
		horizontal_direction = 1.0
	## 伤害命中目标中心，但弹道始终与草坪平行，不随目标高度倾斜。
	var tracer_end := Vector2(target_local_position.x + horizontal_direction * extend_after_target, 0.0)
	## 极淡宽雾光 + 三层连续羽化，避免光束边缘与背景形成硬切。
	_create_tracer_layer(outer_width * 1.65, haze_color, -11.0)
	_create_tracer_layer(outer_width, outer_color, 8.0)
	_create_tracer_layer(glow_width, glow_color, -5.0)
	_create_tracer_layer(core_width, core_color, 2.0)
	for line:Line2D in _tracer_lines:
		line.points = PackedVector2Array([Vector2.ZERO, tracer_end])

	for target:Character000Base in _targets:
		if is_instance_valid(target) and not target.is_death:
			var source_zombie_type := get_attack_source_zombie_type()
			if target is Plant000Base \
			and bullet_camp == CharacterRegistry.CharacterType.Zombie \
			and source_zombie_type != CharacterRegistry.ZombieType.Null:
				(target as Plant000Base).be_attacked_bullet_from_zombie(
					attack_value,
					bullet_mode,
					true,
					true,
					source_zombie_type
				)
			else:
				target.be_attacked_bullet(attack_value, bullet_mode, true, true)
	_start_dissolve()


func _create_tracer_layer(width:float, color:Color, wind_offset:float):
	var line := Line2D.new()
	line.width = width
	line.default_color = color
	line.antialiased = true
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.texture_mode = Line2D.LINE_TEXTURE_STRETCH
	var shader_material := ShaderMaterial.new()
	shader_material.shader = TRACER_SHADER
	shader_material.set_shader_parameter("noise_seed", randf() * 100.0)
	line.material = shader_material
	_materials.append(shader_material)
	_tracer_lines.append(line)
	_base_widths.append(width)
	_wind_offsets.append(wind_offset)
	add_child(line)


func _start_dissolve():
	var tween := create_tween()
	tween.tween_interval(hold_time)
	tween.tween_method(_set_dissolve_progress, 0.0, 1.0, dissolve_duration).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(queue_free)


func _set_dissolve_progress(progress:float):
	for shader_material:ShaderMaterial in _materials:
		shader_material.set_shader_parameter("dissolve_progress", progress)
	## 各层保持水平，只在消散阶段缓慢错位、变宽，模拟残留气流被吹散。
	var wind_progress := ease(progress, 1.6)
	for index:int in _tracer_lines.size():
		_tracer_lines[index].position.y = _wind_offsets[index] * wind_progress
		_tracer_lines[index].width = _base_widths[index] * lerpf(1.0, 1.45, wind_progress)
