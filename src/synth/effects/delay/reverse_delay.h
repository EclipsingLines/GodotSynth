#ifndef REVERSE_DELAY_H
#define REVERSE_DELAY_H

#include "delay_effect.h"

namespace godot {

class ReverseDelay : public DelayEffect {
	GDCLASS(ReverseDelay, DelayEffect)

private:
	// Delay buffer for reverse playback, sized to MAX_DELAY_SECONDS at the current sample rate
	static constexpr float MAX_DELAY_SECONDS = 2.0f;
	std::vector<float> reverse_buffer;
	int write_position;
	int read_position;
	int buffer_size;
	bool is_recording;

public:
	// Parameter names
	static const char *PARAM_DELAY_TIME;
	static const char *PARAM_FEEDBACK;
	static const char *PARAM_MIX;
	static const char *PARAM_CROSSFADE;

protected:
	static void _bind_methods();

public:
	ReverseDelay();
	~ReverseDelay();

	float process_sample(float sample, const Ref<SynthNoteContext> &context) override;
	void reset() override;

	// Resizes the reverse buffer for the new rate (main thread, before playback)
	void set_sample_rate(float p_sample_rate) override;

	// Create a duplicate of this effect
	Ref<SynthAudioEffect> duplicate() const override;

	// Parameter accessors
	void set_crossfade_parameter(const Ref<ModulatedParameter> &param);
	Ref<ModulatedParameter> get_crossfade_parameter() const;

	void set_crossfade_base_value(float p_value);
	float get_crossfade_base_value() const;
};

} // namespace godot

#endif // REVERSE_DELAY_H
