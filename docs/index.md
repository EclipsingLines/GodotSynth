---
layout: landingpage
title: Godot Synth Engine
subtitle: Powerful and flexible audio synthesis engine collection for use with the Godot 4.4+ <br>SFX and procedural music. 
header_type: splash
header_img : "./assets/img/synth_main.webp"
show_sociallinks  : true
project_links:
    - url: https://github.com/EclipsingLines/GodotSynth/releases
      icon: fas fa-file-arrow-down
      label: Download
    - url: https://github.com/EclipsingLines/GodotSynth
      icon: fab fa-github
      label: Source
    - url: https://godotengine.org/asset-library/asset/3839
      icon: fas fa-gamepad
      label: Plugin
---

{% include kofi-widget.html %}

# Godot Synth Engine

A powerful and flexible synthesizer engine for Godot 4, providing virtual analog synthesis with extensive modulation capabilities and audio effects.

## Features

- **Virtual Analog Synthesis**: High-quality oscillators with multiple waveform types
- **Extensive Modulation System**: ADSR envelopes, LFOs, velocity tracking, keyboard tracking
- **Rich Effects Processing**: Filters, delays, distortion, reverb and more
- **Fully Scriptable**: Complete control from GDScript
- **Polyphonic Playback**: Support for multiple simultaneous voices
- **Preset System**: Create and save your own sound presets

## Basic Usage

```gdscript
extends Node

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

Most of the synth configuration can be done directly in the Godot Editor using the inspector. Detailed tutorials with images will be added soon.

## Documentation Sections

- [Synthesis Engines](engines.html)
- [Modulation System](modulation.html)
- [Effects](effects.html)

## Roadmap

- [x] Virtual analog engine
- [ ] Chord Engine
- [ ] 4 OP FM Engine
- [ ] Formant Engine
- [ ] Wavetable Engine
- [ ] Gold braided cable emulation
- [ ] Custom editor window for testing sounds in editor
- [ ] Single track step sequencer module
- [ ] "Curve" modulation source
- [ ] LFO lookup table caching
- [ ] SIMD optimizations
- [ ] Sound caching and async preloading
- [ ] Warmer tone slider
