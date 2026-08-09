extends Node2D
class_name BuffBeam2D

## Slender blue energy tether with soft glow edges and bright core.
##
## Renders via _draw() + ShaderMaterial on self.material — the shader
## handles glow falloff, core highlight, flow animation, and pulse.
##
## Usage:
##   var beam = preload("res://scenes/effects/BuffBeam2D.tscn").instantiate()
##   add_child(beam)
##   beam.set_endpoints(beam.to_local(from_global), beam.to_local(to_global))

# ================================================================
# Exported params
# ================================================================

@export var beam_width := 14.0            ## Total beam width (shader handles glow + core)
@export var curve_height := 0.0           ## Arc sag (negative = downward bow)
@export var point_count := 16             ## Curve resolution
@export var z_index_override := 200

# Shader uniforms — propagated to the ShaderMaterial
@export var glow_color := Color(0.08, 0.35, 1.0, 0.7)
@export var core_color := Color(0.3, 0.7, 1.0, 0.9)
@export var flow_speed := 1.2
@export var flow_density := 8.0
@export var pulse_speed := 3.5
@export var pulse_amount := 0.12
@export var glow_softness := 1.0          ## Lower = softer edge (0.3–3.0)
@export var core_falloff := 3.5           ## Higher = sharper core (1.5–6.0)
@export var core_ratio := 0.15            ## Core width fraction of beam (0.03–0.4)

# ================================================================
# Internal
# ================================================================

const BEAM_SHADER := preload("res://shaders/beam_flow.gdshader")

var _from_pos := Vector2.ZERO
var _to_pos := Vector2.ZERO
var _has_endpoints := false
var _start_tangent_direction := Vector2.ZERO
var _source_straight_length := 0.0

var _shader_material: ShaderMaterial

# Cached segmented ribbon geometry — only rebuilt when endpoints change.
# Convex quads avoid the unstable triangulation of one large concave polygon.
var _edge_a := PackedVector2Array()
var _edge_b := PackedVector2Array()
var _geometry_dirty := true


# ================================================================
# Lifecycle
# ================================================================

func _ready() -> void:
	_shader_material = ShaderMaterial.new()
	_shader_material.shader = BEAM_SHADER
	_apply_shader_params()
	self.material = _shader_material
	z_index = z_index_override
	visible = false
	set_process(true)


func _process(_delta: float) -> void:
	if not _has_endpoints or not visible:
		return
	# Redraw every frame so the shader receives updated TIME for animation
	queue_redraw()


# ================================================================
# Public API
# ================================================================

## Set beam endpoints in LOCAL coordinates (relative to this node).
func set_endpoints(from_local: Vector2, endpoint_local: Vector2) -> void:
	if _from_pos == from_local and _to_pos == endpoint_local:
		return
	_from_pos = from_local
	_to_pos = endpoint_local
	_has_endpoints = true
	_geometry_dirty = true
	visible = true
	queue_redraw()


## Optional source tangent. The beam first follows this direction in a straight
## segment, then bends smoothly toward the target.
func set_start_tangent(direction:Vector2, straight_length:float) -> void:
	var normalized_direction := direction.normalized() if not direction.is_zero_approx() else Vector2.ZERO
	var clamped_length := maxf(straight_length, 0.0)
	if _start_tangent_direction.is_equal_approx(normalized_direction) \
	and is_equal_approx(_source_straight_length, clamped_length):
		return
	_start_tangent_direction = normalized_direction
	_source_straight_length = clamped_length
	_geometry_dirty = true
	queue_redraw()


func show_beam() -> void:
	if _has_endpoints:
		visible = true
		queue_redraw()


func hide_beam() -> void:
	visible = false


func clear() -> void:
	_from_pos = Vector2.ZERO
	_to_pos = Vector2.ZERO
	_has_endpoints = false
	_geometry_dirty = true
	visible = false
	queue_redraw()


# ================================================================
# Rendering
# ================================================================

