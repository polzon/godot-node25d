@tool
class_name Gizmo25D
extends Node2D

const GIZMO_25D_TSCN_PATH := "res://addons/node25d/editor/gizmo_25d.tscn"

# If the mouse is farther than this many pixels, it won't grab anything.
const DEADZONE_RADIUS = 20.0
const DEADZONE_RADIUS_SQ = DEADZONE_RADIUS * DEADZONE_RADIUS
# Not pixel perfect for all axes in all modes, but works well enough.
# Rounding is not done until after the movement is finished.
const ROUGHLY_ROUND_TO_PIXELS = true
## Fallback unit scale if we cannot get a valid value from [member node_25d].
const DEFAULT_UNIT_SCALE: float = 32.0

#region Editor Debug Settings
var debug_print_setup: bool:
	get():
		return Node25DPlugin.get_or_set_editor_setting(
			"gizmo_25d", "debug/enable_print_setup", false
		)
var debug_print_mouse_movement: bool:
	get():
		return Node25DPlugin.get_or_set_editor_setting(
			"gizmo_25d", "debug/enable_print_mouse_movement", false
		)
var debug_print_axis_dominance: bool:
	get():
		return Node25DPlugin.get_or_set_editor_setting(
			"gizmo_25d", "debug/enable_print_axis_dominance", false
		)
var debug_print_line_points: bool:
	get():
		return Node25DPlugin.get_or_set_editor_setting(
			"gizmo_25d", "debug/enable_print_line_points", false
		)
#endregion Editor Debug Settings

# Input from Viewport25D, represents if the mouse is clicked.
var wants_to_move: bool = false

# Set when the node is created.
var node_25d: Node25D

var _spatial_node: Node3D
var _mesh_wireframe_display: MeshWireframeDisplay

# Used to control the state of movement.
var _moving: bool = false
var _start_mouse_position := Vector2.ZERO
var _start_spatial_origin := Vector3.ZERO

# Stores state of closest or currently used axis.
var _dominant_axis: int = -1

@onready var _lines: Array[Line2D] = [$X, $Y, $Z]
@onready var _viewport_overlay: SubViewport = get_parent()
# ! Not sure if this is the correct node?
@onready var _viewport_25d_bg: SubViewport = (
	_viewport_overlay.get_parent().get_child(1) as SubViewport
)


func _process(_delta: float) -> void:
	if not _lines:
		# Somehow this node hasn't been set up yet.
		if debug_print_setup:
			push_warning("Lines not set up yet.")
		return

	if not node_25d or not _viewport_25d_bg:
		assert(node_25d, "Gizmo25D is missing node_25d.")
		assert(_viewport_25d_bg, "Gizmo25D is missing _viewport_25d_bg.")
		if debug_print_setup:
			push_warning("Node25D or viewport not set up yet.")
		return

	global_position = node_25d.global_position

	# While getting the mouse position works in any viewport, it doesn't do
	# anything significant unless the mouse is in the 2.5D viewport.
	var mouse_position: Vector2 = _viewport_25d_bg.get_mouse_position()
	var full_transform: Transform2D = (
		_viewport_overlay.canvas_transform * global_transform
	)
	mouse_position = full_transform.affine_inverse() * mouse_position
	if not _moving:
		determine_dominant_axis(mouse_position)
		if _dominant_axis == -1:
			if debug_print_axis_dominance:
				push_warning("Not hovering over any axis.")
			# If we're not hovering over a line, nothing to do.
			return
		if debug_print_axis_dominance:
			print("Hovering over axis %d." % _dominant_axis)
	_lines[_dominant_axis].modulate.a = 1

	# When we've stopped moving the gizmo.
	if not wants_to_move:
		if _moving:
			# When we're done moving, ensure the inspector is updated.
			node_25d.notify_property_list_changed()
			_moving = false
			if debug_print_mouse_movement:
				print("Stopped moving gizmo.")
		return

	# Finally, move the gizmo.
	if not _moving:
		_moving = true
		_start_mouse_position = mouse_position
		_start_spatial_origin = _spatial_node.transform.origin
		if debug_print_mouse_movement:
			print("Started moving gizmo.")

	# By this point, we are moving.
	move_using_mouse(mouse_position)
	if debug_print_axis_dominance:
		print("Moving gizmo along axis %d." % _dominant_axis)


