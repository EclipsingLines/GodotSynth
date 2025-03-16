#include "filtered_delay.h"
#include <cmath>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/math.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

namespace godot {

// Define parameter name constants
const char *FilteredDelay::PARAM_DELAY_TIME = "delay_time";
const char *FilteredDelay::PARAM_FEEDBACK = "feedback";
const char *FilteredDelay::PARAM_MIX = "mix";
const char *FilteredDelay::PARAM_LP_FREQ = "lp_freq";
const char *FilteredDelay::PARAM_HP_FREQ = "hp_freq";
const char *FilteredDelay::PARAM_RESONANCE = "resonance";

void FilteredDelay::_bind_methods() {
	// Bind parameter accessors

	ClassDB::bind_method(D_METHOD("set_delay_time_base_value", "value"), &FilteredDelay::set_delay_time_base_value);
	ClassDB::bind_method(D_METHOD("get_delay_time_base_value"), &FilteredDelay::get_delay_time_base_value);
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "delay_time", PROPERTY_HINT_RANGE, "0,1,0.01"),
			"set_delay_time_base_value", "get_delay_time_base_value");
	ClassDB::bind_method(D_METHOD("set_delay_time_parameter", "param"), &FilteredDelay::set_delay_time_parameter);
	ClassDB::bind_method(D_METHOD("get_delay_time_parameter"), &FilteredDelay::get_delay_time_parameter);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "delay_time_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
			"set_delay_time_parameter", "get_delay_time_parameter");

	ClassDB::bind_method(D_METHOD("set_feedback_base_value", "value"), &FilteredDelay::set_feedback_base_value);
	ClassDB::bind_method(D_METHOD("get_feedback_base_value"), &FilteredDelay::get_feedback_base_value);
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "feedback", PROPERTY_HINT_RANGE, "0,1,0.01"),
			"set_feedback_base_value", "get_feedback_base_value");
	ClassDB::bind_method(D_METHOD("set_feedback_parameter", "param"), &FilteredDelay::set_feedback_parameter);
	ClassDB::bind_method(D_METHOD("get_feedback_parameter"), &FilteredDelay::get_feedback_parameter);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "feedback_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
			"set_feedback_parameter", "get_feedback_parameter");

	ClassDB::bind_method(D_METHOD("set_mix_base_value", "value"), &FilteredDelay::set_mix_base_value);
	ClassDB::bind_method(D_METHOD("get_mix_base_value"), &FilteredDelay::get_mix_base_value);
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "mix", PROPERTY_HINT_RANGE, "0,1,0.01"),
			"set_mix_base_value", "get_mix_base_value");
	ClassDB::bind_method(D_METHOD("set_mix_parameter", "param"), &FilteredDelay::set_mix_parameter);
	ClassDB::bind_method(D_METHOD("get_mix_parameter"), &FilteredDelay::get_mix_parameter);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "mix_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
			"set_mix_parameter", "get_mix_parameter");

	ClassDB::bind_method(D_METHOD("set_lp_freq_base_value", "value"), &FilteredDelay::set_lp_freq_base_value);
	ClassDB::bind_method(D_METHOD("get_lp_freq_base_value"), &FilteredDelay::get_lp_freq_base_value);
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "lp_freq", PROPERTY_HINT_RANGE, "0,1,0.01"),
			"set_lp_freq_base_value", "get_lp_freq_base_value");
	ClassDB::bind_method(D_METHOD("set_lp_freq_parameter", "param"), &FilteredDelay::set_lp_freq_parameter);
	ClassDB::bind_method(D_METHOD("get_lp_freq_parameter"), &FilteredDelay::get_lp_freq_parameter);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "lp_freq_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
			"set_lp_freq_parameter", "get_lp_freq_parameter");

	ClassDB::bind_method(D_METHOD("set_hp_freq_base_value", "value"), &FilteredDelay::set_hp_freq_base_value);
	ClassDB::bind_method(D_METHOD("get_hp_freq_base_value"), &FilteredDelay::get_hp_freq_base_value);
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "hp_freq", PROPERTY_HINT_RANGE, "0,1,0.01"),
			"set_hp_freq_base_value", "get_hp_freq_base_value");
	ClassDB::bind_method(D_METHOD("set_hp_freq_parameter", "param"), &FilteredDelay::set_hp_freq_parameter);
	ClassDB::bind_method(D_METHOD("get_hp_freq_parameter"), &FilteredDelay::get_hp_freq_parameter);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "hp_freq_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
			"set_hp_freq_parameter", "get_hp_freq_parameter");

	ClassDB::bind_method(D_METHOD("set_resonance_base_value", "value"), &FilteredDelay::set_resonance_base_value);
	ClassDB::bind_method(D_METHOD("get_resonance_base_value"), &FilteredDelay::get_resonance_base_value);
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "resonance", PROPERTY_HINT_RANGE, "0,1,0.01"),
			"set_resonance_base_value", "get_resonance_base_value");
	ClassDB::bind_method(D_METHOD("set_resonance_parameter", "param"), &FilteredDelay::set_resonance_parameter);
	ClassDB::bind_method(D_METHOD("get_resonance_parameter"), &FilteredDelay::get_resonance_parameter);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "resonance_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
			"set_resonance_parameter", "get_resonance_parameter");
}

