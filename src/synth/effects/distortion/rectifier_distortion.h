#ifndef RECTIFIER_DISTORTION_H
#define RECTIFIER_DISTORTION_H

#include "distortion_effect.h"

namespace godot {

class RectifierDistortion : public DistortionEffect {
	GDCLASS(RectifierDistortion, DistortionEffect)

public:
	// Parameter names
	static const char *PARAM_MODE;
	static const char *PARAM_ASYMMETRY;

protected:
	static void _bind_methods();

public:
	// Rectification modes
	enum RectifierMode {
		HALF_WAVE,
		FULL_WAVE,
		ASYMMETRIC
	};

	RectifierDistortion();
	~RectifierDistortion();

	float process_sample(float sample, const Ref<SynthNoteContext> &context) override;
	void reset() override;
	float get_tail_length() const override;
	Ref<SynthAudioEffect> duplicate() const override;

	// Parameter accessorsvoid
	void set_drive_parameter(const Ref<ModulatedParameter> &param);
	Ref<ModulatedParameter> get_drive_parameter() const;

	void set_mix_parameter(const Ref<ModulatedParameter> &param);
	Ref<ModulatedParameter> get_mix_parameter() const;

	void set_output_gain_parameter(const Ref<ModulatedParameter> &param);
	Ref<ModulatedParameter> get_output_gain_parameter() const;

	void set_mode_parameter(const Ref<ModulatedParameter> &param);
	Ref<ModulatedParameter> get_mode_parameter() const;

	void set_asymmetry_parameter(const Ref<ModulatedParameter> &param);
	Ref<ModulatedParameter> get_asymmetry_parameter() const;

	void set_drive_base_value(float p_value);
	float get_drive_base_value() const;
	void set_mix_base_value(float p_value);
	float get_mix_base_value() const;
	void set_output_gain_base_value(float p_value);
	float get_output_gain_base_value() const;
	void set_mode_base_value(float p_value);
	float get_mode_base_value() const;
	void set_asymmetry_base_value(float p_value);
	float get_asymmetry_base_value() const;
};

} // namespace godot

VARIANT_ENUM_CAST(godot::RectifierDistortion::RectifierMode);

#endif // RECTIFIER_DISTORTION_H
