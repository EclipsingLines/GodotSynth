#ifndef COMB_FILTER_DELAY_H
#define COMB_FILTER_DELAY_H

#include "delay_effect.h"

namespace godot {

class CombFilterDelay : public DelayEffect {
	GDCLASS(CombFilterDelay, DelayEffect)

private:
	// Delay buffer for comb filtering, sized to MAX_COMB_SECONDS at the current sample rate
	static constexpr float MAX_COMB_SECONDS = 1.0f;
	std::vector<float> comb_buffer;
	int buffer_position;

public:
	// Parameter names
	static const char *PARAM_DELAY_TIME;
	static const char *PARAM_FEEDBACK;
	static const char *PARAM_MIX;
	static const char *PARAM_RESONANCE;
	static const char *PARAM_POLARITY;

protected:
	static void _bind_methods();

public:
	CombFilterDelay();
	~CombFilterDelay();

	float process_sample(float sample, const Ref<SynthNoteContext> &context) override;
	void reset() override;

	// Resizes the comb buffer for the new rate (main thread, before playback)
	void set_sample_rate(float p_sample_rate) override;

	// Create a duplicate of this effect
	Ref<SynthAudioEffect> duplicate() const override;

	// Parameter accessors
	void set_resonance_parameter(const Ref<ModulatedParameter> &param);
	Ref<ModulatedParameter> get_resonance_parameter() const;
	void set_resonance_base_value(float p_value);
	float get_resonance_base_value() const;

	void set_polarity_parameter(const Ref<ModulatedParameter> &param);
	Ref<ModulatedParameter> get_polarity_parameter() const;
	void set_polarity_base_value(float p_value);
	float get_polarity_base_value() const;
};

} // namespace godot

#endif // COMB_FILTER_DELAY_H
