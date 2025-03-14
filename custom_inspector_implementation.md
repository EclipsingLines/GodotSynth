# Custom Inspector Implementation for LFO and ADSR Visualizations

This document provides the complete implementation plan and code for creating custom inspectors for LFO and ADSR components in the Godot Synth project. The goal is to replace the current static visualization with dynamic visualizations that sample and display the actual output of these modulators.

## Overview

We'll create specialized visualizations for LFO and ADSR that:

1. Sample the actual output values over time
2. Display these values as waveforms using custom drawing
3. Update when parameters change

## Implementation Files

We'll create the following files:

1. `lfo_visualizer.gd` - Visualization for LFO waveforms
2. `adsr_visualizer.gd` - Visualization for ADSR envelopes
3. `lfo_inspector_plugin.gd` - Inspector plugin for LFO objects
4. `adsr_inspector_plugin.gd` - Inspector plugin for ADSR objects
5. `lfo_editor.gd` - Custom property editor for LFO objects
6. `adsr_editor.gd` - Custom property editor for ADSR objects

## File Implementations

### 1. LFO Visualizer (`lfo_visualizer.gd`)

```gdscript
@tool
extends Control

var lfo: LFO
var points = []
var sample_count = 100  # Number of points to sample

func _init(p_lfo: LFO):
    lfo = p_lfo
    custom_minimum_size = Vector2(0, 80)  # Set minimum height
    _generate_points()

func update():
    _generate_points()
    queue_redraw()

func _generate_points():
    points.clear()
    
    if not lfo:
        return
    
    # Sample LFO over 1 second
    for i in range(sample_count):
        var time = float(i) / float(sample_count - 1)  # 0 to 1 second
        var value = lfo.process(time)
        points.append(Vector2(time, value))

func _draw():
    if points.size() < 2:
        return
    
    var rect = Rect2(Vector2.ZERO, size)
    var padding = 10
    var draw_rect = Rect2(
        Vector2(padding, padding),
        Vector2(rect.size.x - padding * 2, rect.size.y - padding * 2)
    )
    
    # Draw background
    var bg_color = Color(0.2, 0.2, 0.2, 0.5)
    draw_rect(draw_rect, bg_color)
    
    # Draw center line (zero value)
    var center_y = draw_rect.position.y + draw_rect.size.y / 2
    draw_line(
        Vector2(draw_rect.position.x, center_y),
        Vector2(draw_rect.position.x + draw_rect.size.x, center_y),
        Color(0.5, 0.5, 0.5, 0.5)
    )
    
    # Draw waveform
    var prev_point = null
    for i in range(points.size()):
        var point = points[i]
        var x = draw_rect.position.x + point.x * draw_rect.size.x
        # Map value from -1,1 to draw_rect y coordinates (inverted)
        var y = draw_rect.position.y + draw_rect.size.y / 2 - point.y * draw_rect.size.y / 2
        
        if prev_point != null:
            draw_line(prev_point, Vector2(x, y), Color.WHITE, 2)
        
        prev_point = Vector2(x, y)
    
    # Draw frequency markers
    var font = get_theme_default_font()
    var font_size = get_theme_default_font_size()
    
    # Draw rate value
    var rate_text = str(lfo.get_rate()) + " Hz"
    draw_string(font, Vector2(draw_rect.position.x + 5, draw_rect.position.y + 15), rate_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
```

### 2. ADSR Visualizer (`adsr_visualizer.gd`)

```gdscript
@tool
extends Control

var adsr: ADSR
var points = []
var sustain_duration = 0.5  # Fixed duration for sustain in visualization

func _init(p_adsr: ADSR):
    adsr = p_adsr
    custom_minimum_size = Vector2(0, 80)  # Set minimum height
    _generate_points()

func update():
    _generate_points()
    queue_redraw()

func _generate_points():
    points.clear()
    
    if not adsr:
        return
    
    var attack = adsr.get_attack()
    var decay = adsr.get_decay()
    var sustain = adsr.get_sustain()
    var release = adsr.get_release()
    
    var total_time = attack + decay + sustain_duration + release
    var time_scale = 1.0 / total_time
    
    # Start point (0,0)
    points.append(Vector2(0, 0))
    
    # Attack peak (attack, 1)
    var attack_time = attack * time_scale
    points.append(Vector2(attack_time, 1))
    
    # End of decay (attack+decay, sustain)
    var decay_time = (attack + decay) * time_scale
    points.append(Vector2(decay_time, sustain))
    
    # End of sustain (attack+decay+sustain_duration, sustain)
    var sustain_time = (attack + decay + sustain_duration) * time_scale
    points.append(Vector2(sustain_time, sustain))
    
    # End of release (attack+decay+sustain_duration+release, 0)
    var release_time = (attack + decay + sustain_duration + release) * time_scale
    points.append(Vector2(release_time, 0))

func _draw():
    if points.size() < 2:
        return
    
    var rect = Rect2(Vector2.ZERO, size)
    var padding = 10
    var draw_rect = Rect2(
        Vector2(padding, padding),
        Vector2(rect.size.x - padding * 2, rect.size.y - padding * 2)
    )
    
    # Draw background
    var bg_color = Color(0.2, 0.2, 0.2, 0.5)
    draw_rect(draw_rect, bg_color)
    
    # Draw envelope
    var prev_point = null
    for i in range(points.size()):
        var point = points[i]
        var x = draw_rect.position.x + point.x * draw_rect.size.x
        # Map value from 0,1 to draw_rect y coordinates (inverted)
        var y = draw_rect.position.y + draw_rect.size.y - point.y * draw_rect.size.y
        
        if prev_point != null:
            draw_line(prev_point, Vector2(x, y), Color.WHITE, 2)
        
        prev_point = Vector2(x, y)
    
    # Draw stage labels
    var font = get_theme_default_font()
    var font_size = get_theme_default_font_size()
    
    if points.size() >= 5:
        # Attack label
        var attack_x = (points[0].x + points[1].x) / 2 * draw_rect.size.x + draw_rect.position.x
        draw_string(font, Vector2(attack_x, draw_rect.position.y + draw_rect.size.y + 15), "A", HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)
        
        # Decay label
        var decay_x = (points[1].x + points[2].x) / 2 * draw_rect.size.x + draw_rect.position.x
        draw_string(font, Vector2(decay_x, draw_rect.position.y + draw_rect.size.y + 15), "D", HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)
        
        # Sustain label
        var sustain_x = (points[2].x + points[3].x) / 2 * draw_rect.size.x + draw_rect.position.x
        draw_string(font, Vector2(sustain_x, draw_rect.position.y + draw_rect.size.y + 15), "S", HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)
        
        # Release label
        var release_x = (points[3].x + points[4].x) / 2 * draw_rect.size.x + draw_rect.position.x
        draw_string(font, Vector2(release_x, draw_rect.position.y + draw_rect.size.y + 15), "R", HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)
```

