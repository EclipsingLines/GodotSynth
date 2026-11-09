#ifndef PING_PONG_DELAY_H
#define PING_PONG_DELAY_H

#include "../../core/modulated_parameter.h"
#include "../../core/synth_note_context.h"
#include "../synth_audio_effect.h"
#include <vector>

namespace godot {

class PingPongDelay : public SynthAudioEffect {
	GDCLASS(PingPongDelay, SynthAudioEffect)

private:
	// Two delay buffers for ping-pong effect, sized to MAX_DELAY_SECONDS at the current sample rate
	static constexpr float MAX_DELAY_SECONDS = 2.0f;
	std::vector<float> delay_buffer_1;
	std::vector<float> delay_buffer_2;
	int buffer_position_1 = 0;
	int buffer_position_2 = 0;

public:
	// Parameter names
	static const char *PARAM_DELAY_TIME;
	static const char *PARAM_FEEDBACK;
	static const char *PARAM_MIX;
	static const char *PARAM_CROSS_FEEDBACK;
	static const char *PARAM_OFFSET;

protected:
	static void _bind_methods();

public:
	PingPongDelay();
	virtual ~PingPongDelay();

	float process_sample(float sample, const Ref<SynthNoteContext> &context) override;
	void reset() override;

	// Resizes the delay buffers for the new rate (main thread, before playback)
	void set_sample_rate(float p_sample_rate) override;

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

	void set_cross_feedback_parameter(const Ref<ModulatedParameter> &param);
	Ref<ModulatedParameter> get_cross_feedback_parameter() const;

	void set_offset_parameter(const Ref<ModulatedParameter> &param);
	Ref<ModulatedParameter> get_offset_parameter() const;

	void set_delay_time_base_value(float p_value);
	float get_delay_time_base_value() const;

	void set_feedback_base_value(float p_value);
	float get_feedback_base_value() const;

	void set_mix_base_value(float p_value);
	float get_mix_base_value() const;

	void set_cross_feedback_base_value(float p_value);
	float get_cross_feedback_base_value() const;

	void set_offset_base_value(float p_value);
	float get_offset_base_value() const;
};

} // namespace godot

#endif // PING_PONG_DELAY_H
