#include "rectifier_distortion.h"
#include <cmath>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

namespace godot {

// Define parameter name constants
const char *RectifierDistortion::PARAM_MODE = "mode";
const char *RectifierDistortion::PARAM_ASYMMETRY = "asymmetry";

void RectifierDistortion::_bind_methods() {
	// Bind base value accessors
	ClassDB::bind_method(D_METHOD("set_drive_base_value", "value"), &RectifierDistortion::set_drive_base_value);
	ClassDB::bind_method(D_METHOD("get_drive_base_value"), &RectifierDistortion::get_drive_base_value);
	ClassDB::bind_method(D_METHOD("set_mix_base_value", "value"), &RectifierDistortion::set_mix_base_value);
	ClassDB::bind_method(D_METHOD("get_mix_base_value"), &RectifierDistortion::get_mix_base_value);
	ClassDB::bind_method(D_METHOD("set_output_gain_base_value", "value"), &RectifierDistortion::set_output_gain_base_value);
	ClassDB::bind_method(D_METHOD("get_output_gain_base_value"), &RectifierDistortion::get_output_gain_base_value);

	ClassDB::bind_method(D_METHOD("set_mode_base_value", "value"), &RectifierDistortion::set_mode_base_value);
	ClassDB::bind_method(D_METHOD("get_mode_base_value"), &RectifierDistortion::get_mode_base_value);
	ClassDB::bind_method(D_METHOD("set_asymmetry_base_value", "value"), &RectifierDistortion::set_asymmetry_base_value);
	ClassDB::bind_method(D_METHOD("get_asymmetry_base_value"), &RectifierDistortion::get_asymmetry_base_value);

	// Bind parameter accessors
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "drive", PROPERTY_HINT_RANGE, "0,1,0.01"),
			"set_drive_base_value", "get_drive_base_value");
	ClassDB::bind_method(D_METHOD("set_drive_parameter", "param"), &RectifierDistortion::set_drive_parameter);
	ClassDB::bind_method(D_METHOD("get_drive_parameter"), &RectifierDistortion::get_drive_parameter);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "drive_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
			"set_drive_parameter", "get_drive_parameter");

	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "mix", PROPERTY_HINT_RANGE, "0,1,0.01"),
			"set_mix_base_value", "get_mix_base_value");
	ClassDB::bind_method(D_METHOD("set_mix_parameter", "param"), &RectifierDistortion::set_mix_parameter);
	ClassDB::bind_method(D_METHOD("get_mix_parameter"), &RectifierDistortion::get_mix_parameter);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "mix_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
			"set_mix_parameter", "get_mix_parameter");

	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "output_gain", PROPERTY_HINT_RANGE, "0,1,0.01"),
			"set_output_gain_base_value", "get_output_gain_base_value");
	ClassDB::bind_method(D_METHOD("set_output_gain_parameter", "param"), &RectifierDistortion::set_output_gain_parameter);
	ClassDB::bind_method(D_METHOD("get_output_gain_parameter"), &RectifierDistortion::get_output_gain_parameter);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "output_gain_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
			"set_output_gain_parameter", "get_output_gain_parameter");

	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "mode", PROPERTY_HINT_RANGE, "0,1,0.01"),
			"set_mode_base_value", "get_mode_base_value");
	ClassDB::bind_method(D_METHOD("set_mode_parameter", "param"), &RectifierDistortion::set_mode_parameter);
	ClassDB::bind_method(D_METHOD("get_mode_parameter"), &RectifierDistortion::get_mode_parameter);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "mode_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
			"set_mode_parameter", "get_mode_parameter");

	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "asymmetry", PROPERTY_HINT_RANGE, "0,1,0.01"),
			"set_asymmetry_base_value", "get_asymmetry_base_value");
	ClassDB::bind_method(D_METHOD("set_asymmetry_parameter", "param"), &RectifierDistortion::set_asymmetry_parameter);
	ClassDB::bind_method(D_METHOD("get_asymmetry_parameter"), &RectifierDistortion::get_asymmetry_parameter);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "asymmetry_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
			"set_asymmetry_parameter", "get_asymmetry_parameter");

	// Register the RectifierMode enum
	BIND_ENUM_CONSTANT(HALF_WAVE);
	BIND_ENUM_CONSTANT(FULL_WAVE);
	BIND_ENUM_CONSTANT(ASYMMETRIC);
}

