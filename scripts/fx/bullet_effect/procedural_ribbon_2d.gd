@tool
extends MeshInstance2D
class_name ProceduralRibbon2D

## 只在初始化或参数变化时构建；运行时动画全部交给 CanvasItem Shader。
@export_range(8, 256, 1) var segment_count := 112


func build_ribbon(max_length:float, max_half_width:float, segments_override:int = -1) -> void:
	var segments := segment_count if segments_override <= 0 else segments_override
	segments = maxi(segments, 8)
	var vertices := PackedVector2Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	vertices.resize((segments + 1) * 2)
	uvs.resize((segments + 1) * 2)

	for segment_index in range(segments + 1):
		var u := float(segment_index) / float(segments)
		var vertex_index := segment_index * 2
		## 基础顶点覆盖最大包围盒，shader 会用 UV 完全重算最终位置。
		vertices[vertex_index] = Vector2(max_length * u, -max_half_width)
		vertices[vertex_index + 1] = Vector2(max_length * u, max_half_width)
		uvs[vertex_index] = Vector2(u, 0.0)
		uvs[vertex_index + 1] = Vector2(u, 1.0)

	for segment_index in range(segments):
		var vertex_index := segment_index * 2
		indices.append_array(PackedInt32Array([
			vertex_index,
			vertex_index + 1,
			vertex_index + 2,
			vertex_index + 2,
			vertex_index + 1,
			vertex_index + 3,
		]))

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var ribbon_mesh := ArrayMesh.new()
	ribbon_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = ribbon_mesh
