extends Window
# Parameter panel UI for gdParameterSync

signal parameter_changed(set_id: String, path: String, value: Variant)

var _set_id: String
var _parameter_widgets: Dictionary = {}  # path -> widget
var _parameter_sync: Node

@onready var main_container: VBoxContainer = VBoxContainer.new()
@onready var scroll_container: ScrollContainer = ScrollContainer.new()

func _ready():
	title = "Parameter Panel"
	size = Vector2i(300, 500)
	
	# Set up UI structure
	add_child(scroll_container)
	scroll_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll_container.add_child(main_container)
	main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func setup_for_parameter_set(set_id: String, param_sync: Node):
	"""Generate UI for a parameter set"""
	_set_id = set_id
	_parameter_sync = param_sync
	
	# Clear existing widgets
	if main_container:
		for child in main_container.get_children():
			child.queue_free()
	_parameter_widgets.clear()
	
	# Get parameter set description
	var description = param_sync.describe_set(set_id)
	if description.is_empty():
		return
	
	# Set window title
	title = description.get("label", set_id) + " Parameters"
	
	# Skip UI generation if running headless
	if DisplayServer.get_name() == "headless":
		print("Skipping UI generation in headless mode")
		return
	
	# Create header
	var header = Label.new()
	header.text = description.get("label", set_id)
	header.add_theme_style_override("normal", _create_header_style())
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_container.add_child(header)
	
	# Add separator
	var sep = HSeparator.new()
	main_container.add_child(sep)
	
	# Generate widgets for parameters
	_generate_widgets_for_structure(description.structure, "")
	
	print("Generated UI for %s with %d widgets" % [set_id, _parameter_widgets.size()])

func _generate_widgets_for_structure(structure: Dictionary, path_prefix: String):
	"""Recursively generate widgets for parameter structure"""
	
	# Add top-level parameters
	for param_info in structure.get("parameters", []):
		_create_parameter_widget(param_info, path_prefix)
	
	# Add groups
	for group_info in structure.get("groups", []):
		_create_group_widgets(group_info, path_prefix)

func _create_group_widgets(group_info: Dictionary, path_prefix: String):
	"""Create widgets for a parameter group"""
	var group_name = group_info.get("name", "")
	var new_prefix = path_prefix + "/" + group_name if path_prefix != "" else group_name
	
	# Create group header
	var group_label = Label.new()
	group_label.text = group_name
	group_label.add_theme_style_override("normal", _create_group_style())
	main_container.add_child(group_label)
	
	# Create container for group contents
	var group_container = VBoxContainer.new()
	group_container.add_theme_constant_override("separation", 2)
	main_container.add_child(group_container)
	
	# Add group parameters
	for param_info in group_info.get("parameters", []):
		var widget_container = _create_parameter_widget(param_info, new_prefix)
		if widget_container:
			group_container.add_child(widget_container)
	
	# Add nested groups
	for nested_group in group_info.get("groups", []):
		_create_group_widgets(nested_group, new_prefix)

func _create_parameter_widget(param_info: Dictionary, path_prefix: String) -> Control:
	"""Create a widget for a single parameter"""
	var param_name = param_info.get("name", "")
	var param_type = param_info.get("type", TYPE_FLOAT)
	var param_value = param_info.get("value", 0)
	var read_only = param_info.get("read_only", false)
	
	var full_path = path_prefix + "/" + param_name if path_prefix != "" else param_name
	
	# Create container for parameter
	var container = HBoxContainer.new()
	container.add_theme_constant_override("separation", 10)
	
	# Create label
	var label = Label.new()
	label.text = param_name + ":"
	label.custom_minimum_size.x = 100
	container.add_child(label)
	
	# Create appropriate widget based on type
	var widget: Control
	
	match param_type:
		TYPE_BOOL:
			widget = _create_bool_widget(param_value, read_only)
		TYPE_INT:
			widget = _create_int_widget(param_info, read_only)
		TYPE_FLOAT:
			widget = _create_float_widget(param_info, read_only)
		TYPE_STRING:
			widget = _create_string_widget(param_value, read_only)
		TYPE_COLOR:
			widget = _create_color_widget(param_value, read_only)
		TYPE_VECTOR2:
			widget = _create_vector2_widget(param_value, read_only)
		TYPE_VECTOR3:
			widget = _create_vector3_widget(param_value, read_only)
		_:
			widget = _create_string_widget(str(param_value), true)
	
	if widget:
		container.add_child(widget)
		_parameter_widgets[full_path] = widget
		
		# Connect change signal
		if not read_only:
			_connect_widget_signal(widget, full_path, param_type)
	
	main_container.add_child(container)
	return container

func _create_bool_widget(value: bool, read_only: bool) -> CheckBox:
	var checkbox = CheckBox.new()
	checkbox.button_pressed = value
	checkbox.disabled = read_only
	return checkbox

