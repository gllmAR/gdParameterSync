extends Control

"""
Automatic UI Generator for gdParameterSync
Generates UI controls from parameter sets automatically
"""

var param_sync
var current_parameter_set: Resource
var ui_panel: Panel
var group_foldouts = {}
var ui_visible = true

signal parameter_changed(set_id: String, param_name: String, value, source: String)

func _ready():
	param_sync = get_node_or_null("/root/ParameterSync")
	if not param_sync:
		print("⚠️ ParameterSync not found. Make sure gdParameterSync addon is enabled.")

func generate_ui_from_tres(tres_file_path: String, ui_position: Vector2 = Vector2(10, 10), ui_size: Vector2 = Vector2(350, 500)) -> bool:
	"""Generate UI from a TRES parameter set file"""
	print("🎛️ Generating UI from: ", tres_file_path)
	
	# Load the parameter set using the config parser
	var ConfigParser = load("res://addons/gdParameterSync/parsers/config_parser.gd")
	var parameter_set = ConfigParser.load_from_file(tres_file_path)
	
	if not parameter_set:
		print("❌ Failed to load parameter set from: ", tres_file_path)
		return false
	
	# Register the parameter set if not already registered
	if param_sync:
		param_sync.register_set(parameter_set)
		print("📋 Registered parameter set: ", parameter_set.id)
	
	# Store reference
	current_parameter_set = parameter_set
	
	# Generate the UI
	create_ui_panel(ui_position, ui_size)
	connect_parameter_events()
	
	return true

func generate_ui_from_parameter_set(parameter_set: Resource, ui_position: Vector2 = Vector2(10, 10), ui_size: Vector2 = Vector2(350, 500)) -> bool:
	"""Generate UI from an already loaded parameter set"""
	if not parameter_set:
		print("❌ Parameter set is null")
		return false
	
	print("🎛️ Generating UI from parameter set: ", parameter_set.id if parameter_set.has_method("get") and parameter_set.get("id") else "Unknown")
	
	# Register the parameter set if not already registered
	if param_sync:
		param_sync.register_set(parameter_set)
	
	# Store reference
	current_parameter_set = parameter_set
	
	# Generate the UI
	create_ui_panel(ui_position, ui_size)
	connect_parameter_events()
	
	return true

func create_ui_panel(pos: Vector2, panel_size: Vector2):
	"""Create the main UI panel"""
	ui_panel = Panel.new()
	ui_panel.position = pos
	ui_panel.size = panel_size
	add_child(ui_panel)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.position = Vector2(10, 10)
	main_vbox.size = Vector2(panel_size.x - 20, panel_size.y - 20)
	ui_panel.add_child(main_vbox)
	
	# Header with show/hide toggle
	create_header(main_vbox)
	
	# Scroll container for parameters
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(scroll)
	
	var scroll_vbox = VBoxContainer.new()
	scroll_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(scroll_vbox)
	
	# Generate parameter controls
	if current_parameter_set and current_parameter_set.has_method("get") and current_parameter_set.get("parameters"):
		create_parameter_controls(scroll_vbox)
	else:
		create_simple_parameter_list(scroll_vbox)
	
	print("✅ UI Panel created successfully")

func create_header(parent: VBoxContainer):
	"""Create header with title and toggle button"""
	var header_hbox = HBoxContainer.new()
	parent.add_child(header_hbox)
	
	var title_label = Label.new()
	var set_label = current_parameter_set.get("label") if current_parameter_set.has_method("get") else "Parameters"
	title_label.text = "🎛️ " + set_label
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title_label)
	
	var toggle_button = Button.new()
	toggle_button.text = "Hide"
	toggle_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	toggle_button.pressed.connect(_toggle_ui_visibility)
	header_hbox.add_child(toggle_button)
	
	var reset_button = Button.new()
	reset_button.text = "Reset All"
	reset_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	reset_button.pressed.connect(_reset_all_parameters)
	header_hbox.add_child(reset_button)

func create_parameter_controls(parent: VBoxContainer):
	"""Create parameter controls with automatic grouping"""
	var parameters = current_parameter_set.get("parameters")
	if not parameters:
		print("⚠️ No parameters found in parameter set")
		return
	
	# Group parameters by logical categories
	var groups = auto_group_parameters(parameters)
	
	for group_name in groups.keys():
		create_parameter_group(parent, group_name, groups[group_name])