FilteredDelay::FilteredDelay() {
	// Initialize delay buffer (2 seconds at 44.1kHz)
	delay_buffer.resize(88200, 0.0f);
	buffer_position = 0;

	// Initialize filter states
	lp_state = 0.0f;
	hp_state = 0.0f;

	// Create default parameters
	Ref<ModulatedParameter> delay_time_param = memnew(ModulatedParameter);
	delay_time_param->set_base_value(0.5f); // 500ms delay
	delay_time_param->set_mod_min(0.01f); // 10ms minimum
	delay_time_param->set_mod_max(2.0f); // 2 seconds maximum
	set_parameter(PARAM_DELAY_TIME, delay_time_param);

	Ref<ModulatedParameter> feedback_param = memnew(ModulatedParameter);
	feedback_param->set_base_value(0.6f); // 60% feedback
	feedback_param->set_mod_min(0.0f); // No feedback
	feedback_param->set_mod_max(0.95f); // Almost 100% feedback
	set_parameter(PARAM_FEEDBACK, feedback_param);

	Ref<ModulatedParameter> mix_param = memnew(ModulatedParameter);
	mix_param->set_base_value(0.5f); // 50% wet/dry mix
	mix_param->set_mod_min(0.0f); // Dry only
	mix_param->set_mod_max(1.0f); // Wet only
	set_parameter(PARAM_MIX, mix_param);

	Ref<ModulatedParameter> lp_freq_param = memnew(ModulatedParameter);
	lp_freq_param->set_base_value(0.7f); // 70% of max frequency (maps to ~8kHz)
	lp_freq_param->set_mod_min(0.1f); // ~500Hz
	lp_freq_param->set_mod_max(1.0f); // ~12kHz
	set_parameter(PARAM_LP_FREQ, lp_freq_param);

	Ref<ModulatedParameter> hp_freq_param = memnew(ModulatedParameter);
	hp_freq_param->set_base_value(0.2f); // 20% of max frequency (maps to ~200Hz)
	hp_freq_param->set_mod_min(0.0f); // ~20Hz
	hp_freq_param->set_mod_max(0.8f); // ~2kHz
	set_parameter(PARAM_HP_FREQ, hp_freq_param);

	Ref<ModulatedParameter> resonance_param = memnew(ModulatedParameter);
	resonance_param->set_base_value(0.3f); // 30% resonance
	resonance_param->set_mod_min(0.0f); // No resonance
	resonance_param->set_mod_max(0.9f); // High resonance
	set_parameter(PARAM_RESONANCE, resonance_param);
}

FilteredDelay::~FilteredDelay() {
	// Clean up resources
}

