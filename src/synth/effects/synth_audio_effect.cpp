#include "synth_audio_effect.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

namespace godot {

void SynthAudioEffect::_bind_methods() {
	ClassDB::bind_method(D_METHOD("process_sample", "sample", "context"), &SynthAudioEffect::process_sample);
	ClassDB::bind_method(D_METHOD("reset"), &SynthAudioEffect::reset);
	ClassDB::bind_method(D_METHOD("get_tail_length"), &SynthAudioEffect::get_tail_length);

	ClassDB::bind_method(D_METHOD("set_parameter", "name", "param"), &SynthAudioEffect::set_parameter);
	ClassDB::bind_method(D_METHOD("get_parameter", "name"), static_cast<Ref<ModulatedParameter> (SynthAudioEffect::*)(const String &) const>(&SynthAudioEffect::get_parameter));
	ClassDB::bind_method(D_METHOD("get_parameters"), &SynthAudioEffect::get_parameters);
	ClassDB::bind_method(D_METHOD("add_parameter", "name", "param"), &SynthAudioEffect::add_parameter);
	ClassDB::bind_method(D_METHOD("set_sample_rate", "sample_rate"), &SynthAudioEffect::set_sample_rate);
	ClassDB::bind_method(D_METHOD("get_sample_rate"), &SynthAudioEffect::get_sample_rate);
}

void SynthAudioEffect::set_sample_rate(float p_sample_rate) {
	if (p_sample_rate > 0.0f) {
		sample_rate = p_sample_rate;
	}
}

float SynthAudioEffect::get_sample_rate() const {
	return sample_rate;
}

void SynthAudioEffect::add_parameter(const String &p_name, const Ref<ModulatedParameter> &p_param) {
	parameters[p_name] = p_param;
	param_cache_count = 0;
}

SynthAudioEffect::SynthAudioEffect() {
	// Initialize base audio effect
}

SynthAudioEffect::~SynthAudioEffect() {
	// Clean up resources
}

float SynthAudioEffect::process_sample(float sample, const Ref<SynthNoteContext> &context) {
	// Base implementation returns the original sample, to be overridden by derived classes
	return sample;
}

void SynthAudioEffect::reset() {
	// Base implementation does nothing, to be overridden by derived classes
}

bool SynthAudioEffect::is_stereo() const {
	return false;
}

void SynthAudioEffect::process_stereo(float &left, float &right, const Ref<SynthNoteContext> &context) {
	// Mono effects: process the mid signal and keep the side as it is.
	// EffectChain doesn't call this for them (it runs a copy per channel).
	float mid = 0.5f * (left + right);
	float side = 0.5f * (left - right);
	mid = process_sample(mid, context);
	left = mid + side;
	right = mid - side;
}

float SynthAudioEffect::get_tail_length() const {
	// Base implementation returns 0 (no tail)
	return 0.0f;
}

Ref<SynthAudioEffect> SynthAudioEffect::duplicate() const {
	// Base implementation - to be overridden by derived classes
	return nullptr;
}

void SynthAudioEffect::set_parameter(const String &name, const Ref<ModulatedParameter> &param) {
	if (param.is_valid()) {
		parameters[name] = param;
		param_cache_count = 0; // Main thread, before playback (see param_cache)
	}
}

Ref<ModulatedParameter> SynthAudioEffect::get_parameter(const String &name) const {
	if (parameters.has(name)) {
		return parameters[name];
	}
	return Ref<ModulatedParameter>();
}

Ref<ModulatedParameter> SynthAudioEffect::get_parameter(const char *name) const {
	for (int i = 0; i < param_cache_count; i++) {
		if (param_cache[i].key == name) {
			return Ref<ModulatedParameter>(param_cache[i].param);
		}
	}

	// First lookup of this name: go through the Dictionary once and remember
	// the result (a missing parameter is cached as null too).
	Ref<ModulatedParameter> param = get_parameter(String(name));
	if (param_cache_count < PARAM_CACHE_SIZE) {
		param_cache[param_cache_count].key = name;
		param_cache[param_cache_count].param = param.is_valid() ? param.ptr() : nullptr;
		param_cache_count++;
	}
	return param;
}

Dictionary SynthAudioEffect::get_parameters() const {
	return parameters;
}

} // namespace godot