RectifierDistortion::RectifierDistortion() {
	// Create default parameters

	// Mode parameter (defaults to HALF_WAVE)
	Ref<ModulatedParameter> mode_param = memnew(ModulatedParameter);
	mode_param->set_base_value(HALF_WAVE);
	mode_param->set_mod_min(HALF_WAVE);
	mode_param->set_mod_max(ASYMMETRIC);
	set_parameter(PARAM_MODE, mode_param);

	// Asymmetry parameter (for ASYMMETRIC mode)
	Ref<ModulatedParameter> asymmetry_param = memnew(ModulatedParameter);
	asymmetry_param->set_base_value(0.5f); // 0.5 = symmetric, <0.5 = more negative, >0.5 = more positive
	asymmetry_param->set_mod_min(0.0f);
	asymmetry_param->set_mod_max(1.0f);
	set_parameter(PARAM_ASYMMETRY, asymmetry_param);

	// Initialize drive, mix, and output_gain parameters from parent class
	Ref<ModulatedParameter> drive_param = memnew(ModulatedParameter);
	drive_param->set_base_value(0.5f);
	drive_param->set_mod_min(0.0f);
	drive_param->set_mod_max(1.0f);
	set_parameter(PARAM_DRIVE, drive_param);

	Ref<ModulatedParameter> mix_param = memnew(ModulatedParameter);
	mix_param->set_base_value(1.0f); // 100% wet by default
	mix_param->set_mod_min(0.0f);
	mix_param->set_mod_max(1.0f);
	set_parameter(PARAM_MIX, mix_param);

	Ref<ModulatedParameter> output_gain_param = memnew(ModulatedParameter);
	output_gain_param->set_base_value(1.0f); // Unity gain
	output_gain_param->set_mod_min(0.0f);
	output_gain_param->set_mod_max(2.0f);
	set_parameter(PARAM_OUTPUT_GAIN, output_gain_param);
}

RectifierDistortion::~RectifierDistortion() {
	// Nothing to clean up
}

float RectifierDistortion::process_sample(float sample, const Ref<SynthNoteContext> &context) {
	if (!context.is_valid())
		return sample; // Return original sample if context is invalid

	// Get parameter values
	int mode = HALF_WAVE; // Default mode
	float asymmetry = 0.5f; // Default asymmetry (symmetric)
	float drive = 0.5f; // Default drive
	float mix = 1.0f; // Default mix (100% wet)
	float output_gain = 1.0f; // Default output gain

	Ref<ModulatedParameter> mode_param = get_parameter(PARAM_MODE);
	if (mode_param.is_valid()) {
		mode = static_cast<int>(mode_param->get_value(context));
	}

	Ref<ModulatedParameter> asymmetry_param = get_parameter(PARAM_ASYMMETRY);
	if (asymmetry_param.is_valid()) {
		asymmetry = asymmetry_param->get_value(context);
	}

	Ref<ModulatedParameter> drive_param = get_parameter(PARAM_DRIVE);
	if (drive_param.is_valid()) {
		drive = drive_param->get_value(context);
	}

	Ref<ModulatedParameter> mix_param = get_parameter(PARAM_MIX);
	if (mix_param.is_valid()) {
		mix = mix_param->get_value(context);
	}

	Ref<ModulatedParameter> output_gain_param = get_parameter(PARAM_OUTPUT_GAIN);
	if (output_gain_param.is_valid()) {
		output_gain = output_gain_param->get_value(context);
	}

	// Scale drive for more useful range (0.1 to 10)
	drive = 0.1f + drive * 9.9f;

	float input = sample;
	float dry = input;

	// Apply drive (pre-gain)
	input *= drive;

	// Apply rectification based on mode
	switch (mode) {
		case HALF_WAVE:
			// Half-wave rectification (keep only positive values)
			input = input > 0.0f ? input : 0.0f;
			break;

		case FULL_WAVE:
			// Full-wave rectification (convert negative to positive)
			input = std::abs(input);
			break;

		case ASYMMETRIC:
			// Asymmetric rectification (different scaling for positive and negative)
			if (input > 0.0f) {
				// Scale positive values by asymmetry
				input *= asymmetry * 2.0f;
			} else {
				// Scale negative values by (1-asymmetry)
				input *= (1.0f - asymmetry) * 2.0f;
				input = -input; // Flip to positive
			}
			break;
	}

	// Apply output gain
	input *= output_gain;

	// Mix dry and wet signals
	return dry * (1.0f - mix) + input * mix;
}

