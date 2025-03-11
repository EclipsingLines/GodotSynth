#pragma once
#include "../core/synth_configuration.h"
#include "../core/wave_helper.h"
#include "../mod/adsr/adsr.h"

namespace godot {

class ChordSynthPreset;

class ChordSynthConfiguration : public SynthConfiguration {
	GDCLASS(ChordSynthConfiguration, SynthConfiguration);

private:
	// Chord-specific properties
	WaveHelper::WaveType waveform;
	Ref<ChordSynthPreset> preset;

protected:
	static void _bind_methods();

public:
	// Static parameter name constants
	static const char *PARAM_CHORD_TYPE;
	static const char *PARAM_INVERSION;
	static const char *PARAM_AMPLITUDE;
	static const char *PARAM_PITCH;
	static const char *PARAM_PULSE_WIDTH;
	static const char *PARAM_DETUNE;

	ChordSynthConfiguration();
	virtual ~ChordSynthConfiguration();

	// Implementation of the abstract method
	virtual Ref<AudioStreamGeneratorEngine> create_engine() const override;

	// Waveform setter/getter
	void set_waveform(WaveHelper::WaveType p_type);
	WaveHelper::WaveType get_waveform() const;

	// Direct modulated parameter accessors
	void set_chord_type_parameter(const Ref<ModulatedParameter> &p_param);
	Ref<ModulatedParameter> get_chord_type_parameter() const;

	void set_inversion_parameter(const Ref<ModulatedParameter> &p_param);
	Ref<ModulatedParameter> get_inversion_parameter() const;

	void set_amplitude_parameter(const Ref<ModulatedParameter> &p_param);
	Ref<ModulatedParameter> get_amplitude_parameter() const;

	void set_pitch_parameter(const Ref<ModulatedParameter> &p_param);
	Ref<ModulatedParameter> get_pitch_parameter() const;

	void set_pulse_width_parameter(const Ref<ModulatedParameter> &p_param);
	Ref<ModulatedParameter> get_pulse_width_parameter() const;

	void set_detune_parameter(const Ref<ModulatedParameter> &p_param);
	Ref<ModulatedParameter> get_detune_parameter() const;

	// Preset management
	void set_preset(const Ref<ChordSynthPreset> &p_preset);
	Ref<ChordSynthPreset> get_preset() const;
	bool root_only;
	void set_root_note_only(const bool &enabled) { root_only = enabled; }
	bool get_root_note_only() const { return root_only; }
};

} // namespace godot
