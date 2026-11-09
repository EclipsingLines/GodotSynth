#ifndef EFFECT_CHAIN_H
#define EFFECT_CHAIN_H

#include "../core/synth_note_context.h"
#include "synth_audio_effect.h"
#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <vector>

namespace godot {

class EffectChain : public Resource {
	GDCLASS(EffectChain, Resource)

private:
	TypedArray<SynthAudioEffect> effects;
	float sample_rate = 44100.0f;

	// Raw pointers to `effects` for the audio thread, so process_sample()
	// doesn't go through Variant for every effect on every sample. `effects`
	// owns them. Rebuilt on the main thread by set_effects(), add_effect() and
	// set_sample_rate() (engines call it when the chain is attached, which
	// also picks up edits made in place to the get_effects() array).
	std::vector<SynthAudioEffect *> effect_ptrs;

	// Stereo (master chain) only: for each effect that isn't is_stereo(), a
	// second copy that processes the right channel. Null for stereo effects.
	std::vector<Ref<SynthAudioEffect>> right_copies;
	bool stereo_prepared = false;

	void rebuild_effect_ptrs();

protected:
	static void _bind_methods();

public:
	EffectChain();
	~EffectChain();

	int get_effect_count() const;
	void set_effects(const TypedArray<SynthAudioEffect> &p_effects);

	TypedArray<SynthAudioEffect> get_effects() const;

	// Add a single effect to the chain
	void add_effect(const Ref<SynthAudioEffect> &effect);

	// Get the maximum tail length from all effects in the chain
	float get_max_tail_length() const;

	// Create a duplicate of this effect chain with new effect instances
	Ref<EffectChain> duplicate() const;

	// Main thread only: passes the sample rate to every effect in the chain.
	void set_sample_rate(float p_sample_rate);
	float get_sample_rate() const;

	float process_sample(const float &sample, const Ref<SynthNoteContext> &context);
	void reset();

	// Main thread: gets the chain ready for process_stereo() (creates the
	// right-channel copies, which allocates). Call after set_sample_rate().
	void prepare_stereo();
	// Audio thread: runs the chain on one stereo frame. prepare_stereo() must
	// have been called.
	void process_stereo(float &left, float &right, const Ref<SynthNoteContext> &context);
};

} // namespace godot

#endif // EFFECT_CHAIN_H
