#include "multi_tap_delay.h"
#include <cmath>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/math.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

namespace godot {

// Define parameter name constants
const char *MultiTapDelay::PARAM_BASE_DELAY = "base_delay";
const char *MultiTapDelay::PARAM_FEEDBACK = "feedback";
const char *MultiTapDelay::PARAM_MIX = "mix";
const char *MultiTapDelay::PARAM_SPREAD = "spread";
const char *MultiTapDelay::PARAM_TAPS = "taps";
const char *MultiTapDelay::PARAM_DECAY = "decay";

void MultiTapDelay::_bind_methods() {
	// Bind parameter accessors

	ClassDB::bind_method(D_METHOD("set_base_delay_base_value", "value"), &MultiTapDelay::set_base_delay_base_value);
	ClassDB::bind_method(D_METHOD("get_base_delay_base_value"), &MultiTapDelay::get_base_delay_base_value);
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "base_delay", PROPERTY_HINT_RANGE, "0,1,0.01"),
			"set_base_delay_base_value", "get_base_delay_base_value");
	ClassDB::bind_method(D_METHOD("set_base_delay_parameter", "param"), &MultiTapDelay::set_base_delay_parameter);
	ClassDB::bind_method(D_METHOD("get_base_delay_parameter"), &MultiTapDelay::get_base_delay_parameter);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "base_delay_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
			"set_base_delay_parameter", "get_base_delay_parameter");

	ClassDB::bind_method(D_METHOD("set_feedback_base_value", "value"), &MultiTapDelay::set_feedback_base_value);
	ClassDB::bind_method(D_METHOD("get_feedback_base_value"), &MultiTapDelay::get_feedback_base_value);
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "feedback", PROPERTY_HINT_RANGE, "0,1,0.01"),
			"set_feedback_base_value", "get_feedback_base_value");
	ClassDB::bind_method(D_METHOD("set_feedback_parameter", "param"), &MultiTapDelay::set_feedback_parameter);
	ClassDB::bind_method(D_METHOD("get_feedback_parameter"), &MultiTapDelay::get_feedback_parameter);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "feedback_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
			"set_feedback_parameter", "get_feedback_parameter");

	ClassDB::bind_method(D_METHOD("set_mix_base_value", "value"), &MultiTapDelay::set_mix_base_value);
	ClassDB::bind_method(D_METHOD("get_mix_base_value"), &MultiTapDelay::get_mix_base_value);
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "mix", PROPERTY_HINT_RANGE, "0,1,0.01"),
			"set_mix_base_value", "get_mix_base_value");
	ClassDB::bind_method(D_METHOD("set_mix_parameter", "param"), &MultiTapDelay::set_mix_parameter);
	ClassDB::bind_method(D_METHOD("get_mix_parameter"), &MultiTapDelay::get_mix_parameter);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "mix_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
			"set_mix_parameter", "get_mix_parameter");

	ClassDB::bind_method(D_METHOD("set_spread_base_value", "value"), &MultiTapDelay::set_spread_base_value);
	ClassDB::bind_method(D_METHOD("get_spread_base_value"), &MultiTapDelay::get_spread_base_value);
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "spread", PROPERTY_HINT_RANGE, "0,1,0.01"),
			"set_spread_base_value", "get_spread_base_value");
	ClassDB::bind_method(D_METHOD("set_spread_parameter", "param"), &MultiTapDelay::set_spread_parameter);
	ClassDB::bind_method(D_METHOD("get_spread_parameter"), &MultiTapDelay::get_spread_parameter);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "spread_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
			"set_spread_parameter", "get_spread_parameter");

	ClassDB::bind_method(D_METHOD("set_taps_base_value", "value"), &MultiTapDelay::set_taps_base_value);
	ClassDB::bind_method(D_METHOD("get_taps_base_value"), &MultiTapDelay::get_taps_base_value);
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "taps", PROPERTY_HINT_RANGE, "0,1,0.01"),
			"set_taps_base_value", "get_taps_base_value");
	ClassDB::bind_method(D_METHOD("set_taps_parameter", "param"), &MultiTapDelay::set_taps_parameter);
	ClassDB::bind_method(D_METHOD("get_taps_parameter"), &MultiTapDelay::get_taps_parameter);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "taps_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
			"set_taps_parameter", "get_taps_parameter");

	ClassDB::bind_method(D_METHOD("set_decay_base_value", "value"), &MultiTapDelay::set_decay_base_value);
	ClassDB::bind_method(D_METHOD("get_decay_base_value"), &MultiTapDelay::get_decay_base_value);
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "decay", PROPERTY_HINT_RANGE, "0,1,0.01"),
			"set_decay_base_value", "get_decay_base_value");
	ClassDB::bind_method(D_METHOD("set_decay_parameter", "param"), &MultiTapDelay::set_decay_parameter);
	ClassDB::bind_method(D_METHOD("get_decay_parameter"), &MultiTapDelay::get_decay_parameter);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "decay_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
			"set_decay_parameter", "get_decay_parameter");
}

