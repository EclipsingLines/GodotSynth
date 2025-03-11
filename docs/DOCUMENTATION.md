# Godot Synth Engine Documentation

This document provides an overview of the Godot Synth Engine, its architecture, and how to use it in your Godot projects.

## Overview

The Godot Synth Engine is a GDExtension plugin that provides virtual analog synthesis capabilities for Godot 4. It allows you to create and manipulate synthesized sounds directly from GDScript with a flexible modulation system and extensive effects processing.

## Core Components

### AudioSynthPlayer

The `AudioSynthPlayer` is the main node that handles audio playback and voice allocation. It manages a pool of voices and provides an interface for playing notes.

Key properties:
- `configuration`: The synth configuration to use (VASynthConfiguration)
- `polyphony`: Number of simultaneous voices (1-32)

Key methods:
- `get_context()`: Get a new note context for playing a note
- `stop_all_notes()`: Stop all currently playing notes
- `set_parameter(name, value)`: Set a parameter value by name

### SynthNoteContext

The `SynthNoteContext` represents a playing note and provides control over its lifecycle. Each context is associated with a voice and tracks the state of a note.

Key properties:
- `absolute_time`: Current absolute time
- `note_time`: Time since note started
- `note`: MIDI note number
- `velocity`: Note velocity (0-1)
- `note_active`: Whether note is active
- `note_on_time`: Time when note started
- `note_off_time`: Time when note was released

Key methods:
- `note_on(note, velocity)`: Start playing a note
- `note_off(time)`: Release a note
- `is_note_active_state()`: Check if note is in ACTIVE state
- `is_note_releasing()`: Check if note is in RELEASING state
- `is_note_finished()`: Check if note is in FINISHED state

### SynthConfiguration

The `SynthConfiguration` is the base class for synth configurations. It stores parameters and effects.

Key properties:
- `output_bus`: Audio bus to output to
- `parameters`: Dictionary of modulated parameters
- `effect_chain`: Chain of audio effects

Key methods:
- `set_parameter(name, param)`: Set a modulated parameter
- `get_parameter(name)`: Get a modulated parameter
- `create_engine()`: Create an engine from this configuration

### VASynthConfiguration

The `VASynthConfiguration` is a specific implementation for virtual analog synthesis.

Key properties:
- `bottom_waveform`: Bottom oscillator waveform
- `middle_waveform`: Middle oscillator waveform
- `top_waveform`: Top oscillator waveform
- `waveform_parameter`: Parameter for waveform blending
- `amplitude_parameter`: Parameter for amplitude
- `pitch_parameter`: Parameter for pitch
- `pulse_width_parameter`: Parameter for pulse width
- `preset`: Preset to use

### ModulatedParameter

The `ModulatedParameter` represents a parameter that can be modulated by a modulation source.

Key properties:
- `base_value`: Base value without modulation
- `modulation/mod_amount`: Amount of modulation to apply
- `modulation/mod_min`: Minimum value after modulation
- `modulation/mod_max`: Maximum value after modulation
- `modulation/mod_source`: Source of modulation
- `modulation/mod_type`: Type of modulation (Additive, Multiplicative, Absolute, Gate)
- `invert_mod`: Whether to invert the modulation

### ModulationSource

The `ModulationSource` is the base class for all modulation sources.

Available modulation sources:
- `ADSR`: Attack, Decay, Sustain, Release envelope
- `LFO`: Low Frequency Oscillator
- `VelocityModSource`: Modulation based on note velocity
- `KeyboardTrackingModSource`: Modulation based on note position
- `NoteDurationModSource`: Modulation based on note duration

### EffectChain

The `EffectChain` is a chain of audio effects that process audio samples.

Key methods:
- `add_effect(effect)`: Add an effect to the chain
- `process_sample(sample, context)`: Process a sample through the chain

## Available Effects

### Filters
- `LowPassFilter`: Attenuates frequencies above the cutoff point
- `HighPassFilter`: Attenuates frequencies below the cutoff point
- `BandPassFilter`: Passes frequencies within a certain range
- `NotchFilter`: Rejects frequencies within a certain range
- `FormantFilter`: Simulates vocal formants
- `MoogFilter`: Classic Moog ladder filter emulation
- `MS20Filter`: Korg MS-20 style filter
- `SteinerParkerFilter`: Steiner-Parker filter emulation
- `ShelfFilter`: Low/high shelf filter

### Delay Effects
- `DelayEffect`: Simple delay line
- `PingPongDelay`: Alternating left/right delay
- `FilteredDelay`: Delay with filtering
- `MultiTapDelay`: Multiple delay taps
- `TapeDelay`: Tape-style delay with wow and flutter
- `ReverseDelay`: Plays delayed signal backwards
- `CombFilterDelay`: Creates comb filtering effects

### Distortion
- `ClipDistortion`: Hard/soft clipping distortion
- `WaveShaperDistortion`: Custom waveshaping
- `FoldbackDistortion`: Signal folding distortion
- `BitcrushDistortion`: Bit depth and sample rate reduction
- `OverdriveDistortion`: Warm overdrive effect
- `FuzzDistortion`: Fuzzy distortion
- `RectifierDistortion`: Half/full wave rectification

### Spatial
- `Reverb`: Room simulation with adjustable parameters

## Usage

For usage examples, please refer to the demo project included in the repository.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
