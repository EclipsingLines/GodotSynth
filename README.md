# Godot Synth Engine

A powerful and flexible synthesizer engine for Godot 4, providing virtual analog synthesis with extensive modulation capabilities and audio effects.

## Features

- **Virtual Analog Synthesis**: High-quality oscillators with multiple waveform types
- **Extensive Modulation System**: ADSR envelopes, LFOs, velocity tracking, keyboard tracking, and note duration modulation
- **Rich Effects Processing**: Filters, delays, distortion, reverb and more
- **Fully Scriptable**: Complete control from GDScript
- **Polyphonic Playback**: Support for multiple simultaneous voices
- **Preset System**: Create and save your own sound presets

## Core Components

### AudioSynthPlayer

The main player node that handles audio playback and voice allocation.

```gdscript
var synth = AudioSynthPlayer.new()
synth.configuration = my_synth_config
synth.polyphony = 8  # Set number of voices
add_child(synth)
```

### SynthNoteContext

Represents a playing note and provides control over its lifecycle.

```gdscript
var context = synth.get_context()
context.note_on(note, velocity)  # Start a note
context.note_off(time)           # Release a note
```

### VASynthConfiguration

Configures the virtual analog synthesizer with oscillators, parameters, and effects.

```gdscript
var config = VASynthConfiguration.new()
config.bottom_waveform = WaveHelper.WAVE_SINE
config.middle_waveform = WaveHelper.WAVE_SAW
config.top_waveform = WaveHelper.WAVE_SQUARE
```

## Effects

The synth engine includes a variety of audio effects:

### Filters
- LowPassFilter, HighPassFilter, BandPassFilter, NotchFilter
- FormantFilter, MoogFilter, MS20Filter, SteinerParkerFilter, ShelfFilter

### Delay Effects
- DelayEffect, PingPongDelay, FilteredDelay, MultiTapDelay
- TapeDelay, ReverseDelay, CombFilterDelay

### Distortion
- ClipDistortion, WaveShaperDistortion, FoldbackDistortion
- BitcrushDistortion, OverdriveDistortion, FuzzDistortion, RectifierDistortion

### Spatial
- Reverb

## Basic Usage Example

```gdscript
extends Node

# Reference to your synth configuration
@export var sound: VASynthConfiguration

func _ready():
    # Create a synth player
    var synth = AudioSynthPlayer.new()
    synth.configuration = sound
    add_child(synth)
    
    # Play a note
    var context = synth.get_context()
    context.note_on(60, 0.8)  # MIDI note 60 (C4) with velocity 0.8
    
    # Stop the note after 1 second
    await get_tree().create_timer(1.0).timeout
    context.note_off(context.absolute_time)
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
