# Glaits Synth Engine Capabilities

The Glaits synthesizer is a powerful, modular audio synthesis system designed for real-time sound generation and processing. This document outlines the core capabilities of the engine.

## Audio Generation

### Oscillator Engines
Glaits features multiple specialized oscillator engines, each with unique sound generation characteristics:

- **Wavetable**: High-quality sample playback with interpolation
- **Modal**: Physical modeling of resonant objects
- **Grain**: Granular synthesis for textural sounds
- **Noise**: Various noise types (white, pink, brown)
- **Filtered Noise**: Noise with spectral shaping
- **Particle**: Physics-based particle system sonification
- **Speech**: Formant synthesis for vocal sounds
- **String**: Physical modeling of string vibrations
- **Waveshaping**: Non-linear waveshaping synthesis
- **Dual Waveshaping**: Advanced waveshaping with dual processors

Each oscillator engine provides specialized parameters for detailed sound design.

## Effects Processing

### Distortion Effects
- **Clip Distortion**: Harsh digital clipping with adjustable threshold and hardness
  - Parameters: drive, mix, output_gain, threshold, hardness
- **Foldback Distortion**: Metallic "folding" of over-threshold signals
  - Parameters: drive, mix, output_gain, threshold, iterations

### Delay Effects
- **Ping Pong Delay**: Stereo panning delay with cross-feedback
  - Parameters: delay_time, feedback, mix, cross_feedback, offset
- **Tape Delay**: Vintage tape emulation with wow/flutter and saturation
  - Parameters: delay_time, feedback, mix, saturation, wow_amount, filtering
- **Reverse Delay**: Backwards delay playback with crossfading
  - Parameters: delay_time, feedback, mix, crossfade

### Filter Effects
- **State Variable Filter**: Multi-mode filter with low-pass, high-pass, band-pass, and notch modes
  - Parameters: cutoff, resonance, filter type

### Spatial Effects
- **Reverb**: Room simulation with adjustable parameters
  - Parameters: room_size, damping, width, mix, pre_delay, diffusion

## Modulation System

### Modulation Sources
- **LFO**: Low Frequency Oscillator with multiple waveforms
  - Parameters: rate, wave_type, amplitude, phase_offset, pulse_width
- **Note Duration**: Modulation based on note duration progress
  - Parameters: attack_time, max_time, min_value, max_value, invert
- **Velocity**: MIDI note velocity for dynamic expression
  - Parameters: min_value, max_value, bipolar

### Modulation Parameters
Each ModulatedParameter supports:
- Base value (static value)
- Modulation range (min/max bounds)
- Modulation source assignment
- Inversion option for modulation signal

## Core Architecture

### Processing Components
- **AudioStreamGeneratorEngine**: Core processing engine for audio generation
- **AudioSynthPlayer**: Player interface for controlling the synth engine
- **SynthNoteContext**: Context for tracking note state and timing

### Performance Features
- **SIMD Optimization**: Utilizes SIMD instructions for efficient processing
- **Lock-free Processing**: Minimizes audio thread blocking
- **Dynamic Voice Allocation**: Intelligent management of polyphony

## Integration
- **Godot Engine Integration**: Seamless integration with Godot 4.x via GDExtension
- **Cross-platform Support**: Windows, macOS, Linux, and mobile platforms
- **Real-time Parameter Control**: All parameters accessible via GDScript

All parameters support real-time adjustment through the modulation system, allowing for complex and evolving sound design. The architecture is designed for extensibility, making it easy to add new oscillator engines, effects, and modulation sources.
