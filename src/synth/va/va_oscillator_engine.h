#pragma once
#include "../core/audio_stream_generator_engine.h"
#include "../core/modulated_parameter.h"
#include "../core/wave_helper.h"

namespace godot {

class VAOscillatorEngine : public AudioStreamGeneratorEngine {
	GDCLASS(VAOscillatorEngine, AudioStreamGeneratorEngine);

private:
	WaveHelper::WaveType bottom_waveform;
	WaveHelper::WaveType middle_waveform;
	WaveHelper::WaveType top_waveform;
	float phase;
	// Half-rate phase for SUB_SQUARE (an octave below the note).
	float sub_phase;
	// One phase per detuned saw for SUPER_SAW.
	float super_phases[WaveHelper::SUPER_SAW_VOICES];
	Dictionary parameters;

	// Raw pointers to the four parameters the render loop reads, so it never
	// looks them up in `parameters` (a Variant-keyed Dictionary). `parameters`
	// owns them; set_parameter() keeps these in sync. Engines are configured
	// on the main thread before the audio thread uses them.
	ModulatedParameter *param_waveform = nullptr;
	ModulatedParameter *param_amplitude = nullptr;
	ModulatedParameter *param_pitch = nullptr;
	ModulatedParameter *param_pulse_width = nullptr;

	// Phase increment of the current block, for PolyBLEP.
	float phase_dt = 0.0f;

	// Cache for frequently used values
	float cached_morph_position;
	float cached_amplitude;
	float cached_pulse_width;
	float cached_output_gain;
	bool use_cached_values;

	float sample_rate_inv;
	int mod_update_rate;

protected:
	static void _bind_methods();

	// Helper method to get the frequency for a MIDI note
	float get_frequency_for_note(float note) const;

	// Sample of one waveform slot at the oscillator's current phases.
	float get_wave_sample(WaveHelper::WaveType type, float pulse_width) const;

	// Helper method to get a sample from the morphed waveform
	float get_morphed_sample(float morph_position, float pulse_width) const;

	// Advance all phase accumulators by one sample.
	void advance_phases(float phase_increment);

	void reset_phases();

public:
	VAOscillatorEngine();
	virtual ~VAOscillatorEngine();

	void set_bottom_waveform(WaveHelper::WaveType p_type);
	WaveHelper::WaveType get_bottom_waveform() const;

	void set_middle_waveform(WaveHelper::WaveType p_type);
	WaveHelper::WaveType get_middle_waveform() const;

	void set_top_waveform(WaveHelper::WaveType p_type);
	WaveHelper::WaveType get_top_waveform() const;

	void set_mod_update_rate(int p_rate);
	int get_mod_update_rate() const;

	// Parameter management - using the base class implementation
	virtual void set_parameter(const String &name, const Ref<ModulatedParameter> &param) override;
	virtual Ref<ModulatedParameter> get_parameter(const String &name) const override;
	virtual Dictionary get_parameters() const override;

	// Override base methods
	virtual PackedFloat32Array process_block(int buffer_size, const Ref<SynthNoteContext> &context, const bool &use_fast_pitch = true) override;
	virtual void render(float *out, int frames, const Ref<SynthNoteContext> &context, bool use_fast_pitch) override;
	virtual void reset() override;

	// Create a duplicate of this engine
	virtual Ref<AudioStreamGeneratorEngine> duplicate() const override;
};

} // namespace godot
