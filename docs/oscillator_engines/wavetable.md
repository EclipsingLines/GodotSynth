# Wavetable Oscillator Engine

The wavetable oscillator engine provides a flexible way to generate audio waveforms using pre-computed wavetable data. This approach offers efficient real-time synthesis while maintaining high sound quality.

## Overview

The wavetable oscillator works by storing pre-computed waveform data in tables and using these tables to generate audio output. The engine supports:
- Custom wavetable data loading
- Phase-based sample playback
- Linear interpolation between samples

## Parameters

The wavetable oscillator engine uses `OscEngTabParams` to configure its behavior:

- `sample_rate`: The audio sample rate used for playback
- Additional parameters can be added for wavetable selection and manipulation

## Usage Example

```gdscript
# Create a new wavetable oscillator engine
var engine = OscEngTab.new()

# Configure the engine parameters
var params = OscEngTabParams.new()
engine.set_params(params)

# Initialize with sample rate
engine.initialize(44100.0)

# Process audio
var output = engine.process(phase)
```

## Implementation Details

The engine is implemented in the following files:
- `src/synth/osc/eng/osc_eng_tab.h`: Header file defining the engine interface
- `src/synth/osc/eng/osc_eng_tab.cpp`: Implementation of the wavetable oscillator
- `src/synth/osc/eng/osc_eng_tab_params.h`: Parameter definitions

The engine inherits from `OscillatorEngineBase` and provides all standard oscillator functionality while adding wavetable-specific features.