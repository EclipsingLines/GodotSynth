# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `SynthOfflineRenderer.render_note(config, note, velocity, duration, release_at, sample_rate, block_size)` renders one note to a `PackedFloat32Array` without an audio device, and `tests/offline_render.gd` uses it as a headless regression test
- `SynthAudioEffect.set_sample_rate()` / `EffectChain.set_sample_rate()`
- `SynthConfiguration.master_effect_chain`: an optional effect chain processed once on the stereo mix of all voices, after the per-voice `effect_chain`. It's off (empty) by default, so existing presets sound the same. `PingPongDelay` and `Reverb` run in true stereo there; other effects run on left and right separately.
- `Reverb` is registered again, meant for `master_effect_chain` (one instance for the whole mix instead of one per voice)
- `SynthOfflineRenderer.render_note_stereo(...)` renders a note through the master chain to a `PackedVector2Array` (x = left, y = right)
- `SynthAudioStreamPlayback.get_mixed_frames()` counts every frame a playback has mixed, silent or not, so a transport can use it as a sample-exact clock. `render_offline(frames)` mixes a playback on the calling thread without the audio server, and `queue_note()` / `queue_note_off()` feed it notes headlessly (see `tests/test_transport_clock.gd`)
- Events in `SynthAudioStreamPlayback` now honour their `frame`: a `SynthNoteEvent` stamped mid-block takes effect on exactly that frame, `queue_note_at()` schedules note-on and note-off frames, and `get_late_event_count()` reports events that arrived after their frame (see `tests/test_transport_schedule.gd`)

### Changed

- Saw, square, pulse, sub square and super saw are band-limited (PolyBLEP), so high notes no longer alias. Aliasing at A7 dropped from about −26 dB to below −80 dB. High notes sound slightly cleaner than before.
- Faster audio path. The mixer no longer allocates per block, voices render straight into a fixed buffer, engines and effects cache their parameter pointers instead of looking them up by name every sample, and effect chains dispatch through raw pointers. In a debug build, a C4 saw renders at about 309× realtime instead of 84×, and with a low-pass filter and ping-pong delay at about 26× instead of 6×.

### Fixed

- Engines are created through the configuration's own `create_engine()`, so a custom `SynthConfiguration` gets its own engine instead of the built-in one picked by type (#3)
- Notes played at the wrong pitch when the mix rate was not 44100 Hz (48 kHz played about 1.5 semitones sharp). Oscillators, LFOs and every delay, filter and distortion effect now use the real mix rate.
- The fast pitch path (`PitchHelper.fast_pitch`, `midi_to_freq`) was badly out of tune (a fifth came out as 1.034 instead of 1.498), and `SynthVoice` switched between fast and exact pitch on every block. Fast pitch is now accurate to a fraction of a cent and stays on.
- `AudioSynthPlayer.stop_all_notes()` (and stopping the player) did nothing; it now releases every playing voice
- `AudioSynthPlayer.set_parameter()` only changed notes started afterwards; it now also reaches voices that are already playing, applied on the audio thread
- `SUB_SQUARE` output a constant DC level instead of a square an octave below the note
- `SUPER_SAW` did not detune: its saws now run at 0, ±8, ±16 and ±24 cents, which gives the usual moving, chorused sound. Presets using it sound different (as intended).
- The `NOISE` waveform repeated a cached 4096-sample cycle instead of being random
- The per-voice copies of the filtered, multi-tap, ping-pong and tape delays and of the bitcrush, clip, foldback, overdrive and wave-shaper distortions lost each parameter's modulation amount, type and invert setting, so modulation set on those effects was not heard. They now copy parameters in full.
- The formant filter's per-voice copy kept the default vowel's coefficients instead of the configured vowel
- Reverse and tape delays could read outside their buffers at very short or rounded delay times
- `VAOscillatorEngine.duplicate()` dropped the modulation update rate, and a rate of 0 crashed
- `Reverb` could build up instead of decaying (its feedback loop gain was above 1 at the default settings), and its `reset()` printed to the console

Planned:

- Chord Engine Implementation
- FM Engine Implementation
- Wavetable Engine Implementation
- SIMD optimizations
- Sound preloading
- Step sequencer
- Gold braided cable emulation

## [v0.96] - 2026-11-09

### Added

- `AudioSynthPlayer.play_note_on_context(context, note, velocity)` and `play_note_off_context(context)`, plus `SynthNoteContext.note_on_deferred(note, velocity)` and `note_off_deferred()`: queue note events for the audio thread so several notes start on the same audio block (#23)

### Changed

- Note start-up is handed to the audio thread through a lock-free, preallocated event queue instead of the main thread editing the mixer's voice list directly
- Windows binaries are now built with MSVC on `windows-latest` instead of MinGW cross-compiled on Ubuntu, and CI pins SCons 4.11.1
- Upgraded godot-cpp from `godot-4.4-stable` to `10.0.0-stable` and set the build to target the Godot 4.7 API (`api_version` 4.7). Builds now require Godot 4.7 or later.
- The minimum supported Godot version is now 4.7: `godot_synth.gdextension` declares `compatibility_minimum = "4.7"`, and the example project was upgraded to Godot 4.7.
- `godot_synth.gdextension` `[libraries]` now matches what the build produces: added Android arm32 and Web (no-threads) entries, and removed Linux arm64/rv64 and Android x86_64 entries that were never built.

### Fixed

- Only the last of several notes started in the same frame was heard (#1)
- `docs/multiple_notes.md` documented APIs that did not exist (#23)
- Clearer basic-usage snippets in the README and the docs site (thanks to @JordanKlooster, #4, #5)
- Fixed the macOS library paths in `godot_synth.gdextension`, which now point to `bin/macos.framework/` where the build puts them (thanks to @speelbarrow, #6).
- `VASynthConfiguration` created outside the editor (in a running game, or loaded from a scene saved with the default waveforms) no longer starts with uninitialized bottom, middle and top waveforms. They now default to sine, triangle and noise, the same as the editor's default preset.
- Build: sources are now collected recursively from `src/synth/`, and the build stops with an error if none are found, instead of linking an empty library. CI now fails any job whose library is under 200 KB or lacks the `synth_library_init` entry symbol, and only publishes a GitHub release for tag pushes (#20)
- Removed per-block debug prints (VA engine timing, ADSR level changes, chord engine silence) from the audio thread

## [v0.95] - 2025-03-16

### Added

- Add articulation modulation source
- Added missing modulated parameters on filter effects

### Fixed

- Fixed modulated parameters on effects

## [v0.94] - 2025-03-14

### Added

- Initial release.
