#include "effect_chain.h"
#include "../core/synth_note_context.h"
#include "synth_audio_effect.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

namespace godot {

void EffectChain::_bind_methods() {
	ClassDB::bind_method(D_METHOD("process_sample", "sample", "context"), &EffectChain::process_sample);
	ClassDB::bind_method(D_METHOD("reset"), &EffectChain::reset);
	ClassDB::bind_method(D_METHOD("set_effects", "effects"), &EffectChain::set_effects);
	ClassDB::bind_method(D_METHOD("get_effects"), &EffectChain::get_effects);
	ClassDB::bind_method(D_METHOD("add_effect", "effect"), &EffectChain::add_effect);
	ClassDB::bind_method(D_METHOD("get_max_tail_length"), &EffectChain::get_max_tail_length);

	ADD_PROPERTY(PropertyInfo(Variant::ARRAY, "effects", PROPERTY_HINT_TYPE_STRING, String::num(Variant::OBJECT) + "/" + String::num(PROPERTY_HINT_RESOURCE_TYPE) + ":SynthAudioEffect"),
			"set_effects", "get_effects");
}

EffectChain::EffectChain() {
	// Initialize effect chain
}

EffectChain::~EffectChain() {
	// Clean up resources
}

void EffectChain::set_effects(const TypedArray<SynthAudioEffect> &p_effects) {
	effects = p_effects;
}

TypedArray<SynthAudioEffect> EffectChain::get_effects() const {
	return effects;
}

void EffectChain::add_effect(const Ref<SynthAudioEffect> &effect) {
	if (effect.is_valid()) {
		effects.push_back(effect);
	}
}

float EffectChain::get_max_tail_length() const {
	float max_tail_length = 0.0f;

	// Find the maximum tail length from all effects
	for (int i = 0; i < effects.size(); i++) {
		Ref<SynthAudioEffect> effect = effects[i];
		if (effect.is_valid()) {
			max_tail_length = MAX(max_tail_length, effect->get_tail_length());
		}
	}

	return max_tail_length;
}

Ref<EffectChain> EffectChain::duplicate() const {
	Ref<EffectChain> new_chain = memnew(EffectChain);

	UtilityFunctions::print("Duplicating effect chain: " + String::num(effects.size()));

	// Create new instances of each effect
	for (int i = 0; i < effects.size(); i++) {
		Ref<SynthAudioEffect> effect = effects[i];
		if (effect.is_valid()) {
			Ref<SynthAudioEffect> new_effect = effect->duplicate();
			UtilityFunctions::print("Duplicating effect: " + effect->get_name());
			if (new_effect.is_valid()) {
				new_chain->add_effect(new_effect);
				UtilityFunctions::print("Duplicated effect: " + new_effect->get_name());
			}
		}
	}

	return new_chain;
}

float EffectChain::process_sample(const float &sample, const Ref<SynthNoteContext> &context) {
	// Start with the original buffer
	float processed_sample = sample;

	// Process the buffer through each effect in the chain
	for (int i = 0; i < effects.size(); i++) {
		Ref<SynthAudioEffect> effect = effects[i];
		if (effect.is_valid()) {
			processed_sample = effect->process_sample(processed_sample, context);
		} else {
			UtilityFunctions::print("Effect not valid - " + effect->get_name());
		}
	}

	return processed_sample;
}

void EffectChain::reset() {
	// Reset all effects in the chain
	for (int i = 0; i < effects.size(); i++) {
		Ref<SynthAudioEffect> effect = effects[i];
		if (effect.is_valid()) {
			effect->reset();
		}
	}
}

} // namespace godot
