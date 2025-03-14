#include "fuzz_distortion.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/math.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

namespace godot {

// Define parameter name constants
const char *FuzzDistortion::PARAM_DRIVE = "drive";
const char *FuzzDistortion::PARAM_MIX = "mix";
const char *FuzzDistortion::PARAM_OUTPUT_GAIN = "output_gain";
const char *FuzzDistortion::PARAM_FUZZ_TYPE = "fuzz_type";
const char *FuzzDistortion::PARAM_TONE = "tone";

void FuzzDistortion::_bind_methods() {
	// Bind methods and properties
	ClassDB::bind_method(D_METHOD("set_drive_parameter", "param"), &FuzzDistortion::set_drive_parameter);
	ClassDB::bind_method(D_METHOD("get_drive_parameter"), &FuzzDistortion::get_drive_parameter);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "drive_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
			"set_drive_parameter", "get_drive_parameter");

	ClassDB::bind_method(D_METHOD("set_mix_parameter", "param"), &FuzzDistortion::set_mix_parameter);
	ClassDB::bind_method(D_METHOD("get_mix_parameter"), &FuzzDistortion::get_mix_parameter);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "mix_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
			"set_mix_parameter", "get_mix_parameter");

	ClassDB::bind_method(D_METHOD("set_output_gain_parameter", "param"), &FuzzDistortion::set_output_gain_parameter);
	ClassDB::bind_method(D_METHOD("get_output_gain_parameter"), &FuzzDistortion::get_output_gain_parameter);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "output_gain_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
			"set_output_gain_parameter", "get_output_gain_parameter");

	ClassDB::bind_method(D_METHOD("set_fuzz_type_parameter", "param"), &FuzzDistortion::set_fuzz_type_parameter);
	ClassDB::bind_method(D_METHOD("get_fuzz_type_parameter"), &FuzzDistortion::get_fuzz_type_parameter);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "fuzz_type_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
			"set_fuzz_type_parameter", "get_fuzz_type_parameter");

	ClassDB::bind_method(D_METHOD("set_tone_parameter", "param"), &FuzzDistortion::set_tone_parameter);
	ClassDB::bind_method(D_METHOD("get_tone_parameter"), &FuzzDistortion::get_tone_parameter);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "tone_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
			"set_tone_parameter", "get_tone_parameter");

	// Register the FuzzType enum
	BIND_ENUM_CONSTANT(FUZZ_CLASSIC);
	BIND_ENUM_CONSTANT(FUZZ_MODERN);
	BIND_ENUM_CONSTANT(FUZZ_OCTAVE);
	BIND_ENUM_CONSTANT(FUZZ_GATED);
}

FuzzDistortion::FuzzDistortion() {
	// Initialize filter states
	lp_state = 0.0f;
	hp_state = 0.0f;

	// Create default parameters
	Ref<ModulatedParameter> drive_param = memnew(ModulatedParameter);
	drive_param->set_base_value(0.7f); // Default: 70% drive
	drive_param->set_mod_min(0.1f); // Minimum drive
	drive_param->set_mod_max(1.0f); // Maximum drive
	set_parameter(PARAM_DRIVE, drive_param);

	Ref<ModulatedParameter> mix_param = memnew(ModulatedParameter);
	mix_param->set_base_value(1.0f); // Default: 100% wet
	mix_param->set_mod_min(0.0f); // Dry only
	mix_param->set_mod_max(1.0f); // Wet only
	set_parameter(PARAM_MIX, mix_param);

	Ref<ModulatedParameter> output_gain_param = memnew(ModulatedParameter);
	output_gain_param->set_base_value(0.5f); // Default: 50% output gain
	output_gain_param->set_mod_min(0.0f); // Silence
	output_gain_param->set_mod_max(1.0f); // Full gain
	set_parameter(PARAM_OUTPUT_GAIN, output_gain_param);

	Ref<ModulatedParameter> fuzz_type_param = memnew(ModulatedParameter);
	fuzz_type_param->set_base_value(0.0f); // Default: Classic fuzz
	fuzz_type_param->set_mod_min(0.0f); // Classic fuzz
	fuzz_type_param->set_mod_max(3.0f); // Gated fuzz
	set_parameter(PARAM_FUZZ_TYPE, fuzz_type_param);

	Ref<ModulatedParameter> tone_param = memnew(ModulatedParameter);
	tone_param->set_base_value(0.5f); // Default: Mid tone
	tone_param->set_mod_min(0.0f); // Dark tone
	tone_param->set_mod_max(1.0f); // Bright tone
	set_parameter(PARAM_TONE, tone_param);
}

FuzzDistortion::~FuzzDistortion() {
	// Cleanup if needed
}

