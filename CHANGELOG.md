# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

- Chord Engine Implementation
- FM Engine Implementation
- Wavetable Engine Implementation
- SIMD optimizations
- Sound preloading
- Step sequencer
- Gold braided cable emulation

### Changed

- Upgraded godot-cpp from `godot-4.4-stable` to `10.0.0-stable` and set the build to target the Godot 4.7 API (`api_version` 4.7). Builds now require Godot 4.7 or later.
- The minimum supported Godot version is now 4.7: `godot_synth.gdextension` declares `compatibility_minimum = "4.7"`, and the example project was upgraded to Godot 4.7.
- `godot_synth.gdextension` `[libraries]` now matches what the build produces: added Android arm32 and Web (no-threads) entries, and removed Linux arm64/rv64 and Android x86_64 entries that were never built.

### Fixed

- Fixed the macOS library paths in `godot_synth.gdextension`, which now point to `bin/macos.framework/` where the build puts them (thanks to @speelbarrow, #6).
- `VASynthConfiguration` created outside the editor (in a running game, or loaded from a scene saved with the default waveforms) no longer starts with uninitialized bottom, middle and top waveforms. They now default to sine, triangle and noise, the same as the editor's default preset.

## [v0.95] - 2025-03-16

### Added

- Add articulation modulation source
- Added missing modulated parameters on filter effects

### Fixed

- Fixed modulated parameters on effects

## [v0.94] - 2025-03-14

### Added

- Initial release.