MultiTapDelay::MultiTapDelay() {
	// Initialize delay buffer (3 seconds at 44.1kHz)
	delay_buffer.resize(132300, 0.0f);
	buffer_position = 0;

	// Create default parameters
	Ref<ModulatedParameter> base_delay_param = memnew(ModulatedParameter);
	base_delay_param->set_base_value(0.3f); // 300ms base delay
	base_delay_param->set_mod_min(0.05f); // 50ms minimum
	base_delay_param->set_mod_max(1.0f); // 1 second maximum
	set_parameter(PARAM_BASE_DELAY, base_delay_param);

	Ref<ModulatedParameter> feedback_param = memnew(ModulatedParameter);
	feedback_param->set_base_value(0.3f); // 30% feedback
	feedback_param->set_mod_min(0.0f); // No feedback
	feedback_param->set_mod_max(0.9f); // 90% feedback
	set_parameter(PARAM_FEEDBACK, feedback_param);

	Ref<ModulatedParameter> mix_param = memnew(ModulatedParameter);
	mix_param->set_base_value(0.5f); // 50% wet/dry mix
	mix_param->set_mod_min(0.0f); // Dry only
	mix_param->set_mod_max(1.0f); // Wet only
	set_parameter(PARAM_MIX, mix_param);

	Ref<ModulatedParameter> spread_param = memnew(ModulatedParameter);
	spread_param->set_base_value(0.5f); // 50% spread
	spread_param->set_mod_min(0.1f); // Minimal spread
	spread_param->set_mod_max(2.0f); // Maximum spread
	set_parameter(PARAM_SPREAD, spread_param);

	Ref<ModulatedParameter> taps_param = memnew(ModulatedParameter);
	taps_param->set_base_value(4.0f); // 4 taps
	taps_param->set_mod_min(2.0f); // Minimum 2 taps
	taps_param->set_mod_max(8.0f); // Maximum 8 taps
	set_parameter(PARAM_TAPS, taps_param);

	Ref<ModulatedParameter> decay_param = memnew(ModulatedParameter);
	decay_param->set_base_value(0.7f); // 70% decay
	decay_param->set_mod_min(0.1f); // Minimal decay
	decay_param->set_mod_max(0.95f); // Maximum decay
	set_parameter(PARAM_DECAY, decay_param);

	// Initialize taps
	update_taps(0.3f, 0.5f, 4, 0.7f);
}

MultiTapDelay::~MultiTapDelay() {
	// Clean up resources
}

void MultiTapDelay::update_taps(float base_delay, float spread, int num_taps, float decay) {
	taps.clear();

	for (int i = 0; i < num_taps; i++) {
		DelayTap tap;

		// Calculate delay time for this tap
		// Each tap is progressively further apart based on spread
		float tap_multiplier = 1.0f + (i * spread);
		tap.delay_time = base_delay * tap_multiplier;

		// Calculate level for this tap (decaying)
		tap.level = std::pow(decay, i);

		taps.push_back(tap);
	}
}

