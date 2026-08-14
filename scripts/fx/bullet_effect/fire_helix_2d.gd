@tool
extends Node2D
class_name FireHelix2D

const FLAME_SHADER := preload("res://shaders/fx/flame_ribbon.gdshader")
const PROCEDURAL_RIBBON_SCRIPT := preload("res://scripts/fx/bullet_effect/procedural_ribbon_2d.gd")
const NOZZLE_RIBBON_COUNT := 4

@export_group("主体螺旋")
@export var length := 720.0
@export var turns := 5.2
@export var amplitude_start := 18.0
@export var amplitude_end := 58.0
@export var spin_speed := 8.0
@export var turbulence := 7.0
@export var direction := Vector2.LEFT

@export_group("三层宽度")
@export var body_width := 28.0
@export var glow_width := 68.0
@export var core_width := 8.0

@export_group("火焰头与发射口")
@export var head_radius := 120.0
@export_range(5, 7, 1) var head_ribbon_count := 6
@export var nozzle_length := 100.0

@export_group("播放")
@export var continuous_preview := true
@export_range(0.0, 2.0, 0.01) var initial_intensity := 1.0

@onready var helix_outer:MeshInstance2D = $Helix/OuterGlow
@onready var helix_body:MeshInstance2D = $Helix/Body
@onready var helix_core:MeshInstance2D = $Helix/Core
@onready var nozzle_glow:Node2D = $Nozzle/Glow
@onready var nozzle_body:Node2D = $Nozzle/Body
@onready var nozzle_core:Node2D = $Nozzle/Core
@onready var head_back:Node2D = $FireHead/RibbonsBack
@onready var head_front:Node2D = $FireHead/RibbonsFront
@onready var head_core:Node2D = $FireHead/CoreRibbons
@onready var flame_wisps:GPUParticles2D = $FlameWisps
@onready var embers:GPUParticles2D = $Embers

var _materials:Array[ShaderMaterial] = []
var _head_base_radii:Dictionary[ShaderMaterial, float] = {}
var _elapsed := 0.0
var _intensity := 1.0
var _active_length := -1.0
var _playing := false
var _configuration_hash := 0


func _ready() -> void:
	_build_effect()
	set_intensity(initial_intensity)
	if continuous_preview or not Engine.is_editor_hint():
		play()
	else:
		stop()


func _process(delta:float) -> void:
	var next_hash := _get_configuration_hash()
	if next_hash != _configuration_hash:
		_build_effect()
	if not _playing:
		return
	_elapsed += delta
	for shader_material in _materials:
		shader_material.set_shader_parameter(&"elapsed_time", _elapsed)
	_update_runtime_layout()


func play() -> void:
	_elapsed = 0.0
	_playing = true
	visible = true
	flame_wisps.emitting = true
	embers.emitting = true
	_update_runtime_layout()


func stop() -> void:
	_playing = false
	flame_wisps.emitting = false
	embers.emitting = false
	if not continuous_preview:
		visible = false


func set_intensity(value:float) -> void:
	_intensity = clampf(value, 0.0, 2.0)
	for shader_material in _materials:
		shader_material.set_shader_parameter(&"intensity", _intensity)
	for shader_material:ShaderMaterial in _head_base_radii:
		shader_material.set_shader_parameter(
			&"head_radius",
			_head_base_radii[shader_material] * _intensity
		)
	flame_wisps.amount_ratio = clampf(_intensity, 0.0, 1.0)
	embers.amount_ratio = clampf(_intensity, 0.0, 1.0)
	_update_runtime_layout()


## 用于实战中让固定网格从发射口逐渐展开；不会重建 mesh。
func set_active_length(value:float) -> void:
	_active_length = clampf(value, 0.0, length)
	_update_runtime_layout()


func _build_effect() -> void:
	if not is_node_ready():
		return
	_materials.clear()
	_head_base_radii.clear()
	var max_half_width := maxf(amplitude_end + glow_width, head_radius + glow_width)
	for ribbon in [helix_outer, helix_body, helix_core]:
		ribbon.call(&"build_ribbon", length, max_half_width, 120)

	helix_outer.material = _create_layer_material(0, glow_width, 0.15, 0.0, 0)
	helix_body.material = _create_layer_material(0, body_width, 0.78, 0.0, 1)
	helix_core.material = _create_layer_material(0, core_width, 0.96, 0.0, 2)

	_rebuild_nozzle_ribbons()
	_rebuild_head_ribbons()
	var particle_texture := _create_soft_particle_texture()
	flame_wisps.texture = particle_texture
	embers.texture = particle_texture
	_configuration_hash = _get_configuration_hash()
	_update_runtime_layout()


