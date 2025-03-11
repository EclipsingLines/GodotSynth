# FM Synthesis Engine Implementation Plan

## Overview

This document outlines the implementation plan for a Frequency Modulation (FM) synthesis engine for the Glaits synthesizer. The implementation will focus on a balanced approach with 3-4 operators and a selection of algorithms, optimized for game audio applications while maintaining compatibility with certain existing FM presets.

## Table of Contents

1. [Architecture](#architecture)
2. [Core Components](#core-components)
3. [Algorithms](#algorithms)
4. [Parameters](#parameters)
5. [Preset Compatibility](#preset-compatibility)
6. [Performance Optimizations](#performance-optimizations)
7. [Integration with Existing Systems](#integration-with-existing-systems)
8. [Implementation Phases](#implementation-phases)
9. [Testing Strategy](#testing-strategy)
10. [References](#references)

## Architecture

### Class Structure

The FM engine will consist of the following primary classes:

1. `FMOscillatorEngine` - Main engine class that inherits from `AudioStreamGeneratorEngine`
2. `FMOperator` - Individual FM operator with its own envelope and parameters
3. `FMAlgorithm` - Defines the routing of operators
4. `FMPresetLoader` - Handles loading and conversion of presets from various formats

### Signal Flow

```mermaid
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│  Operator 1 │───►│  Operator 2 │───►│  Operator 3 │───►│  Operator 4 │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
       │                  │                  │                  │
       │                  │                  │                  │
       └──────────┬──────┴──────────┬───────┴─────────┬────────┘
                  │                 │                 │
                  ▼                 ▼                 ▼
           ┌─────────────┐   ┌─────────────┐   ┌─────────────┐
           │   Mixer     │──►│   Effects   │──►│   Output    │
           └─────────────┘   └─────────────┘   └─────────────┘
```

## Core Components

### FMOscillatorEngine

This is the main class that will:

- Manage all operators
- Handle algorithm selection
- Process audio blocks
- Manage preset loading/saving
- Expose parameters to the modulation system

```cpp
class FMOscillatorEngine : public AudioStreamGeneratorEngine {
private:
 std::vector<FMOperator> operators;
 int current_algorithm;
 float global_feedback;
 // ... other parameters

public:
 // Standard methods
 void reset() override;
 PackedFloat32Array process_block(int buffer_size, const Ref<SynthNoteContext> &context) override;
 Ref<AudioStreamGeneratorEngine> duplicate() const override;

 // FM-specific methods
 void set_algorithm(int algorithm_index);
 void load_preset(const String &preset_path);
 // ... other methods
};
```

### FMOperator

  Each
  operator represents a single sine wave oscillator with its own envelope and parameters :

```cpp
class FMOperator {
private:
 float phase;
 float frequency_ratio;
 float level;
 float feedback_amount;
 float last_output;
 Envelope envelope;

public:
 float process_sample(float modulation, float note_frequency, const Ref<SynthNoteContext> &context);
 void reset();
 // ... other methods
};
```

### FMAlgorithm

  Algorithms define how operators are connected.We'll implement this as a routing matrix:

```cpp
struct FMAlgorithm {
 // For each operator, defines which operators modulate it
 // -1 means no modulation input
 std::vector<std::vector<int>> routing;

 // Which operators contribute to the output
 std::vector<int> output_operators;

 // Feedback paths (operator index, feedback amount)
 std::vector<std::pair<int, float>> feedback_paths;
};
```

## Algorithms

We'll implement 8 algorithms that cover most common FM sounds:

  1. **Simple FM(2 - op)**: Op1 → Op2 → Output
  2. **Parallel Carriers(3 - op)**: Op1 → [Op2, Op3] → Output
  3. **Stacked Modulators(3 - op)**: Op1 → Op2 → Op3 → Output
  4. **Feedback FM(3 - op)**: Op1(feedback) → Op2 → Op3 → Output
  5. **Dual Modulator(4 - op)**: [ Op1, Op2 ] → Op3 → Op4 → Output
  6. **2x2 Stack(4 - op)** : Op1 → Op2 → Output,
  Op3 → Op4 → Output
  7. **Classic DX(4 - op)**: Op1 → Op2 → Op3 → Op4 → Output
  8. **Complex Modulation(4 - op)** : Op1 → [Op2, Op3] → Op4 → Output

Each algorithm will be defined in code as a routing matrix.
For example:

```cpp
  // Algorithm 1: Simple FM (2-op)
  FMAlgorithm alg1;
alg1.routing = { { -1 }, { 0 } }; // Op1 has no input, Op2 is modulated by Op0
alg1.output_operators = { 1 }; // Only Op2 goes to output
alg1.feedback_paths = {}; // No feedback

// Algorithm 4: Feedback FM (3-op)
FMAlgorithm alg4;
alg4.routing = { { 0 }, { 0 }, { 1 } }; // Op1 has feedback, Op2 is modulated by Op1, Op3 is modulated by Op2
alg4.output_operators = { 2 }; // Only Op3 goes to output
alg4.feedback_paths = { { 0, 1.0 } }; // Op1 has feedback with default amount 1.0
```

## Parameters

### Global Parameters

1. **Algorithm** - Selects the operator routing (0-7)
2. **Feedback** - Global feedback amount (0.0-1.0)
3. **FM Amount** - Global modulation index multiplier (0.0-1.0)
4. **Transpose** - Global pitch transpose in semitones (-24 to +24)
5. **Detune** - Global fine tuning in cents (-50 to +50)

### Per-Operator Parameters

For each operator (3-4 operators):

1. **Ratio** - Frequency ratio relative to the note frequency (0.5-16.0)
2. **Fine** - Fine tuning in cents (-50 to +50)
3. **Level** - Output level (0.0-1.0)
4. **Velocity Sensitivity** - How much velocity affects level (0.0-1.0)
5. **Envelope**:
   - Attack time (0.0-10.0s)
   - Decay time (0.0-10.0s)
   - Sustain level (0.0-1.0)
   - Release time (0.0-10.0s)

### Modulation Targets

All parameters should be exposed to the modulation system. Key modulation targets:

1. **FM Amount** - For dynamic timbre changes
2. **Operator Levels** - For spectral evolution
3. **Ratios** - For pitch-related effects
4. **Feedback** - For chaotic/noise effects

## Preset Compatibility

### DX7 Preset Import

For DX7 preset compatibility:

1. Implement a SysEx parser for DX7 format (.syx files)
2. Map the 6-operator DX7 algorithms to our simplified algorithms
3. Convert DX7 envelope parameters to our envelope format
4. Scale operator levels appropriately
5. Handle DX7 keyboard scaling by approximating with velocity sensitivity

```cpp
class DX7PresetLoader {
public:
 bool load_from_sysex(const String &sysex_path, FMOscillatorEngine *engine);

private:
 int map_dx7_algorithm_to_engine(int dx7_algorithm);
 void convert_dx7_envelope(const DX7Envelope &dx7_env, Envelope &engine_env);
 // ... other helper methods
};
```

### Volca FM Preset Import

Volca FM uses a subset of DX7 parameters:

1. Implement a parser for Volca FM format
2. Map the 3-operator algorithms to our engine
3. Convert parameters similar to DX7 but with Volca FM's limitations

### Model:Cycles Preset Import

For Elektron Model:Cycles compatibility:

1. Implement a parser for Model:Cycles FM engine parameters
2. Map the 2-operator structure to our engine
3. Convert the simplified parameters to our more detailed parameters

### Custom Preset Format

Design a native preset format that stores:

1. Algorithm selection
2. All operator parameters
3. Global parameters
4. Modulation assignments

```json
{
 "name" : "FM Bass",
    "algorithm" : 2,
    "feedback" : 0.3,
    "fm_amount" : 0.7,
    "transpose" : 0,
    "detune" : 0,
    "operators" : [
     {
      "ratio" : 1.0,
      "fine" : 0,
      "level" : 0.8,
      "velocity_sensitivity" : 0.5,
      "envelope" : {
       "attack" : 0.01,
       "decay" : 0.3,
       "sustain" : 0.4,
       "release" : 0.2
      }
     },
     // ... other operators
    ],
         "modulation" : [
          {
           "target" : "fm_amount",
           "source" : "lfo1",
           "amount" : 0.3
          },
          // ... other modulation assignments
         ]
}
```

## Performance Optimizations

### Sine Wave Optimization

1. **Lookup Table** : Implement a sine wave lookup table with linear interpolation

```cpp
class SineTable {
private:
 static const int TABLE_SIZE = 4096;
 float table[TABLE_SIZE];

public:
 SineTable() {
  for (int i = 0; i < TABLE_SIZE; i++) {
   table[i] = sin(2.0 * M_PI * i / TABLE_SIZE);
  }
 }

 float get(float phase) {
  float index = phase * TABLE_SIZE;
  int idx = static_cast<int>(index);
  float frac = index - idx;
  idx = idx & (TABLE_SIZE - 1); // Fast modulo for power of 2
  int idx_next = (idx + 1) & (TABLE_SIZE - 1);
  return table[idx] + frac * (table[idx_next] - table[idx]);
 }
};
```

2. **SIMD Processing**: Use SIMD instructions for parallel processing of operators

```cpp
// Example using SSE intrinsics
void process_operators_simd(float* output, int count) {
    // Process 4 samples at once using SSE
    for (int i = 0; i < count; i += 4) {
     // SIMD implementation
    }
   }
```

### Envelope Optimization

1. **Segment Skipping**: Skip envelope segments that are effectively zero-length
2. **Linear Approximation**: Use linear approximation for envelope curves
3. **Downsampling**: Calculate envelopes at a lower rate and interpolate

### Algorithm Optimization

1. **Zero Output Detection**: Skip processing operators that have zero output
2. **Modulation Depth Thresholding**: Skip modulation paths with negligible effect
3. **Operator Caching**: Cache operator outputs when possible

## Integration with Existing Systems

### Modulation System Integration

Integrate with the existing modulation system:

1. Expose all FM parameters as `ModulatedParameter` objects
2. Register parameters with the engine
3. Use the modulation context during processing

```cpp
void FMOscillatorEngine::_bind_methods() {
 ClassDB::bind_method(D_METHOD("set_parameter", "name", "param"), &FMOscillatorEngine::set_parameter);
 ClassDB::bind_method(D_METHOD("get_parameter", "name"), &FMOscillatorEngine::get_parameter);
 // ... other bindings
}

void FMOscillatorEngine::set_parameter(const String &name, const Ref<ModulatedParameter> &param) {
 parameters[name] = param;
}
```

### Effect Chain Integration

Ensure the FM engine works with the existing effect chain :

1. Apply the effect chain to the final output
2. Consider per operator effects for advanced sound design

```cpp
float output_sample = final_mix;
if (effect_chain.is_valid()) {
 output_sample = effect_chain->process_sample(output_sample, context);
}
```

### UI Integration

Design parameters to be easily exposed in the UI:

1. Group parameters logically (global, per-operator)
2. Provide meaningful ranges and defaults
3. Include preset browsing capabilities

## Implementation Phases

### Phase 1: Core Engine (2-Operator)

1. Implement basic `FMOscillatorEngine` class
2. Implement `FMOperator` class with sine generation and envelopes
3. Implement a simple 2-operator algorithm
4. Integrate with the modulation system
5. Add basic parameters (ratio, level, envelope)

### Phase 2: Extended Engine (3-4 Operators)

1. Extend to support 3-4 operators
2. Implement all 8 algorithms
3. Add feedback paths
4. Add all parameters (fine tuning, velocity sensitivity, etc.)
5. Optimize performance

### Phase 3: Preset System

1. Implement native preset saving/loading
2. Implement DX7 preset import
3. Implement Volca FM preset import
4. Implement Model:Cycles preset import
5. Create a preset browser UI

### Phase 4: Advanced Features

1. Add per-operator LFOs
2. Implement keyboard scaling
3. Add alternative waveforms for operators
4. Implement more complex modulation options
5. Add visualization tools for FM

## Testing Strategy

### Unit Tests

1. Test individual operators for correct output
2. Test algorithms for correct routing
3. Test envelope generation
4. Test preset loading/conversion

### Performance Tests

1. Measure CPU usage with different numbers of operators
2. Benchmark different optimization strategies
3. Test polyphony limits

### Sound Tests

1. Compare output with reference FM synthesizers
2. Test with a variety of musical material
3. Verify preset conversions sound correct

## References

### FM Synthesis Theory

1. Chowning, J. (1973). "The Synthesis of Complex Audio Spectra by Means of Frequency Modulation"
2. Roads, C. (1996). "The Computer Music Tutorial" - Chapter on FM Synthesis

### DX7 Technical References

1. [DX7 MIDI Implementation](http://yates.ca/dx7/dx7_midi.txt)
2. [DX7 SysEx Format](http://www.cs.cmu.edu/~music/cmsip/readings/dx7-sysex-format.txt)
3. [DX7 Algorithms](https://www.yamahasynth.com/learn/synth-programming/fm-algorithms-in-4-operators)

### Volca FM References

1. [Volca FM Manual](https://www.korg.com/us/support/download/manual/0/733/3541/)
2. [Volca FM MIDI Implementation](https://www.korg.com/us/support/download/manual/0/733/3542/)

### Model:Cycles References

1. [Model:Cycles Manual](https://www.elektron.se/wp-content/uploads/2020/03/Model-Cycles-User-Manual_ENG.pdf)
2. [Model:Cycles MIDI Implementation](https://www.elektron.se/wp-content/uploads/2020/03/Model-Cycles-MIDI-Implementation-Chart_ENG.pdf)

---

## Implementation Notes

### Sine Wave Generation

For optimal performance, use the `WaveHelperCache` for sine wave generation:

```cpp
float FMOperator::get_sine(float phase) {
 WaveHelperCache *cache = WaveHelperCache::get_singleton();
 if (cache) {
  return cache->get_sample(phase, WaveHelper::SINE, 0.5f);
 } else {
  return sin(2.0f * M_PI * phase);
 }
}
```

### Envelope Implementation

Reuse the existing envelope code if possible, or implement a simplified ADSR:

```cpp
float FMOperator::process_envelope(const Ref<SynthNoteContext> &context) {
 if (!context.is_valid()) {
  return 0.0f;
 }

 float note_time = context->get_note_time();
 float note_off_time = context->get_note_off_time();
 bool note_off = context->is_note_off();

 // ADSR logic
 if (note_off) {
  // Release phase
  float release_time = note_time - note_off_time;
  if (release_time >= release) {
   return 0.0f;
  }
  return sustain * (1.0f - release_time / release);
 } else {
  // Attack/Decay phase
  if (note_time < attack) {
   return note_time / attack;
  } else if (note_time < attack + decay) {
   float decay_progress = (note_time - attack) / decay;
   return 1.0f - (1.0f - sustain) * decay_progress;
  } else {
   return sustain;
  }
 }
}
```

### Algorithm Implementation

Implement the algorithm routing in the main processing loop:

```cpp
PackedFloat32Array FMOscillatorEngine::process_block(int buffer_size, const Ref<SynthNoteContext> &context) {
 // ... initialization code ...

 // For each sample in the buffer
 for (int i = 0; i < buffer_size; i++) {
  // Process operators based on algorithm
  std::vector<float> op_outputs(operators.size(), 0.0f);

  // Process each operator according to the algorithm routing
  const FMAlgorithm &alg = algorithms[current_algorithm];

  // Process operators in the correct order (from modulators to carriers)
  for (size_t op_idx = 0; op_idx < operators.size(); op_idx++) {
   float modulation = 0.0f;

   // Get modulation input from other operators
   for (int mod_idx : alg.routing[op_idx]) {
    if (mod_idx >= 0) {
     modulation += op_outputs[mod_idx];
    }
   }

   // Apply feedback if applicable
   for (const auto &fb_path : alg.feedback_paths) {
    if (fb_path.first == op_idx) {
     modulation += operators[op_idx].get_last_output() * fb_path.second * global_feedback;
    }
   }

   // Process the operator
   op_outputs[op_idx] = operators[op_idx].process_sample(
     modulation, base_frequency, context);
  }

  // Mix output operators
  float mixed_output = 0.0f;
  for (int out_idx : alg.output_operators) {
   mixed_output += op_outputs[out_idx];
  }

  // Apply effects and store in output buffer
  // ...
 }

 return output_buffer;
}
```

This implementation plan provides a comprehensive roadmap for developing a balanced FM synthesis engine that will work well in a game audio context while maintaining compatibility with existing FM presets.
