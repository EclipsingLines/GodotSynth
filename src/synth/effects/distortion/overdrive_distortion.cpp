#include "overdrive_distortion.h"
#include <cmath>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/math.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

namespace godot {

// Define parameter name constants
const char *OverdriveDistortion::PARAM_DRIVE = "drive";
const char *OverdriveDistortion::PARAM_MIX = "mix";
const char *OverdriveDistortion::PARAM_OUTPUT_GAIN = "output_gain";
const char *OverdriveDistortion::PARAM_TONE = "tone";
const char *OverdriveDistortion::PARAM_CHARACTER = "character";

void OverdriveDistortion::_bind_methods() {
	// Bind base value accessors
	ClassDB::bind_method(D_METHOD("set_tone_base_value", "value"), &OverdriveDistortion::set_tone_base_value);
	ClassDB::bind_method(D_METHOD("get_tone_base_value"), &OverdriveDistortion::get_tone_base_value);
	ClassDB::bind_method(D_METHOD("set_character_base_value", "value"), &OverdriveDistortion::set_character_base_value);
	ClassDB::bind_method(D_METHOD("get_character_base_value"), &OverdriveDistortion::get_character_base_value);

	ClassDB::bind_method(D_METHOD("set_drive_base_value", "value"), &OverdriveDistortion::set_drive_base_value);
	ClassDB::bind_method(D_METHOD("get_drive_base_value"), &OverdriveDistortion::get_drive_base_value);
	ClassDB::bind_method(D_METHOD("set_mix_base_value", "value"), &OverdriveDistortion::set_mix_base_value);
	ClassDB::bind_method(D_METHOD("get_mix_base_value"), &OverdriveDistortion::get_mix_base_value);
	ClassDB::bind_method(D_METHOD("set_output_gain_base_value", "value"), &OverdriveDistortion::set_output_gain_base_value);
	ClassDB::bind_method(D_METHOD("get_output_gain_base_value"), &OverdriveDistortion::get_output_gain_base_value);

	// Bind parameter accessors
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "drive", PROPERTY_HINT_RANGE, "0,1,0.01"),
			"set_drive_base_value", "get_drive_base_value");
	ClassDB::bind_method(D_METHOD("set_drive_parameter", "param"), &OverdriveDistortion::set_drive_parameter);
	ClassDB::bind_method(D_METHOD("get_drive_parameter"), &OverdriveDistortion::get_drive_parameter);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "drive_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
			"set_drive_parameter", "get_drive_parameter");

	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "mix", PROPERTY_HINT_RANGE, "0,1,0.01"),
			"set_mix_base_value", "get_mix_base_value");
	ClassDB::bind_method(D_METHOD("set_mix_parameter", "param"), &OverdriveDistortion::set_mix_parameter);
	ClassDB::bind_method(D_METHOD("get_mix_parameter"), &OverdriveDistortion::get_mix_parameter);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "mix_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
			"set_mix_parameter", "get_mix_parameter");

	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "output_gain", PROPERTY_HINT_RANGE, "0,1,0.01"),
			"set_output_gain_base_value", "get_output_gain_base_value");
	ClassDB::bind_method(D_METHOD("set_output_gain_parameter", "param"), &OverdriveDistortion::set_output_gain_parameter);
	ClassDB::bind_method(D_METHOD("get_output_gain_parameter"), &OverdriveDistortion::get_output_gain_parameter);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "output_gain_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
			"set_output_gain_parameter", "get_output_gain_parameter");

	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "tone", PROPERTY_HINT_RANGE, "0,1,0.01"),
			"set_tone_base_value", "get_tone_base_value");
	ClassDB::bind_method(D_METHOD("set_tone_parameter", "param"), &OverdriveDistortion::set_tone_parameter);
	ClassDB::bind_method(D_METHOD("get_tone_parameter"), &OverdriveDistortion::get_tone_parameter);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "tone_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
			"set_tone_parameter", "get_tone_parameter");

	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "character", PROPERTY_HINT_RANGE, "0,1,0.01"),
			"set_character_base_value", "get_character_base_value");
	ClassDB::bind_method(D_METHOD("set_character_parameter", "param"), &OverdriveDistortion::set_character_parameter);
	ClassDB::bind_method(D_METHOD("get_character_parameter"), &OverdriveDistortion::get_character_parameter);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "character_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
			"set_character_parameter", "get_character_parameter");
}

