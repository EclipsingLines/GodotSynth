---
layout: custom_default
title: Audio Effects
---

# Audio Effects

The Godot Synth Engine includes a variety of audio effects that can be chained together to shape your sound.

## Available Effect Types

### Filters
- Low Pass Filter: Attenuates frequencies above the cutoff point
- High Pass Filter: Attenuates frequencies below the cutoff point
- Band Pass Filter: Passes frequencies within a certain range
- Notch Filter: Rejects frequencies within a certain range
- Formant Filter: Simulates vocal formants
- Moog Filter: Classic Moog ladder filter emulation
- MS20 Filter: Korg MS-20 style filter

### Delay Effects
- Simple Delay: Basic delay line
- Ping Pong Delay: Alternating left/right delay
- Filtered Delay: Delay with filtering
- Multi-Tap Delay: Multiple delay taps
- Tape Delay: Tape-style delay with wow and flutter

### Distortion
- Clip Distortion: Hard/soft clipping distortion
- Waveshaper Distortion: Custom waveshaping
- Foldback Distortion: Signal folding distortion
- Bitcrush Distortion: Bit depth and sample rate reduction

### Spatial
- Reverb: Room simulation with adjustable parameters

## Using Effects in GDScript

```gdscript
# Create an effect chain
var chain = EffectChain.new()

# Create a filter
var filter = LowPassFilter.new()
filter.cutoff_parameter.base_value = 1000.0  # 1000 Hz
filter.resonance_parameter.base_value = 0.7  # Resonance amount

# Add the filter to the chain
chain.add_effect(filter)

# Add a delay effect
var delay = DelayEffect.new()
delay.time_parameter.base_value = 0.3  # 300ms delay
delay.feedback_parameter.base_value = 0.4  # 40% feedback
chain.add_effect(delay)

# Set the effect chain in your synth configuration
config.effect_chain = chain
```

Most effect setup can be done directly in the Godot Editor using the inspector panel.
