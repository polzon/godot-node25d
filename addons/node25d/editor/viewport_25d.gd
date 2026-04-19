@tool
class_name Viewport25D
extends Control

# ! Currently breaks Viewport2D again when interacted with.

signal view_mode_changed(new_view_mode: int)

static var _debug_failed_find_attempts: int = 0

var enable_print_debug: bool:
	get():
		return Node25DPlugin.get_or_set_editor_setting(
			"viewport_25d", "debug/enable_print_debug", false
		)

var zoom_level: int = 0
var is_panning: bool = false
var pan_center: Vector2
var viewport_center: Vector2
var view_mode_index: int = 0

var editor_interface: EditorInterface  # Set in node25d_plugin.gd
var undo_redo: EditorUndoRedoManager
var moving: bool = false
var zoom: float = 1.0
var _last_mouse_position_viewport: Vector2 = Vector2.ZERO

var _view_mode_changed_this_frame: bool = false

var _touchpad_pan_enabled: bool:
	get():
		return Node25DPlugin.get_or_set_editor_setting(
			"viewport_25d", "input/touchpad_pan_enabled", false
		)

var _touchpad_wheel_pan_step: float:
	get():
		var pan_step_value: Variant = Node25DPlugin.get_or_set_editor_setting(
			"viewport_25d", "input/touchpad_wheel_pan_step", 40.0
		)
		if pan_step_value is float:
			return pan_step_value
		if pan_step_value is int:
			return pan_step_value
		return 40.0

var _touchpad_pan_invert: bool:
	get():
		return Node25DPlugin.get_or_set_editor_setting(
			"viewport_25d", "input/touchpad_pan_invert", true
		)

@onready var viewport_2d: SubViewport = %Viewport2D
@onready var viewport_overlay: SubViewport = %ViewportOverlay

@onready var view_mode_menu_button: MenuButton = %ViewModeMenu
@onready var view_mode_popup: PopupMenu = view_mode_menu_button.get_popup()

@onready var zoom_label: Label = %ZoomPercent
@onready var gizmo_25d_scene := preload(Gizmo25D.GIZMO_25D_TSCN_PATH)


func _ready() -> void:
	assert(is_inside_tree(), "ready() is called but not inside tree?")
	if not view_mode_popup.id_pressed.is_connected(_on_view_mode_selected):
		view_mode_popup.id_pressed.connect(_on_view_mode_selected)
	_sync_view_mode_controls(view_mode_index)

	const MAX_SCENE_ROOT_WAIT_FRAMES = 30
	var scene_root := await _wait_for_edited_scene_root(
		MAX_SCENE_ROOT_WAIT_FRAMES
	)
	if not scene_root:
		# Godot hasn't finished loading yet, so try loading the plugin again.
		EditorInterface.set_plugin_enabled("node25d", false)
		EditorInterface.set_plugin_enabled("node25d", true)
		if enable_print_debug:
			_debug_failed_find_attempts += 1
			push_warning(
				"Failed to find edited scene root. ",
				"Reloading plugin attempt #",
				_debug_failed_find_attempts
			)
		return

	var world_2d := EditorInterface.get_editor_viewport_2d().world_2d
	if world_2d == get_viewport().world_2d:
		# If the MainScene2D tscn scene if open in the editor.
		return
	viewport_2d.world_2d = world_2d


func _process(_delta: float) -> void:
	if not editor_interface:
		push_error("Editor interface is not set on Viewport25D. Aborting.")
		set_process(false)
	else:
		if not is_visible_in_tree():
			cancel_all_interactions()
			return
		_release_stale_interactions()
		_handle_viewport_input()


func _wait_for_edited_scene_root(max_wait_frames: int) -> Node:
	for _frame_idx: int in range(max_wait_frames):
		var current_tree: SceneTree = get_tree()
		if current_tree == null:
			return null

		var edited_scene_root: Node = current_tree.edited_scene_root
		if edited_scene_root != null:
			return edited_scene_root

		await current_tree.process_frame

	return null


func _handle_viewport_input() -> void:
	_view_mode_changed_this_frame = false
	_last_mouse_position_viewport = get_local_mouse_position()
	zoom = _get_zoom_amount()

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

	_update_gizmos()


func _on_view_mode_selected(item_id: int) -> void:
	_apply_view_mode(item_id)


