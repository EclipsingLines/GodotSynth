#include "bitcrush_distortion.h"
#include "distortion_effect.h"
#include <cmath>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/math.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

namespace godot {

// Define parameter name constants
const char *BitcrushDistortion::PARAM_DRIVE = "drive";
const char *BitcrushDistortion::PARAM_MIX = "mix";
const char *BitcrushDistortion::PARAM_OUTPUT_GAIN = "output_gain";
const char *BitcrushDistortion::PARAM_BIT_DEPTH = "bit_depth";
const char *BitcrushDistortion::PARAM_SAMPLE_RATE = "sample_rate";

void BitcrushDistortion::_bind_methods() {
	// Bind base value accessors
	ClassDB::bind_method(D_METHOD("set_bit_depth_base_value", "value"), &BitcrushDistortion::set_bit_depth_base_value);
	ClassDB::bind_method(D_METHOD("get_bit_depth_base_value"), &BitcrushDistortion::get_bit_depth_base_value);
	ClassDB::bind_method(D_METHOD("set_sample_rate_base_value", "value"), &BitcrushDistortion::set_sample_rate_base_value);
	ClassDB::bind_method(D_METHOD("get_sample_rate_base_value"), &BitcrushDistortion::get_sample_rate_base_value);

	ClassDB::bind_method(D_METHOD("set_drive_base_value", "value"), &BitcrushDistortion::set_drive_base_value);
	ClassDB::bind_method(D_METHOD("get_drive_base_value"), &BitcrushDistortion::get_drive_base_value);
	ClassDB::bind_method(D_METHOD("set_mix_base_value", "value"), &BitcrushDistortion::set_mix_base_value);
	ClassDB::bind_method(D_METHOD("get_mix_base_value"), &BitcrushDistortion::get_mix_base_value);
	ClassDB::bind_method(D_METHOD("set_output_gain_base_value", "value"), &BitcrushDistortion::set_output_gain_base_value);
	ClassDB::bind_method(D_METHOD("get_output_gain_base_value"), &BitcrushDistortion::get_output_gain_base_value);
	// Bind parameter accessors
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "drive", PROPERTY_HINT_RANGE, "0,1,0.01"),
			"set_drive_base_value", "get_drive_base_value");
	ClassDB::bind_method(D_METHOD("set_drive_parameter", "param"), &BitcrushDistortion::set_drive_parameter);
	ClassDB::bind_method(D_METHOD("get_drive_parameter"), &BitcrushDistortion::get_drive_parameter);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "drive_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
			"set_drive_parameter", "get_drive_parameter");

	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "mix", PROPERTY_HINT_RANGE, "0,1,0.01"),
			"set_mix_base_value", "get_mix_base_value");
	ClassDB::bind_method(D_METHOD("set_mix_parameter", "param"), &BitcrushDistortion::set_mix_parameter);
	ClassDB::bind_method(D_METHOD("get_mix_parameter"), &BitcrushDistortion::get_mix_parameter);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "mix_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
			"set_mix_parameter", "get_mix_parameter");

	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "output_gain", PROPERTY_HINT_RANGE, "0,1,0.01"),
			"set_output_gain_base_value", "get_output_gain_base_value");
	ClassDB::bind_method(D_METHOD("set_output_gain_parameter", "param"), &BitcrushDistortion::set_output_gain_parameter);
	ClassDB::bind_method(D_METHOD("get_output_gain_parameter"), &BitcrushDistortion::get_output_gain_parameter);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "output_gain_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
			"set_output_gain_parameter", "get_output_gain_parameter");

	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "bit_depth", PROPERTY_HINT_RANGE, "0,1,0.01"),
			"set_bit_depth_base_value", "get_bit_depth_base_value");
	ClassDB::bind_method(D_METHOD("set_bit_depth_parameter", "param"), &BitcrushDistortion::set_bit_depth_parameter);
	ClassDB::bind_method(D_METHOD("get_bit_depth_parameter"), &BitcrushDistortion::get_bit_depth_parameter);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "bit_depth_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
			"set_bit_depth_parameter", "get_bit_depth_parameter");

	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "sample_rate", PROPERTY_HINT_RANGE, "0,1,0.01"),
			"set_sample_rate_base_value", "get_sample_rate_base_value");
	ClassDB::bind_method(D_METHOD("set_sample_rate_parameter", "param"), &BitcrushDistortion::set_sample_rate_parameter);
	ClassDB::bind_method(D_METHOD("get_sample_rate_parameter"), &BitcrushDistortion::get_sample_rate_parameter);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "sample_rate_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
			"set_sample_rate_parameter", "get_sample_rate_parameter");
}

