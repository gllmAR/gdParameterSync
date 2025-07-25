@tool
extends EditorPlugin

func _enter_tree():
	print("gdParameterSync: Plugin activating...")
	
	# Add the ParameterSync autoload
	add_autoload_singleton("ParameterSync", "res://addons/gdParameterSync/core/parameter_sync.gd")
	
	print("gdParameterSync: Plugin activated successfully!")

func _exit_tree():
	print("gdParameterSync: Plugin deactivating...")
	
	# Remove the autoload
	remove_autoload_singleton("ParameterSync")
	
	print("gdParameterSync: Plugin deactivated")

func get_plugin_name():
	return "gdParameterSync"
