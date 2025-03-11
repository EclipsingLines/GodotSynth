#pragma once
#include "../core/synth_configuration.h"
#include "../core/wave_helper.h"
#include "../mod/adsr/adsr.h"

namespace godot {

class VASynthPreset;

class VASynthConfiguration : public SynthConfiguration {
	GDCLASS(VASynthConfiguration, SynthConfiguration);

private:
	// VA-specific properties
	WaveHelper::WaveType bottom_waveform;
	WaveHelper::WaveType middle_waveform;
	WaveHelper::WaveType top_waveform;
	float waveform_position;
	Ref<VASynthPreset> preset;

protected:
	static void _bind_methods();

public:
	// Static parameter name constants
	static const char *PARAM_WAVEFORM;
	static const char *PARAM_AMPLITUDE;
	static const char *PARAM_PITCH;
	static const char *PARAM_PULSE_WIDTH;
	VASynthConfiguration();
	virtual ~VASynthConfiguration();

	// Implementation of the abstract method
	virtual Ref<AudioStreamGeneratorEngine> create_engine() const override;

	// Waveform setters/getters
	void set_bottom_waveform(WaveHelper::WaveType p_type);
	WaveHelper::WaveType get_bottom_waveform() const;

	void set_middle_waveform(WaveHelper::WaveType p_type);
	WaveHelper::WaveType get_middle_waveform() const;

	void set_top_waveform(WaveHelper::WaveType p_type);
	WaveHelper::WaveType get_top_waveform() const;

	// Direct modulated parameter accessors
	void set_waveform_parameter(const Ref<ModulatedParameter> &p_param);
	Ref<ModulatedParameter> get_waveform_parameter() const;

	void set_amplitude_parameter(const Ref<ModulatedParameter> &p_param);
	Ref<ModulatedParameter> get_amplitude_parameter() const;

	void set_pitch_parameter(const Ref<ModulatedParameter> &p_param);
	Ref<ModulatedParameter> get_pitch_parameter() const;
	
	void set_pulse_width_parameter(const Ref<ModulatedParameter> &p_param);
	Ref<ModulatedParameter> get_pulse_width_parameter() const;
	
	// Preset management
	void set_preset(const Ref<VASynthPreset> &p_preset);
	Ref<VASynthPreset> get_preset() const;
};

} // namespace godot