float FilteredDelay::process_sample(float sample, const Ref<SynthNoteContext> &context) {
	if (!context.is_valid())
		return sample; // Return original sample if context is invalid

	// Get parameter values
	float delay_time = 0.5f; // Default: 500ms
	float feedback = 0.6f; // Default: 60%
	float mix = 0.5f; // Default: 50% wet/dry
	float lp_freq = 0.7f; // Default: 70% (maps to ~8kHz)
	float hp_freq = 0.2f; // Default: 20% (maps to ~200Hz)
	float resonance = 0.3f; // Default: 30% resonance

	Ref<ModulatedParameter> delay_param = get_parameter(PARAM_DELAY_TIME);
	if (delay_param.is_valid()) {
		delay_time = delay_param->get_value(context);
	}

	Ref<ModulatedParameter> fb_param = get_parameter(PARAM_FEEDBACK);
	if (fb_param.is_valid()) {
		feedback = fb_param->get_value(context);
	}

	Ref<ModulatedParameter> mix_param = get_parameter(PARAM_MIX);
	if (mix_param.is_valid()) {
		mix = mix_param->get_value(context);
	}

	Ref<ModulatedParameter> lp_param = get_parameter(PARAM_LP_FREQ);
	if (lp_param.is_valid()) {
		lp_freq = lp_param->get_value(context);
	}

	Ref<ModulatedParameter> hp_param = get_parameter(PARAM_HP_FREQ);
	if (hp_param.is_valid()) {
		hp_freq = hp_param->get_value(context);
	}

	Ref<ModulatedParameter> res_param = get_parameter(PARAM_RESONANCE);
	if (res_param.is_valid()) {
		resonance = res_param->get_value(context);
	}

	// Calculate sample rate (assuming 44.1kHz)
	const float sample_rate = 44100.0f;

	// Calculate delay in samples
	int delay_samples = static_cast<int>(delay_time * sample_rate);
	if (delay_samples >= delay_buffer.size()) {
		delay_samples = delay_buffer.size() - 1;
	}

	// Map normalized parameter values to filter frequencies
	float lp_cutoff = 500.0f + lp_freq * 11500.0f; // 500Hz to 12kHz
	float hp_cutoff = 20.0f + hp_freq * 1980.0f; // 20Hz to 2kHz

	// Calculate filter coefficients
	float lp_coeff = std::exp(-2.0f * Math_PI * lp_cutoff / sample_rate);
	float hp_coeff = std::exp(-2.0f * Math_PI * hp_cutoff / sample_rate);

	// Resonance factor (1.0 to 4.0)
	float res_factor = 1.0f + resonance * 3.0f;

	float input = sample;

	// Calculate read position with wraparound
	int read_pos = buffer_position - delay_samples;
	if (read_pos < 0) {
		read_pos += delay_buffer.size();
	}

	// Read delayed sample
	float delayed_sample = delay_buffer[read_pos];

	// Apply filters to the feedback path
	// Low-pass filter
	lp_state = lp_state * lp_coeff + delayed_sample * (1.0f - lp_coeff);

	// High-pass filter (applied to low-passed signal)
	hp_state = hp_state * hp_coeff + lp_state * (1.0f - hp_coeff);

	// Apply resonance
	float filtered_sample = hp_state;
	if (resonance > 0.0f) {
		// Simple resonance implementation - boost around cutoff
		filtered_sample = filtered_sample * res_factor;
		// Soft clip to prevent excessive resonance
		filtered_sample = std::tanh(filtered_sample);
	}

	// Write to delay buffer with feedback
	delay_buffer[buffer_position] = input + filtered_sample * feedback;

	// Increment and wrap buffer position
	buffer_position = (buffer_position + 1) % delay_buffer.size();

	// Mix dry and wet signals
	return input * (1.0f - mix) + filtered_sample * mix;
}

void FilteredDelay::reset() {
	// Clear delay buffer
	std::fill(delay_buffer.begin(), delay_buffer.end(), 0.0f);
	buffer_position = 0;

	// Reset filter states
	lp_state = 0.0f;
	hp_state = 0.0f;
}

float FilteredDelay::get_tail_length() const {
	// Get the delay time and feedback parameters
	float delay_time = 0.5f; // Default: 500ms
	float feedback = 0.6f; // Default: 60%

	Ref<ModulatedParameter> delay_param = get_parameter(PARAM_DELAY_TIME);
	if (delay_param.is_valid()) {
		delay_time = delay_param->get_base_value();
	}

	Ref<ModulatedParameter> fb_param = get_parameter(PARAM_FEEDBACK);
	if (fb_param.is_valid()) {
		feedback = fb_param->get_base_value();
	}

	// Calculate tail length based on delay time and feedback
	if (feedback < 0.001f) {
		return delay_time; // Just one repeat
	}

	// Calculate number of repeats to reach -60dB
	float repeats = std::log(0.001f) / std::log(feedback);
	if (repeats < 0) {
		repeats = 10.0f;
	}

	// Return total tail length: delay_time * repeats
	return delay_time * repeats;
}

Ref<SynthAudioEffect> FilteredDelay::duplicate() const {
	Ref<FilteredDelay> new_delay = memnew(FilteredDelay);

	// Copy parameters
	Dictionary params = get_parameters();
	Array param_names = params.keys();
	for (int i = 0; i < param_names.size(); i++) {
		String name = param_names[i];
		Ref<ModulatedParameter> param = params[name];
		if (param.is_valid()) {
			Ref<ModulatedParameter> new_param = memnew(ModulatedParameter);
			new_param->set_base_value(param->get_base_value());
			new_param->set_mod_min(param->get_mod_min());
			new_param->set_mod_max(param->get_mod_max());

			// Copy modulation source if available
			Ref<ModulationSource> mod_source = param->get_mod_source();
			if (mod_source.is_valid()) {
				new_param->set_mod_source(mod_source);
			}

			new_delay->set_parameter(name, new_param);
		}
	}

	return new_delay;
}

