@tool
extends EditorProperty

var updating = false
var adsr: ADSR
var visualizer: Control

func _init():
    pass

func _init_adsr(p_adsr: ADSR):
    adsr = p_adsr
    
    # Connect to ADSR's property change signal
    adsr.connect("changed", Callable(self, "update_property"))
    
    # Create the main container
    var main_container = VBoxContainer.new()
    
    # Create the visualization
    visualizer = load("res://addons/godot_synth/inspectors/adsr_visualizer.gd").new(adsr)
    main_container.add_child(visualizer)
    
    # Add parameter controls
    _setup_controls(main_container)
    
    add_child(main_container)

func _setup_controls(container):
    # Attack control
    var attack_container = HBoxContainer.new()
    var attack_label = Label.new()
    attack_label.text = "Attack"
    attack_container.add_child(attack_label)
    
    var attack_edit = EditorSpinSlider.new()
    attack_edit.min_value = 0.00001
    attack_edit.max_value = 5.0
    attack_edit.step = 0.01
    attack_edit.value = adsr.get_attack()
    attack_edit.size_flags_horizontal = SIZE_EXPAND_FILL
    attack_edit.connect("value_changed", Callable(self, "_on_attack_changed"))
    attack_container.add_child(attack_edit)
    
    container.add_child(attack_container)
    
    # Attack type control
    var attack_type_container = HBoxContainer.new()
    var attack_type_label = Label.new()
    attack_type_label.text = "Attack Type"
    attack_type_container.add_child(attack_type_label)
    
    var attack_type_option = OptionButton.new()
    attack_type_option.add_item("Linear", ADSR.LINEAR)
    attack_type_option.add_item("Exponential", ADSR.EXPONENTIAL)
    attack_type_option.add_item("Logarithmic", ADSR.LOGARITHMIC)
    attack_type_option.select(adsr.get_attack_type())
    attack_type_option.size_flags_horizontal = SIZE_EXPAND_FILL
    attack_type_option.connect("item_selected", Callable(self, "_on_attack_type_changed"))
    attack_type_container.add_child(attack_type_option)
    
    container.add_child(attack_type_container)
    
    # Decay control
    var decay_container = HBoxContainer.new()
    var decay_label = Label.new()
    decay_label.text = "Decay"
    decay_container.add_child(decay_label)
    
    var decay_edit = EditorSpinSlider.new()
    decay_edit.min_value = 0.00001
    decay_edit.max_value = 5.0
    decay_edit.step = 0.01
    decay_edit.value = adsr.get_decay()
    decay_edit.size_flags_horizontal = SIZE_EXPAND_FILL
    decay_edit.connect("value_changed", Callable(self, "_on_decay_changed"))
    decay_container.add_child(decay_edit)
    
    container.add_child(decay_container)
    
    # Decay type control
    var decay_type_container = HBoxContainer.new()
    var decay_type_label = Label.new()
    decay_type_label.text = "Decay Type"
    decay_type_container.add_child(decay_type_label)
    
    var decay_type_option = OptionButton.new()
    decay_type_option.add_item("Linear", ADSR.LINEAR)
    decay_type_option.add_item("Exponential", ADSR.EXPONENTIAL)
    decay_type_option.add_item("Logarithmic", ADSR.LOGARITHMIC)
    decay_type_option.select(adsr.get_decay_type())
    decay_type_option.size_flags_horizontal = SIZE_EXPAND_FILL
    decay_type_option.connect("item_selected", Callable(self, "_on_decay_type_changed"))
    decay_type_container.add_child(decay_type_option)
    
    container.add_child(decay_type_container)
    
    # Sustain control
    var sustain_container = HBoxContainer.new()
    var sustain_label = Label.new()
    sustain_label.text = "Sustain"
    sustain_container.add_child(sustain_label)
    
    var sustain_edit = EditorSpinSlider.new()
    sustain_edit.min_value = 0.0
    sustain_edit.max_value = 1.0
    sustain_edit.step = 0.01
    sustain_edit.value = adsr.get_sustain()
    sustain_edit.size_flags_horizontal = SIZE_EXPAND_FILL
    sustain_edit.connect("value_changed", Callable(self, "_on_sustain_changed"))
    sustain_container.add_child(sustain_edit)
    
    container.add_child(sustain_container)
    
    # Release control
    var release_container = HBoxContainer.new()
    var release_label = Label.new()
    release_label.text = "Release"
    release_container.add_child(release_label)
    
    var release_edit = EditorSpinSlider.new()
    release_edit.min_value = 0.00001
    release_edit.max_value = 5.0
    release_edit.step = 0.01
    release_edit.value = adsr.get_release()
    release_edit.size_flags_horizontal = SIZE_EXPAND_FILL
    release_edit.connect("value_changed", Callable(self, "_on_release_changed"))
    release_container.add_child(release_edit)
    
    container.add_child(release_container)
    
    # Release type control
    var release_type_container = HBoxContainer.new()
    var release_type_label = Label.new()
    release_type_label.text = "Release Type"
    release_type_container.add_child(release_type_label)
    
    var release_type_option = OptionButton.new()
    release_type_option.add_item("Linear", ADSR.LINEAR)
    release_type_option.add_item("Exponential", ADSR.EXPONENTIAL)
    release_type_option.add_item("Logarithmic", ADSR.LOGARITHMIC)
    release_type_option.select(adsr.get_release_type())
    release_type_option.size_flags_horizontal = SIZE_EXPAND_FILL
    release_type_option.connect("item_selected", Callable(self, "_on_release_type_changed"))
    release_type_container.add_child(release_type_option)
    
    container.add_child(release_type_container)

func _on_attack_changed(value):
    if updating:
        return
    
    updating = true
    emit_changed("attack", value)
    visualizer.update()
    updating = false

func _on_decay_changed(value):
    if updating:
        return
    
    updating = true
    emit_changed("decay", value)
    visualizer.update()
    updating = false

func _on_sustain_changed(value):
    if updating:
        return
    
    updating = true
    emit_changed("sustain_level", value)
    visualizer.update()
    updating = false

func _on_release_changed(value):
    if updating:
        return
    
    updating = true
    emit_changed("release", value)
    visualizer.update()
    updating = false

func _on_attack_type_changed(index):
    if updating:
        return
    
    updating = true
    emit_changed("attack_type", index)
    visualizer.update()
    updating = false

func _on_decay_type_changed(index):
    if updating:
        return
    
    updating = true
    emit_changed("decay_type", index)
    visualizer.update()
    updating = false

func _on_release_type_changed(index):
    if updating:
        return
    
    updating = true
    emit_changed("release_type", index)
    visualizer.update()
    updating = false

func update_property():
    updating = true
    visualizer.update()
    updating = false