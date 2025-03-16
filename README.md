[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/O5O21BTCOZ) [![GitHub Release](https://img.shields.io/github/v/release/eclipsinglines/godotsynth?style=for-the-badge&logo=godotengine&logoColor=white)
](https://github.com/EclipsingLines/GodotSynth/releases)
 [![Website](https://img.shields.io/website?url=https%3A%2F%2Feclipsinglines.github.io%2FGodotSynth%2F&style=for-the-badge)](https://eclipsinglines.github.io/GodotSynth/)

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
@export var sound:SynthConfiguration
var synth
func initialize_synth() -> void:
 synth = AudioSynthPlayer.new()
 synth.configuration = sound
```

### SynthNoteContext

Represents a playing note and provides control over its lifecycle.

```gdscript
var context = synth.get_context()
context.note_on(note, velocity)  # Start a note
context.note_off(time)           # Release a note
context = null                   # Release the context object from memory
```

Always use a new context for each note, this allows you to do "articulation" on the played notes, you can use tweens, lerps and curves to drive the values in the context.

> [!TIP]
> Use curves to drive the velocity for a more natural sounding voice.

### VASynthConfiguration

Configures the virtual analog synthesizer with oscillators, parameters, and effects.

![image](https://github.com/user-attachments/assets/b2bb414f-5989-41b1-ac91-c19fddbe95d8)

> [!TIP]
> You can save your own variations of any of the included resources
> Build yourself a library of sounds, modulators, effect chains and effects using Godot's built in resource management.

## Modulated Parameters

These are parameters that change automatically over time.

![image](https://github.com/user-attachments/assets/c622c5d6-a32d-417c-be3c-180641391a6c)

- Multiple modulation sources
- Visual approximation of the modulation range
- Real time visualization of the modulation source shape

### Modulation Sources

#### LFO

Low Frecuency Oscillator

![image](https://github.com/user-attachments/assets/305be2c9-f1a3-487c-8317-294ce77f690c)

- Sine wave
- Triangle wave
- Saw Wave
- Square wave
- Random

#### ADSR Envelope

Attack-Delay-Sustain-Release Envelope

![image](https://github.com/user-attachments/assets/d964e48c-e3d6-4541-9976-4066ef8938d0)

- Multiple attack, decay and release shapes
 	- Linear
 	- Logarithmic
 	- Exponential

#### Velocity

Velocity is controlled from the note context, this allows for controlling modulation parameters from GDScript.

Velocity is hardcoded to amplitude on all patches.

#### Articulation

Articulation is a freely assignable parameter that allows controlling any modulated parameter directly from GDScript.

#### Keyboard Tracking

Uses the midi note for modulation, useful for filters and other effects.

#### Note duration

Uses the total duration of the note for modulation.

## Effects

> [!IMPORTANT]
> These effects all accept modulation parameters, which also makes them more CPU intensive than the Godot counterparts.
> If you don't need modulation on the effects please consider using the Godot audio effects in your audio bus instead.

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
>
> [!WARNING]
> The reverb is currently not enabled due to CPU issues.

- ~~Reverb~~

## Presets

Small collection of predefined set of parameters, can be used directly or as a starting point for more complex sounds.

> [!WARNING]
> The current presets are part of the public beta and will most likely change.
> Do not rely on these for production sounds and always save your own sound resources

## Basic Usage Example

Check the piano_keyboard scene inside the addons folder, this scene allows your to test sound configurations.
Check the synth_player node for more information on a how to play notes.

## Planned Features

- [x] Virtual Analog Engine
- [ ] Chord Engine
- [ ] 4 OP FM Engine
- [ ] Formant Engine
- [ ] Wavetable Engine

- [ ] Custom editor window for testing sounds in editor
- [ ] Single track step sequencer module

- [ ] LFO lookup table caching
- [ ] SIMD optimizations
- [ ] Sound caching and async preloading

- [ ] Gold braided cable end simulation
- [ ] Warmer tone slider

## Contributing

This project is open for contributions, if you are knowledgable in sound design, audio processing, SIMD operations or any other related field please consider contributing to the project.

I am looking for people to help create presets, optimize the code and implement new engines.

I would also kindly take a donation.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
