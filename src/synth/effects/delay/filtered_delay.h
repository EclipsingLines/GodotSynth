#ifndef FILTERED_DELAY_H
#define FILTERED_DELAY_H

#include "../../core/modulated_parameter.h"
#include "../../core/synth_note_context.h"
#include "../synth_audio_effect.h"
#include <vector>

namespace godot {

class FilteredDelay : public SynthAudioEffect {
	GDCLASS(FilteredDelay, SynthAudioEffect)

private:
	// Delay buffer
	std::vector<float> delay_buffer;
	int buffer_position = 0;

	// Filter state variables
	float lp_state = 0.0f;
	float hp_state = 0.0f;

public:
	// Parameter names
	static const char *PARAM_DELAY_TIME;
	static const char *PARAM_FEEDBACK;
	static const char *PARAM_MIX;
	static const char *PARAM_LP_FREQ;
	static const char *PARAM_HP_FREQ;
	static const char *PARAM_RESONANCE;

protected:
	static void _bind_methods();

public:
	FilteredDelay();
	virtual ~FilteredDelay();

	float process_sample(float sample, const Ref<SynthNoteContext> &context) override;
	void reset() override;

	// Returns the tail length based on delay time and feedback
	float get_tail_length() const override;

	// Create a duplicate of this effect
	Ref<SynthAudioEffect> duplicate() const override;

	// Parameter accessors
	void set_delay_time_parameter(const Ref<ModulatedParameter> &param);
	Ref<ModulatedParameter> get_delay_time_parameter() const;

	void set_feedback_parameter(const Ref<ModulatedParameter> &param);
	Ref<ModulatedParameter> get_feedback_parameter() const;

	void set_mix_parameter(const Ref<ModulatedParameter> &param);
	Ref<ModulatedParameter> get_mix_parameter() const;

	void set_lp_freq_parameter(const Ref<ModulatedParameter> &param);
	Ref<ModulatedParameter> get_lp_freq_parameter() const;

	void set_hp_freq_parameter(const Ref<ModulatedParameter> &param);
	Ref<ModulatedParameter> get_hp_freq_parameter() const;

	void set_resonance_parameter(const Ref<ModulatedParameter> &param);
	Ref<ModulatedParameter> get_resonance_parameter() const;
};

} // namespace godot

#endif // FILTERED_DELAY_H
