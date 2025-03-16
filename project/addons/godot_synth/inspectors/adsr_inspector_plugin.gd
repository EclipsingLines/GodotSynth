@tool
extends EditorInspectorPlugin

func _can_handle(object):
	return object is ADSR

func _parse_begin(object):
	if object is ADSR:
		# Create a custom property editor for the ADSR
		var editor_script = load("res://addons/godot_synth/inspectors/adsr_editor.gd")
		var editor = EditorProperty.new()
		editor.set_script(editor_script)
		
		# Initialize the editor with the ADSR
		if editor.has_method("_init_adsr"):
			editor._init_adsr(object)
		
		add_custom_control(editor)

func _parse_property(object, type, name, hint_type, hint_string, usage_flags, wide):
	# Let the default inspector handle all properties
	return true
