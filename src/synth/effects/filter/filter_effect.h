#ifndef FILTER_EFFECT_H
#define FILTER_EFFECT_H

#include "../../core/modulated_parameter.h"
#include "../../core/synth_note_context.h"
#include "../synth_audio_effect.h"

namespace godot {

// Filter types enum
enum FilterType {
	LOWPASS,
	HIGHPASS,
	BANDPASS,
	NOTCH,
	PEAK,
	LOWSHELF,
	HIGHSHELF
};

class FilterEffect : public SynthAudioEffect {
	GDCLASS(FilterEffect, SynthAudioEffect)

private:
	// Filter state variables
	float z1, z2;
	FilterType filter_type;

	// Parameter names
public:
	static const char *PARAM_CUTOFF;
	static const char *PARAM_RESONANCE;
	static const char *PARAM_GAIN; // For shelf and peak filters
protected:
	static void _bind_methods();

public:
	FilterEffect();
	virtual ~FilterEffect();

	// Make process_sample pure virtual to force derived classes to implement it
	virtual float process_sample(float sample, const Ref<SynthNoteContext> &context) override { return 0.0f; }
	virtual void reset() override;

	// Filter type
	void set_filter_type(int type);
	int get_filter_type() const;

	// Direct parameter accessors
	void set_cutoff_parameter(const Ref<ModulatedParameter> &param);
	Ref<ModulatedParameter> get_cutoff_parameter() const;

	void set_resonance_parameter(const Ref<ModulatedParameter> &param);
	Ref<ModulatedParameter> get_resonance_parameter() const;

	void set_gain_parameter(const Ref<ModulatedParameter> &param);
	Ref<ModulatedParameter> get_gain_parameter() const;
};

} // namespace godot

#endif // FILTER_EFFECT_H
