#include "state_variable_filter.h"
#include <godot_cpp/core/math.hpp>

namespace godot {

void StateVariableFilter::_bind_methods() {
	// No additional methods needed
}

StateVariableFilter::StateVariableFilter() {
	// Initialize state variables
	z1 = 0.0f;
	z2 = 0.0f;
}

StateVariableFilter::~StateVariableFilter() {
	// Clean up resources
}

float StateVariableFilter::process_sample(float sample, const Ref<SynthNoteContext> &context) {
	if (!context.is_valid())
		return sample;

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
		q = res_param->get_value(context) * 10.0f + 0.707f; // Map 0-1 to Q range
	}

	// Get sample rate from context or use default
	float sample_rate = 44100.0f; // TODO: Get from context

	// Calculate filter coefficients (State Variable Filter)
	float f = 2.0f * Math::sin(Math_PI * cutoff_freq / sample_rate);
	float q_factor = 1.0f / q;

	// State variable filter algorithm
	float lowpass = z1 + f * z2;
	float highpass = sample - lowpass - q_factor * z2;
	float bandpass = f * highpass + z2;
	float notch = lowpass + highpass;

	// Update filter state
	z2 = bandpass;
	z1 = lowpass;

	// Select output based on filter type
	float output = 0.0f;
	switch (get_filter_type()) {
		case FilterType::LOWPASS:
			output = lowpass;
			break;
		case FilterType::HIGHPASS:
			output = highpass;
			break;
		case FilterType::BANDPASS:
			output = bandpass;
			break;
		case FilterType::NOTCH:
			output = notch;
			break;
		default:
			output = lowpass; // Default to lowpass
	}

	return output;
}

void StateVariableFilter::reset() {
	z1 = z2 = 0.0f;
}

Ref<SynthAudioEffect> StateVariableFilter::duplicate() const {
    Ref<StateVariableFilter> new_filter = memnew(StateVariableFilter);
    
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
