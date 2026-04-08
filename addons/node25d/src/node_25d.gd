@tool
@icon("res://addons/node25d/icons/node_25d.svg")
class_name Node25D
extends Node2D
## A [Node2D] in a trenchcoat that converts a child [Node3D] position
## into 2D using a [b]2.5D basis transform[/b].
##
## Converts a 3D child position into 2D using a 2.5D basis transform.
## Requires the first child to be a Node3D for spatial math; add a Sprite2D
## or other Node2D child to render the object.

enum ViewMode {
	DEGREES_45,
	ISOMETRIC,
	TOP_DOWN,
	FRONT_SIDE,
	OBLIQUE_Y,
	OBLIQUE_Z,
}

## Equal axis for 45 degree angles, used in some of the view modes.
const INV_SQRT_2: float = 0.70710678118
## Cosine of 30 degrees, used for the isometric view mode basis.
const HALF_SQRT_3: float = 0.86602540378

## Exported spatial position for editor usage.
@export var spatial_position: Vector3:
	get = get_spatial_position,
	set = set_spatial_position

@export_group("2D to 3D Calculations")

## Number of [b]2D units[/b] in one [b]3D unit[/b].
## It's recommended to use Integer values.
@export_range(1, 100, 1.0) var unit_scale: float = 32
## The [enum ViewMode] that determines how the 3D position is converted to 2D.
@export var view_mode := ViewMode.TOP_DOWN:
	set = set_view_mode

# GDScript throws errors when Basis25D is its own structure.
# There is a broken implementation in a hidden folder.
#
# (Update: I just removed the broken implementation, not sure the point lol.)
#
# https://github.com/godotengine/godot/issues/21461
# https://github.com/godotengine/godot-proposals/issues/279

var _basis_x: Vector2
var _basis_y: Vector2
var _basis_z: Vector2

# Cache the spatial stuff for internal use.
var _spatial_position: Vector3
var _spatial_node: Node3D

func _init() -> void:
	set_view_mode(view_mode)
	child_order_changed.connect(_update_spatial_node)
	ready.connect(_update_spatial_node)


func _process(_delta: float) -> void:
		update_spatial_positioning()


# Call this method in _process, or whenever the position of this object changes.
func update_spatial_positioning() -> void:
	if _spatial_node == null:
		return

	# Update positions.
	set_spatial_position(_spatial_node.position)
	global_position = spatial_to_flat(_spatial_position)


## Convert spatial position to flat 2D position using the Node25D basis.
func spatial_to_flat(spatial_pos: Vector3) -> Vector2:
	var flat_pos: Vector2 = spatial_pos.x * _basis_x
	flat_pos += spatial_pos.y * _basis_y
	flat_pos += spatial_pos.z * _basis_z
	return flat_pos


func get_basis() -> Array[Vector2]:
	return [_basis_x, _basis_y, _basis_z]


func get_spatial_position() -> Vector3:
	return _spatial_node.position if _spatial_node else Vector3.ZERO


func set_spatial_position(value: Vector3) -> void:
	_spatial_position = value
	if _spatial_node:
		_spatial_node.position = value


## Change the basis based on the [ViewMode] enum.
## This will change how the 3D position is converted to 2D
# TODO: Move this to a Node25Basis class.
func set_view_mode(new_view_mode: ViewMode) -> void:
	view_mode = new_view_mode
	match view_mode:
		# 45 Degrees
		ViewMode.DEGREES_45:
			_basis_x = unit_scale * Vector2(1, 0)
			_basis_y = unit_scale * Vector2(0, -INV_SQRT_2)
			_basis_z = unit_scale * Vector2(0, INV_SQRT_2)

		# Isometric
		ViewMode.ISOMETRIC:
			_basis_x = unit_scale * Vector2(HALF_SQRT_3, 0.5)
			_basis_y = unit_scale * Vector2(0, -1)
			_basis_z = unit_scale * Vector2(-HALF_SQRT_3, 0.5)


		# Front Side
		ViewMode.FRONT_SIDE:
			_basis_x = unit_scale * Vector2(1, 0)
			_basis_y = unit_scale * Vector2(0, -1)
			_basis_z = unit_scale * Vector2(0, 0)

		# Oblique Y
		ViewMode.OBLIQUE_Y:
			_basis_x = unit_scale * Vector2(1, 0)
			_basis_y = unit_scale * Vector2(-INV_SQRT_2, -INV_SQRT_2)
			_basis_z = unit_scale * Vector2(0, 1)

		# Oblique Z
		ViewMode.OBLIQUE_Z:
			_basis_x = unit_scale * Vector2(1, 0)
			_basis_y = unit_scale * Vector2(0, -1)
			_basis_z = unit_scale * Vector2(-INV_SQRT_2, INV_SQRT_2)

		# Top Down
		ViewMode.TOP_DOWN, _:
			_basis_x = unit_scale * Vector2(1, 0)
			_basis_y = unit_scale * Vector2(0, 0)
			_basis_z = unit_scale * Vector2(0, 1)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	var child_count := get_child_count(false)

	# Ensure required nodes are present and setup.
	if child_count == 0:
		warnings.append("A Node25D must have a child Node3D to function.")
	elif child_count == 1:
		warnings.append("No second node found, so nothing will be rendered.")

	# Ensure child nodes are correct types.
	if child_count >= 1 and get_child(0) is not Node3D:
		warnings.append("First child node must inherit from Node3D.")
	if child_count >= 2 and get_child(1) is not Node2D:
		warnings.append("Second child node must inherit from Node2D.")

	return warnings


func _update_spatial_node() -> void:
	if get_child_count() > 0:
		_spatial_node = get_child(0) as Node3D


# Used by YSort25D
static func y_sort(a: Node25D, b: Node25D) -> bool:
	return a._spatial_position.y < b._spatial_position.y


static func y_sort_slight_xz(a: Node25D, b: Node25D) -> bool:
	var a_xz_spatial := a._spatial_position.x + a._spatial_position.z
	var a_index := a._spatial_position.y + 0.001 * a_xz_spatial

	var b_xz_spatial := b._spatial_position.x + b._spatial_position.z
	var b_index := b._spatial_position.y + 0.001 * b_xz_spatial

	return a_index < b_index
