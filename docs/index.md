---
layout: landingpage
title: Godot Synth Engine
subtitle: Powerful and flexible audio synthesis engine collection for use with the Godot engine (4.4+). SFX and procedural music. 
header_type: splash
header_img : "./assets/img/gallery/synth_main.jpg"
show_sociallinks  : true
project_links:
    - url: https://github.com/EclipsingLines/GodotSynth
      icon: https://github.com/godotengine/godot-website/blob/master/favicon.ico
      label: Synth
    - url: https://godotengine.org/
      icon: fas fa-superscript
      label: Godot
---

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