func auto_group_parameters(parameters: Array) -> Dictionary:
	"""Group parameters by their defined group property or fallback to name patterns"""
	var groups = {}
	
	for param in parameters:
		var param_name = param.get("name") if param.has_method("get") else ""
		var group_name = param.get("group") if param.has_method("get") and param.get("group") else null
		
		# Use defined group or fallback to pattern matching
		if group_name and group_name != "":
			# Use the group defined in the parameter
			if not groups.has(group_name):
				groups[group_name] = []
			groups[group_name].append(param)
		else:
			# Fallback to name pattern matching for legacy support
			var fallback_group = _get_fallback_group(param_name)
			if not groups.has(fallback_group):
				groups[fallback_group] = []
			groups[fallback_group].append(param)
	
	return groups

func _get_fallback_group(param_name: String) -> String:
	"""Get fallback group based on parameter name patterns"""
	# Group by name patterns (legacy fallback)
	if param_name.contains("color") or param_name.contains("line") or param_name.contains("fill"):
		return "Visual"
	elif param_name.contains("rotate") or param_name.contains("pulse") or param_name.contains("speed") or param_name.contains("auto"):
		return "Animation"
	elif param_name.contains("position") or param_name.contains("scale") or param_name.contains("transform"):
		return "Transform"
	elif param_name.contains("sides") or param_name.contains("radius") or param_name.contains("width") or param_name.contains("height"):
		return "Basic"
	else:
		return "Other"

func create_parameter_group(parent: VBoxContainer, group_name: String, parameters: Array):
	"""Create a foldable group of parameters"""
	# Group header button (foldable)
	var group_button = Button.new()
	group_button.text = "▼ " + group_name
	group_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	group_button.flat = true
	parent.add_child(group_button)
	
	# Group container
	var group_container = VBoxContainer.new()
	group_container.visible = true
	parent.add_child(group_container)
	
	# Store foldout state
	group_foldouts[group_name] = {
		"button": group_button,
		"container": group_container,
		"visible": true
	}
	
	# Connect fold/unfold
	group_button.pressed.connect(_toggle_group_fold.bind(group_name))
	
	# Add parameters to group
	for param in parameters:
		var param_control = create_parameter_control(param)
		if param_control:
			group_container.add_child(param_control)

func create_simple_parameter_list(parent: VBoxContainer):
	"""Create simple list of all parameters if grouping fails"""
	if not current_parameter_set:
		return
	
	var set_id = current_parameter_set.get("id") if current_parameter_set.has_method("get") else "unknown"
	
	# Get all parameter names from the sync system
	if param_sync and param_sync.has_method("get_parameter_names"):
		var param_names = param_sync.get_parameter_names(set_id)
		for param_name in param_names:
			var param_control = create_parameter_control_by_name(param_name, set_id)
			if param_control:
				parent.add_child(param_control)

func create_parameter_control(param: Resource) -> Control:
	"""Create a control for a parameter resource"""
	if not param or not param.has_method("get"):
		return null
	
	var param_name = param.get("name")
	# var _param_type = param.get("type")  # Not used in this function
	var current_value = param.get("value")
	var min_value = param.get("min_value")
	var max_value = param.get("max_value")
	var step = param.get("step")
	var description = param.get("description")
	
	return create_parameter_control_internal(param_name, current_value, min_value, max_value, step, description)

func create_parameter_control_by_name(param_name: String, set_id: String) -> Control:
	"""Create a control for a parameter by name (fallback method)"""
	var current_value = param_sync.get_value(set_id, param_name) if param_sync else null
	if current_value == null:
		return null
	
	return create_parameter_control_internal(param_name, current_value, null, null, null, param_name.capitalize())

func create_parameter_control_internal(param_name: String, current_value, min_value, max_value, step, description: String) -> Control:
	"""Internal method to create parameter controls"""
	var hbox = HBoxContainer.new()
	
	var label = Label.new()
	label.text = (description if description else param_name.capitalize().replace("_", " ")) + ":"
	label.custom_minimum_size.x = 120
	hbox.add_child(label)
	
	var control = null
	var set_id = current_parameter_set.get("id") if current_parameter_set else "unknown"
	
	# Create appropriate control based on type
	if current_value is bool:
		control = create_bool_control(param_name, current_value, set_id)
	elif current_value is int:
		control = create_int_control(param_name, current_value, min_value, max_value, step, set_id)
	elif current_value is float:
		control = create_float_control(param_name, current_value, min_value, max_value, step, set_id)
	elif current_value is Vector2:
		control = create_vector2_control(param_name, current_value, set_id)
	elif current_value is Color:
		control = create_color_control(param_name, current_value, set_id)
	else:
		# Fallback to string
		control = create_string_control(param_name, str(current_value), set_id)
	
	if control:
		hbox.add_child(control)
	
	return hbox

