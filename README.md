[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/O5O21BTCOZ) [![GitHub Release](https://img.shields.io/github/v/release/eclipsinglines/godotsynth?style=for-the-badge&logo=godotengine&logoColor=white)
](https://github.com/EclipsingLines/GodotSynth/releases)
 [![Website](https://img.shields.io/website?url=https%3A%2F%2Feclipsinglines.github.io%2FGodotSynth%2F&style=for-the-badge)](https://eclipsinglines.github.io/GodotSynth/) ![GitHub Downloads (all assets, all releases)](https://img.shields.io/github/downloads/eclipsinglines/godotsynth/total?style=for-the-badge) ![GitHub Sponsors](https://img.shields.io/github/sponsors/eclipsinglines?style=for-the-badge&color=red)


# Godot Synth Engine

A powerful and flexible synthesizer engine for Godot 4, providing virtual analog synthesis with extensive modulation capabilities and audio effects.

## Requirements

- **Godot 4.7 or later.** Earlier Godot versions are not supported (v0.95 and older targeted Godot 4.4).

## Installation

Download [latest zip](https://github.com/EclipsingLines/GodotSynth/releases) or directly from the [asset library](https://godotengine.org/asset-library/asset/3839).

> ![image](https://github.com/user-attachments/assets/b28105ab-799c-41a4-8743-ff2c4f625541)


Enable the plugin custom inspectors by navigating to:
> Project / Project Settings... / Plugins
and enable the plugin
> ![image](https://github.com/user-attachments/assets/be7a46a8-eaeb-481f-9568-6e2f215265ae)


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
#SOUND SETUP INSTRUCTIONS: either in the file system or inspector create a new VASynthConfiguration resource

var synth : AudioSynthPlayer
func initialize_synth() -> void:
 synth = AudioSynthPlayer.new()
 synth.configuration = sound
```

### SynthNoteContext

Represents a playing note and provides control over its lifecycle.

```gdscript
var context : SynthNoteContext = synth.get_context()
context.note_on(note, velocity)  # Start a note
context.note_off(time)           # Release a note
context = null                   # Release the context object from memory
```

Always use a new context for each note, this allows you to do "articulation" on the played notes, you can use tweens, lerps and curves to drive the values in the context.

To start several notes together (for example a chord), queue them so they all start on the same audio block:

```gdscript
var context = synth.get_context()
synth.play_note_on_context(context, note, velocity)  # or context.note_on_deferred(note, velocity)
synth.play_note_off_context(context)                 # or context.note_off_deferred()
```

See [Playing Multiple Notes in the Same Frame](docs/multiple_notes.md).

> [!TIP]
> Use curves to drive the velocity for a more natural sounding voice.

### Scheduling

`get_mixed_frames()` returns the player's audio clock: the number of frames its playback has mixed since it started. Schedule notes and parameter changes at exact frames on that scale. A frame is one sample at `AudioServer.get_mix_rate()` (44100 frames per second at 44.1 kHz).

```gdscript
var now := synth.get_mixed_frames()
var rate := AudioServer.get_mix_rate()
synth.schedule_note(60, 0.8, now + int(0.1 * rate), now + int(0.2 * rate), {"pulse_width": 0.3})
synth.schedule_parameter("pulse_width", 0.5, now + int(0.15 * rate))
```

`schedule_note(note, velocity, on_frame, off_frame, controls)` allocates a voice when you call it and queues note-on at `on_frame`, an optional note-off at `off_frame` (pass -1 for none), and each entry of `controls` on that voice at `on_frame`. `schedule_parameter(name, value, frame)` changes the parameter on every pooled voice without changing the configuration's base value.

Both calls also take `fx<i>.<param>` names, which address parameter `<param>` of effect `<i>` (0-based, in chain order) in each voice's effect chain: `synth.schedule_parameter("fx0.cutoff", 800.0, frame)` moves the first effect's filter cutoff, and `{"fx0.cutoff": 800.0}` does the same for one note's controls. `AudioSynthPlayer.has_parameter(name)` reports whether a name resolves. Master-chain effects are not addressable, only the per-voice chain.

Because a voice is reserved when you schedule the note (round robin, stealing the oldest voice when all are busy), a note scheduled far ahead holds its voice from that call until it ends. A control in `controls` is written to that voice's engine, so it stays on the voice for later notes until it is overwritten: send a control with every note that needs it.

`restart_stream()` stops and restarts the player and re-acquires its new playback. Call it for several players inside one `AudioServer.lock()`/`AudioServer.unlock()` pair so their clocks start together:

```gdscript
AudioServer.lock()
player_a.restart_stream()
player_b.restart_stream()
AudioServer.unlock()
```

### VASynthConfiguration

Configures the virtual analog synthesizer with oscillators, parameters, and effects.

> ![image](https://github.com/user-attachments/assets/b2bb414f-5989-41b1-ac91-c19fddbe95d8)

> [!TIP]
> You can save your own variations of any of the included resources
> Build yourself a library of sounds, modulators, effect chains and effects using Godot's built in resource management.

## Modulated Parameters

These are parameters that change automatically over time.

> ![image](https://github.com/user-attachments/assets/c622c5d6-a32d-417c-be3c-180641391a6c)

- Multiple modulation sources
- Visual approximation of the modulation range
- Real time visualization of the modulation source shape

### Modulation Sources

#### LFO

Low Frecuency Oscillator

> ![image](https://github.com/user-attachments/assets/305be2c9-f1a3-487c-8317-294ce77f690c)

- Sine wave
- Triangle wave
- Saw Wave
- Square wave
- Random

#### ADSR Envelope

Attack-Delay-Sustain-Release Envelope

> ![image](https://github.com/user-attachments/assets/d964e48c-e3d6-4541-9976-4066ef8938d0)

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

The synth engine includes a variety of audio effects.

A configuration has two chains. `effect_chain` runs separately on every voice, so effects there can follow each note's modulation (a filter envelope, for example). `master_effect_chain` is optional and runs once on the stereo mix of all voices, which is cheaper and the right place for delays and reverb. `PingPongDelay` and `Reverb` are true stereo in the master chain.

```gdscript
var master := EffectChain.new()
master.add_effect(Reverb.new())
config.master_effect_chain = master
```

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

- Reverb (use it in `master_effect_chain`; one reverb per voice is expensive)

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

## Building from source

GodotSynth is built with SCons. CI and local builds use the same pinned version, **SCons 4.11.1**:

```sh
git submodule update --init
python -m pip install scons==4.11.1
python -m SCons target=template_debug   # or target=template_release
```

On Windows, SCons finds MSVC (Visual Studio 2022 or its Build Tools) on its own; run it from PowerShell or cmd, not Git Bash. CI builds Windows with MSVC on `windows-latest`. The library is installed into `project/addons/godot_synth/bin/`.

## Contributing

This project is open for contributions, if you are knowledgable in sound design, audio processing, SIMD operations or any other related field please consider contributing to the project.

I am looking for people to help create presets, optimize the code and implement new engines.

I would also kindly take a donation.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
