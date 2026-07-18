@tool
extends Node2D
class_name ComponentDjFlexibleClothing

## Uses the imported leg animation nodes as an invisible rig. The trousers are
## rebuilt as small textured strips, so every existing and future dance motion
## automatically bends them without adding clothing animation tracks.

@export_group("Rig")
@export var inner_upper_path: NodePath
@export var inner_lower_path: NodePath
@export var inner_foot_path: NodePath
@export var outer_upper_path: NodePath
@export var outer_lower_path: NodePath
@export var outer_foot_path: NodePath

@export_group("Textures")
@export var inner_pants_texture: Texture2D
@export var outer_pants_texture: Texture2D
@export var shoe_texture: Texture2D

@export_group("Fit")
@export var pants_half_widths := PackedFloat32Array([15.0, 16.0, 18.0, 21.0, 26.0, 34.0])
@export var hem_extension := 9.0
@export var inner_shoe_offset := Vector2(17.0, 17.0)
@export var outer_shoe_offset := Vector2(22.0, 9.0)
@export var inner_shoe_scale := Vector2(0.30, 0.30)
@export var outer_shoe_scale := Vector2(0.30, 0.30)

@export_group("Layering")
@export var inner_pants_z_index := 1
@export var outer_pants_z_index := 1
@export var inner_shoe_z_index := 2
@export var outer_shoe_z_index := 2

var _inner_upper: Node2D
var _inner_lower: Node2D
var _inner_foot: Node2D
var _outer_upper: Node2D
var _outer_lower: Node2D
var _outer_foot: Node2D

var _inner_pants: MeshInstance2D
var _outer_pants: MeshInstance2D
var _inner_shoe: Sprite2D
var _outer_shoe: Sprite2D


func _ready() -> void:
	_initialize_visuals()


func _initialize_visuals() -> void:
	if not _resolve_rig():
		return

	_inner_pants = _create_pants_mesh(
		"InnerFlexiblePants", inner_pants_texture, inner_pants_z_index
	)
	_outer_pants = _create_pants_mesh(
		"OuterFlexiblePants", outer_pants_texture, outer_pants_z_index
	)
	_inner_shoe = _create_shoe("InnerRigidShoe", inner_shoe_z_index)
	_outer_shoe = _create_shoe("OuterRigidShoe", outer_shoe_z_index)

	_update_visuals()


func _process(_delta: float) -> void:
	if not is_instance_valid(_inner_pants):
		_initialize_visuals()
	_update_visuals()


func _resolve_rig() -> bool:
	_inner_upper = get_node_or_null(inner_upper_path) as Node2D
	_inner_lower = get_node_or_null(inner_lower_path) as Node2D
	_inner_foot = get_node_or_null(inner_foot_path) as Node2D
	_outer_upper = get_node_or_null(outer_upper_path) as Node2D
	_outer_lower = get_node_or_null(outer_lower_path) as Node2D
	_outer_foot = get_node_or_null(outer_foot_path) as Node2D
	return (
		is_instance_valid(_inner_upper)
		and is_instance_valid(_inner_lower)
		and is_instance_valid(_inner_foot)
		and is_instance_valid(_outer_upper)
		and is_instance_valid(_outer_lower)
		and is_instance_valid(_outer_foot)
	)


func _create_pants_mesh(node_name: String, texture: Texture2D, draw_z: int) -> MeshInstance2D:
	var mesh_instance := get_node_or_null(NodePath(node_name)) as MeshInstance2D
	if mesh_instance == null:
		mesh_instance = MeshInstance2D.new()
		mesh_instance.name = node_name
		add_child(mesh_instance, false, Node.INTERNAL_MODE_BACK)
	mesh_instance.name = node_name
	mesh_instance.texture = texture
	if not mesh_instance.mesh is ArrayMesh:
		mesh_instance.mesh = ArrayMesh.new()
	mesh_instance.z_index = draw_z
	return mesh_instance


func _create_shoe(node_name: String, draw_z: int) -> Sprite2D:
	var shoe := get_node_or_null(NodePath(node_name)) as Sprite2D
	if shoe == null:
		shoe = Sprite2D.new()
		shoe.name = node_name
		add_child(shoe, false, Node.INTERNAL_MODE_BACK)
	shoe.texture = shoe_texture
	shoe.z_index = draw_z
	return shoe


func _update_visuals() -> void:
	if not is_instance_valid(_inner_pants):
		return
	if not _resolve_rig():
		return

	_inner_pants.texture = inner_pants_texture
	_outer_pants.texture = outer_pants_texture
	_inner_pants.z_index = inner_pants_z_index
	_outer_pants.z_index = outer_pants_z_index
	_inner_shoe.texture = shoe_texture
	_outer_shoe.texture = shoe_texture
	_inner_shoe.z_index = inner_shoe_z_index
	_outer_shoe.z_index = outer_shoe_z_index

	_update_leg_mesh(_inner_pants.mesh as ArrayMesh, _inner_upper, _inner_lower, _inner_foot)
	_update_leg_mesh(_outer_pants.mesh as ArrayMesh, _outer_upper, _outer_lower, _outer_foot)

	_inner_shoe.transform = _inner_foot.transform * Transform2D(
		0.0, inner_shoe_scale, 0.0, inner_shoe_offset
	)
	_outer_shoe.transform = _outer_foot.transform * Transform2D(
		0.0, outer_shoe_scale, 0.0, outer_shoe_offset
	)


func _update_leg_mesh(mesh: ArrayMesh, upper: Node2D, lower: Node2D, foot: Node2D) -> void:
	var hip := upper.position
	var knee := lower.position
	var ankle := foot.position
	var lower_direction := (ankle - knee).normalized()
	if lower_direction.is_zero_approx():
		lower_direction = Vector2.DOWN

	var centers := PackedVector2Array([
		hip,
		hip.lerp(knee, 0.5),
		knee,
		knee.lerp(ankle, 0.5),
		ankle,
		ankle + lower_direction * hem_extension,
	])
	var width_scale := (
		absf(upper.scale.x) + absf(lower.scale.x) + absf(foot.scale.x)
	) / 2.4

	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for row: int in centers.size():
		var previous := centers[maxi(row - 1, 0)]
		var following := centers[mini(row + 1, centers.size() - 1)]
		var tangent := (following - previous).normalized()
		if tangent.is_zero_approx():
			tangent = Vector2.DOWN
		var normal := Vector2(-tangent.y, tangent.x)
		var half_width := 0.0
		if not pants_half_widths.is_empty():
			half_width = pants_half_widths[mini(row, pants_half_widths.size() - 1)] * width_scale
		for column: int in 3:
			var across := float(column - 1)
			var vertex := centers[row] + normal * half_width * across
			vertices.append(Vector3(vertex.x, vertex.y, 0.0))
			uvs.append(Vector2(float(column) * 0.5, float(row) / float(centers.size() - 1)))

	for row: int in centers.size() - 1:
		for column: int in 2:
			var top_left := row * 3 + column
			var top_right := top_left + 1
			var bottom_left := top_left + 3
			var bottom_right := bottom_left + 1
			indices.append_array(PackedInt32Array([
				top_left, bottom_left, top_right,
				top_right, bottom_left, bottom_right,
			]))

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