func _apply_view_mode(new_view_mode: int) -> void:
	if new_view_mode < 0 or view_mode_index == new_view_mode:
		return

	view_mode_index = new_view_mode
	_view_mode_changed_this_frame = true
	view_mode_changed.emit(view_mode_index)
	_sync_view_mode_controls(view_mode_index)
	if enable_print_debug:
		print("View mode changed to index: ", view_mode_index)

	var scene_root: Node = get_tree().edited_scene_root
	assert(scene_root, "Scene root is null. This should never happen.")
	_recursive_change_view_mode(scene_root)


func _sync_view_mode_controls(selected_index: int) -> void:
	for item_index: int in range(view_mode_popup.item_count):
		view_mode_popup.set_item_checked(
			item_index,
			view_mode_popup.get_item_id(item_index) == selected_index
		)


func _ensure_node25d_has_gizmo(node: Node25D, gizmos: Array[Gizmo25D]) -> void:
	for gizmo: Gizmo25D in gizmos:
		if node == gizmo.node_25d:
			return

	var gizmo := gizmo_25d_scene.instantiate() as Gizmo25D
	viewport_overlay.add_child(gizmo)
	gizmo.undo_redo = undo_redo
	gizmo.setup(node)


# This only accepts input when the mouse is inside of the 2.5D viewport.
func _input(input_event: InputEvent) -> void:
	if not is_visible_in_tree():
		return

	if not (
		input_event is InputEventPanGesture
		or input_event is InputEventMouseButton
		or input_event is InputEventMouseMotion
	):
		return

	if not get_global_rect().has_point(get_global_mouse_position()):
		return

	if input_event is InputEventPanGesture:
		_handle_pan_gesture(input_event as InputEventPanGesture)
	elif input_event is InputEventMouseButton:
		_handle_mouse_button(input_event as InputEventMouseButton)
	elif input_event is InputEventMouseMotion:
		_handle_mouse_motion(input_event as InputEventMouseMotion)


func _handle_pan_gesture(pan_event: InputEventPanGesture) -> void:
	if not _touchpad_pan_enabled:
		return
	viewport_center += (
		_apply_touchpad_pan_invert(pan_event.delta) / _get_zoom_amount()
	)
	if enable_print_debug:
		print("Touchpad panning viewport to center:", viewport_center)
	get_viewport().set_input_as_handled()


func _handle_mouse_button(mouse_event: InputEventMouseButton) -> void:
	_last_mouse_position_viewport = mouse_event.position
	if mouse_event.is_pressed():
		_handle_mouse_button_pressed(mouse_event)
	else:
		_handle_mouse_button_released(mouse_event)


func _handle_mouse_button_pressed(
	mouse_event: InputEventMouseButton,
) -> void:
	match mouse_event.button_index:
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
			_handle_wheel_scroll(mouse_event)
		MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT:
			if _touchpad_pan_enabled:
				_pan_from_wheel(mouse_event)
				get_viewport().set_input_as_handled()
		MOUSE_BUTTON_MIDDLE:
			is_panning = true
			pan_center = (
				viewport_center - mouse_event.position / _get_zoom_amount()
			)
			get_viewport().set_input_as_handled()
		MOUSE_BUTTON_LEFT:
			_handle_left_click_pressed()


func _handle_mouse_button_released(
	mouse_event: InputEventMouseButton,
) -> void:
	match mouse_event.button_index:
		MOUSE_BUTTON_MIDDLE:
			is_panning = false
			if enable_print_debug:
				print("Stopped panning viewport.")
			get_viewport().set_input_as_handled()
		MOUSE_BUTTON_LEFT:
			_handle_left_click_released()


func _handle_wheel_scroll(mouse_event: InputEventMouseButton) -> void:
	if _should_pan_from_wheel(mouse_event):
		_pan_from_wheel(mouse_event)
	elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
		zoom_level += 1
	else:
		zoom_level -= 1
	get_viewport().set_input_as_handled()


func _handle_left_click_pressed() -> void:
	var gizmo := _get_first_gizmo_child_node()
	if gizmo and gizmo.can_start_move():
		if enable_print_debug:
			print("Wants to move gizmo along axis: ", gizmo._dominant_axis)
		gizmo.wants_to_move = true
		get_viewport().set_input_as_handled()
	elif enable_print_debug:
		push_warning("Failed to find a movable gizmo axis.")