void RectifierDistortion::reset() {
	// No internal state to reset
}

float RectifierDistortion::get_tail_length() const {
	// No tail for this effect
	return 0.0f;
}

Ref<SynthAudioEffect> RectifierDistortion::duplicate() const {
	Ref<RectifierDistortion> copy = memnew(RectifierDistortion);

	// Copy parameters
	Dictionary params = get_parameters();
	Array param_names = params.keys();

	for (int i = 0; i < param_names.size(); i++) {
		String name = param_names[i];
		Ref<ModulatedParameter> param = params[name];
		if (param.is_valid()) {
			Ref<ModulatedParameter> param_copy = param->duplicate();
			copy->set_parameter(name, param_copy);
		}
	}

	return copy;
}

// Parameter accessors
void RectifierDistortion::set_mode_parameter(const Ref<ModulatedParameter> &param) {
	if (param.is_valid()) {
		set_parameter(PARAM_MODE, param);
	}
}

Ref<ModulatedParameter> RectifierDistortion::get_mode_parameter() const {
	return get_parameter(PARAM_MODE);
}

void RectifierDistortion::set_asymmetry_parameter(const Ref<ModulatedParameter> &param) {
	if (param.is_valid()) {
		set_parameter(PARAM_ASYMMETRY, param);
	}
}

Ref<ModulatedParameter> RectifierDistortion::get_asymmetry_parameter() const {
	return get_parameter(PARAM_ASYMMETRY);
}

void RectifierDistortion::set_mode_base_value(float p_value) {
	Ref<ModulatedParameter> param = get_parameter(PARAM_MODE);
	if (param.is_valid()) {
		param->set_base_value(p_value);
	}
}

float RectifierDistortion::get_mode_base_value() const {
	return get_parameter(PARAM_MODE)->get_base_value();
}

void RectifierDistortion::set_asymmetry_base_value(float p_value) {
	Ref<ModulatedParameter> param = get_parameter(PARAM_ASYMMETRY);
	if (param.is_valid()) {
		param->set_base_value(p_value);
	}
}

float RectifierDistortion::get_asymmetry_base_value() const {
	return get_parameter(PARAM_ASYMMETRY)->get_base_value();
}

void RectifierDistortion::set_drive_parameter(const Ref<ModulatedParameter> &param) {
	if (param.is_valid()) {
		set_parameter(PARAM_DRIVE, param);
	}
}

Ref<ModulatedParameter> RectifierDistortion::get_drive_parameter() const {
	return get_parameter(PARAM_DRIVE);
}

void RectifierDistortion::set_mix_parameter(const Ref<ModulatedParameter> &param) {
	if (param.is_valid()) {
		set_parameter(PARAM_MIX, param);
	}
}

Ref<ModulatedParameter> RectifierDistortion::get_mix_parameter() const {
	return get_parameter(PARAM_MIX);
}

void RectifierDistortion::set_output_gain_parameter(const Ref<ModulatedParameter> &param) {
	if (param.is_valid()) {
		set_parameter(PARAM_OUTPUT_GAIN, param);
	}
}

Ref<ModulatedParameter> RectifierDistortion::get_output_gain_parameter() const {
	return get_parameter(PARAM_OUTPUT_GAIN);
}

void RectifierDistortion::set_drive_base_value(float p_value) {
	Ref<ModulatedParameter> param = get_parameter(PARAM_DRIVE);
	if (param.is_valid()) {
		param->set_base_value(p_value);
	}
}

float RectifierDistortion::get_drive_base_value() const {
	return get_parameter(PARAM_DRIVE)->get_base_value();
}

void RectifierDistortion::set_mix_base_value(float p_value) {
	Ref<ModulatedParameter> param = get_parameter(PARAM_MIX);
	if (param.is_valid()) {
		param->set_base_value(p_value);
	}
}

float RectifierDistortion::get_mix_base_value() const {
	return get_parameter(PARAM_MIX)->get_base_value();
}

void RectifierDistortion::set_output_gain_base_value(float p_value) {
	Ref<ModulatedParameter> param = get_parameter(PARAM_OUTPUT_GAIN);
	if (param.is_valid()) {
		param->set_base_value(p_value);
	}
}

float RectifierDistortion::get_output_gain_base_value() const {
	return get_parameter(PARAM_OUTPUT_GAIN)->get_base_value();
}
} // namespace godot