OverdriveDistortion::OverdriveDistortion() {
	// Initialize filter states
	lp_state = 0.0f;
	hp_state = 0.0f;

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

	Ref<ModulatedParameter> tone_param = memnew(ModulatedParameter);
	tone_param->set_base_value(0.5f); // Neutral tone
	tone_param->set_mod_min(0.0f); // Dark
	tone_param->set_mod_max(1.0f); // Bright
	set_parameter(PARAM_TONE, tone_param);

	Ref<ModulatedParameter> character_param = memnew(ModulatedParameter);
	character_param->set_base_value(0.5f); // Medium character
	character_param->set_mod_min(0.0f); // Smooth
	character_param->set_mod_max(1.0f); // Aggressive
	set_parameter(PARAM_CHARACTER, character_param);
}

OverdriveDistortion::~OverdriveDistortion() {
	// Clean up resources
}

float OverdriveDistortion::process_sample(float sample, const Ref<SynthNoteContext> &context) {
	if (!context.is_valid())
		return sample; // Return original sample if context is invalid

	// Get parameter values
	float drive = 0.5f; // Default: 50% drive
	float mix = 1.0f; // Default: 100% wet
	float output_gain = 0.7f; // Default: 70% output gain
	float tone = 0.5f; // Default: neutral tone
	float character = 0.5f; // Default: medium character

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

	Ref<ModulatedParameter> tone_param = get_parameter(PARAM_TONE);
	if (tone_param.is_valid()) {
		tone = tone_param->get_value(context);
	}

	Ref<ModulatedParameter> character_param = get_parameter(PARAM_CHARACTER);
	if (character_param.is_valid()) {
		character = character_param->get_value(context);
	}

	// Scale drive to get more extreme effect at higher values
	float scaled_drive = 1.0f + drive * 9.0f; // Range 1-10

	// Calculate filter coefficients for tone control
	float sample_rate = 44100.0f; // Assuming 44.1kHz

	// Map tone to filter frequencies
	float lp_freq = 1000.0f + tone * 15000.0f; // 1kHz to 16kHz
	float hp_freq = 20.0f + (1.0f - tone) * 980.0f; // 20Hz to 1kHz

	float lp_coeff = std::exp(-2.0f * Math_PI * lp_freq / sample_rate);
	float hp_coeff = std::exp(-2.0f * Math_PI * hp_freq / sample_rate);

	float input = sample;

	// Apply drive
	float x = input * scaled_drive;

	float distorted;

	// Apply different overdrive algorithms based on character
	if (character < 0.33f) {
		// Smooth overdrive: y = x/(1+|x|)
		float character_factor = character * 3.0f; // 0 to 1 within this range
		float smooth = x / (1.0f + std::abs(x));
		float medium = x / (1.0f + std::abs(x) * 0.5f);
		distorted = smooth * (1.0f - character_factor) + medium * character_factor;
	} else if (character < 0.66f) {
		// Medium overdrive: y = x/(1+|x|*0.5)
		float character_factor = (character - 0.33f) * 3.0f; // 0 to 1 within this range
		float medium = x / (1.0f + std::abs(x) * 0.5f);
		float hard = std::tanh(x);
		distorted = medium * (1.0f - character_factor) + hard * character_factor;
	} else {
		// Aggressive overdrive: y = tanh(x)
		float character_factor = (character - 0.66f) * 3.0f; // 0 to 1 within this range
		float hard = std::tanh(x);
		float very_hard = x > 0.0f ? 1.0f - std::exp(-x) : -1.0f + std::exp(x);
		distorted = hard * (1.0f - character_factor) + very_hard * character_factor;
	}

	// Apply tone control (simple high/low pass filtering)
	// Low-pass filter
	lp_state = lp_state * lp_coeff + distorted * (1.0f - lp_coeff);

	// High-pass filter
	hp_state = hp_state * hp_coeff + lp_state * (1.0f - hp_coeff);

	distorted = hp_state;

	// Mix dry/wet
	float output = input * (1.0f - mix) + distorted * mix;

	// Apply output gain
	return output * output_gain;
}