func _create_int_widget(param_info: Dictionary, read_only: bool) -> Control:
	var value = param_info.get("value", 0)
	var min_val = param_info.get("min_value", 0)
	var max_val = param_info.get("max_value", 100)
	
	var spinbox = SpinBox.new()
	spinbox.value = value
	spinbox.min_value = min_val
	spinbox.max_value = max_val
	spinbox.step = 1
	spinbox.editable = not read_only
	return spinbox

func _create_float_widget(param_info: Dictionary, read_only: bool) -> Control:
	var value = param_info.get("value", 0.0)
	var min_val = param_info.get("min_value", 0.0)
	var max_val = param_info.get("max_value", 1.0)
	var step_val = param_info.get("step", 0.01)
	
	var container = VBoxContainer.new()
	
	# Create slider for better UX
	var slider = HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = step_val
	slider.value = value
	slider.editable = not read_only
	slider.custom_minimum_size.x = 150
	
	# Create value label
	var value_label = Label.new()
	value_label.text = "%.3f" % value
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	container.add_child(slider)
	container.add_child(value_label)
	
	# Update label when slider changes
	slider.value_changed.connect(func(new_value): value_label.text = "%.3f" % new_value)
	
	return container

func _create_string_widget(value: String, read_only: bool) -> LineEdit:
	var line_edit = LineEdit.new()
	line_edit.text = value
	line_edit.editable = not read_only
	line_edit.custom_minimum_size.x = 150
	return line_edit

func _create_color_widget(value: Color, _read_only: bool) -> ColorPicker:
	var color_picker = ColorPicker.new()
	color_picker.color = value
	color_picker.edit_alpha = false
	color_picker.custom_minimum_size = Vector2(200, 150)
	return color_picker

func _create_vector2_widget(value: Vector2, read_only: bool) -> Control:
	var container = HBoxContainer.new()
	
	var x_spin = SpinBox.new()
	x_spin.value = value.x
	x_spin.step = 0.1
	x_spin.editable = not read_only
	
	var y_spin = SpinBox.new()
	y_spin.value = value.y
	y_spin.step = 0.1
	y_spin.editable = not read_only
	
	container.add_child(Label.new())
	container.get_child(0).text = "X:"
	container.add_child(x_spin)
	container.add_child(Label.new())
	container.get_child(2).text = "Y:"
	container.add_child(y_spin)
	
	return container

func _create_vector3_widget(value: Vector3, read_only: bool) -> Control:
	var container = HBoxContainer.new()
	
	var x_spin = SpinBox.new()
	x_spin.value = value.x
	x_spin.step = 0.1
	x_spin.editable = not read_only
	
	var y_spin = SpinBox.new()
	y_spin.value = value.y
	y_spin.step = 0.1
	y_spin.editable = not read_only
	
	var z_spin = SpinBox.new()
	z_spin.value = value.z
	z_spin.step = 0.1
	z_spin.editable = not read_only
	
	container.add_child(Label.new())
	container.get_child(0).text = "X:"
	container.add_child(x_spin)
	container.add_child(Label.new())
	container.get_child(2).text = "Y:"
	container.add_child(y_spin)
	container.add_child(Label.new())
	container.get_child(4).text = "Z:"
	container.add_child(z_spin)
	
	return container

func _connect_widget_signal(widget: Control, param_path: String, _param_type: int):
	"""Connect appropriate signal based on widget type"""
	if widget is CheckBox:
		widget.toggled.connect(func(pressed): _on_parameter_changed(param_path, pressed))
	elif widget is SpinBox:
		widget.value_changed.connect(func(value): _on_parameter_changed(param_path, value))
	elif widget is LineEdit:
		widget.text_changed.connect(func(text): _on_parameter_changed(param_path, text))
	elif widget is ColorPicker:
		widget.color_changed.connect(func(color): _on_parameter_changed(param_path, color))
	elif widget is VBoxContainer and widget.get_child_count() > 0:
		# Float widget with slider
		var slider = widget.get_child(0)
		if slider is HSlider:
			slider.value_changed.connect(func(value): _on_parameter_changed(param_path, value))

func _on_parameter_changed(param_path: String, value: Variant):
	"""Handle parameter changes from UI widgets"""
	if _parameter_sync:
		_parameter_sync.set_value(_set_id, param_path, value, "ui")
	parameter_changed.emit(_set_id, param_path, value)

func update_parameter_value(param_path: String, value: Variant):
	"""Update widget when parameter changes from external source"""
	if param_path not in _parameter_widgets:
		return
	
	var widget = _parameter_widgets[param_path]
	
	# Temporarily disconnect signals to avoid feedback loop
	# TODO: Implement proper signal disconnection
	
	if widget is CheckBox:
		widget.button_pressed = value
	elif widget is SpinBox:
		widget.value = value
	elif widget is LineEdit:
		widget.text = str(value)
	elif widget is ColorPicker:
		widget.color = value
	elif widget is VBoxContainer and widget.get_child_count() > 0:
		# Float widget with slider
		var slider = widget.get_child(0)
		if slider is HSlider:
			slider.value = value

func _create_header_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.3, 0.4)
	style.set_corner_radius_all(4)
	return style

func _create_group_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2)
	style.set_corner_radius_all(2)
	return style
