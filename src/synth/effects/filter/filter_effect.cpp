#include "filter_effect.h"
#include "../../core/modulated_parameter.h"
#include "../../core/synth_note_context.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/math.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

namespace godot {

// Define static parameter name constants
const char *FilterEffect::PARAM_CUTOFF = "cutoff";
const char *FilterEffect::PARAM_RESONANCE = "resonance";
const char *FilterEffect::PARAM_GAIN = "gain";

void FilterEffect::_bind_methods() {
	// Bind parameter accessors - base values first, then modulated parameters
	// Cutoff Frequency
	ClassDB::bind_method(D_METHOD("set_cutoff_base_value", "value"), &FilterEffect::set_cutoff_base_value);
	ClassDB::bind_method(D_METHOD("get_cutoff_base_value"), &FilterEffect::get_cutoff_base_value);
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "cutoff_base_value", PROPERTY_HINT_RANGE, "20,20000,1"), "set_cutoff_base_value", "get_cutoff_base_value");

	ClassDB::bind_method(D_METHOD("set_cutoff_parameter", "param"), &FilterEffect::set_cutoff_parameter);
	ClassDB::bind_method(D_METHOD("get_cutoff_parameter"), &FilterEffect::get_cutoff_parameter);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "cutoff_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
			"set_cutoff_parameter", "get_cutoff_parameter");

	// Resonance
	ClassDB::bind_method(D_METHOD("set_resonance_base_value", "value"), &FilterEffect::set_resonance_base_value);
	ClassDB::bind_method(D_METHOD("get_resonance_base_value"), &FilterEffect::get_resonance_base_value);
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "resonance_base_value", PROPERTY_HINT_RANGE, "0,1,0.01"), "set_resonance_base_value", "get_resonance_base_value");

	ClassDB::bind_method(D_METHOD("set_resonance_parameter", "param"), &FilterEffect::set_resonance_parameter);
	ClassDB::bind_method(D_METHOD("get_resonance_parameter"), &FilterEffect::get_resonance_parameter);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "resonance_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
			"set_resonance_parameter", "get_resonance_parameter");

	// Gain
	ClassDB::bind_method(D_METHOD("set_gain_base_value", "value"), &FilterEffect::set_gain_base_value);
	ClassDB::bind_method(D_METHOD("get_gain_base_value"), &FilterEffect::get_gain_base_value);
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "gain_base_value"), "set_gain_base_value", "get_gain_base_value");

	ClassDB::bind_method(D_METHOD("set_gain_parameter", "param"), &FilterEffect::set_gain_parameter);
	ClassDB::bind_method(D_METHOD("get_gain_parameter"), &FilterEffect::get_gain_parameter);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "gain_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
			"set_gain_parameter", "get_gain_parameter");
}

FilterEffect::FilterEffect() :
		z1(0.0f), z2(0.0f), filter_type(FilterType::LOWPASS) {
	// Create default parameters
	Ref<ModulatedParameter> cutoff_param = memnew(ModulatedParameter);
	cutoff_param->set_base_value(1000.0f); // Default to 1000 Hz
	cutoff_param->set_mod_min(20.0f); // Minimum cutoff (20 Hz)
	cutoff_param->set_mod_max(20000.0f); // Maximum cutoff (20 kHz)
	set_parameter(PARAM_CUTOFF, cutoff_param);

	Ref<ModulatedParameter> resonance_param = memnew(ModulatedParameter);
	resonance_param->set_base_value(0.0f); // Default to minimum resonance
	resonance_param->set_mod_min(0.0f); // Minimum resonance
	resonance_param->set_mod_max(1.0f); // Maximum resonance
	set_parameter(PARAM_RESONANCE, resonance_param);

	Ref<ModulatedParameter> gain_param = memnew(ModulatedParameter);
	gain_param->set_base_value(0.0f); // 0 dB gain by default
	gain_param->set_mod_min(-24.0f); // -24 dB
	gain_param->set_mod_max(24.0f); // +24 dB
	set_parameter(PARAM_GAIN, gain_param);
}

FilterEffect::~FilterEffect() {
	// Clean up resources
}

void FilterEffect::reset() {
	z1 = z2 = 0.0f; // Reset filter state
}

void FilterEffect::set_filter_type(int type) {
	filter_type = (FilterType)type;
}

int FilterEffect::get_filter_type() const {
	return (int)filter_type;
}

// Direct parameter accessors
void FilterEffect::set_cutoff_parameter(const Ref<ModulatedParameter> &param) {
	if (param.is_valid()) {
		set_parameter(PARAM_CUTOFF, param);
	}
}

Ref<ModulatedParameter> FilterEffect::get_cutoff_parameter() const {
	return get_parameter(PARAM_CUTOFF);
}

void FilterEffect::set_resonance_parameter(const Ref<ModulatedParameter> &param) {
	if (param.is_valid()) {
		set_parameter(PARAM_RESONANCE, param);
	}
}

Ref<ModulatedParameter> FilterEffect::get_resonance_parameter() const {
	return get_parameter(PARAM_RESONANCE);
}

void FilterEffect::set_gain_parameter(const Ref<ModulatedParameter> &param) {
	if (param.is_valid()) {
		set_parameter(PARAM_GAIN, param);
	}
}

Ref<ModulatedParameter> FilterEffect::get_gain_parameter() const {
	return get_parameter(PARAM_GAIN);
}

// Base value implementations
void FilterEffect::set_cutoff_base_value(float p_value) {
	Ref<ModulatedParameter> param = get_cutoff_parameter();
	if (param.is_valid()) {
		param->set_base_value(p_value);
	}
}

float FilterEffect::get_cutoff_base_value() const {
	Ref<ModulatedParameter> param = get_cutoff_parameter();
	return param.is_valid() ? param->get_base_value() : 0.0f;
}

void FilterEffect::set_resonance_base_value(float p_value) {
	Ref<ModulatedParameter> param = get_resonance_parameter();
	if (param.is_valid()) {
		param->set_base_value(p_value);
	}
}

float FilterEffect::get_resonance_base_value() const {
	Ref<ModulatedParameter> param = get_resonance_parameter();
	return param.is_valid() ? param->get_base_value() : 0.0f;
}

void FilterEffect::set_gain_base_value(float p_value) {
	Ref<ModulatedParameter> param = get_gain_parameter();
	if (param.is_valid()) {
		param->set_base_value(p_value);
	}
}

float FilterEffect::get_gain_base_value() const {
	Ref<ModulatedParameter> param = get_gain_parameter();
	return param.is_valid() ? param->get_base_value() : 0.0f;
}

} // namespace godot
