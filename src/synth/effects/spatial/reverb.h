#ifndef REVERB_H
#define REVERB_H

#include "../synth_audio_effect.h"
#include <vector>

namespace godot {

class Reverb : public SynthAudioEffect {
	GDCLASS(Reverb, SynthAudioEffect)

private:
	// Delay lines for early reflections and late reverb
	std::vector<std::vector<float>> early_delay_lines;
	std::vector<std::vector<float>> late_delay_lines;

	// Delay line positions
	std::vector<int> early_positions;
	std::vector<int> late_positions;

	// Feedback filters
	std::vector<float> lp_states;
	std::vector<float> hp_states;

	// The delay line lengths are prime sample counts tuned at this rate; other
	// rates scale them so the reflection times in seconds stay the same
	static constexpr float DELAY_TUNING_RATE = 44100.0f;

	// (Re)allocates all delay lines for the current sample_rate and clears state.
	// Allocates, so main thread only (constructor / set_sample_rate)
	void allocate_delay_lines();

	struct Settings {
		float room_size = 0.5f;
		float damping = 0.5f;
		float width = 0.7f;
		float mix = 0.3f;
		float pre_delay = 0.02f;
		float diffusion = 0.6f;
	};
	Settings read_settings(const Ref<SynthNoteContext> &context) const;
	// Runs the network for one input sample and returns the wet stereo pair
	// (before width and mix).
	void process_wet(float input, const Settings &s, float &wet_left, float &wet_right);

public:
	// Parameter names
	static const char *PARAM_ROOM_SIZE;
	static const char *PARAM_DAMPING;
	static const char *PARAM_WIDTH;
	static const char *PARAM_MIX;
	static const char *PARAM_PRE_DELAY;
	static const char *PARAM_DIFFUSION;

protected:
	static void _bind_methods();

public:
	Reverb();
	~Reverb();

	float process_sample(float sample, const Ref<SynthNoteContext> &context) override;
	void reset() override;

	// Stereo output (master chain): `width` spreads the two halves of the
	// network across left and right.
	bool is_stereo() const override;
	void process_stereo(float &left, float &right, const Ref<SynthNoteContext> &context) override;

	// Resizes the delay lines for the new rate (main thread, before playback)
	void set_sample_rate(float p_sample_rate) override;

	float get_tail_length() const override;
	Ref<SynthAudioEffect> duplicate() const override;

	// Parameter accessors
	void set_room_size_parameter(const Ref<ModulatedParameter> &param);
	Ref<ModulatedParameter> get_room_size_parameter() const;

	void set_damping_parameter(const Ref<ModulatedParameter> &param);
	Ref<ModulatedParameter> get_damping_parameter() const;

	void set_width_parameter(const Ref<ModulatedParameter> &param);
	Ref<ModulatedParameter> get_width_parameter() const;

	void set_mix_parameter(const Ref<ModulatedParameter> &param);
	Ref<ModulatedParameter> get_mix_parameter() const;

	void set_pre_delay_parameter(const Ref<ModulatedParameter> &param);
	Ref<ModulatedParameter> get_pre_delay_parameter() const;

	void set_diffusion_parameter(const Ref<ModulatedParameter> &param);
	Ref<ModulatedParameter> get_diffusion_parameter() const;
};

} // namespace godot

#endif // REVERB_H