func _rebuild_nozzle_ribbons() -> void:
	_clear_dynamic_children(nozzle_glow)
	_clear_dynamic_children(nozzle_body)
	_clear_dynamic_children(nozzle_core)
	for ribbon_index in range(NOZZLE_RIBBON_COUNT):
		var phase := float(ribbon_index) * 1.47
		_create_dynamic_ribbon(nozzle_glow, 2, glow_width * 0.42, 0.12, phase, 0, 56)
		_create_dynamic_ribbon(nozzle_body, 2, body_width * 0.68, 0.72, phase, 1, 56)
		_create_dynamic_ribbon(nozzle_core, 2, core_width * 0.72, 0.92, phase, 2, 56)


func _rebuild_head_ribbons() -> void:
	_clear_dynamic_children(head_back)
	_clear_dynamic_children(head_front)
	_clear_dynamic_children(head_core)
	for ribbon_index in range(head_ribbon_count):
		var ribbon_seed := float(ribbon_index) + 1.0
		var phase := ribbon_seed * 1.731
		var is_back := ribbon_index % 2 == 0
		var body_parent := head_back if is_back else head_front
		_create_head_ribbon(body_parent, ribbon_index, glow_width * 0.72, 0.13, phase, 0)
		_create_head_ribbon(body_parent, ribbon_index, body_width * 1.14, 0.76, phase, 1)
		if ribbon_index % 2 == 1 or ribbon_index == head_ribbon_count - 1:
			_create_head_ribbon(head_core, ribbon_index, core_width * 0.86, 0.88, phase, 2)


func _create_dynamic_ribbon(
	parent:Node2D,
	mode:int,
	width:float,
	alpha:float,
	phase:float,
	layer_kind:int,
	segments:int
) -> MeshInstance2D:
	var ribbon:MeshInstance2D = PROCEDURAL_RIBBON_SCRIPT.new()
	ribbon.name = "Ribbon%02d" % parent.get_child_count()
	parent.add_child(ribbon)
	ribbon.call(&"build_ribbon", nozzle_length, amplitude_start + glow_width, segments)
	ribbon.material = _create_layer_material(mode, width, alpha, phase, layer_kind)
	return ribbon


func _create_head_ribbon(
	parent:Node2D,
	ribbon_index:int,
	width:float,
	alpha:float,
	phase:float,
	layer_kind:int
) -> MeshInstance2D:
	var ribbon:MeshInstance2D = PROCEDURAL_RIBBON_SCRIPT.new()
	ribbon.name = "HeadRibbon%02d_%d" % [ribbon_index, layer_kind]
	parent.add_child(ribbon)
	ribbon.call(&"build_ribbon", head_radius * 2.0 + 230.0, head_radius + glow_width, 88)
	var shader_material := _create_layer_material(1, width, alpha, phase, layer_kind)
	var radius_variation := lerpf(0.72, 1.15, _hash(float(ribbon_index) * 4.17 + 0.3))
	var base_radius := head_radius * radius_variation
	shader_material.set_shader_parameter(&"head_radius", base_radius * _intensity)
	_head_base_radii[shader_material] = base_radius
	shader_material.set_shader_parameter(&"head_base_angle", TAU * float(ribbon_index) / float(head_ribbon_count) + phase * 0.21)
	var speed := lerpf(0.58, 1.18, _hash(float(ribbon_index) * 5.31 + 1.7))
	if ribbon_index % 3 == 0:
		speed *= -1.0
	shader_material.set_shader_parameter(&"head_angular_speed", speed)
	shader_material.set_shader_parameter(&"head_drag", lerpf(48.0, 118.0, _hash(float(ribbon_index) * 2.93 + 2.4)))
	ribbon.material = shader_material
	return ribbon


