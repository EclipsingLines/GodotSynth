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
