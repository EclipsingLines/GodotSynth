#ifndef FOLDBACK_DISTORTION_H
#define FOLDBACK_DISTORTION_H

#include "../synth_audio_effect.h"

namespace godot {

class FoldbackDistortion : public SynthAudioEffect {
	GDCLASS(FoldbackDistortion, SynthAudioEffect)

public:
	// Parameter names
	static const char *PARAM_DRIVE;
	static const char *PARAM_MIX;
	static const char *PARAM_OUTPUT_GAIN;
	static const char *PARAM_THRESHOLD;
	static const char *PARAM_ITERATIONS;

protected:
	static void _bind_methods();

public:
	FoldbackDistortion();
	~FoldbackDistortion();

	void set_drive_base_value(float p_value);
	float get_drive_base_value() const;
	void set_mix_base_value(float p_value);
	float get_mix_base_value() const;
	void set_output_gain_base_value(float p_value);
	float get_output_gain_base_value() const;
	void set_threshold_base_value(float p_value);
	float get_threshold_base_value() const;
	void set_iterations_base_value(float p_value);
	float get_iterations_base_value() const;

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

	void set_threshold_parameter(const Ref<ModulatedParameter> &param);
	Ref<ModulatedParameter> get_threshold_parameter() const;

	void set_iterations_parameter(const Ref<ModulatedParameter> &param);
	Ref<ModulatedParameter> get_iterations_parameter() const;
};

} // namespace godot

#endif // FOLDBACK_DISTORTION_H
