#include "va_oscillator_engine.h"
#include "../core/modulated_parameter.h"
#include "../core/synth_note_context.h"
#include "../core/wave_helper_cache.h"
#include "va_synth_configuration.h"
#include <cmath>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/templates/pair.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

namespace godot {

void VAOscillatorEngine::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_bottom_waveform", "type"), &VAOscillatorEngine::set_bottom_waveform);
	ClassDB::bind_method(D_METHOD("get_bottom_waveform"), &VAOscillatorEngine::get_bottom_waveform);

	ClassDB::bind_method(D_METHOD("set_middle_waveform", "type"), &VAOscillatorEngine::set_middle_waveform);
	ClassDB::bind_method(D_METHOD("get_middle_waveform"), &VAOscillatorEngine::get_middle_waveform);

	ClassDB::bind_method(D_METHOD("set_top_waveform", "type"), &VAOscillatorEngine::set_top_waveform);
	ClassDB::bind_method(D_METHOD("get_top_waveform"), &VAOscillatorEngine::get_top_waveform);

	ClassDB::bind_method(D_METHOD("set_parameter", "name", "param"), &VAOscillatorEngine::set_parameter);
	ClassDB::bind_method(D_METHOD("get_parameter", "name"), &VAOscillatorEngine::get_parameter);
	ClassDB::bind_method(D_METHOD("get_parameters"), &VAOscillatorEngine::get_parameters);
}

VAOscillatorEngine::VAOscillatorEngine() :
		bottom_waveform(WaveHelper::SINE),
		middle_waveform(WaveHelper::TRIANGLE),
		top_waveform(WaveHelper::SAW),
		phase(0.0f),
		cached_morph_position(0.5f),
		cached_amplitude(0.0f),
		cached_pulse_width(0.5f),
		cached_output_gain(1.0f),
		use_cached_values(false) {
}

VAOscillatorEngine::~VAOscillatorEngine() {
}

float VAOscillatorEngine::get_frequency_for_note(int note) const {
	// A4 = 440Hz = MIDI note 69
	return 440.0f * std::pow(2.0f, (note - 69) / 12.0f);
}

float VAOscillatorEngine::get_morphed_sample(float p_phase, float morph_position, float pulse_width) const {
	// Get samples from each waveform using the cache if available
	float bottom_sample, middle_sample, top_sample;
	
	WaveHelperCache *cache = WaveHelperCache::get_singleton();
	if (cache) {
		bottom_sample = cache->get_sample(p_phase, bottom_waveform, pulse_width);
		middle_sample = cache->get_sample(p_phase, middle_waveform, pulse_width);
		top_sample = cache->get_sample(p_phase, top_waveform, pulse_width);
	} else {
		// Fallback to direct calculation if cache is not available
		bottom_sample = WaveHelper::get_wave_sample(p_phase, bottom_waveform, pulse_width);
		middle_sample = WaveHelper::get_wave_sample(p_phase, middle_waveform, pulse_width);
		top_sample = WaveHelper::get_wave_sample(p_phase, top_waveform, pulse_width);
	}

	// Morph between the waveforms based on position
	if (morph_position <= 0.5f) {
		// Morph between bottom and middle (0.0 to 0.5)
		float t = morph_position * 2.0f; // Scale to 0-1 range
		return bottom_sample * (1.0f - t) + middle_sample * t;
	} else {
		// Morph between middle and top (0.5 to 1.0)
		float t = (morph_position - 0.5f) * 2.0f; // Scale to 0-1 range
		return middle_sample * (1.0f - t) + top_sample * t;
	}
}

void VAOscillatorEngine::set_parameter(const String &name, const Ref<ModulatedParameter> &param) {
	parameters[name] = param;
}

Ref<ModulatedParameter> VAOscillatorEngine::get_parameter(const String &name) const {
	if (parameters.has(name)) {
		return parameters[name];
	}
	return Ref<ModulatedParameter>();
}

Dictionary VAOscillatorEngine::get_parameters() const {
	return parameters;
}

