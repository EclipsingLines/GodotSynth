#include "steiner_parker_filter.h"
#include <cmath>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/math.hpp>

namespace godot {
const char *SteinerParkerFilter::PARAM_DRIVE = "drive";

void SteinerParkerFilter::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_drive_parameter", "param"), &SteinerParkerFilter::set_drive_parameter);
	ClassDB::bind_method(D_METHOD("get_drive_parameter"), &SteinerParkerFilter::get_drive_parameter);
	ClassDB::bind_method(D_METHOD("set_drive_base_value", "value"), &SteinerParkerFilter::set_drive_base_value);
	ClassDB::bind_method(D_METHOD("get_drive_base_value"), &SteinerParkerFilter::get_drive_base_value);

	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "drive_base_value", PROPERTY_HINT_RANGE, "0.0,1.0,0.01"),
			"set_drive_base_value", "get_drive_base_value");
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "drive_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
			"set_drive_parameter", "get_drive_parameter");
}

SteinerParkerFilter::SteinerParkerFilter() {
	Ref<ModulatedParameter> drive_mp = memnew(ModulatedParameter);
	drive_mp->set_base_value(0.0f);
	drive_mp->set_mod_min(0.0f);
	drive_mp->set_mod_max(1.0f);
	set_parameter(PARAM_DRIVE, drive_mp);
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

	// Get modulated drive value
	Ref<ModulatedParameter> drive_param = get_parameter(PARAM_DRIVE);
	float drive_value = drive_param.is_valid() ? drive_param->get_value(context) : 0.0f;

	// Get modulated parameter values
	float cutoff_freq = 1000.0f;
	float resonance = 0.5f;

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
	float sample_rate = 44100.0f;

	// Calculate filter coefficients
	float f = 2.0f * Math::sin(Math_PI * cutoff_freq / sample_rate);
	float q = resonance * 10.0f;
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
			output = lp;
	}

	return output;
}

void SteinerParkerFilter::reset() {
	hp1 = bp1 = lp1 = hp = bp = lp = 0.0f;
}

void SteinerParkerFilter::set_drive_parameter(const Ref<ModulatedParameter> &param) {
	set_parameter(PARAM_DRIVE, param);
}

Ref<ModulatedParameter> SteinerParkerFilter::get_drive_parameter() const {
	return get_parameter(PARAM_DRIVE);
}

void SteinerParkerFilter::set_drive_base_value(float p_value) {
	Ref<ModulatedParameter> param = get_parameter(PARAM_DRIVE);
	if (param.is_valid()) {
		param->set_base_value(Math::clamp(p_value, 0.0f, 1.0f));
	}
}

float SteinerParkerFilter::get_drive_base_value() const {
	Ref<ModulatedParameter> param = get_parameter(PARAM_DRIVE);
	return param.is_valid() ? param->get_base_value() : 0.0f;
}

Ref<SynthAudioEffect> SteinerParkerFilter::duplicate() const {
	Ref<SteinerParkerFilter> new_filter = memnew(SteinerParkerFilter);
	new_filter->set_filter_type(get_filter_type());

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
