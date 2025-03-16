#include "formant_filter.h"
#include <cmath>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/math.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

namespace godot {
const char *FormantFilter::PARAM_VOWEL_POSITION = "vowel_position";

// Formant frequencies for vowels A, E, I, O, U (in Hz)
const float FormantFilter::formant_freqs[VOWEL_COUNT][3] = {
	{ 800.0f, 1150.0f, 2900.0f }, // A
	{ 350.0f, 2000.0f, 2800.0f }, // E
	{ 270.0f, 2140.0f, 2950.0f }, // I
	{ 450.0f, 800.0f, 2830.0f }, // O
	{ 325.0f, 700.0f, 2700.0f } // U
};

// Formant bandwidths for vowels A, E, I, O, U (in Hz)
const float FormantFilter::formant_bandwidths[VOWEL_COUNT][3] = {
	{ 80.0f, 90.0f, 120.0f }, // A
	{ 60.0f, 100.0f, 120.0f }, // E
	{ 60.0f, 90.0f, 100.0f }, // I
	{ 70.0f, 80.0f, 100.0f }, // O
	{ 50.0f, 60.0f, 170.0f } // U
};

void FormantFilter::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_vowel_position_parameter", "param"), &FormantFilter::set_vowel_position_parameter);
	ClassDB::bind_method(D_METHOD("get_vowel_position_parameter"), &FormantFilter::get_vowel_position_parameter);
	ClassDB::bind_method(D_METHOD("set_vowel_position_base_value", "value"), &FormantFilter::set_vowel_position_base_value);
	ClassDB::bind_method(D_METHOD("get_vowel_position_base_value"), &FormantFilter::get_vowel_position_base_value);

	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "vowel_position_base_value", PROPERTY_HINT_RANGE, "0.0,4.0,0.01"),
			"set_vowel_position_base_value", "get_vowel_position_base_value");
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "vowel_position_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
			"set_vowel_position_parameter", "get_vowel_position_parameter");
}

FormantFilter::FormantFilter() {
	// Initialize vowel position parameter
	Ref<ModulatedParameter> vowel_mp = memnew(ModulatedParameter);
	vowel_mp->set_base_value(0.0f); // Default to vowel A
	vowel_mp->set_mod_min(0.0f);
	vowel_mp->set_mod_max(4.0f);
	set_parameter(PARAM_VOWEL_POSITION, vowel_mp);

	// Initialize filter bands
	for (int i = 0; i < 3; i++) {
		bands[i].x1 = bands[i].x2 = bands[i].y1 = bands[i].y2 = 0.0f;
	}

	// Initialize with default sample rate
	update_coefficients(44100.0f);
}

FormantFilter::~FormantFilter() {
	// Clean up resources
}

void FormantFilter::update_coefficients(float sample_rate) {
	// Get current vowel position
	float vowel_pos = 0.0f;
	Ref<ModulatedParameter> vowel_param = get_parameter(PARAM_VOWEL_POSITION);
	if (vowel_param.is_valid()) {
		vowel_pos = vowel_param->get_base_value();
	}

	// Determine which vowels to interpolate between
	int vowel_idx = static_cast<int>(vowel_pos);
	float t = vowel_pos - vowel_idx; // Interpolation factor

	// Clamp to valid range
	vowel_idx = Math::clamp(vowel_idx, 0, VOWEL_COUNT - 2);

	// For each formant band
	for (int i = 0; i < 3; i++) {
		// Interpolate frequency and bandwidth
		float freq = formant_freqs[vowel_idx][i] * (1.0f - t) + formant_freqs[vowel_idx + 1][i] * t;
		float bandwidth = formant_bandwidths[vowel_idx][i] * (1.0f - t) + formant_bandwidths[vowel_idx + 1][i] * t;

		// Convert to angular frequency
		float omega = 2.0f * Math_PI * freq / sample_rate;
		float sin_omega = Math::sin(omega);
		float cos_omega = Math::cos(omega);

		// Calculate alpha (for bandwidth)
		float alpha = sin_omega * Math::sinh(Math::log(2.0f) / 2.0f * bandwidth / freq * omega / sin_omega);

		// Calculate coefficients for bandpass filter
		float a0 = 1.0f + alpha;
		bands[i].b0 = alpha / a0;
		bands[i].b1 = 0.0f;
		bands[i].b2 = -alpha / a0;
		bands[i].a1 = -2.0f * cos_omega / a0;
		bands[i].a2 = (1.0f - alpha) / a0;
	}
}

float FormantFilter::process_sample(float sample, const Ref<SynthNoteContext> &context) {
	if (!context.is_valid())
		return sample;

	// Get vowel position from parameter if available
	Ref<ModulatedParameter> vowel_param = get_parameter(PARAM_VOWEL_POSITION);
	if (vowel_param.is_valid()) {
		float vowel_pos = vowel_param->get_value(context);
		vowel_pos = Math::clamp(vowel_pos, 0.0f, 4.0f);

		// Update coefficients if vowel position changed
		if (vowel_pos != vowel_param->get_base_value()) {
			update_coefficients(44100.0f); // TODO: Get sample rate from context
		}
	}

	float output = 0.0f;

	// Process through each formant band
	for (int j = 0; j < 3; j++) {
		// Apply bandpass filter for this formant
		float y = bands[j].b0 * sample + bands[j].b1 * bands[j].x1 + bands[j].b2 * bands[j].x2 -
				bands[j].a1 * bands[j].y1 - bands[j].a2 * bands[j].y2;

		// Update state variables
		bands[j].x2 = bands[j].x1;
		bands[j].x1 = sample;
		bands[j].y2 = bands[j].y1;
		bands[j].y1 = y;

		// Sum the output (with different gains for each formant)
		float gain = (j == 0) ? 1.0f : ((j == 1) ? 0.8f : 0.6f);
		output += y * gain;
	}

	// Apply overall gain adjustment
	output *= 0.5f;

	return output;
}

void FormantFilter::reset() {
	// Reset all filter states
	for (int i = 0; i < 3; i++) {
		bands[i].x1 = bands[i].x2 = bands[i].y1 = bands[i].y2 = 0.0f;
	}
}

void FormantFilter::set_vowel_position_parameter(const Ref<ModulatedParameter> &param) {
	if (param.is_valid()) {
		set_parameter(PARAM_VOWEL_POSITION, param);
	}
}

Ref<ModulatedParameter> FormantFilter::get_vowel_position_parameter() const {
	return get_parameter(PARAM_VOWEL_POSITION);
}

void FormantFilter::set_vowel_position_base_value(float p_value) {
	Ref<ModulatedParameter> param = get_parameter(PARAM_VOWEL_POSITION);
	if (param.is_valid()) {
		param->set_base_value(Math::clamp(p_value, 0.0f, 4.0f));
	}
}

float FormantFilter::get_vowel_position_base_value() const {
	Ref<ModulatedParameter> param = get_parameter(PARAM_VOWEL_POSITION);
	return param.is_valid() ? param->get_base_value() : 0.0f;
}

Ref<SynthAudioEffect> FormantFilter::duplicate() const {
	Ref<FormantFilter> new_filter = memnew(FormantFilter);

	// Copy parameters
	Dictionary params = get_parameters();
	Array param_names = params.keys();
	for (int i = 0; i < param_names.size(); i++) {
		String name = param_names[i];
		Ref<ModulatedParameter> param = params[name];
		if (param.is_valid()) {
			new_filter->set_parameter(name, param->duplicate());
		}
	}

	return new_filter;
}

} // namespace godot
