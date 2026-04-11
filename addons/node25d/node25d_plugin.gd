@tool
class_name Node25DPlugin
extends EditorPlugin

# TODO: Clean this up, I really don't like these hard-coded paths.
#       However I've been having even more issues with UIDs as well...
const PATH_PREFIX := "res://addons/node25d/"
const MAIN_SCREEN_TSCN_PATH := PATH_PREFIX + "editor/main_screen_25d.tscn"

const EDITOR_SETTINGS_PREFIX := "node25d"

const MainPanel: PackedScene = preload(MAIN_SCREEN_TSCN_PATH)

var main_panel_instance: VBoxContainer

## If the plugin should also handle children of Node25D nodes.
## This will be toggled in the plugin settings later.
var handles_node25d_children: bool = true


func _enter_tree() -> void:
	# Create main panel.
	main_panel_instance = MainPanel.instantiate()
	var viewport_25d: Viewport25D = main_panel_instance.get_child(1)
	assert(
		viewport_25d != null, "Failed to get Viewport25D from MainPanel scene."
	)
	assert(
		get_editor_interface() != null,
		"Editor interface is null in _enter_tree."
	)
	viewport_25d.editor_interface = get_editor_interface()
	assert(
		viewport_25d.editor_interface == get_editor_interface(),
		"Failed to set editor interface on Viewport25D."
	)

	# Add the main panel to the editor's main viewport.
	var editor_main_screen := EditorInterface.get_editor_main_screen()
	editor_main_screen.add_child(main_panel_instance)

	# Move between 2D and 3D buttons.
	# ? Why doesn't this change the order? Are the main buttons hardcoded?
	# editor_main_screen.move_child(main_panel_instance, 0)
	_make_visible(false)
	_enable_custom_types()


func _exit_tree() -> void:
	if main_panel_instance:
		main_panel_instance.queue_free()
	_disable_custom_types()


func _enable_custom_types() -> void:
	# When this plugin node enters tree, add the custom types.
	# ? What is the purpose of this? Is this older Godot code?
	add_custom_type(
		"Node25D",
		"Node2D",
		preload("src/node_25d.gd"),
		preload("icons/node_25d.svg")
	)
	add_custom_type(
		"YSort25D",
		"Node",
		preload("src/y_sort_25d.gd"),
		preload("icons/y_sort_25d.svg")
	)
	add_custom_type(
		"ShadowMath25D",
		"CharacterBody3D",
		preload("src/shadow_math_25d.gd"),
		preload("icons/shadow_math_25d.svg")
	)


func _disable_custom_types() -> void:
	# When the plugin node exits the tree, remove the custom types.
	remove_custom_type("ShadowMath25D")
	remove_custom_type("YSort25D")
	remove_custom_type("Node25D")


func _has_main_screen() -> bool:
	return true


func _make_visible(visible: bool) -> void:
	if main_panel_instance:
		if visible:
			main_panel_instance.show()
		else:
			main_panel_instance.hide()


func _get_plugin_name() -> String:
	return "2.5D"


func _get_plugin_icon() -> Texture2D:
	return preload("res://addons/node25d/icons/viewport_25d.svg")


func _handles(obj: Object) -> bool:
	if obj is Node:
		var node_obj := obj as Node
		return (
			node_obj is Node25D
			or (
				Node25D.has_node25d_parent(node_obj)
				if handles_node25d_children
				else false
			)
		)
	return false


## Helper function to get or set an editor setting for this plugin.
## If the setting doesn't exist, it will be created with the
## provided default value.
static func get_or_set_editor_setting(
	category_name: String, setting_name: String, default_value: Variant
) -> Variant:
	var editor_settings := EditorInterface.get_editor_settings()
	var full_setting_path := (
		("%s/%s/%s" % [EDITOR_SETTINGS_PREFIX, category_name, setting_name])
		. simplify_path()
	)
	if not editor_settings.has_setting(full_setting_path):
		editor_settings.set_setting(full_setting_path, default_value)
		editor_settings.set_initial_value(
			full_setting_path, default_value, false
		)
	return editor_settings.get_setting(full_setting_path)
