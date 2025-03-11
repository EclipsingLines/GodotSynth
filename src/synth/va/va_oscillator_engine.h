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
	Dictionary parameters;
	
	// Cache for frequently used values
	float cached_morph_position;
	float cached_amplitude;
	float cached_pulse_width;
	float cached_output_gain;
	bool use_cached_values;

protected:
	static void _bind_methods();

	// Helper method to get the frequency for a MIDI note
	float get_frequency_for_note(int note) const;

	// Helper method to get a sample from the morphed waveform
	float get_morphed_sample(float phase, float morph_position, float pulse_width) const;

public:
	VAOscillatorEngine();
	virtual ~VAOscillatorEngine();

	void set_bottom_waveform(WaveHelper::WaveType p_type);
	WaveHelper::WaveType get_bottom_waveform() const;

	void set_middle_waveform(WaveHelper::WaveType p_type);
	WaveHelper::WaveType get_middle_waveform() const;

	void set_top_waveform(WaveHelper::WaveType p_type);
	WaveHelper::WaveType get_top_waveform() const;

	// Parameter management - using the base class implementation
	virtual void set_parameter(const String &name, const Ref<ModulatedParameter> &param) override;
	virtual Ref<ModulatedParameter> get_parameter(const String &name) const override;
	virtual Dictionary get_parameters() const override;

	// Override base methods
	virtual PackedFloat32Array process_block(int buffer_size, const Ref<SynthNoteContext> &context) override;
	virtual void reset() override;
	
	// Create a duplicate of this engine
	virtual Ref<AudioStreamGeneratorEngine> duplicate() const override;
};

} // namespace godot
