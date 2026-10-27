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

## [v0.95] - 2025-03-16

### Added

- Add articulation modulation source
- Added missing modulated parameters on filter effects

### Fixed

- Fixed modulated parameters on effects

## [v0.94] - 2025-03-14

### Added

- Initial release.