// Parameter accessors
void FilteredDelay::set_delay_time_parameter(const Ref<ModulatedParameter> &param) {
	if (param.is_valid()) {
		set_parameter(PARAM_DELAY_TIME, param);
	}
}

Ref<ModulatedParameter> FilteredDelay::get_delay_time_parameter() const {
	return get_parameter(PARAM_DELAY_TIME);
}

void FilteredDelay::set_delay_time_base_value(float p_value) {
	Ref<ModulatedParameter> param = get_delay_time_parameter();
	if (param.is_valid()) {
		param->set_base_value(p_value);
	}
}

float FilteredDelay::get_delay_time_base_value() const {
	Ref<ModulatedParameter> param = get_delay_time_parameter();
	if (param.is_valid()) {
		return param->get_base_value();
	}
	return 0.0f;
}

void FilteredDelay::set_feedback_parameter(const Ref<ModulatedParameter> &param) {
	if (param.is_valid()) {
		set_parameter(PARAM_FEEDBACK, param);
	}
}

Ref<ModulatedParameter> FilteredDelay::get_feedback_parameter() const {
	return get_parameter(PARAM_FEEDBACK);
}

void FilteredDelay::set_feedback_base_value(float p_value) {
	Ref<ModulatedParameter> param = get_feedback_parameter();
	if (param.is_valid()) {
		param->set_base_value(p_value);
	}
}

float FilteredDelay::get_feedback_base_value() const {
	Ref<ModulatedParameter> param = get_feedback_parameter();
	if (param.is_valid()) {
		return param->get_base_value();
	}
	return 0.0f;
}

void FilteredDelay::set_mix_parameter(const Ref<ModulatedParameter> &param) {
	if (param.is_valid()) {
		set_parameter(PARAM_MIX, param);
	}
}

Ref<ModulatedParameter> FilteredDelay::get_mix_parameter() const {
	return get_parameter(PARAM_MIX);
}

void FilteredDelay::set_mix_base_value(float p_value) {
	Ref<ModulatedParameter> param = get_mix_parameter();
	if (param.is_valid()) {
		param->set_base_value(p_value);
	}
}

float FilteredDelay::get_mix_base_value() const {
	Ref<ModulatedParameter> param = get_mix_parameter();
	if (param.is_valid()) {
		return param->get_base_value();
	}
	return 0.0f;
}

void FilteredDelay::set_lp_freq_parameter(const Ref<ModulatedParameter> &param) {
	if (param.is_valid()) {
		set_parameter(PARAM_LP_FREQ, param);
	}
}

Ref<ModulatedParameter> FilteredDelay::get_lp_freq_parameter() const {
	return get_parameter(PARAM_LP_FREQ);
}

void FilteredDelay::set_lp_freq_base_value(float p_value) {
	Ref<ModulatedParameter> param = get_lp_freq_parameter();
	if (param.is_valid()) {
		param->set_base_value(p_value);
	}
}

float FilteredDelay::get_lp_freq_base_value() const {
	Ref<ModulatedParameter> param = get_lp_freq_parameter();
	if (param.is_valid()) {
		return param->get_base_value();
	}
	return 0.0f;
}

void FilteredDelay::set_hp_freq_parameter(const Ref<ModulatedParameter> &param) {
	if (param.is_valid()) {
		set_parameter(PARAM_HP_FREQ, param);
	}
}

Ref<ModulatedParameter> FilteredDelay::get_hp_freq_parameter() const {
	return get_parameter(PARAM_HP_FREQ);
}

void FilteredDelay::set_hp_freq_base_value(float p_value) {
	Ref<ModulatedParameter> param = get_hp_freq_parameter();
	if (param.is_valid()) {
		param->set_base_value(p_value);
	}
}

float FilteredDelay::get_hp_freq_base_value() const {
	Ref<ModulatedParameter> param = get_hp_freq_parameter();
	if (param.is_valid()) {
		return param->get_base_value();
	}
	return 0.0f;
}

void FilteredDelay::set_resonance_parameter(const Ref<ModulatedParameter> &param) {
	if (param.is_valid()) {
		set_parameter(PARAM_RESONANCE, param);
	}
}

Ref<ModulatedParameter> FilteredDelay::get_resonance_parameter() const {
	return get_parameter(PARAM_RESONANCE);
}

void FilteredDelay::set_resonance_base_value(float p_value) {
	Ref<ModulatedParameter> param = get_resonance_parameter();
	if (param.is_valid()) {
		param->set_base_value(p_value);
	}
}

float FilteredDelay::get_resonance_base_value() const {
	Ref<ModulatedParameter> param = get_resonance_parameter();
	if (param.is_valid()) {
		return param->get_base_value();
	}
	return 0.0f;
}

} // namespace godot
