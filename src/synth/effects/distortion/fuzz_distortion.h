#ifndef FUZZ_DISTORTION_H
#define FUZZ_DISTORTION_H

#include "distortion_effect.h"

namespace godot {

class FuzzDistortion : public DistortionEffect {
	GDCLASS(FuzzDistortion, DistortionEffect)

public:
	// Parameter names
	static const char *PARAM_DRIVE;
	static const char *PARAM_MIX;
	static const char *PARAM_OUTPUT_GAIN;
	static const char *PARAM_FUZZ_TYPE;
	static const char *PARAM_TONE;

private:
	// Internal state
	float lp_state;
	float hp_state;

protected:
	static void _bind_methods();

public:
	FuzzDistortion();
	~FuzzDistortion();

	void set_drive_base_value(float p_value);
	float get_drive_base_value() const;
	void set_mix_base_value(float p_value);
	float get_mix_base_value() const;
	void set_output_gain_base_value(float p_value);
	float get_output_gain_base_value() const;
	void set_fuzz_type_base_value(float p_value);
	float get_fuzz_type_base_value() const;
	void set_tone_base_value(float p_value);
	float get_tone_base_value() const;

	// Fuzz types
	enum FuzzType {
		FUZZ_CLASSIC,
		FUZZ_MODERN,
		FUZZ_OCTAVE,
		FUZZ_GATED
	};

	float process_sample(float sample, const Ref<SynthNoteContext> &context) override;
	void reset() override;
	Ref<SynthAudioEffect> duplicate() const override;

	// Parameter accessors
	void set_drive_parameter(const Ref<ModulatedParameter> &param);
	Ref<ModulatedParameter> get_drive_parameter() const;

	void set_mix_parameter(const Ref<ModulatedParameter> &param);
	Ref<ModulatedParameter> get_mix_parameter() const;

	void set_output_gain_parameter(const Ref<ModulatedParameter> &param);
	Ref<ModulatedParameter> get_output_gain_parameter() const;

	void set_fuzz_type_parameter(const Ref<ModulatedParameter> &param);
	Ref<ModulatedParameter> get_fuzz_type_parameter() const;

	void set_tone_parameter(const Ref<ModulatedParameter> &param);
	Ref<ModulatedParameter> get_tone_parameter() const;
};

} // namespace godot

VARIANT_ENUM_CAST(godot::FuzzDistortion::FuzzType);

#endif // FUZZ_DISTORTION_H
