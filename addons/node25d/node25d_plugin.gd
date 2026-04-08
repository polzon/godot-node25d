@tool
extends EditorPlugin

# TODO: Clean this up, I really don't like these hard-coded paths.
#       However I've been having even more issues with UIDs as well...
const PATH_PREFIX := "res://addons/node25d/"
const MAIN_SCREEN_TSCN_PATH := PATH_PREFIX + "editor/main_screen_25d.tscn"

const MainPanel: PackedScene = preload(MAIN_SCREEN_TSCN_PATH)

var main_panel_instance: VBoxContainer


func _enter_tree() -> void:
	# Create main panel.
	main_panel_instance = MainPanel.instantiate()
	var viewport_25d := main_panel_instance.get_child(1) as Viewport25D
	assert(
		viewport_25d != null, "Failed to get Viewport25D from MainPanel scene."
	)
	viewport_25d.editor_interface = get_editor_interface()

	# Add the main panel to the editor's main viewport.
	var editor_main_screen := EditorInterface.get_editor_main_screen()
	editor_main_screen.add_child(main_panel_instance)

	# Move between 2D and 3D buttons.
	# ? Why doesn't this change the order? Are the main buttons hardcoded?
	editor_main_screen.move_child(main_panel_instance, 0)

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
	return obj is Node25D
