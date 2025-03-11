---
layout: default
title: Synthesis Engines
---

# Synthesis Engines

## Virtual Analog Synthesis

The Godot Synth Engine currently provides a Virtual Analog (VA) synthesis engine that simulates classic analog synthesizers.

### Features

- Multiple oscillator waveforms (Sine, Square, Saw, Triangle, Pulse)
- Waveform blending between three oscillators
- Adjustable pulse width for pulse waveforms
- Frequency modulation capabilities
- Rich harmonic content

### Using the VA Synth in GDScript

```gdscript
# Create a VA synth configuration
var config = VASynthConfiguration.new()

# Set oscillator waveforms
config.bottom_waveform = WaveHelper.WAVE_SINE
config.middle_waveform = WaveHelper.WAVE_SAW
config.top_waveform = WaveHelper.WAVE_SQUARE

# Create a synth player
var synth = AudioSynthPlayer.new()
synth.configuration = config
add_child(synth)
```

Most configuration can be done directly in the Godot Editor using the inspector panel.