PackedFloat32Array VAOscillatorEngine::process_block(int buffer_size, const Ref<SynthNoteContext> &context) {
	// Create output buffer
	PackedFloat32Array output_buffer;
	output_buffer.resize(buffer_size);

	if (!context.is_valid()) {
		// Fill buffer with silence
		std::fill(output_buffer.ptrw(), output_buffer.ptrw() + buffer_size, 0.0f);
		return output_buffer;
	}

	// If no note is playing, return silence
	if (context->get_note() < 0 || context->get_velocity() <= 0.0f) {
		std::fill(output_buffer.ptrw(), output_buffer.ptrw() + buffer_size, 0.0f);
		return output_buffer;
	}

	// Calculate frequency for the current note
	float frequency = get_frequency_for_note(context->get_note());

	// Apply pitch modulation if available
	if (parameters.has(VASynthConfiguration::PARAM_PITCH)) {
		Ref<ModulatedParameter> pitch_param = parameters[VASynthConfiguration::PARAM_PITCH];
		if (pitch_param.is_valid()) {
			float pitch_offset = pitch_param->get_value(context);
			// Convert semitone offset to frequency multiplier
			// Each semitone is a factor of 2^(1/12)
			float pitch_multiplier = std::pow(2.0f, pitch_offset / 12.0f);
			frequency *= pitch_multiplier;
		}
	}

	float phase_increment = frequency / sample_rate;

	// Calculate time increment per sample
	double time_increment = 1.0 / sample_rate;
	double current_time = context->get_absolute_time();

	// Pre-fetch parameter values for the first sample
	// We'll update these periodically rather than every sample
	float morph_position = 0.5f; // Default to middle
	if (parameters.has(VASynthConfiguration::PARAM_WAVEFORM)) {
		Ref<ModulatedParameter> waveform_param = parameters[VASynthConfiguration::PARAM_WAVEFORM];
		if (waveform_param.is_valid()) {
			morph_position = waveform_param->get_value(context);
		}
	}

	float amplitude = 0.0f;
	if (parameters.has(VASynthConfiguration::PARAM_AMPLITUDE)) {
		Ref<ModulatedParameter> amp_param = parameters[VASynthConfiguration::PARAM_AMPLITUDE];
		if (amp_param.is_valid()) {
			amplitude = amp_param->get_value(context);
		}
	}

	float pulse_width = 0.5f; // Default to 50% duty cycle
	if (parameters.has(VASynthConfiguration::PARAM_PULSE_WIDTH)) {
		Ref<ModulatedParameter> pw_param = parameters[VASynthConfiguration::PARAM_PULSE_WIDTH];
		if (pw_param.is_valid()) {
			pulse_width = pw_param->get_value(context);
		}
	}
	
	// Store these values in the cache
	cached_morph_position = morph_position;
	cached_amplitude = amplitude;
	cached_pulse_width = pulse_width;
	
	// How often to update modulation values (every N samples)
	const int mod_update_rate = 8; // Update every 8 samples
	
	// Generate audio samples
	for (int i = 0; i < buffer_size; i++) {
		// Update context time for this sample
		context->update_time(current_time);

		// Only update modulation values periodically to save CPU
		if (i % mod_update_rate == 0) {
			// Get the waveform morph parameter from the parameters dictionary
			if (parameters.has(VASynthConfiguration::PARAM_WAVEFORM)) {
				Ref<ModulatedParameter> waveform_param = parameters[VASynthConfiguration::PARAM_WAVEFORM];
				if (waveform_param.is_valid()) {
					cached_morph_position = waveform_param->get_value(context);
				}
			}

			// Get the amplitude parameter (controlled by ADSR)
			if (parameters.has(VASynthConfiguration::PARAM_AMPLITUDE)) {
				Ref<ModulatedParameter> amp_param = parameters[VASynthConfiguration::PARAM_AMPLITUDE];
				if (amp_param.is_valid()) {
					cached_amplitude = amp_param->get_value(context);
				}
			}

			// Get the pulse width parameter
			if (parameters.has(VASynthConfiguration::PARAM_PULSE_WIDTH)) {
				Ref<ModulatedParameter> pw_param = parameters[VASynthConfiguration::PARAM_PULSE_WIDTH];
				if (pw_param.is_valid()) {
					cached_pulse_width = pw_param->get_value(context);
				}
			}
		}

		// Get the morphed waveform sample using cached values
		float sample = get_morphed_sample(phase, cached_morph_position, cached_pulse_width);
		// Apply amplitude (including ADSR envelope)
		float output_sample = sample * cached_amplitude * context->get_velocity();
		// Apply effects if available
		if (effect_chain.is_valid()) {
			output_sample = effect_chain->process_sample(output_sample, context);
		}
		output_buffer[i] = output_sample;

		// Increment phase
		phase += phase_increment;
		if (phase >= 1.0f) {
			phase -= 1.0f;
		}

		// Increment time for next sample
		current_time += time_increment;
	}

	return output_buffer;
}

void VAOscillatorEngine::reset() {
	phase = 0.0f;
	// No need to reset modulation sources - handled by ModulationContext

	// Reset the effect chain
	AudioStreamGeneratorEngine::reset();
}

Ref<AudioStreamGeneratorEngine> VAOscillatorEngine::duplicate() const {
	Ref<VAOscillatorEngine> new_engine = memnew(VAOscillatorEngine);

	// Copy waveform settings
	new_engine->set_bottom_waveform(bottom_waveform);
	new_engine->set_middle_waveform(middle_waveform);
	new_engine->set_top_waveform(top_waveform);

	// Copy sample rate
	new_engine->set_sample_rate(get_sample_rate());

	// Copy parameters
	Dictionary params = get_parameters();
	Array param_names = params.keys();
	for (int i = 0; i < param_names.size(); i++) {
		String name = param_names[i];
		Ref<ModulatedParameter> param = params[name];
		if (param.is_valid()) {
			Ref<ModulatedParameter> new_param = param->duplicate();
			new_engine->set_parameter(name, new_param);
		}
	}

	// Duplicate the effect chain
	Ref<EffectChain> effect_chain = get_effect_chain();
	if (effect_chain.is_valid()) {
		Ref<EffectChain> new_chain = effect_chain->duplicate();
		new_engine->set_effect_chain(new_chain);
	}

	return new_engine;
}

void VAOscillatorEngine::set_bottom_waveform(WaveHelper::WaveType p_type) {
	bottom_waveform = p_type;
}

WaveHelper::WaveType VAOscillatorEngine::get_bottom_waveform() const {
	return bottom_waveform;
}

void VAOscillatorEngine::set_middle_waveform(WaveHelper::WaveType p_type) {
	middle_waveform = p_type;
}

WaveHelper::WaveType VAOscillatorEngine::get_middle_waveform() const {
	return middle_waveform;
}

void VAOscillatorEngine::set_top_waveform(WaveHelper::WaveType p_type) {
	top_waveform = p_type;
}

WaveHelper::WaveType VAOscillatorEngine::get_top_waveform() const {
	return top_waveform;
}

} // namespace godot
