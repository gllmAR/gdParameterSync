# Example: Using gdParameterSync with Automatic UI Generation

extends Control

func _ready():
	# Create the UI generator
	var ui_generator = load("res://addons/gdParameterSync/ui/parameter_ui_generator.gd").new()
	add_child(ui_generator)
	
	# Generate UI from any TRES file - that's it!
	ui_generator.generate_ui_from_tres("res://polygon_config.tres")
	
	# Optional: Connect to parameter changes
	ui_generator.parameter_changed.connect(_on_parameter_changed)

func _on_parameter_changed(set_id: String, param_name: String, value, source: String):
	print("Parameter changed: ", param_name, " = ", value)
