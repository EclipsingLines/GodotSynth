#include "ms20_filter.h"
#include <cmath>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/math.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

namespace godot {
const char *MS20Filter::PARAM_SATURATION = "saturation";

void MS20Filter::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_saturation_parameter", "param"), &MS20Filter::set_saturation_parameter);
	ClassDB::bind_method(D_METHOD("get_saturation_parameter"), &MS20Filter::get_saturation_parameter);
	ClassDB::bind_method(D_METHOD("set_saturation_base_value", "value"), &MS20Filter::set_saturation_base_value);
	ClassDB::bind_method(D_METHOD("get_saturation_base_value"), &MS20Filter::get_saturation_base_value);

	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "saturation_base_value", PROPERTY_HINT_RANGE, "0.0,1.0,0.01"),
			"set_saturation_base_value", "get_saturation_base_value");
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "saturation_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
			"set_saturation_parameter", "get_saturation_parameter");
}

MS20Filter::MS20Filter() {
	// Initialize saturation parameter
	Ref<ModulatedParameter> saturation_mp = memnew(ModulatedParameter);
	saturation_mp->set_base_value(0.5f); // Default to 0.5
	saturation_mp->set_mod_min(0.0f);
	saturation_mp->set_mod_max(1.0f);
	set_parameter(PARAM_SATURATION, saturation_mp);
}

MS20Filter::~MS20Filter() {
	// Clean up resources
}

float MS20Filter::saturate(float x, float p_saturation) const {
	// Soft clipping function
	if (p_saturation < 0.0001f)
		return x;
	return Math::tanh(x * p_saturation) / p_saturation;
}

float MS20Filter::process_sample(float sample, const Ref<SynthNoteContext> &context) {
	if (!context.is_valid()) {
		return sample;
	}

	// Get modulated parameter values
	float cutoff_freq = 1000.0f; // Default to 1000 Hz
	float q = 0.707f; // Default Q value
	float saturation = 0.5f; // Default saturation

	Ref<ModulatedParameter> cutoff_param = get_parameter(PARAM_CUTOFF);
	if (cutoff_param.is_valid()) {
		cutoff_freq = cutoff_param->get_value(context);
		cutoff_freq = Math::clamp(cutoff_freq, 20.0f, 20000.0f);
	}

	Ref<ModulatedParameter> res_param = get_parameter(PARAM_RESONANCE);
	if (res_param.is_valid()) {
		q = res_param->get_value(context); // Map 0-1 directly to resonance
	}

	Ref<ModulatedParameter> saturation_param = get_parameter(PARAM_SATURATION);
	if (saturation_param.is_valid()) {
		saturation = saturation_param->get_value(context);
		saturation = Math::clamp(saturation, 0.0f, 1.0f);
	}

	// Get sample rate from context or use default
	float sample_rate = 44100.0f; // TODO: Get from context

	// Calculate filter coefficients
	float w0 = 2.0f * Math_PI * cutoff_freq / sample_rate;
	float alpha = Math::sin(w0) / (2.0f * q);

	// Update coefficients
	b0 = (1.0f - Math::cos(w0)) / 2.0f;
	b1 = 1.0f - Math::cos(w0);
	b2 = (1.0f - Math::cos(w0)) / 2.0f;
	a1 = -2.0f * Math::cos(w0);
	a2 = 1.0f - alpha;

	// Apply saturation to input
	float input = saturate(sample, saturation);

	// Process filter
	float output = b0 * input + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2;

	// Update state variables
	x2 = x1;
	x1 = input;
	y2 = y1;
	y1 = output;

	return output;
}

void MS20Filter::reset() {
	// Reset filter state
	x1 = x2 = y1 = y2 = 0.0f;
}

void MS20Filter::set_saturation_parameter(const Ref<ModulatedParameter> &param) {
	if (param.is_valid()) {
		set_parameter(PARAM_SATURATION, param);
	}
}

Ref<ModulatedParameter> MS20Filter::get_saturation_parameter() const {
	return get_parameter(PARAM_SATURATION);
}

void MS20Filter::set_saturation_base_value(float p_value) {
	Ref<ModulatedParameter> param = get_parameter(PARAM_SATURATION);
	if (param.is_valid()) {
		param->set_base_value(Math::clamp(p_value, 0.0f, 1.0f));
	}
}

float MS20Filter::get_saturation_base_value() const {
	Ref<ModulatedParameter> param = get_parameter(PARAM_SATURATION);
	return param.is_valid() ? param->get_base_value() : 0.5f;
}

Ref<SynthAudioEffect> MS20Filter::duplicate() const {
	Ref<MS20Filter> new_filter = memnew(MS20Filter);

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
