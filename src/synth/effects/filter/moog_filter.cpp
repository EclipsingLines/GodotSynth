#include "moog_filter.h"
#include <cmath>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/math.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

namespace godot {

void MoogFilter::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_oversampling", "factor"), &MoogFilter::set_oversampling);
	ClassDB::bind_method(D_METHOD("get_oversampling"), &MoogFilter::get_oversampling);
	ADD_PROPERTY(PropertyInfo(Variant::INT, "oversampling", PROPERTY_HINT_ENUM, "1x,2x,4x"),
			"set_oversampling", "get_oversampling");
}

MoogFilter::MoogFilter() {
	// Set filter type to low pass by default
	set_filter_type(FilterType::LOWPASS);
}

MoogFilter::~MoogFilter() {
	// Clean up resources
}

// Fast approximation of tanh that's suitable for audio
inline float fast_tanh(float x) {
	float x2 = x * x;
	return x * (27.0f + x2) / (27.0f + 9.0f * x2);
}

float MoogFilter::process_sample(float sample, const Ref<SynthNoteContext> &context) {
	if (!context.is_valid()) {
		UtilityFunctions::print("Filter - Context not valid");
		return sample;
	}

	// Get modulated parameter values
	float cutoff_freq = 1000.0f; // Default to 1000 Hz
	float q = 0.707f; // Default Q value

	Ref<ModulatedParameter> cutoff_param = get_parameter(PARAM_CUTOFF);
	if (cutoff_param.is_valid()) {
		cutoff_freq = cutoff_param->get_value(context);
		cutoff_freq = Math::clamp(cutoff_freq, 20.0f, 20000.0f);
	}

	Ref<ModulatedParameter> res_param = get_parameter(PARAM_RESONANCE);
	if (res_param.is_valid()) {
		q = res_param->get_value(context); // Map 0-1 directly to resonance
	}

	// Get sample rate from context or use default
	float sample_rate = 44100.0f; // TODO: Get from context

	// Apply oversampling to sample rate for internal processing
	float internal_sample_rate = sample_rate * oversampling;

	// Frequency tuning
	float fc = cutoff_freq / internal_sample_rate;
	fc = Math::clamp(fc, 0.0f, 0.49f); // Prevent instability

	// Resonance [0, 4]
	float res = q * 4.0f;

	// Compute filter coefficients if cutoff or resonance changed
	if (fc != old_freq || res != old_res) {
		old_freq = fc;
		old_res = res;

		// Frequency & resonance tuning
		float f = fc * 1.16f;
		float k = 3.6f * res * (1.0f - 0.15f * f * f);

		// Compute derived coefficients
		old_tune = 2.0f * f * (1.0f - f);
		old_acr = 1.0f - k * 0.5f;
	}

	// Apply oversampling
	float output = 0.0f;
	for (int j = 0; j < oversampling; j++) {
		// Input with resonance applied
		float input = sample - 4.0f * stage[3] * old_acr;

		// Four cascaded one-pole filters (bilinear transform)
		input *= 0.35013f; // Scale input to prevent clipping

		// First stage
		stage[0] = stage[0] + old_tune * (fast_tanh(input) - tanhstage[0]);
		tanhstage[0] = fast_tanh(stage[0]);

		// Second stage
		stage[1] = stage[1] + old_tune * (tanhstage[0] - tanhstage[1]);
		tanhstage[1] = fast_tanh(stage[1]);

		// Third stage
		stage[2] = stage[2] + old_tune * (tanhstage[1] - tanhstage[2]);
		tanhstage[2] = fast_tanh(stage[2]);

		// Fourth stage
		stage[3] = stage[3] + old_tune * (tanhstage[2] - fast_tanh(stage[3]));

		output += stage[3];
	}

	// Average the oversampled output
	return output / oversampling;
}

void MoogFilter::reset() {
	// Reset filter state
	for (int i = 0; i < 4; i++) {
		stage[i] = 0.0f;
		delay[i] = 0.0f;
	}

	for (int i = 0; i < 3; i++) {
		tanhstage[i] = 0.0f;
	}

	old_freq = 0.0f;
	old_res = 0.0f;
	old_acr = 0.0f;
	old_tune = 0.0f;
}

void MoogFilter::set_oversampling(int factor) {
	// Only allow 1, 2, or 4
	if (factor == 1 || factor == 2 || factor == 4) {
		oversampling = factor;
	}
}

int MoogFilter::get_oversampling() const {
	return oversampling;
}

Ref<SynthAudioEffect> MoogFilter::duplicate() const {
	Ref<MoogFilter> new_filter = memnew(MoogFilter);

	// Copy filter type
	new_filter->set_filter_type(get_filter_type());

	// Copy oversampling setting
	new_filter->set_oversampling(oversampling);

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
