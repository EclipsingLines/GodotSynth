#ifndef MOOG_FILTER_H
#define MOOG_FILTER_H

#include "filter_effect.h"

namespace godot {

class MoogFilter : public FilterEffect {
	GDCLASS(MoogFilter, FilterEffect)

public:
	static const char *PARAM_OVERSAMPLING;

private:
	// Moog filter state variables
	float stage[4] = { 0.0f, 0.0f, 0.0f, 0.0f };
	float delay[4] = { 0.0f, 0.0f, 0.0f, 0.0f };
	float tanhstage[3] = { 0.0f, 0.0f, 0.0f };
	float old_freq = 0.0f;
	float old_res = 0.0f;
	float old_acr = 0.0f;
	float old_tune = 0.0f;

protected:
	static void _bind_methods();

public:
	MoogFilter();
	~MoogFilter();

	float process_sample(float sample, const Ref<SynthNoteContext> &context) override;
	void reset() override;

	// Oversampling parameter accessors
	void set_oversampling_parameter(const Ref<ModulatedParameter> &param);
	Ref<ModulatedParameter> get_oversampling_parameter() const;
	void set_oversampling_base_value(float p_value);
	float get_oversampling_base_value() const;

	Ref<SynthAudioEffect> duplicate() const override;
};

} // namespace godot

#endif // MOOG_FILTER_H
