@tool
class_name Viewport25D
extends Control

var zoom_level: int = 0
var is_panning: bool = false
var pan_center: Vector2
var viewport_center: Vector2
var view_mode_index: int = 0

var editor_interface: EditorInterface # Set in node25d_plugin.gd
var moving: bool = false

@onready var viewport_2d: SubViewport = $Viewport2D
@onready var viewport_overlay: SubViewport = $ViewportOverlay
# TODO: This can be cleaned up.
@onready var view_mode_button_group: ButtonGroup = (
	($"../TopBar/ViewModeButtons/45Degree" as BaseButton).button_group
)
@onready var zoom_label: Label = $"../TopBar/Zoom/ZoomPercent"
@onready var gizmo_25d_scene: PackedScene = preload(
	Gizmo25D.GIZMO_25D_TSCN_PATH
)


func _ready() -> void:
	# Give Godot a chance to fully load the scene. Should take two frames.
	for i: int in 2:
		await get_tree().process_frame

	var edited_scene_root: Node = get_tree().edited_scene_root
	if not edited_scene_root:
		# Godot hasn't finished loading yet, so try loading the plugin again.
		EditorInterface.set_plugin_enabled("node25d", false)
		EditorInterface.set_plugin_enabled("node25d", true)
		return

	var world_2d := EditorInterface.get_editor_viewport_2d().world_2d
	if world_2d == get_viewport().world_2d:
		# This is the MainScreen25D scene opened in the editor!
		return
	viewport_2d.world_2d = world_2d


func _process(_delta: float) -> void:
	if not editor_interface:
		# Something's not right... bail!
		return


func _handle_viewport_input() -> void:
	# View mode polling.
	var view_mode_changed_this_frame: bool = false
	var new_view_mode := -1

	if view_mode_button_group.get_pressed_button():
		new_view_mode = view_mode_button_group.get_pressed_button().get_index()
	if view_mode_index != new_view_mode:
		view_mode_index = new_view_mode
		view_mode_changed_this_frame = true
		_recursive_change_view_mode(get_tree().edited_scene_root)

	# Zooming.
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_WHEEL_UP):
		zoom_level += 1
	elif Input.is_mouse_button_pressed(MOUSE_BUTTON_WHEEL_DOWN):
		zoom_level -= 1
	var zoom := _get_zoom_amount()

	# SubViewport size.
	var vp_size := get_global_rect().size
	viewport_2d.size = vp_size
	viewport_overlay.size = vp_size

	# SubViewport transform.
	var viewport_trans := Transform2D.IDENTITY
	viewport_trans.x *= zoom
	viewport_trans.y *= zoom
	viewport_trans.origin = (
		viewport_trans.basis_xform(viewport_center) + size / 2
	)
	viewport_2d.canvas_transform = viewport_trans
	viewport_overlay.canvas_transform = viewport_trans

	# Delete unused gizmos.
	var selection := EditorInterface.get_selection().get_selected_nodes()
	var gizmos: Array[Gizmo25D] = []
	for node: Node in viewport_overlay.get_children():
		if node is Gizmo25D:
			var gizmo := node as Gizmo25D
			var contains: bool = false
			for selected: Node in selection:
				if (
					selected == gizmo.node_25d
					and not view_mode_changed_this_frame
				):
					contains = true
			if not contains:
				gizmo.queue_free()

	# Add new gizmos.
	for selected: Node in selection:
		if selected is Node25D:
			_ensure_node25d_has_gizmo(selected as Node25D, gizmos)

	# Update gizmo zoom.
	for gizmo in gizmos:
		gizmo.set_zoom(zoom)


func _ensure_node25d_has_gizmo(node: Node25D, gizmos: Array[Gizmo25D]) -> void:
	for gizmo: Gizmo25D in gizmos:
		if node == gizmo.node_25d:
			return

	var gizmo := gizmo_25d_scene.instantiate() as Gizmo25D
	viewport_overlay.add_child(gizmo)
	gizmo.setup(node)


# This only accepts input when the mouse is inside of the 2.5D viewport.
func _gui_input(input_event: InputEvent) -> void:
	if input_event is InputEventMouseButton:
		var mouse_event := input_event as InputEventMouseButton
		if mouse_event.is_pressed():
			if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
				zoom_level += 1
				accept_event()

			elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				zoom_level -= 1
				accept_event()

			elif mouse_event.button_index == MOUSE_BUTTON_MIDDLE:
				is_panning = true
				pan_center = (
					viewport_center - mouse_event.position / _get_zoom_amount()
				)
				accept_event()

			elif mouse_event.button_index == MOUSE_BUTTON_LEFT:
				var overlay_children := viewport_overlay.get_children()
				for overlay_child: Variant in overlay_children:
					overlay_child.wants_to_move = true
				accept_event()

		elif mouse_event.button_index == MOUSE_BUTTON_MIDDLE:
			is_panning = false
			accept_event()

		elif mouse_event.button_index == MOUSE_BUTTON_LEFT:
			var overlay_children := viewport_overlay.get_children()
			for overlay_child: Variant in overlay_children:
				overlay_child.wants_to_move = false
			accept_event()

	elif input_event is InputEventMouseMotion:
		var motion_event := input_event as InputEventMouseMotion
		if is_panning:
			viewport_center = (
				pan_center + motion_event.position / _get_zoom_amount()
			)
			accept_event()


func _recursive_change_view_mode(current_node: Node) -> void:
	if not current_node:
		return

	if current_node is Node25D:
		(current_node as Node25D).set_view_mode(view_mode_index)

	for child: Node in current_node.get_children():
		_recursive_change_view_mode(child)


func _get_zoom_amount() -> float:
	const THIRTEENTH_ROOT_OF_2 = 1.05476607648
	var zoom_amount := pow(THIRTEENTH_ROOT_OF_2, zoom_level)
	zoom_label.text = str(round(zoom_amount * 1000) / 10) + "%"
	return zoom_amount


func _on_ZoomOut_pressed() -> void:
	zoom_level -= 1


func _on_ZoomIn_pressed() -> void:
	zoom_level += 1


func _on_ZoomReset_pressed() -> void:
	zoom_level = 0
