#include "ms20_filter.h"
#include <cmath>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/math.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

namespace godot {

const char *MS20Filter::PARAM_SATURATION = "saturation";

void MS20Filter::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_saturation", "saturation"), &MS20Filter::set_saturation);
	ClassDB::bind_method(D_METHOD("get_saturation"), &MS20Filter::get_saturation);
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "saturation", PROPERTY_HINT_RANGE, "0.0,1.0,0.01"),
			"set_saturation", "get_saturation");
}

MS20Filter::MS20Filter() {
	Ref<ModulatedParameter> sat_mp = memnew(ModulatedParameter);
	sat_mp->set_base_value(0.5f);
	add_parameter(PARAM_SATURATION, sat_mp);
	// Set filter type to low pass by default
	set_filter_type(FilterType::LOWPASS);
}

MS20Filter::~MS20Filter() {
	// Clean up resources
}

float MS20Filter::saturate(float x, float p_saturation) const {
	// MS-20 style saturation using the provided saturation value
	float sat_amount = 1.0f + p_saturation * 9.0f; // Scale from 1 to 10
	if (x > 1.0f) {
		return 1.0f + (1.0f - std::exp(-(x - 1.0f) * sat_amount));
	} else if (x < -1.0f) {
		return -1.0f - (1.0f - std::exp(-(-x - 1.0f) * sat_amount));
	}

	return x;
}

float MS20Filter::process_sample(float sample, const Ref<SynthNoteContext> &context) {
	if (!context.is_valid())
		return sample;

	// Get modulated parameter values
	float cutoff_freq = 1000.0f; // Default to 1000 Hz
	float resonance = 0.5f; // Default resonance

	Ref<ModulatedParameter> cutoff_param = get_parameter(PARAM_CUTOFF);
	if (cutoff_param.is_valid()) {
		cutoff_freq = cutoff_param->get_value(context);
		cutoff_freq = Math::clamp(cutoff_freq, 20.0f, 20000.0f);
	}

	Ref<ModulatedParameter> res_param = get_parameter(PARAM_RESONANCE);
	if (res_param.is_valid()) {
		resonance = res_param->get_value(context);
		resonance = Math::clamp(resonance, 0.0f, 1.0f);
	}

	// Get sample rate from context or use default
	float sample_rate = 44100.0f; // TODO: Get from context

	// Get modulated saturation parameter value
	Ref<ModulatedParameter> sat_param = get_parameter(PARAM_SATURATION);
	float saturation_value = 0.5f;
	if (sat_param.is_valid()) {
	    saturation_value = sat_param->get_value(context);
	}

	// Calculate filter coefficients
	float omega = 2.0f * Math_PI * cutoff_freq / sample_rate;
	float sin_omega = Math::sin(omega);
	float cos_omega = Math::cos(omega);
	float alpha = sin_omega * (1.0f - resonance * 0.99f); // Prevent instability

	if (get_filter_type() == FilterType::LOWPASS) {
		// MS-20 lowpass coefficients
		b0 = (1.0f - cos_omega) * 0.5f;
		b1 = 1.0f - cos_omega;
		b2 = (1.0f - cos_omega) * 0.5f;
		a1 = -2.0f * cos_omega;
		a2 = 1.0f - alpha;
	} else if (get_filter_type() == FilterType::HIGHPASS) {
		// MS-20 highpass coefficients
		b0 = (1.0f + cos_omega) * 0.5f;
		b1 = -(1.0f + cos_omega);
		b2 = (1.0f + cos_omega) * 0.5f;
		a1 = -2.0f * cos_omega;
		a2 = 1.0f - alpha;
	} else {
		// Default to lowpass for other types
		b0 = (1.0f - cos_omega) * 0.5f;
		b1 = 1.0f - cos_omega;
		b2 = (1.0f - cos_omega) * 0.5f;
		a1 = -2.0f * cos_omega;
		a2 = 1.0f - alpha;
	}

	// Normalize coefficients
	float a0 = 1.0f + alpha;
	b0 /= a0;
	b1 /= a0;
	b2 /= a0;
	a1 /= a0;
	a2 /= a0;

	// Apply MS-20 style nonlinearity to input
	sample = saturate(sample * (1.0f + resonance * 2.0f), saturation_value) / (1.0f + resonance * 2.0f);

	// Apply biquad filter
	float output = b0 * sample + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2;

	// Apply resonance feedback saturation
	if (resonance > 0.5f) {
		float fb_amount = (resonance - 0.5f) * 2.0f; // 0.0 to 1.0
		output = saturate(output * (1.0f + fb_amount * 3.0f), saturation_value) / (1.0f + fb_amount * 3.0f);
	}

	// Update state variables
	x2 = x1;
	x1 = sample;
	y2 = y1;
	y1 = output;

	return output;
}

void MS20Filter::reset() {
	x1 = x2 = y1 = y2 = 0.0f;
}

void MS20Filter::set_saturation(float p_saturation) {
	Ref<ModulatedParameter> sat_mp = get_parameter(PARAM_SATURATION);
	if (sat_mp.is_valid())
		sat_mp->set_base_value(Math::clamp(p_saturation, 0.0f, 1.0f));
}

float MS20Filter::get_saturation() const {
	Ref<ModulatedParameter> sat_mp = get_parameter(PARAM_SATURATION);
	return sat_mp.is_valid() ? sat_mp->get_base_value() : 0.5f;
}

Ref<SynthAudioEffect> MS20Filter::duplicate() const {
    Ref<MS20Filter> new_filter = memnew(MS20Filter);
    
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
