#include "moog_filter.h"
#include <cmath>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/math.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

namespace godot {
const char *MoogFilter::PARAM_OVERSAMPLING = "oversampling";

void MoogFilter::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_oversampling_parameter", "param"), &MoogFilter::set_oversampling_parameter);
	ClassDB::bind_method(D_METHOD("get_oversampling_parameter"), &MoogFilter::get_oversampling_parameter);
	ClassDB::bind_method(D_METHOD("set_oversampling_base_value", "value"), &MoogFilter::set_oversampling_base_value);
	ClassDB::bind_method(D_METHOD("get_oversampling_base_value"), &MoogFilter::get_oversampling_base_value);

	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "oversampling_base_value", PROPERTY_HINT_RANGE, "1,4,1"),
			"set_oversampling_base_value", "get_oversampling_base_value");
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "oversampling_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
			"set_oversampling_parameter", "get_oversampling_parameter");
}

MoogFilter::MoogFilter() {
	// Set filter type to low pass by default
	set_filter_type(FilterType::LOWPASS);

	// Initialize oversampling parameter
	Ref<ModulatedParameter> oversampling_mp = memnew(ModulatedParameter);
	oversampling_mp->set_base_value(2.0f); // Default to 2x oversampling
	oversampling_mp->set_mod_min(1.0f);
	oversampling_mp->set_mod_max(4.0f);
	set_parameter(PARAM_OVERSAMPLING, oversampling_mp);
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
		return sample;
	}

	// Get modulated parameter values
	float cutoff_freq = 1000.0f; // Default to 1000 Hz
	float q = 0.707f; // Default Q value
	int oversampling = 2; // Default oversampling

	Ref<ModulatedParameter> cutoff_param = get_parameter(PARAM_CUTOFF);
	if (cutoff_param.is_valid()) {
		cutoff_freq = cutoff_param->get_value(context);
		cutoff_freq = Math::clamp(cutoff_freq, 20.0f, 20000.0f);
	}

	Ref<ModulatedParameter> res_param = get_parameter(PARAM_RESONANCE);
	if (res_param.is_valid()) {
		q = res_param->get_value(context); // Map 0-1 directly to resonance
	}

	Ref<ModulatedParameter> oversampling_param = get_parameter(PARAM_OVERSAMPLING);
	if (oversampling_param.is_valid()) {
		oversampling = static_cast<int>(Math::round(oversampling_param->get_value(context)));
		oversampling = Math::clamp(oversampling, 1, 4);
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

void MoogFilter::set_oversampling_parameter(const Ref<ModulatedParameter> &param) {
	if (param.is_valid()) {
		set_parameter(PARAM_OVERSAMPLING, param);
	}
}

Ref<ModulatedParameter> MoogFilter::get_oversampling_parameter() const {
	return get_parameter(PARAM_OVERSAMPLING);
}

void MoogFilter::set_oversampling_base_value(float p_value) {
	Ref<ModulatedParameter> param = get_parameter(PARAM_OVERSAMPLING);
	if (param.is_valid()) {
		param->set_base_value(Math::clamp(p_value, 1.0f, 4.0f));
	}
}

float MoogFilter::get_oversampling_base_value() const {
	Ref<ModulatedParameter> param = get_parameter(PARAM_OVERSAMPLING);
	return param.is_valid() ? param->get_base_value() : 2.0f;
}

Ref<SynthAudioEffect> MoogFilter::duplicate() const {
	Ref<MoogFilter> new_filter = memnew(MoogFilter);

	// Copy filter type
	new_filter->set_filter_type(get_filter_type());

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
