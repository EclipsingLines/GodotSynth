#ifndef BITCRUSH_DISTORTION_H
#define BITCRUSH_DISTORTION_H

#include "../synth_audio_effect.h"

namespace godot {

class BitcrushDistortion : public SynthAudioEffect {
	GDCLASS(BitcrushDistortion, SynthAudioEffect)

private:
	// Internal state
	float sample_hold = 0.0f;
	int sample_counter = 0;

public:
	// Parameter names
	static const char *PARAM_DRIVE;
	static const char *PARAM_MIX;
	static const char *PARAM_OUTPUT_GAIN;
	static const char *PARAM_BIT_DEPTH;
	static const char *PARAM_SAMPLE_RATE;

protected:
	static void _bind_methods();

public:
	BitcrushDistortion();
	~BitcrushDistortion();

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

	void set_bit_depth_parameter(const Ref<ModulatedParameter> &param);
	Ref<ModulatedParameter> get_bit_depth_parameter() const;

	void set_sample_rate_parameter(const Ref<ModulatedParameter> &param);
	Ref<ModulatedParameter> get_sample_rate_parameter() const;
};

} // namespace godot

#endif // BITCRUSH_DISTORTION_H