float MultiTapDelay::process_sample(float sample, const Ref<SynthNoteContext> &context) {
	if (!context.is_valid())
		return sample; // Return original sample if context is invalid

	// Get parameter values
	float base_delay = 0.3f; // Default: 300ms
	float feedback = 0.3f; // Default: 30%
	float mix = 0.5f; // Default: 50% wet/dry
	float spread = 0.5f; // Default: 50% spread
	int num_taps = 4; // Default: 4 taps
	float decay = 0.7f; // Default: 70% decay

	Ref<ModulatedParameter> base_delay_param = get_parameter(PARAM_BASE_DELAY);
	if (base_delay_param.is_valid()) {
		base_delay = base_delay_param->get_value(context);
	}

	Ref<ModulatedParameter> fb_param = get_parameter(PARAM_FEEDBACK);
	if (fb_param.is_valid()) {
		feedback = fb_param->get_value(context);
	}

	Ref<ModulatedParameter> mix_param = get_parameter(PARAM_MIX);
	if (mix_param.is_valid()) {
		mix = mix_param->get_value(context);
	}

	Ref<ModulatedParameter> spread_param = get_parameter(PARAM_SPREAD);
	if (spread_param.is_valid()) {
		spread = spread_param->get_value(context);
	}

	Ref<ModulatedParameter> taps_param = get_parameter(PARAM_TAPS);
	if (taps_param.is_valid()) {
		num_taps = static_cast<int>(taps_param->get_value(context));
		// Ensure we have at least 2 taps
		num_taps = std::max(2, num_taps);
	}

	Ref<ModulatedParameter> decay_param = get_parameter(PARAM_DECAY);
	if (decay_param.is_valid()) {
		decay = decay_param->get_value(context);
	}

	// Update taps if parameters have changed
	update_taps(base_delay, spread, num_taps, decay);

	// Calculate sample rate (assuming 44.1kHz)
	const float sample_rate = 44100.0f;

	float input = sample;
	float output = 0.0f;

	// Process each tap
	for (size_t t = 0; t < taps.size(); t++) {
		// Calculate delay in samples
		int delay_samples = static_cast<int>(taps[t].delay_time * sample_rate);
		if (delay_samples >= delay_buffer.size()) {
			delay_samples = delay_buffer.size() - 1;
		}

		// Calculate read position with wraparound
		int read_pos = buffer_position - delay_samples;
		if (read_pos < 0) {
			read_pos += delay_buffer.size();
		}

		// Read delayed sample and add to output
		output += delay_buffer[read_pos] * taps[t].level;
	}

	// Write to delay buffer with feedback
	delay_buffer[buffer_position] = input + output * feedback;

	// Increment and wrap buffer position
	buffer_position = (buffer_position + 1) % delay_buffer.size();

	// Mix dry and wet signals
	return input * (1.0f - mix) + output * mix;
}

void MultiTapDelay::reset() {
	// Clear delay buffer
	std::fill(delay_buffer.begin(), delay_buffer.end(), 0.0f);
	buffer_position = 0;
}

float MultiTapDelay::get_tail_length() const {
	// Get the base delay and feedback parameters
	float base_delay = 0.3f; // Default: 300ms
	float feedback = 0.3f; // Default: 30%
	float spread = 0.5f; // Default: 50% spread
	int num_taps = 4; // Default: 4 taps

	Ref<ModulatedParameter> base_delay_param = get_parameter(PARAM_BASE_DELAY);
	if (base_delay_param.is_valid()) {
		base_delay = base_delay_param->get_base_value();
	}

	Ref<ModulatedParameter> fb_param = get_parameter(PARAM_FEEDBACK);
	if (fb_param.is_valid()) {
		feedback = fb_param->get_base_value();
	}

	Ref<ModulatedParameter> spread_param = get_parameter(PARAM_SPREAD);
	if (spread_param.is_valid()) {
		spread = spread_param->get_base_value();
	}

	Ref<ModulatedParameter> taps_param = get_parameter(PARAM_TAPS);
	if (taps_param.is_valid()) {
		num_taps = static_cast<int>(taps_param->get_base_value());
		num_taps = std::max(2, num_taps);
	}

	// Calculate the longest tap delay time
	float longest_tap = base_delay * (1.0f + ((num_taps - 1) * spread));

	// Calculate tail length based on longest tap and feedback
	if (feedback < 0.001f) {
		return longest_tap; // Just one repeat
	}

	// Calculate number of repeats to reach -60dB
	float repeats = std::log(0.001f) / std::log(feedback);
	if (repeats < 0) {
		repeats = 10.0f;
	}

	// Return total tail length: longest_tap * repeats
	return longest_tap * repeats;
}

Ref<SynthAudioEffect> MultiTapDelay::duplicate() const {
	Ref<MultiTapDelay> new_delay = memnew(MultiTapDelay);

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

	// Update taps based on current parameters
	float base_delay = 0.3f;
	float spread = 0.5f;
	int num_taps = 4;
	float decay = 0.7f;

	Ref<ModulatedParameter> base_delay_param = get_parameter(PARAM_BASE_DELAY);
	if (base_delay_param.is_valid()) {
		base_delay = base_delay_param->get_base_value();
	}

	Ref<ModulatedParameter> spread_param = get_parameter(PARAM_SPREAD);
	if (spread_param.is_valid()) {
		spread = spread_param->get_base_value();
	}

	Ref<ModulatedParameter> taps_param = get_parameter(PARAM_TAPS);
	if (taps_param.is_valid()) {
		num_taps = static_cast<int>(taps_param->get_base_value());
	}

	Ref<ModulatedParameter> decay_param = get_parameter(PARAM_DECAY);
	if (decay_param.is_valid()) {
		decay = decay_param->get_base_value();
	}

	new_delay->update_taps(base_delay, spread, num_taps, decay);

	return new_delay;
}

