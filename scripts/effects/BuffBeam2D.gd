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

var _shader_material: ShaderMaterial

# Cached geometry — only rebuilt when endpoints change
var _vertices := PackedVector2Array()
var _uvs := PackedVector2Array()
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
func set_endpoints(from_local: Vector2, to_local: Vector2) -> void:
	if _from_pos == from_local and _to_pos == to_local:
		return
	_from_pos = from_local
	_to_pos = to_local
	_has_endpoints = true
	_geometry_dirty = true
	visible = true
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

	# Single polygon strip with UVs — shader handles glow + core + flow + pulse
	draw_colored_polygon(_vertices, Color.WHITE, _uvs)


func _rebuild_geometry() -> void:
	var direction := (_to_pos - _from_pos).normalized()
	var normal := Vector2(-direction.y, direction.x)
	var half_width := beam_width * 0.5
	var pts := clampi(point_count, 2, 64)

	_vertices = PackedVector2Array()
	_vertices.resize(pts * 2)
	_uvs = PackedVector2Array()
	_uvs.resize(pts * 2)

	for i in range(pts):
		var t := float(i) / float(pts - 1)
		var arc := sin(t * PI) * curve_height
		var center := _from_pos.lerp(_to_pos, t) + normal * arc

		# Bottom edge vertex
		_vertices[i] = center - normal * half_width
		_uvs[i] = Vector2(t, 0.0)

		# Top edge vertex (reversed index to close polygon CCW)
		var ri := pts * 2 - 1 - i
		_vertices[ri] = center + normal * half_width
		_uvs[ri] = Vector2(t, 1.0)


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
