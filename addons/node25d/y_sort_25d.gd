@tool
@icon("res://addons/node25d/icons/y_sort_25d.svg")
class_name YSort25D
extends Node # NOTE: NOT Node2D or Node25D.
## Sorts all Node25D children of its parent.
##
## This is different from the C# version of this project
## because the execution order is different and otherwise
## sorting is delayed by one frame.

## Whether or not to automatically call sort() in _process().
@export var sort_enabled: bool = true
var _parent_node: Node2D # NOT Node25D


func _ready() -> void:
	_parent_node = get_parent()


func _process(_delta: float) -> void:
	if sort_enabled:
		sort()


# Call this method in _process, or whenever you want to sort children.
func sort() -> void:
	if _parent_node == null:
		# _ready() hasn't been run yet
		return

	var parent_children: Array[Node] = _parent_node.get_children()
	if parent_children.size() > 4000:
		# The Z index only goes from -4096 to 4096, and we want room for
		# objects having multiple layers.
		printerr("Sorting failed: Max number of YSort25D nodes is 4000.")
		return

	# We only want to get Node25D children.
	# Currently, it also grabs Node2D children.
	var node25d_nodes: Array[Node25D] = []
	for n: Node in parent_children:
		if n is Node25D:
			node25d_nodes.append(n)
	node25d_nodes.sort_custom(Node25D.y_sort_slight_xz)

	var z_index: int = -4000
	for i: int in range(0, node25d_nodes.size()):
		node25d_nodes[i].z_index = z_index
		# Increment by 2 each time, to allow for shadows in-between.
		# This does mean that we have a limit of 4000 total sorted Node25Ds.
		z_index += 2