func determine_dominant_axis(mouse_position: Vector2) -> void:
	var closest_distance := DEADZONE_RADIUS
	_dominant_axis = -1
	for i in range(3):
		_lines[i].modulate.a = 0.8  # Unrelated, but needs a loop too.
		var distance := _distance_to_segment_at_index(i, mouse_position)
		if distance < closest_distance:
			closest_distance = distance
			_dominant_axis = i
	if debug_print_axis_dominance and _dominant_axis == -1:
		printerr(
			"Failed to find a dominant axis. Mouse position: ", mouse_position
		)


func move_using_mouse(mouse_position: Vector2) -> void:
	# Change modulate of unselected axes.
	_lines[(_dominant_axis + 1) % 3].modulate.a = 0.5
	_lines[(_dominant_axis + 2) % 3].modulate.a = 0.5

	# Calculate movement.
	var mouse_diff: Vector2 = mouse_position - _start_mouse_position
	var line_end_point: Vector2 = _lines[_dominant_axis].points[1]
	var projected_diff: Vector2 = mouse_diff.project(line_end_point)
	var movement: float = (
		projected_diff.length() * global_scale.x / get_unit_scale()
	)
	if is_equal_approx(PI, projected_diff.angle_to(line_end_point)):
		movement *= -1

	# Apply movement.
	var move_dir_3d: Vector3 = _spatial_node.transform.basis[_dominant_axis]
	_spatial_node.transform.origin = (
		_start_spatial_origin + move_dir_3d * movement
	)
	if debug_print_mouse_movement:
		print(
			"Mouse diff: ",
			mouse_diff,
			" Projected diff: ",
			projected_diff,
			" Movement: ",
			movement
		)
	_snap_spatial_position()

	# Move the gizmo appropriately.
	global_position = node_25d.global_position


# Setup after _ready due to the onready vars, called manually in Viewport25D.gd.
# Sets up the points based on the basis values of the Node25D.
func setup(in_node_25d: Node25D) -> void:
	node_25d = in_node_25d
	var basis := node_25d.get_basis()
	for i: int in range(3):
		_lines[i].points[1] = basis[i] * 3
	global_position = node_25d.global_position
	_spatial_node = node_25d.get_child(0)
	_mesh_wireframe_display = MeshWireframeDisplay.new(self)
	if debug_print_setup:
		print("Gizmo25D setup complete.")


func set_zoom(zoom: float) -> void:
	var new_scale: float = EditorInterface.get_editor_scale() / zoom
	global_scale = Vector2(new_scale, new_scale)


func get_unit_scale() -> float:
	return (
		node_25d.unit_scale
		if node_25d and node_25d.unit_scale > 0
		else DEFAULT_UNIT_SCALE
	)


func _snap_spatial_position(
	step_meters: float = 1.0 / get_unit_scale()
) -> void:
	var scaled_px: Vector3 = _spatial_node.transform.origin / step_meters
	_spatial_node.transform.origin = scaled_px.round() * step_meters


# Figures out if the mouse is very close to a segment. This method is
# specialized for this script, it assumes that each segment starts at
# (0, 0) and it provides a deadzone around the origin.
func _distance_to_segment_at_index(index: int, point: Vector2) -> float:
	if not _lines or point.length_squared() < DEADZONE_RADIUS_SQ:
		if debug_print_line_points:
			push_warning(
				"Lines not set up yet or point is in deadzone. Point: ", point
			)
		return INF

	var segment_end: Vector2 = _lines[index].points[1]
	var length_squared := segment_end.length_squared()
	if length_squared < DEADZONE_RADIUS_SQ:
		if debug_print_line_points:
			push_warning(
				"Line segment at index %d is too short to interact." % index
			)
		if debug_print_line_points:
			print(
				"Distance to segment at index %d: %f" % [index, point.length()]
			)
		return INF

	var t: float = clampf(point.dot(segment_end) / length_squared, 0, 1)
	var projection: Vector2 = t * segment_end
	if debug_print_line_points:
		print(
			(
				"Distance to segment at index %d: %f"
				% [index, point.distance_to(projection)]
			)
		)
	return point.distance_to(projection)
