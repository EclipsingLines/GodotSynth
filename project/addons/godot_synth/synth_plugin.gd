@tool
extends EditorPlugin

var inspector_plugin

func _enter_tree() -> void:
	# Create the inspector plugin
	inspector_plugin = load("res://addons/godot_synth/inspectors/modulated_parameter_inspector_plugin.gd").new()
	add_inspector_plugin(inspector_plugin)


func _exit_tree() -> void:
	# Clean-up
	remove_inspector_plugin(inspector_plugin)
	inspector_plugin = null