func _handle_left_click_released() -> void:
	var gizmo := _get_first_gizmo_child_node()
	if gizmo:
		gizmo.wants_to_move = false
	if enable_print_debug:
		print("No longer wants to move gizmo.")
	if gizmo:
		get_viewport().set_input_as_handled()


func _handle_mouse_motion(motion_event: InputEventMouseMotion) -> void:
	_last_mouse_position_viewport = motion_event.position
	if is_panning:
		viewport_center = (
			pan_center + motion_event.position / _get_zoom_amount()
		)
		if enable_print_debug:
			print("Panning viewport to center:", viewport_center)
		get_viewport().set_input_as_handled()


func _should_pan_from_wheel(mouse_event: InputEventMouseButton) -> bool:
	if not _touchpad_pan_enabled:
		return false

	# Keep Ctrl + wheel available for explicit zoom with a touchpad.
	return not mouse_event.ctrl_pressed


func _pan_from_wheel(mouse_event: InputEventMouseButton) -> void:
	var pan_delta := Vector2.ZERO
	var pan_step := _touchpad_wheel_pan_step * mouse_event.factor

	if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
		pan_delta.y -= pan_step
	elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		pan_delta.y += pan_step
	elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_LEFT:
		pan_delta.x -= pan_step
	elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_RIGHT:
		pan_delta.x += pan_step

	# Shift + vertical wheel commonly represents horizontal touchpad scroll.
	if mouse_event.shift_pressed and pan_delta.y != 0.0:
		pan_delta.x = pan_delta.y
		pan_delta.y = 0.0

	viewport_center += (
		_apply_touchpad_pan_invert(pan_delta) / _get_zoom_amount()
	)
	if enable_print_debug:
		print("Wheel panning viewport to center:", viewport_center)


func _apply_touchpad_pan_invert(pan_delta: Vector2) -> Vector2:
	if _touchpad_pan_invert:
		return -pan_delta
	return pan_delta


func cancel_all_interactions() -> void:
	is_panning = false
	for overlay_child: Node in viewport_overlay.get_children():
		if overlay_child is Gizmo25D:
			(overlay_child as Gizmo25D).cancel_move()


func _release_stale_interactions() -> void:
	if is_panning and not Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		is_panning = false

	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		for overlay_child: Node in viewport_overlay.get_children():
			if overlay_child is Gizmo25D:
				(overlay_child as Gizmo25D).cancel_move()


func get_last_mouse_position_viewport() -> Vector2:
	return _last_mouse_position_viewport


func _recursive_change_view_mode(current_node: Node) -> void:
	if not current_node:
		return

	if current_node is Node25D:
		(current_node as Node25D).set_view_mode(view_mode_index)

	for child: Node in current_node.get_children():
		_recursive_change_view_mode(child)


func _update_gizmos() -> Array[Gizmo25D]:
	var selection := EditorInterface.get_selection().get_selected_nodes()
	var gizmos: Array[Gizmo25D] = []
	for node: Node in viewport_overlay.get_children():
		if node is Gizmo25D:
			var gizmo := node as Gizmo25D
			var contains: bool = false
			for selected: Node in selection:
				if (
					selected == gizmo.node_25d
					and not _view_mode_changed_this_frame
				):
					contains = true
			if not contains:
				# Delete unused gizmos.
				if enable_print_debug:
					print("Freed gizmo: %s" % gizmo.name)
				gizmo.queue_free()
			else:
				gizmos.append(gizmo)

	# Add new gizmos.
	for selected: Node in selection:
		if selected is Node25D:
			_ensure_node25d_has_gizmo(selected as Node25D, gizmos)

	# Update gizmo zoom.
	for gizmo in gizmos:
		gizmo.set_zoom(zoom)
	return gizmos


func _get_first_gizmo_child_node() -> Gizmo25D:
	for overlay_child: Node in viewport_overlay.get_children():
		if overlay_child is Gizmo25D:
			return overlay_child
	return null


func _get_zoom_amount() -> float:
	const THIRTEENTH_ROOT_OF_2 = 1.05476607648
	var zoom_amount := pow(THIRTEENTH_ROOT_OF_2, zoom_level)
	zoom_label.text = str(roundf(zoom_amount * 1000) / 10) + "%"
	return zoom_amount


func _on_ZoomOut_pressed() -> void:
	zoom_level -= 1


func _on_ZoomIn_pressed() -> void:
	zoom_level += 1


func _on_ZoomReset_pressed() -> void:
	zoom_level = 0
