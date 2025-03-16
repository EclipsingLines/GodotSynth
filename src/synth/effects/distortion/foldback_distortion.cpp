#include "foldback_distortion.h"
#include <cmath>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/math.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

namespace godot {

// Define parameter name constants
const char *FoldbackDistortion::PARAM_DRIVE = "drive";
const char *FoldbackDistortion::PARAM_MIX = "mix";
const char *FoldbackDistortion::PARAM_OUTPUT_GAIN = "output_gain";
const char *FoldbackDistortion::PARAM_THRESHOLD = "threshold";
const char *FoldbackDistortion::PARAM_ITERATIONS = "iterations";

void FoldbackDistortion::_bind_methods() {
	// Bind base value accessors
	ClassDB::bind_method(D_METHOD("set_threshold_base_value", "value"), &FoldbackDistortion::set_threshold_base_value);
	ClassDB::bind_method(D_METHOD("get_threshold_base_value"), &FoldbackDistortion::get_threshold_base_value);
	ClassDB::bind_method(D_METHOD("set_iterations_base_value", "value"), &FoldbackDistortion::set_iterations_base_value);
	ClassDB::bind_method(D_METHOD("get_iterations_base_value"), &FoldbackDistortion::get_iterations_base_value);
	ClassDB::bind_method(D_METHOD("set_drive_base_value", "value"), &FoldbackDistortion::set_drive_base_value);
	ClassDB::bind_method(D_METHOD("get_drive_base_value"), &FoldbackDistortion::get_drive_base_value);
	ClassDB::bind_method(D_METHOD("set_mix_base_value", "value"), &FoldbackDistortion::set_mix_base_value);
	ClassDB::bind_method(D_METHOD("get_mix_base_value"), &FoldbackDistortion::get_mix_base_value);
	ClassDB::bind_method(D_METHOD("set_output_gain_base_value", "value"), &FoldbackDistortion::set_output_gain_base_value);
	ClassDB::bind_method(D_METHOD("get_output_gain_base_value"), &FoldbackDistortion::get_output_gain_base_value);

	// Bind parameter accessors

	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "drive", PROPERTY_HINT_RANGE, "0,1,0.01"),
			"set_drive_base_value", "get_drive_base_value");
	ClassDB::bind_method(D_METHOD("set_drive_parameter", "param"), &FoldbackDistortion::set_drive_parameter);
	ClassDB::bind_method(D_METHOD("get_drive_parameter"), &FoldbackDistortion::get_drive_parameter);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "drive_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
			"set_drive_parameter", "get_drive_parameter");

	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "mix", PROPERTY_HINT_RANGE, "0,1,0.01"),
			"set_mix_base_value", "get_mix_base_value");
	ClassDB::bind_method(D_METHOD("set_mix_parameter", "param"), &FoldbackDistortion::set_mix_parameter);
	ClassDB::bind_method(D_METHOD("get_mix_parameter"), &FoldbackDistortion::get_mix_parameter);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "mix_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
			"set_mix_parameter", "get_mix_parameter");

	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "output_gain", PROPERTY_HINT_RANGE, "0,1,0.01"),
			"set_output_gain_base_value", "get_output_gain_base_value");
	ClassDB::bind_method(D_METHOD("set_output_gain_parameter", "param"), &FoldbackDistortion::set_output_gain_parameter);
	ClassDB::bind_method(D_METHOD("get_output_gain_parameter"), &FoldbackDistortion::get_output_gain_parameter);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "output_gain_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
			"set_output_gain_parameter", "get_output_gain_parameter");

	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "threshold", PROPERTY_HINT_RANGE, "0,1,0.01"),
			"set_threshold_base_value", "get_threshold_base_value");
	ClassDB::bind_method(D_METHOD("set_threshold_parameter", "param"), &FoldbackDistortion::set_threshold_parameter);
	ClassDB::bind_method(D_METHOD("get_threshold_parameter"), &FoldbackDistortion::get_threshold_parameter);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "threshold_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
			"set_threshold_parameter", "get_threshold_parameter");

	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "iterations", PROPERTY_HINT_RANGE, "0,1,0.01"),
			"set_iterations_base_value", "get_iterations_base_value");
	ClassDB::bind_method(D_METHOD("set_iterations_parameter", "param"), &FoldbackDistortion::set_iterations_parameter);
	ClassDB::bind_method(D_METHOD("get_iterations_parameter"), &FoldbackDistortion::get_iterations_parameter);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "iterations_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
			"set_iterations_parameter", "get_iterations_parameter");
}

