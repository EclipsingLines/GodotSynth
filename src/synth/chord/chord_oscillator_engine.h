#pragma once
#include "../core/audio_stream_generator_engine.h"
#include "../core/modulated_parameter.h"
#include "../core/wave_helper.h"
#include <vector>

namespace godot {

// Enum for chord types
enum ChordType {
    CHORD_MAJOR = 0,
    CHORD_MINOR = 1,
    CHORD_DIMINISHED = 2,
    CHORD_AUGMENTED = 3,
    CHORD_SUSPENDED_2 = 4,
    CHORD_SUSPENDED_4 = 5,
    CHORD_MAJOR_7 = 6,
    CHORD_MINOR_7 = 7,
    CHORD_DOMINANT_7 = 8,
    CHORD_DIMINISHED_7 = 9,
    CHORD_HALF_DIMINISHED_7 = 10,
    CHORD_AUGMENTED_7 = 11,
    CHORD_MINOR_MAJOR_7 = 12,
    CHORD_MAJOR_6 = 13,
    CHORD_MINOR_6 = 14,
    CHORD_DOMINANT_9 = 15,
    CHORD_MAJOR_9 = 16,
    CHORD_MINOR_9 = 17,
    CHORD_ADD_9 = 18,
    CHORD_MAX
};

class ChordOscillatorEngine : public AudioStreamGeneratorEngine {
    GDCLASS(ChordOscillatorEngine, AudioStreamGeneratorEngine);

private:
    WaveHelper::WaveType waveform;
    float phase;
    Dictionary parameters;
    
    // Cache for frequently used values
    float cached_chord_type;
    float cached_inversion;
    float cached_amplitude;
    float cached_pulse_width;
    float cached_detune;
    float cached_output_gain;
    
    // Debug mode - when true, only plays the root note (no chord)
    bool root_note_only;
    
    // Helper methods
    std::vector<int> get_chord_intervals(int chord_type) const;
    std::vector<int> apply_inversion(const std::vector<int>& intervals, int inversion) const;
    
    // Helper to ensure phases are properly distributed
    void initialize_chord_phases(std::vector<float>& phases, size_t count);

protected:
    static void _bind_methods();

    // Helper method to get the frequency for a MIDI note
    float get_frequency_for_note(int note) const;

public:
    ChordOscillatorEngine();
    virtual ~ChordOscillatorEngine();

    void set_waveform(WaveHelper::WaveType p_type);
    WaveHelper::WaveType get_waveform() const;

    // Parameter management - using the base class implementation
    virtual void set_parameter(const String &name, const Ref<ModulatedParameter> &param) override;
    virtual Ref<ModulatedParameter> get_parameter(const String &name) const override;
    virtual Dictionary get_parameters() const override;

    // Override base methods
    virtual PackedFloat32Array process_block(int buffer_size, const Ref<SynthNoteContext> &context) override;
    virtual void reset() override;
    
    // Create a duplicate of this engine
    virtual Ref<AudioStreamGeneratorEngine> duplicate() const override;
    
    // Root note only mode (for debugging)
    void set_root_note_only(bool enabled);
    bool get_root_note_only() const;
};

} // namespace godot
