@tool
extends EditorInspectorPlugin

func _can_handle(object):
	return object is LFO

func _parse_begin(object):
	if object is LFO:
		# Create a custom property editor for the LFO
		var editor_script = load("res://addons/godot_synth/inspectors/lfo_editor.gd")
		var editor = EditorProperty.new()
		editor.set_script(editor_script)
		
		# Initialize the editor with the LFO
		if editor.has_method("_init_lfo"):
			editor._init_lfo(object)
		
		add_custom_control(editor)

func _parse_property(object, type, name, hint_type, hint_string, usage_flags, wide):
	# Let the default inspector handle all properties
	return true
