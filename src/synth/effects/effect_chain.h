#ifndef EFFECT_CHAIN_H
#define EFFECT_CHAIN_H

#include "../core/synth_note_context.h"
#include "synth_audio_effect.h"
#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>

namespace godot {

class EffectChain : public Resource {
	GDCLASS(EffectChain, Resource)

private:
	TypedArray<SynthAudioEffect> effects;

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

	float process_sample(const float &sample, const Ref<SynthNoteContext> &context);
	void reset();
};

} // namespace godot

#endif // EFFECT_CHAIN_H
