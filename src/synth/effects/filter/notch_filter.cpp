#include "notch_filter.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/math.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

namespace godot {

void NotchFilter::_bind_methods() {
	// Bind methods and properties specific to NotchFilter
	ClassDB::bind_method(D_METHOD("set_bandwidth_parameter", "param"), &NotchFilter::set_bandwidth_parameter);
	ClassDB::bind_method(D_METHOD("get_bandwidth_parameter"), &NotchFilter::get_bandwidth_parameter);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "bandwidth_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
			"set_bandwidth_parameter", "get_bandwidth_parameter");
}

NotchFilter::NotchFilter() {
	// Create default bandwidth parameter
	Ref<ModulatedParameter> bandwidth_param = memnew(ModulatedParameter);
	bandwidth_param->set_base_value(0.5f); // Default bandwidth
	bandwidth_param->set_mod_min(0.1f); // Narrow notch
	bandwidth_param->set_mod_max(2.0f); // Wide notch
	set_parameter(PARAM_BANDWIDTH, bandwidth_param);

	// Set default filter type to notch
	set_filter_type(NOTCH);
}

NotchFilter::~NotchFilter() {
	// Cleanup if needed
}

float NotchFilter::process_sample(float sample, const Ref<SynthNoteContext> &context) {
	if (!context.is_valid())
		return sample;

	// Get parameter values
	float cutoff = 0.5f; // Default: normalized cutoff frequency (0.0 to 1.0)
	float resonance = 0.7f; // Default: moderate resonance
	float bandwidth = 0.5f; // Default: moderate bandwidth

	Ref<ModulatedParameter> cutoff_param = get_parameter(PARAM_CUTOFF);
	if (cutoff_param.is_valid()) {
		cutoff = cutoff_param->get_value(context);
	}

	Ref<ModulatedParameter> resonance_param = get_parameter(PARAM_RESONANCE);
	if (resonance_param.is_valid()) {
		resonance = resonance_param->get_value(context);
	}

	Ref<ModulatedParameter> bandwidth_param = get_parameter(PARAM_BANDWIDTH);
	if (bandwidth_param.is_valid()) {
		bandwidth = bandwidth_param->get_value(context);
	}

	// Get sample rate from context or use default
	float sample_rate = 44100.0f; // TODO: Get from context

	// Convert normalized cutoff to angular frequency (0 to pi)
	float omega = Math_PI * cutoff;

	// Calculate filter coefficients
	float alpha = Math::sin(omega) * bandwidth;
	float cosw = Math::cos(omega);
	float beta = 1.0f - alpha * resonance;

	// Normalize coefficients
	float a0 = 1.0f + alpha;
	float a1 = -2.0f * cosw;
	float a2 = 1.0f - alpha;
	float b0 = 1.0f;
	float b1 = -2.0f * cosw;
	float b2 = 1.0f;

	// Normalize by a0
	b0 /= a0;
	b1 /= a0;
	b2 /= a0;
	a1 /= a0;
	a2 /= a0;

	// Direct form II implementation
	float y = b0 * sample + z1;
	z1 = b1 * sample - a1 * y + z2;
	z2 = b2 * sample - a2 * y;

	return y;
}

void NotchFilter::reset() {
	// Reset filter state
	z1 = 0.0f;
	z2 = 0.0f;

	UtilityFunctions::print("NotchFilter: Reset called - filter state cleared");
}

Ref<SynthAudioEffect> NotchFilter::duplicate() const {
    Ref<NotchFilter> new_filter = memnew(NotchFilter);
    
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

// Parameter accessors
void NotchFilter::set_bandwidth_parameter(const Ref<ModulatedParameter> &param) {
	if (param.is_valid()) {
		set_parameter(PARAM_BANDWIDTH, param);
	}
}

Ref<ModulatedParameter> NotchFilter::get_bandwidth_parameter() const {
	return get_parameter(PARAM_BANDWIDTH);
}

} // namespace godot