func create_bool_control(param_name: String, value: bool, set_id: String) -> Control:
	"""Create a checkbox control"""
	var checkbox = CheckBox.new()
	checkbox.button_pressed = value
	checkbox.toggled.connect(func(new_value): _on_parameter_changed(set_id, param_name, new_value))
	return checkbox

func create_int_control(param_name: String, value: int, min_val, max_val, step_val, set_id: String) -> Control:
	"""Create integer control with slider and spinbox"""
	# Use defaults if not provided
	var min_value = min_val if min_val != null else 0
	var max_value = max_val if max_val != null else 100
	var step = step_val if step_val != null else 1
	
	# Special case for "sides" parameter - create option menu
	if param_name == "sides" and min_value <= 20 and max_value <= 20:
		return create_sides_option_menu(param_name, value, min_value, max_value, set_id)
	
	# Regular slider + spinbox
	var vbox = VBoxContainer.new()
	
	var slider = HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = value
	slider.custom_minimum_size.x = 150
	
	var spin = SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.step = step
	spin.value = value
	spin.custom_minimum_size.x = 80
	
	# Connect both controls
	slider.value_changed.connect(func(val): 
		spin.value = val
		_on_parameter_changed(set_id, param_name, int(val))
	)
	spin.value_changed.connect(func(val): 
		slider.value = val
		_on_parameter_changed(set_id, param_name, int(val))
	)
	
	vbox.add_child(slider)
	vbox.add_child(spin)
	return vbox

func create_float_control(param_name: String, value: float, min_val, max_val, step_val, set_id: String) -> Control:
	"""Create float control with slider and spinbox"""
	# Use defaults if not provided
	var min_value = min_val if min_val != null else 0.0
	var max_value = max_val if max_val != null else 100.0
	var step = step_val if step_val != null else 0.1
	
	var vbox = VBoxContainer.new()
	
	var slider = HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = value
	slider.custom_minimum_size.x = 150
	
	var spin = SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.step = step
	spin.value = value
	spin.custom_minimum_size.x = 80
	
	# Connect both controls
	slider.value_changed.connect(func(val): 
		spin.value = val
		_on_parameter_changed(set_id, param_name, val)
	)
	spin.value_changed.connect(func(val): 
		slider.value = val
		_on_parameter_changed(set_id, param_name, val)
	)
	
	vbox.add_child(slider)
	vbox.add_child(spin)
	return vbox

func create_vector2_control(param_name: String, value: Vector2, set_id: String) -> Control:
	"""Create Vector2 control with X/Y spinboxes"""
	var hbox = HBoxContainer.new()
	
	var x_spin = SpinBox.new()
	x_spin.value = value.x
	x_spin.step = 1
	x_spin.allow_greater = true
	x_spin.allow_lesser = true
	x_spin.custom_minimum_size.x = 80
	
	var y_spin = SpinBox.new()
	y_spin.value = value.y
	y_spin.step = 1
	y_spin.allow_greater = true
	y_spin.allow_lesser = true
	y_spin.custom_minimum_size.x = 80
	
	x_spin.value_changed.connect(func(val): 
		var current = param_sync.get_value(set_id, param_name)
		if current is Vector2:
			current.x = val
			_on_parameter_changed(set_id, param_name, current)
	)
	y_spin.value_changed.connect(func(val): 
		var current = param_sync.get_value(set_id, param_name)
		if current is Vector2:
			current.y = val
			_on_parameter_changed(set_id, param_name, current)
	)
	
	hbox.add_child(x_spin)
	hbox.add_child(y_spin)
	return hbox

func create_color_control(param_name: String, value: Color, set_id: String) -> Control:
	"""Create color control with preview and picker"""
	var hbox = HBoxContainer.new()
	
	var color_rect = ColorRect.new()
	color_rect.color = value
	color_rect.custom_minimum_size = Vector2(40, 20)
	
	var color_button = Button.new()
	color_button.text = "Pick"
	color_button.custom_minimum_size = Vector2(50, 20)
	
	color_button.pressed.connect(func(): 
		_show_color_picker(param_name, value, color_rect, set_id)
	)
	
	hbox.add_child(color_rect)
	hbox.add_child(color_button)
	return hbox

func create_string_control(param_name: String, value: String, set_id: String) -> Control:
	"""Create string control with line edit"""
	var line_edit = LineEdit.new()
	line_edit.text = value
	line_edit.custom_minimum_size.x = 150
	line_edit.text_changed.connect(func(new_text): _on_parameter_changed(set_id, param_name, new_text))
	return line_edit

