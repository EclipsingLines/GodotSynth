@tool
extends EditorProperty

var updating = false
var lfo: LFO
var visualizer: Control

func _init():
	pass

func _init_lfo(p_lfo: LFO):
	lfo = p_lfo
	
	# Connect to LFO's property change signal
	lfo.connect("changed", Callable(self, "update_property"))
	
	# Create the main container
	var main_container = VBoxContainer.new()
	
	# Create the visualization
	visualizer = load("res://addons/godot_synth/inspectors/lfo_visualizer.gd").new(lfo)
	main_container.add_child(visualizer)
	
	# Add parameter controls
	_setup_controls(main_container)
	
	add_child(main_container)

func _setup_controls(container):
	# Rate control
	var rate_container = HBoxContainer.new()
	var rate_label = Label.new()
	rate_label.text = "Rate"
	rate_container.add_child(rate_label)
	
	var rate_edit = EditorSpinSlider.new()
	rate_edit.min_value = 0.01
	rate_edit.max_value = 20.0
	rate_edit.step = 0.01
	rate_edit.value = lfo.get_rate()
	rate_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	rate_edit.connect("value_changed", Callable(self, "_on_rate_changed"))
	rate_container.add_child(rate_edit)
	
	container.add_child(rate_container)
	
	# Wave Type control
	var type_container = HBoxContainer.new()
	var type_label = Label.new()
	type_label.text = "Wave Type"
	type_container.add_child(type_label)
	
	var type_option = OptionButton.new()
	# Add wave type options based on WaveHelper::WaveType enum
	# This will need to be adjusted based on the actual enum values
	type_option.add_item("Sine", 0)
	type_option.add_item("Square", 1)
	type_option.add_item("Triangle", 2)
	type_option.add_item("Sawtooth", 3)
	type_option.add_item("Noise", 4)
	type_option.selected = lfo.get_wave_type()
	type_option.size_flags_horizontal = SIZE_EXPAND_FILL
	type_option.connect("item_selected", Callable(self, "_on_wave_type_changed"))
	type_container.add_child(type_option)
	
	container.add_child(type_container)
	
	# Amplitude control
	var amp_container = HBoxContainer.new()
	var amp_label = Label.new()
	amp_label.text = "Amplitude"
	amp_container.add_child(amp_label)
	
	var amp_edit = EditorSpinSlider.new()
	amp_edit.min_value = 0.0
	amp_edit.max_value = 1.0
	amp_edit.step = 0.01
	amp_edit.value = lfo.get_amplitude()
	amp_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	amp_edit.connect("value_changed", Callable(self, "_on_amplitude_changed"))
	amp_container.add_child(amp_edit)
	
	container.add_child(amp_container)
	
	# Phase Offset control
	var phase_container = HBoxContainer.new()
	var phase_label = Label.new()
	phase_label.text = "Phase Offset"
	phase_container.add_child(phase_label)
	
	var phase_edit = EditorSpinSlider.new()
	phase_edit.min_value = 0.0
	phase_edit.max_value = 1.0
	phase_edit.step = 0.01
	phase_edit.value = lfo.get_phase_offset()
	phase_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	phase_edit.connect("value_changed", Callable(self, "_on_phase_offset_changed"))
	phase_container.add_child(phase_edit)
	
	container.add_child(phase_container)
	
	# Pulse Width control (only relevant for pulse/square waves)
	var pulse_container = HBoxContainer.new()
	var pulse_label = Label.new()
	pulse_label.text = "Pulse Width"
	pulse_container.add_child(pulse_label)
	
	var pulse_edit = EditorSpinSlider.new()
	pulse_edit.min_value = 0.01
	pulse_edit.max_value = 0.99
	pulse_edit.step = 0.01
	pulse_edit.value = lfo.get_pulse_width()
	pulse_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	pulse_edit.connect("value_changed", Callable(self, "_on_pulse_width_changed"))
	pulse_container.add_child(pulse_edit)
	
	container.add_child(pulse_container)

func _on_rate_changed(value):
	if updating:
		return
	
	updating = true
	emit_changed("rate", value)
	visualizer.update()
	updating = false

func _on_wave_type_changed(index):
	if updating:
		return
	
	updating = true
	emit_changed("wave_type", index)
	visualizer.update()
	updating = false

func _on_amplitude_changed(value):
	if updating:
		return
	
	updating = true
	emit_changed("amplitude", value)
	visualizer.update()
	updating = false

func _on_phase_offset_changed(value):
	if updating:
		return
	
	updating = true
	emit_changed("phase_offset", value)
	visualizer.update()
	updating = false

func _on_pulse_width_changed(value):
	if updating:
		return
	
	updating = true
	emit_changed("pulse_width", value)
	visualizer.update()
	updating = false

func update_property():
	updating = true
	visualizer.update()
	updating = false
