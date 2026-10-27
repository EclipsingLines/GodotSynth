# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `AudioSynthPlayer.play_note_on_context(context, note, velocity)` and `play_note_off_context(context)`, plus `SynthNoteContext.note_on_deferred(note, velocity)` and `note_off_deferred()`: queue note events for the audio thread so several notes start on the same audio block (#23)

### Changed

- Minimum Godot version is now 4.7 (Godot 4.7 / godot-cpp 10 upgrade). Godot 4.4 is no longer supported
- Note start-up is handed to the audio thread through a lock-free, preallocated event queue instead of the main thread editing the mixer's voice list directly

### Fixed

- Only the last of several notes started in the same frame was heard (#1)
- `docs/multiple_notes.md` documented APIs that did not exist (#23)

- Chord Engine Implementation
- FM Engine Implementation
- Wavetable Engine Implementation
- SIMD optimizations
- Sound preloading
- Step sequencer
- Gold braided cable emulation

### Changed

- Windows binaries are now built with MSVC on `windows-latest` instead of MinGW cross-compiled on Ubuntu, and CI pins SCons 4.11.1
- Upgraded godot-cpp from `godot-4.4-stable` to `10.0.0-stable` and set the build to target the Godot 4.7 API (`api_version` 4.7). Builds now require Godot 4.7 or later.
- The minimum supported Godot version is now 4.7: `godot_synth.gdextension` declares `compatibility_minimum = "4.7"`, and the example project was upgraded to Godot 4.7.
- `godot_synth.gdextension` `[libraries]` now matches what the build produces: added Android arm32 and Web (no-threads) entries, and removed Linux arm64/rv64 and Android x86_64 entries that were never built.

### Fixed

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
