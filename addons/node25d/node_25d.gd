@tool
@icon("res://addons/node25d/icons/node_25d.svg")
class_name Node25D
extends Node2D
## A [Node2D] that converts a [Node3D] child position into 2D using
## a 2.5D basis transform.
##
## Converts a 3D child position into 2D using a 2.5D basis transform.
## Requires the first child to be a Node3D for spatial math; add a Sprite2D
## or other Node2D child to render the object.

## The number of 2D units in one 3D unit.
## Ideally, but not necessarily, an integer.
const SCALE: int = 32
## Equal axis for 45 degree angles, used in some of the view modes.
const INV_SQRT_2: float = 0.70710678118
## Cosine of 30 degrees, used for the isometric view mode basis.
const HALF_SQRT_3: float = 0.86602540378

# Exported spatial position for editor usage.
@export var spatial_position: Vector3:
	get = get_spatial_position,
	set = set_spatial_position

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


# These are separated in case anyone wishes to easily extend Node25D.
func _ready() -> void:
	node25d_ready()


func _process(_delta: float) -> void:
	node25d_process()


# Call this method in _ready, or before node25d_process is first ran.
func node25d_ready() -> void:
	_update_spatial_node()
	child_order_changed.connect(_update_spatial_node)

	_basis_x = SCALE * Vector2(1, 0)
	_basis_y = SCALE * Vector2(0, -INV_SQRT_2)
	_basis_z = SCALE * Vector2(0, INV_SQRT_2)


# Call this method in _process, or whenever the position of this object changes.
func node25d_process() -> void:
	if _spatial_node == null:
		return

	set_spatial_position(_spatial_node.position)

	var flat_pos: Vector2 = _spatial_position.x * _basis_x
	flat_pos += _spatial_position.y * _basis_y
	flat_pos += _spatial_position.z * _basis_z

	global_position = flat_pos


func get_basis() -> Array[Vector2]:
	return [_basis_x, _basis_y, _basis_z]


func get_spatial_position() -> Vector3:
	return _spatial_node.position if _spatial_node else Vector3.ZERO


func set_spatial_position(value: Vector3) -> void:
	_spatial_position = value
	if _spatial_node:
		_spatial_node.position = value


## Change the basis based on the view_mode_index argument.
## This can be changed or removed in actual games where you only need
## one view mode.
func set_view_mode(view_mode_index: int) -> void:
	# TODO: This can be moved out of this class.
	match view_mode_index:
		0: # 45 Degrees
			_basis_x = SCALE * Vector2(1, 0)
			_basis_y = SCALE * Vector2(0, -INV_SQRT_2)
			_basis_z = SCALE * Vector2(0, INV_SQRT_2)
		1: # Isometric
			_basis_x = SCALE * Vector2(HALF_SQRT_3, 0.5)
			_basis_y = SCALE * Vector2(0, -1)
			_basis_z = SCALE * Vector2(-HALF_SQRT_3, 0.5)
		2: # Top Down
			_basis_x = SCALE * Vector2(1, 0)
			_basis_y = SCALE * Vector2(0, 0)
			_basis_z = SCALE * Vector2(0, 1)
		3: # Front Side
			_basis_x = SCALE * Vector2(1, 0)
			_basis_y = SCALE * Vector2(0, -1)
			_basis_z = SCALE * Vector2(0, 0)
		4: # Oblique Y
			_basis_x = SCALE * Vector2(1, 0)
			_basis_y = SCALE * Vector2(-INV_SQRT_2, -INV_SQRT_2)
			_basis_z = SCALE * Vector2(0, 1)
		5: # Oblique Z
			_basis_x = SCALE * Vector2(1, 0)
			_basis_y = SCALE * Vector2(0, -1)
			_basis_z = SCALE * Vector2(-INV_SQRT_2, INV_SQRT_2)


func _get_configuration_warnings() -> PackedStringArray:
	if get_child_count() == 0:
		return ["A Node25D must have a child Node3D to function."]

	var warnings: PackedStringArray = []
	if get_child(0) is not Node3D:
		warnings.append("The first child of a Node25D must be a Node3D.")

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
