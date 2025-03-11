#ifndef DELAY_EFFECT_H
#define DELAY_EFFECT_H

#include "../../core/modulated_parameter.h"
#include "../../core/synth_note_context.h"
#include "../synth_audio_effect.h"
#include <vector>

namespace godot {

class DelayEffect : public SynthAudioEffect {
	GDCLASS(DelayEffect, SynthAudioEffect)

private:
	// Delay buffer
	std::vector<float> delay_buffer;
	int buffer_position = 0;

public:
	// Parameter names
	static const char *PARAM_DELAY_TIME;
	static const char *PARAM_FEEDBACK;
	static const char *PARAM_MIX;

protected:
	static void _bind_methods();

public:
	DelayEffect();
	virtual ~DelayEffect();

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
};

} // namespace godot

#endif // DELAY_EFFECT_H
