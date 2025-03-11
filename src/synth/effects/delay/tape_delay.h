#ifndef TAPE_DELAY_H
#define TAPE_DELAY_H

#include "../../core/modulated_parameter.h"
#include "../../core/synth_note_context.h"
#include "../synth_audio_effect.h"
#include <vector>

namespace godot {

class TapeDelay : public SynthAudioEffect {
	GDCLASS(TapeDelay, SynthAudioEffect)

private:
	// Delay buffer
	std::vector<float> delay_buffer;
	float read_position = 0.0f; // Fractional read position for smooth time changes
	int write_position = 0;
	float last_delay_time = 0.5f; // Track previous delay time for smooth transitions

	// Low/high pass filter state variables
	float lp_state = 0.0f;
	float hp_state = 0.0f;

	// Wow and flutter LFO
	float wow_phase = 0.0f;

public:
	// Parameter names
	static const char *PARAM_DELAY_TIME;
	static const char *PARAM_FEEDBACK;
	static const char *PARAM_MIX;
	static const char *PARAM_SATURATION;
	static const char *PARAM_WOW_AMOUNT;
	static const char *PARAM_FILTERING;

protected:
	static void _bind_methods();

public:
	TapeDelay();
	virtual ~TapeDelay();

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

	void set_saturation_parameter(const Ref<ModulatedParameter> &param);
	Ref<ModulatedParameter> get_saturation_parameter() const;

	void set_wow_parameter(const Ref<ModulatedParameter> &param);
	Ref<ModulatedParameter> get_wow_parameter() const;

	void set_filtering_parameter(const Ref<ModulatedParameter> &param);
	Ref<ModulatedParameter> get_filtering_parameter() const;
};

} // namespace godot

#endif // TAPE_DELAY_H
