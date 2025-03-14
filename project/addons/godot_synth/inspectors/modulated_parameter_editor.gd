@tool
extends EditorProperty

var updating = false
var parameter: ModulatedParameter
var visualization_slider: Control
var base_value_slider: EditorSpinSlider

# Import the ModulationType enum constants
const MODULATION_ADDITIVE = 0
const MODULATION_MULTIPLICATIVE = 1
const MODULATION_ABSOLUTE = 2
const MODULATION_GATE = 3

func _init():
    pass

func _init_param(param: ModulatedParameter):
    parameter = param
    
    # Connect to parameter's property change signal
    parameter.connect("changed", Callable(self, "update_property"))
    
    # Create the main container
    var main_container = VBoxContainer.new()
    # We no longer need a base value slider here as it's moved to the configuration
    
    # Create the visualization slider (non-interactive)
    visualization_slider = load("res://addons/godot_synth/inspectors/modulated_slider.gd").new(parameter)
    main_container.add_child(visualization_slider)
    
    # Add modulation controls directly to main container
    _setup_modulation_controls(main_container)
    
    add_child(main_container)

func _setup_modulation_controls(container):
    # Add controls for mod_amount, mod_min, mod_max, mod_type, mod_source, etc.
    # Mod Amount
    var amount_container = HBoxContainer.new()
    var amount_label = Label.new()
    amount_label.text = "Amount"
    amount_container.add_child(amount_label)
    
    var amount_edit = EditorSpinSlider.new()
    amount_edit.min_value = 0
    amount_edit.max_value = 1
    amount_edit.step = 0.01
    amount_edit.value = parameter.get_mod_amount()
    amount_edit.size_flags_horizontal = SIZE_EXPAND_FILL
    amount_edit.connect("value_changed", Callable(self, "_on_mod_amount_changed"))
    amount_container.add_child(amount_edit)
    
    container.add_child(amount_container)
    
    # Min and Max values are now defined by code and not editable by users
    
    # Mod Type
    var type_container = HBoxContainer.new()
    var type_label = Label.new()
    type_label.text = "Type"
    type_container.add_child(type_label)
    
    var type_option = OptionButton.new()
    type_option.add_item("Additive", MODULATION_ADDITIVE)
    type_option.add_item("Multiplicative", MODULATION_MULTIPLICATIVE)
    type_option.add_item("Absolute", MODULATION_ABSOLUTE)
    type_option.add_item("Gate", MODULATION_GATE)
    type_option.selected = parameter.get_mod_type()
    type_option.size_flags_horizontal = SIZE_EXPAND_FILL
    type_option.connect("item_selected", Callable(self, "_on_mod_type_changed"))
    type_container.add_child(type_option)
    
    container.add_child(type_container)
    
    # Invert Modulation
    var invert_container = HBoxContainer.new()
    var invert_label = Label.new()
    invert_label.text = "Invert"
    invert_container.add_child(invert_label)
    
    var invert_check = CheckBox.new()
    invert_check.button_pressed = parameter.get_invert_mod()
    invert_check.size_flags_horizontal = SIZE_EXPAND_FILL
    invert_check.connect("toggled", Callable(self, "_on_invert_mod_changed"))
    invert_container.add_child(invert_check)
    
    container.add_child(invert_container)
    
# Base value is now controlled by the configuration

func _on_mod_amount_changed(value):
    if updating:
        return
    
    updating = true
    emit_changed("mod_amount", value)
    visualization_slider.update_from_parameter()
    updating = false

# Min and Max values are now defined by code and not editable by users

func _on_mod_type_changed(index):
    if updating:
        return
    
    updating = true
    emit_changed("mod_type", index)
    visualization_slider.update_from_parameter()
    updating = false

func _on_invert_mod_changed(button_pressed):
    if updating:
        return
    
    updating = true
    emit_changed("invert_mod", button_pressed)
    visualization_slider.update_from_parameter()
    updating = false


func update_property():
    updating = true
    
    # No need to update base value slider as it's removed
    
    # Update visualization
    visualization_slider.update_from_parameter()
    
    updating = false