void OverdriveDistortion::reset() {
	// Reset filter states
	lp_state = 0.0f;
	hp_state = 0.0f;
}

float OverdriveDistortion::get_tail_length() const {
	// Distortion effects don't have a tail
	return 0.0f;
}

Ref<SynthAudioEffect> OverdriveDistortion::duplicate() const {
	Ref<OverdriveDistortion> new_effect = memnew(OverdriveDistortion);

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
void OverdriveDistortion::set_drive_parameter(const Ref<ModulatedParameter> &param) {
	if (param.is_valid()) {
		set_parameter(PARAM_DRIVE, param);
	}
}

Ref<ModulatedParameter> OverdriveDistortion::get_drive_parameter() const {
	return get_parameter(PARAM_DRIVE);
}

void OverdriveDistortion::set_mix_parameter(const Ref<ModulatedParameter> &param) {
	if (param.is_valid()) {
		set_parameter(PARAM_MIX, param);
	}
}

Ref<ModulatedParameter> OverdriveDistortion::get_mix_parameter() const {
	return get_parameter(PARAM_MIX);
}

void OverdriveDistortion::set_output_gain_parameter(const Ref<ModulatedParameter> &param) {
	if (param.is_valid()) {
		set_parameter(PARAM_OUTPUT_GAIN, param);
	}
}

Ref<ModulatedParameter> OverdriveDistortion::get_output_gain_parameter() const {
	return get_parameter(PARAM_OUTPUT_GAIN);
}

void OverdriveDistortion::set_tone_parameter(const Ref<ModulatedParameter> &param) {
	if (param.is_valid()) {
		set_parameter(PARAM_TONE, param);
	}
}

Ref<ModulatedParameter> OverdriveDistortion::get_tone_parameter() const {
	return get_parameter(PARAM_TONE);
}

void OverdriveDistortion::set_character_parameter(const Ref<ModulatedParameter> &param) {
	if (param.is_valid()) {
		set_parameter(PARAM_CHARACTER, param);
	}
}

Ref<ModulatedParameter> OverdriveDistortion::get_character_parameter() const {
	return get_parameter(PARAM_CHARACTER);
}

void OverdriveDistortion::set_tone_base_value(float p_value) {
	Ref<ModulatedParameter> param = get_parameter(PARAM_TONE);
	if (param.is_valid()) {
		param->set_base_value(p_value);
	}
}

float OverdriveDistortion::get_tone_base_value() const {
	return get_parameter(PARAM_TONE)->get_base_value();
}

void OverdriveDistortion::set_character_base_value(float p_value) {
	Ref<ModulatedParameter> param = get_parameter(PARAM_CHARACTER);
	if (param.is_valid()) {
		param->set_base_value(p_value);
	}
}

float OverdriveDistortion::get_character_base_value() const {
	return get_parameter(PARAM_CHARACTER)->get_base_value();
}

void OverdriveDistortion::set_drive_base_value(float p_value) {
	Ref<ModulatedParameter> param = get_parameter(PARAM_DRIVE);
	if (param.is_valid()) {
		param->set_base_value(p_value);
	}
}

float OverdriveDistortion::get_drive_base_value() const {
	return get_parameter(PARAM_DRIVE)->get_base_value();
}

void OverdriveDistortion::set_mix_base_value(float p_value) {
	Ref<ModulatedParameter> param = get_parameter(PARAM_MIX);
	if (param.is_valid()) {
		param->set_base_value(p_value);
	}
}

float OverdriveDistortion::get_mix_base_value() const {
	return get_parameter(PARAM_MIX)->get_base_value();
}

void OverdriveDistortion::set_output_gain_base_value(float p_value) {
	Ref<ModulatedParameter> param = get_parameter(PARAM_OUTPUT_GAIN);
	if (param.is_valid()) {
		param->set_base_value(p_value);
	}
}

float OverdriveDistortion::get_output_gain_base_value() const {
	return get_parameter(PARAM_OUTPUT_GAIN)->get_base_value();
}

} // namespace godot
