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

- Windows binaries are now built with MSVC on `windows-latest` instead of MinGW cross-compiled on Ubuntu, and CI pins SCons 4.11.1
- Upgraded godot-cpp from `godot-4.4-stable` to `10.0.0-stable` and set the build to target the Godot 4.7 API (`api_version` 4.7). Builds now require Godot 4.7 or later.

### Fixed

- Build: sources are now collected recursively from `src/synth/`, and the build stops with an error if none are found, instead of linking an empty library. CI now fails any job whose library is under 200 KB or lacks the `synth_library_init` entry symbol, and only publishes a GitHub release for tag pushes (#20)

## [v0.95] - 2025-03-16

### Added

- Add articulation modulation source
- Added missing modulated parameters on filter effects

### Fixed

- Fixed modulated parameters on effects

## [v0.94] - 2025-03-14

### Added

- Initial release.