BitcrushDistortion::BitcrushDistortion() {
	// Initialize state
	sample_hold = 0.0f;
	sample_counter = 0;

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

	Ref<ModulatedParameter> bit_depth_param = memnew(ModulatedParameter);
	bit_depth_param->set_base_value(0.5f); // 8 bits (mapped from 0-1 to 1-16)
	bit_depth_param->set_mod_min(0.0f); // 1 bit
	bit_depth_param->set_mod_max(1.0f); // 16 bits
	set_parameter(PARAM_BIT_DEPTH, bit_depth_param);

	Ref<ModulatedParameter> sample_rate_param = memnew(ModulatedParameter);
	sample_rate_param->set_base_value(0.5f); // Half sample rate
	sample_rate_param->set_mod_min(0.0f); // Extreme downsampling
	sample_rate_param->set_mod_max(1.0f); // No downsampling
	set_parameter(PARAM_SAMPLE_RATE, sample_rate_param);
}

BitcrushDistortion::~BitcrushDistortion() {
	// Clean up resources
}

float BitcrushDistortion::process_sample(float sample, const Ref<SynthNoteContext> &context) {
	if (!context.is_valid())
		return sample; // Return original sample if context is invalid

	// Get parameter values
	float drive = 0.5f; // Default: 50% drive
	float mix = 1.0f; // Default: 100% wet
	float output_gain = 0.7f; // Default: 70% output gain
	float bit_depth = 0.5f; // Default: 8 bits
	float sample_rate = 0.5f; // Default: half sample rate

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

	Ref<ModulatedParameter> bit_depth_param = get_parameter(PARAM_BIT_DEPTH);
	if (bit_depth_param.is_valid()) {
		bit_depth = bit_depth_param->get_value(context);
	}

	Ref<ModulatedParameter> sample_rate_param = get_parameter(PARAM_SAMPLE_RATE);
	if (sample_rate_param.is_valid()) {
		sample_rate = sample_rate_param->get_value(context);
	}

	// Scale drive to get more extreme effect at higher values
	float scaled_drive = 1.0f + drive * 4.0f; // Range 1-5

	// Map bit_depth from 0-1 to 1-16 bits
	float bit_depth_value = 1.0f + bit_depth * 15.0f;

	// Calculate the number of possible values
	float steps = powf(2.0f, bit_depth_value) - 1.0f;

	// Apply sample rate reduction (sample_rate is 0-1, where 0 is extreme reduction)
	// Map sample_rate to a meaningful range (1-44100/2)
	float base_sample_rate = 44100.0f; // Assuming 44.1kHz
	float rate_reduction = 1.0f + sample_rate * sample_rate * (base_sample_rate / 2.0f - 1.0f);

	float input = sample;

	// Apply drive
	float amplified = input * scaled_drive;

	// Only update the output when the counter reaches zero
	if (sample_counter <= 0) {
		// Apply bit reduction
		sample_hold = roundf(amplified * steps) / steps;
		sample_counter = static_cast<int>(rate_reduction);
	} else {
		sample_counter--;
	}

	float distorted = sample_hold;

	// Mix dry/wet
	float output = input * (1.0f - mix) + distorted * mix;

	// Apply output gain
	return output * output_gain;
}

void BitcrushDistortion::reset() {
	// Reset internal state
	sample_hold = 0.0f;
	sample_counter = 0;
}

