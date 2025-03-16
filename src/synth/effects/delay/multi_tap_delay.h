#ifndef MULTI_TAP_DELAY_H
#define MULTI_TAP_DELAY_H

#include "../../core/modulated_parameter.h"
#include "../../core/synth_note_context.h"
#include "../synth_audio_effect.h"
#include <vector>

namespace godot {

class MultiTapDelay : public SynthAudioEffect {
	GDCLASS(MultiTapDelay, SynthAudioEffect)

private:
	// Delay buffer
	std::vector<float> delay_buffer;
	int buffer_position = 0;

	// Define multiple taps with different times and levels
	struct DelayTap {
		float delay_time;
		float level;
	};

	std::vector<DelayTap> taps;

public:
	// Parameter names
	static const char *PARAM_BASE_DELAY;
	static const char *PARAM_FEEDBACK;
	static const char *PARAM_MIX;
	static const char *PARAM_SPREAD;
	static const char *PARAM_TAPS;
	static const char *PARAM_DECAY;

protected:
	static void _bind_methods();

public:
	MultiTapDelay();
	virtual ~MultiTapDelay();

	float process_sample(float sample, const Ref<SynthNoteContext> &context) override;
	void reset() override;

	// Returns the tail length based on delay time and feedback
	float get_tail_length() const override;

	// Create a duplicate of this effect
	Ref<SynthAudioEffect> duplicate() const override;

	// Parameter accessors
	void set_base_delay_parameter(const Ref<ModulatedParameter> &param);
	Ref<ModulatedParameter> get_base_delay_parameter() const;
	void set_base_delay_base_value(float p_value);
	float get_base_delay_base_value() const;

	void set_feedback_parameter(const Ref<ModulatedParameter> &param);
	Ref<ModulatedParameter> get_feedback_parameter() const;
	void set_feedback_base_value(float p_value);
	float get_feedback_base_value() const;

	void set_mix_parameter(const Ref<ModulatedParameter> &param);
	Ref<ModulatedParameter> get_mix_parameter() const;
	void set_mix_base_value(float p_value);
	float get_mix_base_value() const;

	void set_spread_parameter(const Ref<ModulatedParameter> &param);
	Ref<ModulatedParameter> get_spread_parameter() const;
	void set_spread_base_value(float p_value);
	float get_spread_base_value() const;

	void set_taps_parameter(const Ref<ModulatedParameter> &param);
	Ref<ModulatedParameter> get_taps_parameter() const;
	void set_taps_base_value(float p_value);
	float get_taps_base_value() const;

	void set_decay_parameter(const Ref<ModulatedParameter> &param);
	Ref<ModulatedParameter> get_decay_parameter() const;
	void set_decay_base_value(float p_value);
	float get_decay_base_value() const;

	// Update the taps based on current parameters
	void update_taps(float base_delay, float spread, int num_taps, float decay);
};

} // namespace godot

#endif // MULTI_TAP_DELAY_H
