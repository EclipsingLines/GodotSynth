#ifndef CLIP_DISTORTION_H
#define CLIP_DISTORTION_H

#include "../synth_audio_effect.h"

namespace godot {

class ClipDistortion : public SynthAudioEffect {
	GDCLASS(ClipDistortion, SynthAudioEffect)

public:
	// Parameter names
	static const char *PARAM_DRIVE;
	static const char *PARAM_MIX;
	static const char *PARAM_OUTPUT_GAIN;
	static const char *PARAM_THRESHOLD;
	static const char *PARAM_HARDNESS;

protected:
	static void _bind_methods();

public:
	ClipDistortion();
	~ClipDistortion();

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

	void set_hardness_parameter(const Ref<ModulatedParameter> &param);
	Ref<ModulatedParameter> get_hardness_parameter() const;
};

} // namespace godot

#endif // CLIP_DISTORTION_H