func create_sides_option_menu(param_name: String, value: int, min_val: int, max_val: int, set_id: String) -> Control:
	"""Create option menu for polygon sides"""
	var option_menu = OptionButton.new()
	
	for i in range(min_val, max_val + 1):
		var item_label = ""
		match i:
			3: item_label = "Triangle (3)"
			4: item_label = "Square (4)"
			5: item_label = "Pentagon (5)"
			6: item_label = "Hexagon (6)"
			7: item_label = "Heptagon (7)" 
			8: item_label = "Octagon (8)"
			_: item_label = str(i) + " sides"
		option_menu.add_item(item_label)
		if i == value:
			option_menu.selected = option_menu.get_item_count() - 1
	
	option_menu.item_selected.connect(func(index): 
		var actual_value = min_val + index
		_on_parameter_changed(set_id, param_name, actual_value)
	)
	
	return option_menu

func _show_color_picker(param_name: String, initial_color: Color, color_rect: ColorRect, set_id: String):
	"""Show color picker dialog"""
	var color_picker_dialog = AcceptDialog.new()
	color_picker_dialog.title = "Choose Color - " + param_name
	color_picker_dialog.size = Vector2(400, 300)
	
	var color_picker = ColorPicker.new()
	color_picker.color = initial_color
	color_picker_dialog.add_child(color_picker)
	
	# Connect color picker events
	color_picker.color_changed.connect(func(color): 
		_on_parameter_changed(set_id, param_name, color)
		color_rect.color = color
	)
	
	# Connect dialog close to cleanup properly
	color_picker_dialog.close_requested.connect(func():
		color_picker_dialog.queue_free()
	)
	
	# Add to scene and show
	get_tree().root.add_child(color_picker_dialog)
	color_picker_dialog.popup_centered()

func _on_parameter_changed(set_id: String, param_name: String, value):
	"""Handle parameter changes"""
	if param_sync:
		param_sync.set_value(set_id, param_name, value)
	
	# Emit signal for external listeners
	parameter_changed.emit(set_id, param_name, value, "ui")

func connect_parameter_events():
	"""Connect to parameter change events from the sync system"""
	if param_sync and param_sync.has_signal("parameter_changed"):
		param_sync.parameter_changed.connect(_on_external_parameter_changed)

func _on_external_parameter_changed(_set_id: String, _param_name: String, _value, _source: String):
	"""Handle parameter changes from external sources"""
	# TODO: Update UI controls when parameters change externally
	pass

func _toggle_ui_visibility():
	"""Toggle UI panel visibility"""
	ui_visible = !ui_visible
	if ui_panel:
		ui_panel.visible = ui_visible
		var toggle_button = ui_panel.get_child(0).get_child(0).get_child(1)
		toggle_button.text = "Show" if !ui_visible else "Hide"

func _toggle_group_fold(group_name: String):
	"""Toggle group fold state"""
	var group_data = group_foldouts[group_name]
	group_data.visible = !group_data.visible
	group_data.container.visible = group_data.visible
	group_data.button.text = ("▼ " if group_data.visible else "▶ ") + group_data.button.text.substr(2)

func get_ui_panel() -> Panel:
	"""Get the generated UI panel"""
	return ui_panel

func set_ui_visible(show_ui: bool):
	"""Set UI visibility"""
	ui_visible = show_ui
	if ui_panel:
		ui_panel.visible = show_ui

func _reset_all_parameters():
	"""Reset all parameters to their factory values"""
	if not current_parameter_set:
		return
	
	var parameters = current_parameter_set.get("parameters") if current_parameter_set.has_method("get") else []
	var set_id = current_parameter_set.get("id") if current_parameter_set.has_method("get") else "unknown"
	
	for param in parameters:
		if param.has_method("reset_to_factory"):
			param.reset_to_factory()
			# Update the sync system
			if param_sync:
				var param_name = param.get("name")
				var new_value = param.get("value")
				param_sync.set_value(set_id, param_name, new_value)
	
	# TODO: Refresh UI controls to show reset values
	print("🔄 Reset all parameters to factory defaults")

func _reset_parameter(param_name: String):
	"""Reset a specific parameter to its factory value"""
	if not current_parameter_set:
		return
	
	var parameters = current_parameter_set.get("parameters") if current_parameter_set.has_method("get") else []
	var set_id = current_parameter_set.get("id") if current_parameter_set.has_method("get") else "unknown"
	
	for param in parameters:
		if param.get("name") == param_name and param.has_method("reset_to_factory"):
			param.reset_to_factory()
			# Update the sync system
			if param_sync:
				var new_value = param.get("value")
				param_sync.set_value(set_id, param_name, new_value)
			print("🔄 Reset parameter '", param_name, "' to factory default")
			break
