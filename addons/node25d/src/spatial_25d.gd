@tool
class_name Spatial25D
extends Node25D
## Similar to [Node25D], but it instead has an internal 3D spatial node and
## only requires a [Node2D] child.


func _init() -> void:
	_spatial_node = Node3D.new()


func _ready() -> void:
	_spatial_node.name = "%s_Internal_SpatialNode" % name
	add_child(_spatial_node)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if get_child_count() == 0:
		warnings.append("Spatial25D requires a child Node2D to function.")
	elif not get_child(0) is Node2D:
		warnings.append("The first child of Spatial25D must be a Node2D.")
	return warnings
