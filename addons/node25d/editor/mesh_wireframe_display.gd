@tool
class_name MeshWireframeDisplay
extends RefCounted
## Draw tool to display a wireframe of a CollisionShape3D's shape in
## the 2.5D viewport, as part of Gizmo25D.

# ? We can probably convert this to a Node2D instead of creating _draw_host.

const WIREFRAME_COLOR: Color = Color(1, 1, 1, 0.45)
const WIREFRAME_WIDTH: float = 1.0

var _gizmo_25d: Gizmo25D
var _spatial_node: Node3D
var _node25d: Node25D
var _collision_shape: CollisionShape3D
var _viewport_overlay: SubViewport
var _draw_host: Node2D


func _init(parent_gizmo_25d: Gizmo25D) -> void:
	_gizmo_25d = parent_gizmo_25d
	if not _gizmo_25d:
		return

	_node25d = _gizmo_25d.node_25d
	_spatial_node = _gizmo_25d._spatial_node
	_viewport_overlay = _gizmo_25d.get_parent() as SubViewport
	_collision_shape = _find_collision_shape(_node25d)
	_draw_host = Node2D.new()
	_draw_host.name = "MeshWireframeDrawHost"
	_viewport_overlay.add_child(_draw_host)

	if not _draw_host.draw.is_connected(_on_draw_requested):
		_draw_host.draw.connect(_on_draw_requested)
	if not _gizmo_25d.tree_exiting.is_connected(_on_gizmo_tree_exiting):
		_gizmo_25d.tree_exiting.connect(_on_gizmo_tree_exiting)


func _on_draw_requested() -> void:
	if (
		not is_instance_valid(_gizmo_25d)
		or not is_instance_valid(_node25d)
		or not is_instance_valid(_spatial_node)
		or not is_instance_valid(_draw_host)
	):
		return

	if not is_instance_valid(_collision_shape):
		_collision_shape = _find_collision_shape(_node25d)
		if not _collision_shape:
			return

	var shape: Shape3D = _collision_shape.shape
	if not shape:
		return

	var debug_mesh: ArrayMesh = shape.get_debug_mesh()
	if not debug_mesh:
		return

	for surface_idx: int in range(debug_mesh.get_surface_count()):
		_draw_surface_wireframe(debug_mesh, surface_idx)


func _draw_surface_wireframe(mesh: Mesh, surface_idx: int) -> void:
	assert(mesh, "MeshWireframeDisplay expected a valid Mesh to draw.")
	var arrays: Array = mesh.surface_get_arrays(surface_idx)
	if (
		arrays.size() <= Mesh.ARRAY_VERTEX
		or arrays.is_empty()
		or arrays[Mesh.ARRAY_VERTEX] is not PackedVector3Array
	):
		return

	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if vertices.is_empty():
		return

	var indices := PackedInt32Array()
	if arrays.size() > Mesh.ARRAY_INDEX:
		if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
			var surface_indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			indices = surface_indices

	if indices.is_empty():
		for i: int in range(0, vertices.size() - 2, 3):
			_draw_triangle_edges(vertices[i], vertices[i + 1], vertices[i + 2])
		return

	for i: int in range(0, indices.size() - 2, 3):
		var index_a: int = indices[i]
		var index_b: int = indices[i + 1]
		var index_c: int = indices[i + 2]
		if (
			index_a < 0
			or index_b < 0
			or index_c < 0
			or index_a >= vertices.size()
			or index_b >= vertices.size()
			or index_c >= vertices.size()
		):
			continue

		_draw_triangle_edges(
			vertices[index_a], vertices[index_b], vertices[index_c]
		)


func _draw_triangle_edges(a: Vector3, b: Vector3, c: Vector3) -> void:
	_draw_world_line(a, b)
	_draw_world_line(b, c)
	_draw_world_line(c, a)


func _draw_world_line(from_local: Vector3, to_local: Vector3) -> void:
	var from_global: Vector3 = _collision_shape.global_transform * from_local
	var to_global: Vector3 = _collision_shape.global_transform * to_local

	var from_spatial_local: Vector3 = _spatial_node.to_local(from_global)
	var to_spatial_local: Vector3 = _spatial_node.to_local(to_global)

	# Convert from spatial-node local space into Node25D 3D space.
	var from_spatial: Vector3 = _spatial_node.transform * from_spatial_local
	var to_spatial: Vector3 = _spatial_node.transform * to_spatial_local

	var from_flat: Vector2 = _node25d.spatial_to_flat(from_spatial)
	var to_flat: Vector2 = _node25d.spatial_to_flat(to_spatial)

	_draw_host.draw_line(
		from_flat, to_flat, WIREFRAME_COLOR, WIREFRAME_WIDTH, false
	)


func _on_gizmo_tree_exiting() -> void:
	if is_instance_valid(_draw_host):
		_draw_host.queue_free()
	_draw_host = null


func _find_collision_shape(root: Node) -> CollisionShape3D:
	if root == null:
		return null
	if root is CollisionShape3D:
		return root as CollisionShape3D

	for child: Node in root.get_children():
		var collision_shape: CollisionShape3D = _find_collision_shape(child)
		if collision_shape:
			return collision_shape

	return null
