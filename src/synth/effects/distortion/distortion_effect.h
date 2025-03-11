#ifndef DISTORTION_EFFECT_H
#define DISTORTION_EFFECT_H

#include "../synth_audio_effect.h"

namespace godot {

// Distortion types supported by the effect
enum DistortionType {
	SOFT_CLIP,
	HARD_CLIP,
	WAVE_SHAPING,
	FOLDBACK,
	BITCRUSH,
	OVERDRIVE,
	RECTIFY_HALF,
	RECTIFY_FULL
};

class DistortionEffect : public SynthAudioEffect {
	GDCLASS(DistortionEffect, SynthAudioEffect)

private:
	// Bitcrushing state
	float sample_hold = 0.0f;
	int sample_counter = 0;

	// Parameter names

protected:
	static void _bind_methods();

public:
	static const char *PARAM_DRIVE;
	static const char *PARAM_MIX;
	static const char *PARAM_OUTPUT_GAIN;
	DistortionEffect();
	~DistortionEffect();

	float process_sample(float sample, const Ref<SynthNoteContext> &context) override = 0;
};

} // namespace godot

#endif // DISTORTION_EFFECT_H
