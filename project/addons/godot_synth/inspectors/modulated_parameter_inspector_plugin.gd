@tool
extends EditorInspectorPlugin

func _can_handle(object):
	return object is ModulatedParameter

func _parse_property(object, type, name, hint_type, hint_string, usage_flags, wide):
	# We'll handle all properties of ModulatedParameter
	if object is ModulatedParameter:
		if name == "base_value":
			# Create a custom property editor
			var editor_script = load("res://addons/godot_synth/inspectors/modulated_parameter_editor.gd")
			
			# Create an instance of EditorProperty (the base class of our script)
			var editor = EditorProperty.new()
			
			# Set the script to our custom script
			editor.set_script(editor_script)
			
			# Initialize the editor with the parameter
			if editor.has_method("_init_param"):
				editor._init_param(object)
			
			add_property_editor(name, editor)
			return true
		elif name.begins_with("mod") or name == "invert_mod":
			# Skip these properties as they'll be handled by our custom editor
			return true
	
	# Let the default inspector handle other properties
	return false