// Parameter accessors
void MultiTapDelay::set_base_delay_parameter(const Ref<ModulatedParameter> &param) {
	if (param.is_valid()) {
		set_parameter(PARAM_BASE_DELAY, param);
	}
}

Ref<ModulatedParameter> MultiTapDelay::get_base_delay_parameter() const {
	return get_parameter(PARAM_BASE_DELAY);
}

void MultiTapDelay::set_base_delay_base_value(float p_value) {
	Ref<ModulatedParameter> param = get_base_delay_parameter();
	if (param.is_valid()) {
		param->set_base_value(p_value);
	}
}

float MultiTapDelay::get_base_delay_base_value() const {
	Ref<ModulatedParameter> param = get_base_delay_parameter();
	if (param.is_valid()) {
		return param->get_base_value();
	}
	return 0.0f;
}

void MultiTapDelay::set_feedback_parameter(const Ref<ModulatedParameter> &param) {
	if (param.is_valid()) {
		set_parameter(PARAM_FEEDBACK, param);
	}
}

Ref<ModulatedParameter> MultiTapDelay::get_feedback_parameter() const {
	return get_parameter(PARAM_FEEDBACK);
}

void MultiTapDelay::set_feedback_base_value(float p_value) {
	Ref<ModulatedParameter> param = get_feedback_parameter();
	if (param.is_valid()) {
		param->set_base_value(p_value);
	}
}

float MultiTapDelay::get_feedback_base_value() const {
	Ref<ModulatedParameter> param = get_feedback_parameter();
	if (param.is_valid()) {
		return param->get_base_value();
	}
	return 0.0f;
}

void MultiTapDelay::set_mix_parameter(const Ref<ModulatedParameter> &param) {
	if (param.is_valid()) {
		set_parameter(PARAM_MIX, param);
	}
}

Ref<ModulatedParameter> MultiTapDelay::get_mix_parameter() const {
	return get_parameter(PARAM_MIX);
}

void MultiTapDelay::set_mix_base_value(float p_value) {
	Ref<ModulatedParameter> param = get_mix_parameter();
	if (param.is_valid()) {
		param->set_base_value(p_value);
	}
}

float MultiTapDelay::get_mix_base_value() const {
	Ref<ModulatedParameter> param = get_mix_parameter();
	if (param.is_valid()) {
		return param->get_base_value();
	}
	return 0.0f;
}

void MultiTapDelay::set_spread_parameter(const Ref<ModulatedParameter> &param) {
	if (param.is_valid()) {
		set_parameter(PARAM_SPREAD, param);
	}
}

Ref<ModulatedParameter> MultiTapDelay::get_spread_parameter() const {
	return get_parameter(PARAM_SPREAD);
}

void MultiTapDelay::set_spread_base_value(float p_value) {
	Ref<ModulatedParameter> param = get_spread_parameter();
	if (param.is_valid()) {
		param->set_base_value(p_value);
	}
}

float MultiTapDelay::get_spread_base_value() const {
	Ref<ModulatedParameter> param = get_spread_parameter();
	if (param.is_valid()) {
		return param->get_base_value();
	}
	return 0.0f;
}

void MultiTapDelay::set_taps_parameter(const Ref<ModulatedParameter> &param) {
	if (param.is_valid()) {
		set_parameter(PARAM_TAPS, param);
	}
}

Ref<ModulatedParameter> MultiTapDelay::get_taps_parameter() const {
	return get_parameter(PARAM_TAPS);
}

void MultiTapDelay::set_taps_base_value(float p_value) {
	Ref<ModulatedParameter> param = get_taps_parameter();
	if (param.is_valid()) {
		param->set_base_value(p_value);
	}
}

float MultiTapDelay::get_taps_base_value() const {
	Ref<ModulatedParameter> param = get_taps_parameter();
	if (param.is_valid()) {
		return param->get_base_value();
	}
	return 0.0f;
}

void MultiTapDelay::set_decay_parameter(const Ref<ModulatedParameter> &param) {
	if (param.is_valid()) {
		set_parameter(PARAM_DECAY, param);
	}
}

Ref<ModulatedParameter> MultiTapDelay::get_decay_parameter() const {
	return get_parameter(PARAM_DECAY);
}

void MultiTapDelay::set_decay_base_value(float p_value) {
	Ref<ModulatedParameter> param = get_decay_parameter();
	if (param.is_valid()) {
		param->set_base_value(p_value);
	}
}

float MultiTapDelay::get_decay_base_value() const {
	Ref<ModulatedParameter> param = get_decay_parameter();
	if (param.is_valid()) {
		return param->get_base_value();
	}
	return 0.0f;
}

} // namespace godot
