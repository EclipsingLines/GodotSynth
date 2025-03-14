#include "delay_effect.h"
#include <cmath>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/math.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

namespace godot {

// Define parameter name constants
const char *DelayEffect::PARAM_DELAY_TIME = "delay_time";
const char *DelayEffect::PARAM_FEEDBACK = "feedback";
const char *DelayEffect::PARAM_MIX = "mix";

void DelayEffect::_bind_methods() {
	// Bind parameter accessors
	ClassDB::bind_method(D_METHOD("set_delay_time_parameter", "param"), &DelayEffect::set_delay_time_parameter);
	ClassDB::bind_method(D_METHOD("get_delay_time_parameter"), &DelayEffect::get_delay_time_parameter);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "delay_time_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
			"set_delay_time_parameter", "get_delay_time_parameter");

	ClassDB::bind_method(D_METHOD("set_feedback_parameter", "param"), &DelayEffect::set_feedback_parameter);
	ClassDB::bind_method(D_METHOD("get_feedback_parameter"), &DelayEffect::get_feedback_parameter);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "feedback_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
			"set_feedback_parameter", "get_feedback_parameter");

	ClassDB::bind_method(D_METHOD("set_mix_parameter", "param"), &DelayEffect::set_mix_parameter);
	ClassDB::bind_method(D_METHOD("get_mix_parameter"), &DelayEffect::get_mix_parameter);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "mix_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
			"set_mix_parameter", "get_mix_parameter");
}

DelayEffect::DelayEffect() {
	// Initialize delay buffer (2 seconds at 44.1kHz)
	delay_buffer.resize(88200, 0.0f);
	buffer_position = 0;

	// Create default parameters
	Ref<ModulatedParameter> delay_time_param = memnew(ModulatedParameter);
	delay_time_param->set_base_value(0.5f); // 500ms delay
	delay_time_param->set_mod_min(0.01f); // 10ms minimum
	delay_time_param->set_mod_max(2.0f); // 2 seconds maximum
	set_parameter(PARAM_DELAY_TIME, delay_time_param);

	Ref<ModulatedParameter> feedback_param = memnew(ModulatedParameter);
	feedback_param->set_base_value(0.3f); // 30% feedback
	feedback_param->set_mod_min(0.0f); // No feedback
	feedback_param->set_mod_max(0.95f); // Almost 100% feedback (avoid instability)
	set_parameter(PARAM_FEEDBACK, feedback_param);

	Ref<ModulatedParameter> mix_param = memnew(ModulatedParameter);
	mix_param->set_base_value(0.5f); // 50% wet/dry mix
	mix_param->set_mod_min(0.0f); // Dry only
	mix_param->set_mod_max(1.0f); // Wet only
	set_parameter(PARAM_MIX, mix_param);
}

DelayEffect::~DelayEffect() {
	// Clean up resources
}

float DelayEffect::process_sample(float sample, const Ref<SynthNoteContext> &context) {
	if (!context.is_valid())
		return sample; // Return original sample if context is invalid

	// Get parameter values
	float delay_time = 0.5f; // Default: 500ms
	float feedback = 0.3f; // Default: 30%
	float mix = 0.5f; // Default: 50% wet/dry

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

	// Calculate delay in samples (assuming 44.1kHz sample rate)
	int delay_samples = int(delay_time * 44100.0f);
	if (delay_samples >= delay_buffer.size()) {
		delay_samples = delay_buffer.size() - 1;
	}

	// Calculate read position with wraparound
	int read_pos = buffer_position - delay_samples;
	if (read_pos < 0) {
		read_pos += delay_buffer.size();
	}

	// Read delayed sample
	float delayed_sample = delay_buffer[read_pos];

	// Write to delay buffer with feedback
	delay_buffer[buffer_position] = sample + delayed_sample * feedback;

	// Increment and wrap buffer position
	buffer_position = (buffer_position + 1) % delay_buffer.size();

	// Mix dry and wet signals
	return sample * (1.0f - mix) + delayed_sample * mix;
}

void DelayEffect::reset() {
	// Clear delay buffer
	std::fill(delay_buffer.begin(), delay_buffer.end(), 0.0f);
	buffer_position = 0;

	// Log that the delay effect has been reset
}

float DelayEffect::get_tail_length() const {
	// Get the delay time parameter
	float delay_time = 0.5f; // Default: 500ms
	float feedback = 0.3f; // Default: 30%

	Ref<ModulatedParameter> delay_param = get_parameter(PARAM_DELAY_TIME);
	if (delay_param.is_valid()) {
		delay_time = delay_param->get_base_value();
	}

	Ref<ModulatedParameter> fb_param = get_parameter(PARAM_FEEDBACK);
	if (fb_param.is_valid()) {
		feedback = fb_param->get_base_value();
	}

	// Calculate tail length based on delay time and feedback
	// For a delay effect, the tail length depends on how many times the signal
	// will repeat at an audible level. We use a threshold of -60dB (0.001 amplitude)

	if (feedback < 0.001f) {
		return delay_time; // Just one repeat
	}

	// Calculate number of repeats to reach -60dB
	// Formula: feedback^n < 0.001, solve for n: n = log(0.001)/log(feedback)
	float repeats = std::log(0.001f) / std::log(feedback);
	if (repeats < 0) {
		// If feedback > 1 (which shouldn't happen but just in case),
		// this would give a negative value, so cap it
		repeats = 10.0f;
	}

	// Return total tail length: delay_time * sum of geometric series
	// This is approximately delay_time * repeats for feedback < 1
	return delay_time * repeats;
}

Ref<SynthAudioEffect> DelayEffect::duplicate() const {
	Ref<DelayEffect> new_delay = memnew(DelayEffect);

	// Copy parameters
	Dictionary params = get_parameters();
	Array param_names = params.keys();
	for (int i = 0; i < param_names.size(); i++) {
		String name = param_names[i];
		Ref<ModulatedParameter> param = params[name];
		if (param.is_valid()) {
			Ref<ModulatedParameter> new_param = param->duplicate();
			new_delay->set_parameter(name, new_param);
		}
	}

	return new_delay;
}

// Parameter accessors
void DelayEffect::set_delay_time_parameter(const Ref<ModulatedParameter> &param) {
	if (param.is_valid()) {
		set_parameter(PARAM_DELAY_TIME, param);
	}
}

Ref<ModulatedParameter> DelayEffect::get_delay_time_parameter() const {
	return get_parameter(PARAM_DELAY_TIME);
}

void DelayEffect::set_feedback_parameter(const Ref<ModulatedParameter> &param) {
	if (param.is_valid()) {
		set_parameter(PARAM_FEEDBACK, param);
	}
}

Ref<ModulatedParameter> DelayEffect::get_feedback_parameter() const {
	return get_parameter(PARAM_FEEDBACK);
}

void DelayEffect::set_mix_parameter(const Ref<ModulatedParameter> &param) {
	if (param.is_valid()) {
		set_parameter(PARAM_MIX, param);
	}
}

Ref<ModulatedParameter> DelayEffect::get_mix_parameter() const {
	return get_parameter(PARAM_MIX);
}

} // namespace godot
