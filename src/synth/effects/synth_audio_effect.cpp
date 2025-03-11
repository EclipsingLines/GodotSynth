#include "synth_audio_effect.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

namespace godot {

void SynthAudioEffect::_bind_methods() {
	ClassDB::bind_method(D_METHOD("process_sample", "sample", "context"), &SynthAudioEffect::process_sample);
	ClassDB::bind_method(D_METHOD("reset"), &SynthAudioEffect::reset);
	ClassDB::bind_method(D_METHOD("get_tail_length"), &SynthAudioEffect::get_tail_length);

	ClassDB::bind_method(D_METHOD("set_parameter", "name", "param"), &SynthAudioEffect::set_parameter);
	ClassDB::bind_method(D_METHOD("get_parameter", "name"), &SynthAudioEffect::get_parameter);
	ClassDB::bind_method(D_METHOD("get_parameters"), &SynthAudioEffect::get_parameters);
	ClassDB::bind_method(D_METHOD("add_parameter", "name", "param"), &SynthAudioEffect::add_parameter);
}

void SynthAudioEffect::add_parameter(const String &p_name, const Ref<ModulatedParameter> &p_param) {
	parameters[p_name] = p_param;
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
	}
}

Ref<ModulatedParameter> SynthAudioEffect::get_parameter(const String &name) const {
	if (parameters.has(name)) {
		return parameters[name];
	}
	return Ref<ModulatedParameter>();
}

Dictionary SynthAudioEffect::get_parameters() const {
	return parameters;
}

} // namespace godot
