#include "audio_stream_generator_engine.h"
#include "../effects/effect_chain.h"
#include "modulated_parameter.h"
#include "synth_note_context.h"
#include "wave_helper_cache.h"
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

	// Initialize the waveform cache if it doesn't exist
	if (!WaveHelperCache::get_singleton()) {
		Ref<WaveHelperCache> cache = memnew(WaveHelperCache);
		cache->initialize();
	}
}

AudioStreamGeneratorEngine::~AudioStreamGeneratorEngine() {
}

PackedFloat32Array AudioStreamGeneratorEngine::process_block(int buffer_size, const Ref<SynthNoteContext> &context) {
	// Create a new buffer filled with silence
	PackedFloat32Array output_buffer;
	output_buffer.resize(buffer_size);
	for (int i = 0; i < buffer_size; i++) {
		output_buffer[i] = 0.0f;
	}
	return output_buffer;
}

void AudioStreamGeneratorEngine::set_effect_chain(const Ref<EffectChain> &p_chain) {
	effect_chain = p_chain;

	// Reset the effect chain when it's set
	if (effect_chain.is_valid()) {
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

	// Note: We don't reset the waveform cache as it's shared across all engines
}

void AudioStreamGeneratorEngine::set_sample_rate(float p_sample_rate) {
	sample_rate = p_sample_rate;
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
