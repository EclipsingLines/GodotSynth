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
	ClassDB::bind_method(D_METHOD("set_sample_rate", "sample_rate"), &EffectChain::set_sample_rate);
	ClassDB::bind_method(D_METHOD("get_sample_rate"), &EffectChain::get_sample_rate);

	ADD_PROPERTY(PropertyInfo(Variant::ARRAY, "effects", PROPERTY_HINT_TYPE_STRING, String::num(Variant::OBJECT) + "/" + String::num(PROPERTY_HINT_RESOURCE_TYPE) + ":SynthAudioEffect"),
			"set_effects", "get_effects");
}

EffectChain::EffectChain() {
}

EffectChain::~EffectChain() {
}

void EffectChain::rebuild_effect_ptrs() {
	effect_ptrs.clear();
	for (int i = 0; i < effects.size(); i++) {
		Ref<SynthAudioEffect> effect = effects[i];
		if (effect.is_valid()) {
			effect_ptrs.push_back(effect.ptr());
		}
	}
	// The right-channel copies follow effect_ptrs; redo them if they existed.
	if (stereo_prepared) {
		prepare_stereo();
	}
}

void EffectChain::set_effects(const TypedArray<SynthAudioEffect> &p_effects) {
	effects = p_effects;
	rebuild_effect_ptrs();
}

void EffectChain::set_sample_rate(float p_sample_rate) {
	if (p_sample_rate <= 0.0f) {
		return;
	}
	sample_rate = p_sample_rate;
	for (int i = 0; i < effects.size(); i++) {
		Ref<SynthAudioEffect> effect = effects[i];
		if (effect.is_valid()) {
			effect->set_sample_rate(sample_rate);
		}
	}
	rebuild_effect_ptrs();
}

float EffectChain::get_sample_rate() const {
	return sample_rate;
}

TypedArray<SynthAudioEffect> EffectChain::get_effects() const {
	return effects;
}

void EffectChain::add_effect(const Ref<SynthAudioEffect> &effect) {
	if (effect.is_valid()) {
		effects.push_back(effect);
		rebuild_effect_ptrs();
	}
}

float EffectChain::get_max_tail_length() const {
	// Called from the audio thread (voice tail checks): no Variant access.
	float max_tail_length = 0.0f;
	for (SynthAudioEffect *effect : effect_ptrs) {
		max_tail_length = MAX(max_tail_length, effect->get_tail_length());
	}
	return max_tail_length;
}

Ref<EffectChain> EffectChain::duplicate() const {
	Ref<EffectChain> new_chain = memnew(EffectChain);

	// Create new instances of each effect
	for (int i = 0; i < effects.size(); i++) {
		Ref<SynthAudioEffect> effect = effects[i];
		if (effect.is_valid()) {
			Ref<SynthAudioEffect> new_effect = effect->duplicate();
			if (new_effect.is_valid()) {
				new_chain->add_effect(new_effect);
			}
		}
	}

	new_chain->set_sample_rate(sample_rate);
	return new_chain;
}

float EffectChain::process_sample(const float &sample, const Ref<SynthNoteContext> &context) {
	float processed_sample = sample;
	for (SynthAudioEffect *effect : effect_ptrs) {
		processed_sample = effect->process_sample(processed_sample, context);
	}
	return processed_sample;
}

void EffectChain::prepare_stereo() {
	stereo_prepared = true;
	right_copies.clear();
	right_copies.resize(effect_ptrs.size());
	for (size_t i = 0; i < effect_ptrs.size(); i++) {
		SynthAudioEffect *effect = effect_ptrs[i];
		if (!effect->is_stereo()) {
			Ref<SynthAudioEffect> copy = effect->duplicate();
			if (copy.is_valid()) {
				copy->set_sample_rate(sample_rate);
				copy->reset();
			}
			right_copies[i] = copy;
		}
	}
}

void EffectChain::process_stereo(float &left, float &right, const Ref<SynthNoteContext> &context) {
	for (size_t i = 0; i < effect_ptrs.size(); i++) {
		SynthAudioEffect *effect = effect_ptrs[i];
		if (effect->is_stereo()) {
			effect->process_stereo(left, right, context);
			continue;
		}
		left = effect->process_sample(left, context);
		if (i < right_copies.size() && right_copies[i].is_valid()) {
			right = right_copies[i]->process_sample(right, context);
		} else {
			// No copy (the effect can't duplicate itself): use the left result.
			right = left;
		}
	}
}

void EffectChain::reset() {
	for (int i = 0; i < effects.size(); i++) {
		Ref<SynthAudioEffect> effect = effects[i];
		if (effect.is_valid()) {
			effect->reset();
		}
	}
	for (Ref<SynthAudioEffect> &copy : right_copies) {
		if (copy.is_valid()) {
			copy->reset();
		}
	}
}

} // namespace godot
