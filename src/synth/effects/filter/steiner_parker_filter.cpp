#include "steiner_parker_filter.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/math.hpp>

#include <cmath>
#include <godot_cpp/variant/utility_functions.hpp>

namespace godot {
const char *SteinerParkerFilter::PARAM_DRIVE = "drive";

void SteinerParkerFilter::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_drive", "drive"), &SteinerParkerFilter::set_drive);
	ClassDB::bind_method(D_METHOD("get_drive"), &SteinerParkerFilter::get_drive);
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "drive", PROPERTY_HINT_RANGE, "0.0,1.0,0.01"),
			"set_drive", "get_drive");
}

SteinerParkerFilter::SteinerParkerFilter() {
	Ref<ModulatedParameter> drive_mp = memnew(ModulatedParameter);
	drive_mp->set_base_value(0.0f);
	add_parameter(PARAM_DRIVE, drive_mp);
	// Set filter type to low pass by default
	set_filter_type(FilterType::LOWPASS);
}

SteinerParkerFilter::~SteinerParkerFilter() {
	// Clean up resources
}

float SteinerParkerFilter::fast_tanh(float x) const {
	// Fast approximation of tanh
	float x2 = x * x;
	return x * (27.0f + x2) / (27.0f + 9.0f * x2);
}

float SteinerParkerFilter::process_sample(float sample, const Ref<SynthNoteContext> &context) {
	if (!context.is_valid())
		return sample;

	Ref<ModulatedParameter> drive_param = get_parameter(PARAM_DRIVE);
	float drive_value = 0.0f;
	if (drive_param.is_valid())
		drive_value = drive_param->get_value(context);

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

	// Calculate filter coefficients
	float f = 2.0f * Math::sin(Math_PI * cutoff_freq / sample_rate);
	float q = resonance * 10.0f; // Scale resonance for more dramatic effect
	float scale = Math::sqrt(q) * 0.1f;

	// Apply input drive/saturation
	if (drive_value > 0.0f) {
		sample = fast_tanh(sample * (1.0f + drive_value * 5.0f)) / (1.0f + drive_value * 5.0f);
	}

	// Steiner-Parker filter algorithm
	hp = sample - lp1 - bp * q;
	bp = bp + f * hp;
	lp = lp + f * bp;

	// Apply nonlinear feedback for more character
	if (drive_value > 0.0f) {
		bp = fast_tanh(bp * (1.0f + drive_value * 2.0f)) / (1.0f + drive_value * 2.0f);
		lp = fast_tanh(lp * (1.0f + drive_value * 2.0f)) / (1.0f + drive_value * 2.0f);
	}

	// Store state for next sample
	hp1 = hp;
	bp1 = bp;
	lp1 = lp;

	// Select output based on filter type
	float output = 0.0f;
	switch (get_filter_type()) {
		case FilterType::LOWPASS:
			output = lp;
			break;
		case FilterType::HIGHPASS:
			output = hp;
			break;
		case FilterType::BANDPASS:
			output = bp;
			break;
		case FilterType::NOTCH:
			output = sample - bp * scale;
			break;
		default:
			output = lp; // Default to lowpass
	}

	return output;
}

void SteinerParkerFilter::reset() {
	hp1 = bp1 = lp1 = hp = bp = lp = 0.0f;
}

void SteinerParkerFilter::set_drive(float p_drive) {
	Ref<ModulatedParameter> drive_mp = get_parameter(PARAM_DRIVE);
	if (drive_mp.is_valid())
		drive_mp->set_base_value(Math::clamp(p_drive, 0.0f, 1.0f));
}

float SteinerParkerFilter::get_drive() const {
	Ref<ModulatedParameter> drive_mp = get_parameter(PARAM_DRIVE);
	return drive_mp.is_valid() ? drive_mp->get_base_value() : 0.0f;
}

Ref<SynthAudioEffect> SteinerParkerFilter::duplicate() const {
    Ref<SteinerParkerFilter> new_filter = memnew(SteinerParkerFilter);
    
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
