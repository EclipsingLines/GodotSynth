#include "audio_stream_generator_engine.h"
#include "../effects/effect_chain.h"
#include "modulated_parameter.h"
#include "synth_note_context.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

namespace godot {

void AudioStreamGeneratorEngine::_bind_methods() {
	ClassDB::bind_method(D_METHOD("process_block", "buffer", "context"), &AudioStreamGeneratorEngine::process_block);
	ClassDB::bind_method(D_METHOD("reset"), &AudioStreamGeneratorEngine::reset);

	ClassDB::bind_method(D_METHOD("set_sample_rate", "sample_rate"), &AudioStreamGeneratorEngine::set_sample_rate);
	ClassDB::bind_method(D_METHOD("get_sample_rate"), &AudioStreamGeneratorEngine::get_sample_rate);

	ClassDB::bind_method(D_METHOD("set_effect_chain", "chain"), &AudioStreamGeneratorEngine::set_effect_chain);
	ClassDB::bind_method(D_METHOD("get_effect_chain"), &AudioStreamGeneratorEngine::get_effect_chain);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "effect_chain", PROPERTY_HINT_RESOURCE_TYPE, "EffectChain"),
			"set_effect_chain", "get_effect_chain");

	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "sample_rate"), "set_sample_rate", "get_sample_rate");
}

AudioStreamGeneratorEngine::AudioStreamGeneratorEngine() {
	effect_chain = Ref<EffectChain>();
}

AudioStreamGeneratorEngine::~AudioStreamGeneratorEngine() {
}

PackedFloat32Array AudioStreamGeneratorEngine::process_block(int buffer_size, const Ref<SynthNoteContext> &context, const bool &use_fast_pitch) {
	// Create a new buffer filled with silence
	PackedFloat32Array output_buffer;
	output_buffer.resize(buffer_size);
	for (int i = 0; i < buffer_size; i++) {
		output_buffer[i] = 0.0f;
	}
	return output_buffer;
}

void AudioStreamGeneratorEngine::render(float *out, int frames, const Ref<SynthNoteContext> &context, bool use_fast_pitch) {
	PackedFloat32Array block = process_block(frames, context, use_fast_pitch);
	const float *src = block.ptr();
	const int count = MIN(frames, (int)block.size());
	for (int i = 0; i < count; i++) {
		out[i] = src[i];
	}
	for (int i = count; i < frames; i++) {
		out[i] = 0.0f;
	}
}

void AudioStreamGeneratorEngine::set_effect_chain(const Ref<EffectChain> &p_chain) {
	effect_chain = p_chain;

	// Reset the effect chain when it's set
	if (effect_chain.is_valid()) {
		effect_chain->set_sample_rate(sample_rate);

		// Main thread: run one silent sample and the tail query so each
		// effect's first parameter lookups (which allocate once) happen here
		// and not on the audio thread, then clear what that sample left behind.
		Ref<SynthNoteContext> warmup;
		warmup.instantiate();
		effect_chain->process_sample(0.0f, warmup);
		effect_chain->get_max_tail_length();

		effect_chain->reset();
	}
}

Ref<EffectChain> AudioStreamGeneratorEngine::get_effect_chain() const {
	return effect_chain;
}

void AudioStreamGeneratorEngine::reset() {
	// Base implementation does nothing

	// Reset effect chain if available
	if (effect_chain.is_valid()) {
		effect_chain->reset();
	}
}

void AudioStreamGeneratorEngine::set_sample_rate(float p_sample_rate) {
	if (p_sample_rate <= 0.0f) {
		return;
	}
	sample_rate = p_sample_rate;
	if (effect_chain.is_valid()) {
		effect_chain->set_sample_rate(sample_rate);
	}
}

float AudioStreamGeneratorEngine::get_sample_rate() const {
	return sample_rate;
}

void AudioStreamGeneratorEngine::set_parameter(const String &name, const Ref<ModulatedParameter> &param) {
	parameters[name] = param;
}

Ref<ModulatedParameter> AudioStreamGeneratorEngine::get_parameter(const String &name) const {
	if (parameters.has(name)) {
		return parameters[name];
	}
	return Ref<ModulatedParameter>();
}

Ref<ModulatedParameter> AudioStreamGeneratorEngine::resolve_parameter(const String &p_name) const {
	Ref<ModulatedParameter> param = get_parameter(p_name);
	if (param.is_valid()) {
		return param;
	}
	return resolve_effect_parameter(effect_chain, p_name);
}

Ref<ModulatedParameter> AudioStreamGeneratorEngine::resolve_effect_parameter(const Ref<EffectChain> &p_chain, const String &p_name) {
	if (p_chain.is_null()) {
		return Ref<ModulatedParameter>();
	}

	int index = 0;
	String param_name;
	if (!parse_effect_name(p_name, index, param_name)) {
		return Ref<ModulatedParameter>();
	}
	TypedArray<SynthAudioEffect> effects = p_chain->get_effects();
	if (index < 0 || index >= effects.size()) {
		return Ref<ModulatedParameter>();
	}
	Ref<SynthAudioEffect> effect = effects[index];
	if (effect.is_null()) {
		return Ref<ModulatedParameter>();
	}
	return effect->get_parameter(param_name);
}

bool AudioStreamGeneratorEngine::parse_effect_name(const String &p_name, int &r_index, String &r_param) {
	if (!p_name.begins_with("fx")) {
		return false;
	}
	const int dot = p_name.find(".");
	if (dot < 0) {
		return false;
	}

	const String digits = p_name.substr(2, dot - 2);
	if (digits.length() < 1 || digits.length() > 3) {
		return false;
	}
	for (int i = 0; i < digits.length(); i++) {
		const char32_t c = digits[i];
		if (c < '0' || c > '9') {
			return false;
		}
	}

	const String param = p_name.substr(dot + 1);
	if (param.is_empty()) {
		return false;
	}

	r_index = digits.to_int();
	r_param = param;
	return true;
}

Ref<AudioStreamGeneratorEngine> AudioStreamGeneratorEngine::duplicate() const {
	// Base implementation - to be overridden by derived classes
	return nullptr;
}

float AudioStreamGeneratorEngine::get_tail_length() const {
	float max_tail_length = 0.0f;

	// Get the maximum tail length from the effect chain
	if (effect_chain.is_valid()) {
		max_tail_length = effect_chain->get_max_tail_length();
	}

	return max_tail_length;
}

bool AudioStreamGeneratorEngine::has_active_tail(const Ref<SynthNoteContext> &context) const {
	if (!context.is_valid() || !context->is_note_off()) {
		return false;
	}

	// Get the time since note off
	double note_off_time = context->get_note_off_time();
	double current_time = context->get_absolute_time();
	double time_since_note_off = current_time - note_off_time;

	// Check if we're still within the tail length
	return time_since_note_off < get_tail_length();
}

Dictionary AudioStreamGeneratorEngine::get_parameters() const {
	return parameters;
}

} // namespace godot