FoldbackDistortion::FoldbackDistortion() {
	// Create default parameters
	Ref<ModulatedParameter> drive_param = memnew(ModulatedParameter);
	drive_param->set_base_value(0.5f); // 50% drive
	drive_param->set_mod_min(0.0f); // No drive
	drive_param->set_mod_max(1.0f); // Maximum drive
	set_parameter(PARAM_DRIVE, drive_param);

	Ref<ModulatedParameter> mix_param = memnew(ModulatedParameter);
	mix_param->set_base_value(1.0f); // 100% wet by default
	mix_param->set_mod_min(0.0f); // Dry only
	mix_param->set_mod_max(1.0f); // Wet only
	set_parameter(PARAM_MIX, mix_param);

	Ref<ModulatedParameter> output_gain_param = memnew(ModulatedParameter);
	output_gain_param->set_base_value(0.7f); // Slight reduction to prevent clipping
	output_gain_param->set_mod_min(0.0f); // Silence
	output_gain_param->set_mod_max(1.5f); // Boost
	set_parameter(PARAM_OUTPUT_GAIN, output_gain_param);

	Ref<ModulatedParameter> threshold_param = memnew(ModulatedParameter);
	threshold_param->set_base_value(0.5f); // Medium threshold
	threshold_param->set_mod_min(0.1f); // Low threshold (more folding)
	threshold_param->set_mod_max(1.0f); // High threshold (less folding)
	set_parameter(PARAM_THRESHOLD, threshold_param);

	Ref<ModulatedParameter> iterations_param = memnew(ModulatedParameter);
	iterations_param->set_base_value(0.3f); // 30% iterations (maps to ~3)
	iterations_param->set_mod_min(0.0f); // Minimum iterations (1)
	iterations_param->set_mod_max(1.0f); // Maximum iterations (10)
	set_parameter(PARAM_ITERATIONS, iterations_param);
}

FoldbackDistortion::~FoldbackDistortion() {
	// Clean up resources
}

float FoldbackDistortion::process_sample(float sample, const Ref<SynthNoteContext> &context) {
	if (!context.is_valid())
		return sample; // Return original sample if context is invalid

	// Get parameter values
	float drive = 0.5f; // Default: 50% drive
	float mix = 1.0f; // Default: 100% wet
	float output_gain = 0.7f; // Default: 70% output gain
	float threshold = 0.5f; // Default: medium threshold
	float iterations_norm = 0.3f; // Default: 30% iterations

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

	Ref<ModulatedParameter> threshold_param = get_parameter(PARAM_THRESHOLD);
	if (threshold_param.is_valid()) {
		threshold = threshold_param->get_value(context);
	}

	Ref<ModulatedParameter> iterations_param = get_parameter(PARAM_ITERATIONS);
	if (iterations_param.is_valid()) {
		iterations_norm = iterations_param->get_value(context);
	}

	// Scale drive to get more extreme effect at higher values
	float scaled_drive = 1.0f + drive * 19.0f; // Range 1-20

	// Threshold determines where folding begins
	float t = threshold * 0.9f + 0.1f; // Range 0.1-1.0

	// Map normalized iterations to actual iteration count (1-10)
	int max_iterations = 1 + static_cast<int>(iterations_norm * 9.0f);

	float input = sample;
	float x = input * scaled_drive;

	// Apply foldback distortion with multiple iterations
	for (int iter = 0; iter < max_iterations; iter++) {
		if (x > t || x < -t) {
			if (x > t) {
				x = 2.0f * t - x;
			} else if (x < -t) {
				x = -2.0f * t - x;
			}
		} else {
			// If we're within threshold, no need for more iterations
			break;
		}
	}

	float distorted = x;

	// Mix dry/wet
	float output = input * (1.0f - mix) + distorted * mix;

	// Apply output gain
	return output * output_gain;
}

void FoldbackDistortion::reset() {
	// No state to reset for this effect
}

float FoldbackDistortion::get_tail_length() const {
	// Distortion effects don't have a tail
	return 0.0f;
}

