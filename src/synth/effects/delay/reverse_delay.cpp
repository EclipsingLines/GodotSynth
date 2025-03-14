#include "reverse_delay.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/math.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

namespace godot {

// Define parameter name constants
const char *ReverseDelay::PARAM_DELAY_TIME = "delay_time";
const char *ReverseDelay::PARAM_FEEDBACK = "feedback";
const char *ReverseDelay::PARAM_MIX = "mix";
const char *ReverseDelay::PARAM_CROSSFADE = "crossfade";

void ReverseDelay::_bind_methods() {
	// Bind parameter accessors
	ClassDB::bind_method(D_METHOD("set_crossfade_parameter", "param"), &ReverseDelay::set_crossfade_parameter);
	ClassDB::bind_method(D_METHOD("get_crossfade_parameter"), &ReverseDelay::get_crossfade_parameter);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "crossfade_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
			"set_crossfade_parameter", "get_crossfade_parameter");
}

ReverseDelay::ReverseDelay() {
	// Initialize with a default buffer size (2 seconds at 44.1kHz)
	buffer_size = 88200;
	reverse_buffer.resize(buffer_size, 0.0f);
	write_position = 0;
	read_position = 0;
	is_recording = true;

	// Create default parameters
	Ref<ModulatedParameter> delay_time_param = memnew(ModulatedParameter);
	delay_time_param->set_base_value(1.0f); // 1 second delay
	delay_time_param->set_mod_min(0.1f); // 100ms minimum
	delay_time_param->set_mod_max(2.0f); // 2 seconds maximum
	set_parameter(PARAM_DELAY_TIME, delay_time_param);

	Ref<ModulatedParameter> feedback_param = memnew(ModulatedParameter);
	feedback_param->set_base_value(0.3f); // 30% feedback
	feedback_param->set_mod_min(0.0f); // No feedback
	feedback_param->set_mod_max(0.9f); // 90% feedback (avoid instability)
	set_parameter(PARAM_FEEDBACK, feedback_param);

	Ref<ModulatedParameter> mix_param = memnew(ModulatedParameter);
	mix_param->set_base_value(0.5f); // 50% wet/dry mix
	mix_param->set_mod_min(0.0f); // Dry only
	mix_param->set_mod_max(1.0f); // Wet only
	set_parameter(PARAM_MIX, mix_param);

	Ref<ModulatedParameter> crossfade_param = memnew(ModulatedParameter);
	crossfade_param->set_base_value(0.1f); // 10% crossfade
	crossfade_param->set_mod_min(0.0f); // No crossfade
	crossfade_param->set_mod_max(0.5f); // 50% crossfade
	set_parameter(PARAM_CROSSFADE, crossfade_param);
}

ReverseDelay::~ReverseDelay() {
	// Cleanup if needed
}

float ReverseDelay::process_sample(float sample, const Ref<SynthNoteContext> &context) {
	if (!context.is_valid())
		return sample; // Return original sample if context is invalid

	// Get parameter values
	float delay_time = 1.0f; // Default: 1 second
	float feedback = 0.3f; // Default: 30%
	float mix = 0.5f; // Default: 50% wet/dry
	float crossfade = 0.1f; // Default: 10% crossfade

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

	Ref<ModulatedParameter> crossfade_param = get_parameter(PARAM_CROSSFADE);
	if (crossfade_param.is_valid()) {
		crossfade = crossfade_param->get_value(context);
	}

	// Calculate delay in samples (assuming 44.1kHz sample rate)
	int delay_samples = static_cast<int>(delay_time * 44100.0f);
	if (delay_samples >= buffer_size) {
		delay_samples = buffer_size - 1;
	}

	// Calculate crossfade samples
	int crossfade_samples = static_cast<int>(crossfade * delay_samples);

	float input = sample;
	float output = 0.0f;

	// Store input in reverse buffer
	reverse_buffer[write_position] = input;

	// Check if we need to switch between recording and playback
	if (is_recording && write_position >= delay_samples - 1) {
		is_recording = false;
		read_position = write_position; // Start reading from the end
	}

	if (!is_recording) {
		// Read from reverse buffer (backwards)
		float delayed_sample = reverse_buffer[read_position];

		// Apply crossfade if near the boundaries
		float fade_factor = 1.0f;
		int distance_from_start = read_position;
		int distance_from_end = delay_samples - 1 - read_position;

		if (distance_from_start < crossfade_samples) {
			fade_factor = static_cast<float>(distance_from_start) / crossfade_samples;
		} else if (distance_from_end < crossfade_samples) {
			fade_factor = static_cast<float>(distance_from_end) / crossfade_samples;
		}

		// Apply fade factor
		output = delayed_sample * fade_factor;

		// Move read position backwards (with wraparound)
		read_position--;
		if (read_position < 0) {
			read_position = delay_samples - 1;

			// Apply feedback by copying the buffer with attenuation
			for (int j = 0; j < delay_samples; j++) {
				reverse_buffer[j] *= feedback;
			}
		}
	}

	// Increment write position with wraparound
	write_position = (write_position + 1) % buffer_size;

	// Mix dry and wet signals
	return input * (1.0f - mix) + output * mix;
}

void ReverseDelay::reset() {
	// Clear reverse buffer
	std::fill(reverse_buffer.begin(), reverse_buffer.end(), 0.0f);
	write_position = 0;
	read_position = 0;
	is_recording = true;
}

Ref<SynthAudioEffect> ReverseDelay::duplicate() const {
	Ref<ReverseDelay> new_delay = memnew(ReverseDelay);

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
void ReverseDelay::set_crossfade_parameter(const Ref<ModulatedParameter> &param) {
	if (param.is_valid()) {
		set_parameter(PARAM_CROSSFADE, param);
	}
}

Ref<ModulatedParameter> ReverseDelay::get_crossfade_parameter() const {
	return get_parameter(PARAM_CROSSFADE);
}

} // namespace godot
