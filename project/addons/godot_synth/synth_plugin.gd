@tool
extends EditorPlugin

var modulated_parameter_inspector
var lfo_inspector
var adsr_inspector

func _enter_tree() -> void:
	# Create the inspector plugins
	modulated_parameter_inspector = load("res://addons/godot_synth/inspectors/modulated_parameter_inspector_plugin.gd").new()
	lfo_inspector = load("res://addons/godot_synth/inspectors/lfo_inspector_plugin.gd").new()
	adsr_inspector = load("res://addons/godot_synth/inspectors/adsr_inspector_plugin.gd").new()
	
	# Add the inspector plugins
	add_inspector_plugin(modulated_parameter_inspector)
	add_inspector_plugin(lfo_inspector)
	add_inspector_plugin(adsr_inspector)


func _exit_tree() -> void:
	# Clean-up
	remove_inspector_plugin(modulated_parameter_inspector)
	remove_inspector_plugin(lfo_inspector)
	remove_inspector_plugin(adsr_inspector)
	
	modulated_parameter_inspector = null
	lfo_inspector = null
	adsr_inspector = null