Ref<SynthAudioEffect> FoldbackDistortion::duplicate() const {
	Ref<FoldbackDistortion> new_effect = memnew(FoldbackDistortion);

	// Copy parameters
	Dictionary params = get_parameters();
	Array param_names = params.keys();
	for (int i = 0; i < param_names.size(); i++) {
		String name = param_names[i];
		Ref<ModulatedParameter> param = params[name];
		if (param.is_valid()) {
			Ref<ModulatedParameter> new_param = memnew(ModulatedParameter);
			new_param->set_base_value(param->get_base_value());
			new_param->set_mod_min(param->get_mod_min());
			new_param->set_mod_max(param->get_mod_max());

			// Copy modulation source if available
			Ref<ModulationSource> mod_source = param->get_mod_source();
			if (mod_source.is_valid()) {
				new_param->set_mod_source(mod_source);
			}

			new_effect->set_parameter(name, new_param);
		}
	}

	return new_effect;
}

// Parameter accessors
void FoldbackDistortion::set_drive_parameter(const Ref<ModulatedParameter> &param) {
	if (param.is_valid()) {
		set_parameter(PARAM_DRIVE, param);
	}
}

Ref<ModulatedParameter> FoldbackDistortion::get_drive_parameter() const {
	return get_parameter(PARAM_DRIVE);
}

void FoldbackDistortion::set_mix_parameter(const Ref<ModulatedParameter> &param) {
	if (param.is_valid()) {
		set_parameter(PARAM_MIX, param);
	}
}

Ref<ModulatedParameter> FoldbackDistortion::get_mix_parameter() const {
	return get_parameter(PARAM_MIX);
}

void FoldbackDistortion::set_output_gain_parameter(const Ref<ModulatedParameter> &param) {
	if (param.is_valid()) {
		set_parameter(PARAM_OUTPUT_GAIN, param);
	}
}

Ref<ModulatedParameter> FoldbackDistortion::get_output_gain_parameter() const {
	return get_parameter(PARAM_OUTPUT_GAIN);
}

void FoldbackDistortion::set_threshold_parameter(const Ref<ModulatedParameter> &param) {
	if (param.is_valid()) {
		set_parameter(PARAM_THRESHOLD, param);
	}
}

Ref<ModulatedParameter> FoldbackDistortion::get_threshold_parameter() const {
	return get_parameter(PARAM_THRESHOLD);
}

void FoldbackDistortion::set_iterations_parameter(const Ref<ModulatedParameter> &param) {
	if (param.is_valid()) {
		set_parameter(PARAM_ITERATIONS, param);
	}
}

Ref<ModulatedParameter> FoldbackDistortion::get_iterations_parameter() const {
	return get_parameter(PARAM_ITERATIONS);
}

void FoldbackDistortion::set_threshold_base_value(float p_value) {
	Ref<ModulatedParameter> param = get_parameter(PARAM_THRESHOLD);
	if (param.is_valid()) {
		param->set_base_value(p_value);
	}
}

float FoldbackDistortion::get_threshold_base_value() const {
	return get_parameter(PARAM_THRESHOLD)->get_base_value();
}

void FoldbackDistortion::set_iterations_base_value(float p_value) {
	Ref<ModulatedParameter> param = get_parameter(PARAM_ITERATIONS);
	if (param.is_valid()) {
		param->set_base_value(p_value);
	}
}

float FoldbackDistortion::get_iterations_base_value() const {
	return get_parameter(PARAM_ITERATIONS)->get_base_value();
}

void FoldbackDistortion::set_drive_base_value(float p_value) {
	Ref<ModulatedParameter> param = get_parameter(PARAM_DRIVE);
	if (param.is_valid()) {
		param->set_base_value(p_value);
	}
}

float FoldbackDistortion::get_drive_base_value() const {
	return get_parameter(PARAM_DRIVE)->get_base_value();
}

void FoldbackDistortion::set_mix_base_value(float p_value) {
	Ref<ModulatedParameter> param = get_parameter(PARAM_MIX);
	if (param.is_valid()) {
		param->set_base_value(p_value);
	}
}

float FoldbackDistortion::get_mix_base_value() const {
	return get_parameter(PARAM_MIX)->get_base_value();
}

void FoldbackDistortion::set_output_gain_base_value(float p_value) {
	Ref<ModulatedParameter> param = get_parameter(PARAM_OUTPUT_GAIN);
	if (param.is_valid()) {
		param->set_base_value(p_value);
	}
}

float FoldbackDistortion::get_output_gain_base_value() const {
	return get_parameter(PARAM_OUTPUT_GAIN)->get_base_value();
}

} // namespace godot