func _create_layer_material(
	mode:int,
	width:float,
	alpha:float,
	phase:float,
	layer_kind:int
) -> ShaderMaterial:
	var shader_material := ShaderMaterial.new()
	shader_material.shader = FLAME_SHADER
	shader_material.set_shader_parameter(&"path_mode", mode)
	shader_material.set_shader_parameter(&"effect_length", nozzle_length if mode == 2 else length)
	shader_material.set_shader_parameter(&"turns", turns)
	shader_material.set_shader_parameter(&"spin_speed", spin_speed)
	shader_material.set_shader_parameter(&"amplitude_start", amplitude_start)
	shader_material.set_shader_parameter(&"amplitude_end", amplitude_end)
	shader_material.set_shader_parameter(&"turbulence", turbulence)
	shader_material.set_shader_parameter(&"layer_width", width)
	shader_material.set_shader_parameter(&"layer_alpha", alpha)
	shader_material.set_shader_parameter(&"phase_offset", phase)
	shader_material.set_shader_parameter(&"elapsed_time", _elapsed)
	shader_material.set_shader_parameter(&"intensity", _intensity)
	if layer_kind == 0:
		shader_material.set_shader_parameter(&"edge_color", Color(0.72, 0.015, 0.002, 0.34))
		shader_material.set_shader_parameter(&"middle_color", Color(1.0, 0.10, 0.006, 0.42))
		shader_material.set_shader_parameter(&"hot_color", Color(1.0, 0.28, 0.018, 0.36))
	elif layer_kind == 1:
		shader_material.set_shader_parameter(&"edge_color", Color(1.0, 0.055, 0.004, 0.82))
		shader_material.set_shader_parameter(&"middle_color", Color(1.0, 0.31, 0.025, 0.94))
		shader_material.set_shader_parameter(&"hot_color", Color(1.0, 0.66, 0.16, 1.0))
	else:
		shader_material.set_shader_parameter(&"edge_color", Color(1.0, 0.52, 0.10, 0.88))
		shader_material.set_shader_parameter(&"middle_color", Color(1.0, 0.86, 0.48, 1.0))
		shader_material.set_shader_parameter(&"hot_color", Color(1.0, 1.0, 0.90, 1.0))
	_materials.append(shader_material)
	return shader_material


func _update_runtime_layout() -> void:
	if not is_node_ready():
		return
	rotation = direction.angle()
	var current_length := length if _active_length < 0.0 else _active_length
	var visible_ratio := clampf(current_length / maxf(length, 0.001), 0.0, 1.0)
	for shader_material in _materials:
		shader_material.set_shader_parameter(&"visible_ratio", visible_ratio)
		shader_material.set_shader_parameter(&"intensity", _intensity)
	$FireHead.position = Vector2(current_length, 0.0)
	$FireHead.visible = current_length > maxf(nozzle_length * 0.45, 8.0)
	embers.position = Vector2(current_length, 0.0)
	flame_wisps.position = Vector2(current_length * 0.5, 0.0)
	var wisp_material := flame_wisps.process_material as ParticleProcessMaterial
	if is_instance_valid(wisp_material):
		wisp_material.emission_box_extents = Vector3(
			maxf(current_length * 0.5, 1.0),
			maxf(amplitude_end * _intensity, 1.0),
			1.0
		)


func _clear_dynamic_children(parent:Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _create_soft_particle_texture() -> ImageTexture:
	const TEXTURE_SIZE := 32
	var image := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	var center := Vector2(TEXTURE_SIZE - 1, TEXTURE_SIZE - 1) * 0.5
	var max_radius := float(TEXTURE_SIZE) * 0.5
	for y in range(TEXTURE_SIZE):
		for x in range(TEXTURE_SIZE):
			var distance := Vector2(x, y).distance_to(center) / max_radius
			var alpha := pow(maxf(0.0, 1.0 - distance), 2.4)
			image.set_pixel(x, y, Color(1.0, 0.34, 0.035, alpha))
	return ImageTexture.create_from_image(image)


func _get_configuration_hash() -> int:
	return [
		length, turns, amplitude_start, amplitude_end, spin_speed, turbulence,
		body_width, glow_width, core_width, head_radius, head_ribbon_count, nozzle_length
	].hash()


func _hash(hash_seed:float) -> float:
	return fposmod(sin(hash_seed * 12.9898) * 43758.5453, 1.0)
