#ifndef OVERDRIVE_DISTORTION_H
#define OVERDRIVE_DISTORTION_H

#include "../synth_audio_effect.h"

namespace godot {

class OverdriveDistortion : public SynthAudioEffect {
	GDCLASS(OverdriveDistortion, SynthAudioEffect)

public:
	// Parameter names
	static const char *PARAM_DRIVE;
	static const char *PARAM_MIX;
	static const char *PARAM_OUTPUT_GAIN;
	static const char *PARAM_TONE;
	static const char *PARAM_CHARACTER;

private:
	// Filter state for tone control
	float lp_state = 0.0f;
	float hp_state = 0.0f;

protected:
	static void _bind_methods();

public:
	OverdriveDistortion();
	~OverdriveDistortion();

	void set_drive_base_value(float p_value);
	float get_drive_base_value() const;
	void set_mix_base_value(float p_value);
	float get_mix_base_value() const;
	void set_output_gain_base_value(float p_value);
	float get_output_gain_base_value() const;
	void set_tone_base_value(float p_value);
	float get_tone_base_value() const;
	void set_character_base_value(float p_value);
	float get_character_base_value() const;

	float process_sample(float sample, const Ref<SynthNoteContext> &context) override;
	void reset() override;
	float get_tail_length() const override;
	Ref<SynthAudioEffect> duplicate() const override;

	// Parameter accessors
	void set_drive_parameter(const Ref<ModulatedParameter> &param);
	Ref<ModulatedParameter> get_drive_parameter() const;

	void set_mix_parameter(const Ref<ModulatedParameter> &param);
	Ref<ModulatedParameter> get_mix_parameter() const;

	void set_output_gain_parameter(const Ref<ModulatedParameter> &param);
	Ref<ModulatedParameter> get_output_gain_parameter() const;

	void set_tone_parameter(const Ref<ModulatedParameter> &param);
	Ref<ModulatedParameter> get_tone_parameter() const;

	void set_character_parameter(const Ref<ModulatedParameter> &param);
	Ref<ModulatedParameter> get_character_parameter() const;
};

} // namespace godot

#endif // OVERDRIVE_DISTORTION_H