float BitcrushDistortion::get_tail_length() const {
	// Distortion effects don't have a tail
	return 0.0f;
}

Ref<SynthAudioEffect> BitcrushDistortion::duplicate() const {
	Ref<BitcrushDistortion> new_effect = memnew(BitcrushDistortion);

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
void BitcrushDistortion::set_drive_parameter(const Ref<ModulatedParameter> &param) {
	if (param.is_valid()) {
		set_parameter(PARAM_DRIVE, param);
	}
}

Ref<ModulatedParameter> BitcrushDistortion::get_drive_parameter() const {
	return get_parameter(PARAM_DRIVE);
}

void BitcrushDistortion::set_mix_parameter(const Ref<ModulatedParameter> &param) {
	if (param.is_valid()) {
		set_parameter(PARAM_MIX, param);
	}
}

Ref<ModulatedParameter> BitcrushDistortion::get_mix_parameter() const {
	return get_parameter(PARAM_MIX);
}

void BitcrushDistortion::set_output_gain_parameter(const Ref<ModulatedParameter> &param) {
	if (param.is_valid()) {
		set_parameter(PARAM_OUTPUT_GAIN, param);
	}
}

Ref<ModulatedParameter> BitcrushDistortion::get_output_gain_parameter() const {
	return get_parameter(PARAM_OUTPUT_GAIN);
}

void BitcrushDistortion::set_bit_depth_parameter(const Ref<ModulatedParameter> &param) {
	if (param.is_valid()) {
		set_parameter(PARAM_BIT_DEPTH, param);
	}
}

Ref<ModulatedParameter> BitcrushDistortion::get_bit_depth_parameter() const {
	return get_parameter(PARAM_BIT_DEPTH);
}

void BitcrushDistortion::set_sample_rate_parameter(const Ref<ModulatedParameter> &param) {
	if (param.is_valid()) {
		set_parameter(PARAM_SAMPLE_RATE, param);
	}
}

Ref<ModulatedParameter> BitcrushDistortion::get_sample_rate_parameter() const {
	return get_parameter(PARAM_SAMPLE_RATE);
}

void BitcrushDistortion::set_bit_depth_base_value(float p_value) {
	Ref<ModulatedParameter> param = get_parameter(PARAM_BIT_DEPTH);
	if (param.is_valid()) {
		param->set_base_value(p_value);
	}
}

float BitcrushDistortion::get_bit_depth_base_value() const {
	return get_parameter(PARAM_BIT_DEPTH)->get_base_value();
}

void BitcrushDistortion::set_sample_rate_base_value(float p_value) {
	Ref<ModulatedParameter> param = get_parameter(PARAM_SAMPLE_RATE);
	if (param.is_valid()) {
		param->set_base_value(p_value);
	}
}

float BitcrushDistortion::get_sample_rate_base_value() const {
	return get_parameter(PARAM_SAMPLE_RATE)->get_base_value();
}

void BitcrushDistortion::set_drive_base_value(float p_value) {
	Ref<ModulatedParameter> param = get_parameter(PARAM_DRIVE);
	if (param.is_valid()) {
		param->set_base_value(p_value);
	}
}

float BitcrushDistortion::get_drive_base_value() const {
	return get_parameter(PARAM_DRIVE)->get_base_value();
}

void BitcrushDistortion::set_mix_base_value(float p_value) {
	Ref<ModulatedParameter> param = get_parameter(PARAM_MIX);
	if (param.is_valid()) {
		param->set_base_value(p_value);
	}
}

float BitcrushDistortion::get_mix_base_value() const {
	return get_parameter(PARAM_MIX)->get_base_value();
}

void BitcrushDistortion::set_output_gain_base_value(float p_value) {
	Ref<ModulatedParameter> param = get_parameter(PARAM_OUTPUT_GAIN);
	if (param.is_valid()) {
		param->set_base_value(p_value);
	}
}

float BitcrushDistortion::get_output_gain_base_value() const {
	return get_parameter(PARAM_OUTPUT_GAIN)->get_base_value();
}

} // namespace godot
