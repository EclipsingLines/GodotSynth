#ifndef MOOG_FILTER_H
#define MOOG_FILTER_H

#include "filter_effect.h"

namespace godot {

class MoogFilter : public FilterEffect {
	GDCLASS(MoogFilter, FilterEffect)

private:
	// Moog filter state variables
	float stage[4] = { 0.0f, 0.0f, 0.0f, 0.0f };
	float delay[4] = { 0.0f, 0.0f, 0.0f, 0.0f };
	float tanhstage[3] = { 0.0f, 0.0f, 0.0f };
	float old_freq = 0.0f;
	float old_res = 0.0f;
	float old_acr = 0.0f;
	float old_tune = 0.0f;

	// Oversampling factor (can be 1, 2, or 4)
	int oversampling = 2;

protected:
	static void _bind_methods();

public:
	MoogFilter();
	~MoogFilter();

	// Override process_sample to use the Moog algorithm
	float process_sample(float sample, const Ref<SynthNoteContext> &context) override;

	// Override reset to clear filter state
	void reset() override;

	// Oversampling control
	void set_oversampling(int factor);
	int get_oversampling() const;
	
	Ref<SynthAudioEffect> duplicate() const override;
};

} // namespace godot

#endif // MOOG_FILTER_H
