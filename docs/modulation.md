---
layout: custom_default
title: Modulation System
---

# Modulation System

The Godot Synth Engine features a powerful modulation system that allows you to create dynamic and expressive sounds.

## Modulation Sources

- **ADSR Envelopes**: Control how parameters change over time with Attack, Decay, Sustain, and Release stages
- **LFOs**: Low Frequency Oscillators for cyclic modulation
- **Velocity Tracking**: Modulate parameters based on note velocity
- **Keyboard Tracking**: Modulate parameters based on note position
- **Note Duration**: Modulate parameters based on how long a note has been playing

## Modulation Types

- **Additive**: Adds the modulation value to the base value
- **Multiplicative**: Multiplies the base value by the modulation value
- **Absolute**: Directly sets the parameter to the modulation value
- **Gate**: On/off control based on modulation threshold

## Using Modulation in GDScript

```gdscript
# Create a modulated parameter
var amp_param = ModulatedParameter.new()
amp_param.base_value = 0.8

# Create an ADSR envelope
var envelope = ADSR.new()
envelope.attack = 0.1
envelope.decay = 0.2
envelope.sustain = 0.7
envelope.release = 0.5

# Apply the envelope to modulate the amplitude
amp_param.modulation.mod_source = envelope
amp_param.modulation.mod_amount = 1.0
amp_param.modulation.mod_type = ModulationType.MULTIPLICATIVE

# Set the parameter in your synth configuration
config.set_parameter("amplitude", amp_param)
```

Most modulation setup can be done directly in the Godot Editor using the inspector panel.