### 3. LFO Inspector Plugin (`lfo_inspector_plugin.gd`)

```gdscript
@tool
extends EditorInspectorPlugin

func _can_handle(object):
    return object is LFO

func _parse_property(object, type, name, hint_type, hint_string, usage_flags, wide):
    # Add a custom editor for all LFO properties
    if object is LFO:
        # Create a custom property editor for the LFO
        var editor_script = load("res://addons/godot_synth/inspectors/lfo_editor.gd")
        var editor = EditorProperty.new()
        editor.set_script(editor_script)
        
        # Initialize the editor with the LFO
        if editor.has_method("_init_lfo"):
            editor._init_lfo(object)
        
        add_property_editor("", editor)
        return true
    
    return false
```

### 4. ADSR Inspector Plugin (`adsr_inspector_plugin.gd`)

```gdscript
@tool
extends EditorInspectorPlugin

func _can_handle(object):
    return object is ADSR

func _parse_property(object, type, name, hint_type, hint_string, usage_flags, wide):
    # Add a custom editor for all ADSR properties
    if object is ADSR:
        # Create a custom property editor for the ADSR
        var editor_script = load("res://addons/godot_synth/inspectors/adsr_editor.gd")
        var editor = EditorProperty.new()
        editor.set_script(editor_script)
        
        # Initialize the editor with the ADSR
        if editor.has_method("_init_adsr"):
            editor._init_adsr(object)
        
        add_property_editor("", editor)
        return true
    
    return false
```

### 5. LFO Editor (`lfo_editor.gd`)

```gdscript
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
```

### 6. ADSR Editor (`adsr_editor.gd`)

```gdscript
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

func update_property():
    updating = true
    visualizer.update()
    updating = false
```

### 7. Plugin Registration

Modify the plugin initialization code to register the new inspector plugins:

```gdscript
# In the plugin.gd file or wherever the inspector plugins are registered

func _enter_tree():
    # Register existing plugins
    # ...
    
    # Register new inspector plugins for LFO and ADSR
    var lfo_inspector = load("res://addons/godot_synth/inspectors/lfo_inspector_plugin.gd").new()
    var adsr_inspector = load("res://addons/godot_synth/inspectors/adsr_inspector_plugin.gd").new()
    
    add_inspector_plugin(lfo_inspector)
    add_inspector_plugin(adsr_inspector)

func _exit_tree():
    # Remove existing plugins
    # ...
    
    # Remove new inspector plugins
    remove_inspector_plugin(lfo_inspector)
    remove_inspector_plugin(adsr_inspector)
```

## Implementation Notes

### LFO Visualization

The LFO visualization samples the LFO output over a 1-second window. This provides:

- For a 1Hz LFO, exactly one complete cycle
- For higher frequencies, multiple cycles
- For lower frequencies, partial cycles

The visualization is static (not animated) to avoid CPU overhead, but updates whenever parameters change.

### ADSR Visualization

The ADSR visualization shows a static representation of the envelope based on the parameters:

- Attack stage: from 0 to peak (1.0)
- Decay stage: from peak to sustain level
- Sustain stage: constant at sustain level (for a fixed duration in the visualization)
- Release stage: from sustain level to 0

The visualization is scaled to fit the available space, with the time axis normalized based on the total envelope duration.

### Integration with Existing Code

These new inspectors will completely replace the current visualization approach for LFO and ADSR components. The existing ModulatedParameter inspector will continue to work as before for other types of parameters.

## Next Steps

1. Implement the files as described above
2. Test with various LFO and ADSR configurations
3. Refine the visualizations based on feedback
4. Consider future enhancements:
   - Interactive controls (e.g., dragging points to adjust parameters)
   - Additional visualization options (e.g., showing multiple cycles for LFO)
   - Performance optimizations for complex waveforms