func _draw() -> void:
	if not _has_endpoints:
		return

	var dist := _from_pos.distance_to(_to_pos)
	if dist < 0.5:
		return

	if _geometry_dirty:
		_rebuild_geometry()
		_geometry_dirty = false

	## 每段都是凸四边形，避免大角度弯曲时凹多边形三角化塌缩。
	for i in range(_edge_a.size() - 1):
		var t0 := float(i) / float(_edge_a.size() - 1)
		var t1 := float(i + 1) / float(_edge_a.size() - 1)
		var quad := PackedVector2Array([
			_edge_a[i],
			_edge_a[i + 1],
			_edge_b[i + 1],
			_edge_b[i],
		])
		var quad_uvs := PackedVector2Array([
			Vector2(t0, 0.0),
			Vector2(t1, 0.0),
			Vector2(t1, 1.0),
			Vector2(t0, 1.0),
		])
		draw_colored_polygon(quad, Color.WHITE, quad_uvs)


func _rebuild_geometry() -> void:
	var direction := (_to_pos - _from_pos).normalized()
	var path_normal := Vector2(-direction.y, direction.x)
	var half_width := beam_width * 0.5
	var pts := clampi(point_count, 4, 64)
	var distance := _from_pos.distance_to(_to_pos)
	var use_source_tangent := _source_straight_length > 0.0 \
		and not _start_tangent_direction.is_zero_approx()
	var straight_length := minf(_source_straight_length, distance * 0.45)
	var straight_end := _from_pos + _start_tangent_direction * straight_length
	var remaining_distance := straight_end.distance_to(_to_pos)
	var curve_control_1 := straight_end \
		+ _start_tangent_direction * remaining_distance * 0.22 \
		+ path_normal * curve_height
	var curve_control_2 := _to_pos.lerp(straight_end, 0.22) \
		+ path_normal * curve_height * 0.35
	var centers := PackedVector2Array()
	centers.resize(pts)

	for i in range(pts):
		var t := float(i) / float(pts - 1)
		if use_source_tangent and i == 0:
			centers[i] = _from_pos
		elif use_source_tangent and i == 1:
			## 固定长度的微小直线段，不再按整条光束比例放大。
			centers[i] = straight_end
		elif use_source_tangent:
			var curve_t := float(i - 1) / float(pts - 2)
			var one_minus_t := 1.0 - curve_t
			centers[i] = one_minus_t * one_minus_t * one_minus_t * straight_end \
				+ 3.0 * one_minus_t * one_minus_t * curve_t * curve_control_1 \
				+ 3.0 * one_minus_t * curve_t * curve_t * curve_control_2 \
				+ curve_t * curve_t * curve_t * _to_pos
		else:
			var arc := sin(t * PI) * curve_height
			centers[i] = _from_pos.lerp(_to_pos, t) + path_normal * arc

	_edge_a = PackedVector2Array()
	_edge_a.resize(pts)
	_edge_b = PackedVector2Array()
	_edge_b.resize(pts)

	for i in range(pts):
		var previous_center := centers[maxi(i - 1, 0)]
		var next_center := centers[mini(i + 1, pts - 1)]
		var local_direction := (next_center - previous_center).normalized()
		if local_direction.is_zero_approx():
			local_direction = direction
		var local_normal := Vector2(-local_direction.y, local_direction.x)

		_edge_a[i] = centers[i] - local_normal * half_width
		_edge_b[i] = centers[i] + local_normal * half_width


# ================================================================
# Shader param sync
# ================================================================

func _apply_shader_params() -> void:
	if not _shader_material:
		return
	_shader_material.set_shader_parameter("glow_color", glow_color)
	_shader_material.set_shader_parameter("core_color", core_color)
	_shader_material.set_shader_parameter("flow_speed", flow_speed)
	_shader_material.set_shader_parameter("flow_density", flow_density)
	_shader_material.set_shader_parameter("pulse_speed", pulse_speed)
	_shader_material.set_shader_parameter("pulse_amount", pulse_amount)
	_shader_material.set_shader_parameter("glow_softness", glow_softness)
	_shader_material.set_shader_parameter("core_falloff", core_falloff)
	_shader_material.set_shader_parameter("core_ratio", core_ratio)