float FuzzDistortion::process_sample(float sample, const Ref<SynthNoteContext> &context) {
	if (!context.is_valid())
		return sample; // Return original sample if context is invalid

	// Get parameter values
	float drive = 0.7f; // Default: 70% drive
	float mix = 1.0f; // Default: 100% wet
	float output_gain = 0.5f; // Default: 50% output gain
	float fuzz_type_val = 0.0f; // Default: Classic fuzz
	float tone = 0.5f; // Default: Mid tone

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

	Ref<ModulatedParameter> fuzz_type_param = get_parameter(PARAM_FUZZ_TYPE);
	if (fuzz_type_param.is_valid()) {
		fuzz_type_val = fuzz_type_param->get_value(context);
	}

	Ref<ModulatedParameter> tone_param = get_parameter(PARAM_TONE);
	if (tone_param.is_valid()) {
		tone = tone_param->get_value(context);
	}

	// Determine fuzz type
	int fuzz_type = static_cast<int>(fuzz_type_val);
	if (fuzz_type > FUZZ_GATED)
		fuzz_type = FUZZ_GATED;

	// Calculate tone filter coefficients
	float lp_coeff = 1.0f - tone; // Low-pass coefficient (higher for darker tone)
	float hp_coeff = tone * 0.2f; // High-pass coefficient (higher for brighter tone)

	// Scale drive for different algorithms
	float scaled_drive = drive * 40.0f + 1.0f; // Scale drive for more extreme effect

	float input = sample;
	float wet_signal = 0.0f;

	// Apply different fuzz algorithms based on type
	switch (fuzz_type) {
		case FUZZ_CLASSIC: {
			// Classic fuzz: hard clipping with asymmetry
			float asymmetry = 0.2f;
			float clipped = input * scaled_drive;

			// Apply asymmetric clipping
			if (clipped > 1.0f) {
				clipped = 1.0f;
			} else if (clipped < -1.0f + asymmetry) {
				clipped = -1.0f + asymmetry;
			}

			wet_signal = clipped;
			break;
		}

		case FUZZ_MODERN: {
			// Modern fuzz: smoother distortion with more harmonics
			float shaped = Math::tanh(input * scaled_drive);

			// Add some higher harmonics
			wet_signal = shaped * 0.7f + Math::tanh(shaped * shaped * shaped) * 0.3f;
			break;
		}

		case FUZZ_OCTAVE: {
			// Octave fuzz: adds upper octave by rectifying
			float rectified = Math::abs(input); // Full-wave rectification

			// Mix original signal with rectified signal
			wet_signal = input * 0.6f + rectified * 0.4f * scaled_drive;

			// Apply soft clipping
			wet_signal = Math::tanh(wet_signal * 2.0f);
			break;
		}

		case FUZZ_GATED: {
			// Gated fuzz: creates a "sputtery" sound with a noise gate
			float threshold = 0.1f;
			float gated = (Math::abs(input) > threshold) ? input * scaled_drive : 0.0f;

			// Apply hard clipping
			if (gated > 1.0f)
				gated = 1.0f;
			if (gated < -1.0f)
				gated = -1.0f;

			wet_signal = gated;
			break;
		}
	}

	// Apply tone control (simple low-pass and high-pass filtering)
	lp_state = lp_state * lp_coeff + wet_signal * (1.0f - lp_coeff);
	hp_state = hp_state * (1.0f - hp_coeff) + wet_signal * hp_coeff;

	wet_signal = lp_state + (wet_signal - hp_state);

	// Apply output gain
	wet_signal *= output_gain * 2.0f; // Scale output gain

	// Mix dry and wet signals
	return input * (1.0f - mix) + wet_signal * mix;
}

void FuzzDistortion::reset() {
	// Reset filter states
	lp_state = 0.0f;
	hp_state = 0.0f;
}

Ref<SynthAudioEffect> FuzzDistortion::duplicate() const {
	Ref<FuzzDistortion> new_effect = memnew(FuzzDistortion);

	// Copy parameters
	Dictionary params = get_parameters();
	Array param_names = params.keys();
	for (int i = 0; i < param_names.size(); i++) {
		String name = param_names[i];
		Ref<ModulatedParameter> param = params[name];
		if (param.is_valid()) {
			Ref<ModulatedParameter> new_param = param->duplicate();
			new_effect->set_parameter(name, new_param);
		}
	}

	return new_effect;
}

// Parameter accessors
void FuzzDistortion::set_drive_parameter(const Ref<ModulatedParameter> &param) {
	if (param.is_valid()) {
		set_parameter(PARAM_DRIVE, param);
	}
}

Ref<ModulatedParameter> FuzzDistortion::get_drive_parameter() const {
	return get_parameter(PARAM_DRIVE);
}

void FuzzDistortion::set_mix_parameter(const Ref<ModulatedParameter> &param) {
	if (param.is_valid()) {
		set_parameter(PARAM_MIX, param);
	}
}

Ref<ModulatedParameter> FuzzDistortion::get_mix_parameter() const {
	return get_parameter(PARAM_MIX);
}

void FuzzDistortion::set_output_gain_parameter(const Ref<ModulatedParameter> &param) {
	if (param.is_valid()) {
		set_parameter(PARAM_OUTPUT_GAIN, param);
	}
}

Ref<ModulatedParameter> FuzzDistortion::get_output_gain_parameter() const {
	return get_parameter(PARAM_OUTPUT_GAIN);
}

void FuzzDistortion::set_fuzz_type_parameter(const Ref<ModulatedParameter> &param) {
	if (param.is_valid()) {
		set_parameter(PARAM_FUZZ_TYPE, param);
	}
}

Ref<ModulatedParameter> FuzzDistortion::get_fuzz_type_parameter() const {
	return get_parameter(PARAM_FUZZ_TYPE);
}

void FuzzDistortion::set_tone_parameter(const Ref<ModulatedParameter> &param) {
	if (param.is_valid()) {
		set_parameter(PARAM_TONE, param);
	}
}

Ref<ModulatedParameter> FuzzDistortion::get_tone_parameter() const {
	return get_parameter(PARAM_TONE);
}

} // namespace godot
