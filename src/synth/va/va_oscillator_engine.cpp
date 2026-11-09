#include "va_oscillator_engine.h"
#include "../core/modulated_parameter.h"
#include "../core/pitch_helper.h"
#include "../core/synth_note_context.h"
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

	ClassDB::bind_method(D_METHOD("set_mod_update_rate", "rate"), &VAOscillatorEngine::set_mod_update_rate);
	ClassDB::bind_method(D_METHOD("get_mod_update_rate"), &VAOscillatorEngine::get_mod_update_rate);

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
		use_cached_values(false),
		mod_update_rate(8) {
	sample_rate_inv = 1.0f / sample_rate;
	reset_phases();
}

VAOscillatorEngine::~VAOscillatorEngine() {
}

float VAOscillatorEngine::get_frequency_for_note(float note) const {
	// A4 = 440Hz = MIDI note 69
	return 440.0f * std::pow(2.0f, (note - 69) / 12.0f);
}

void VAOscillatorEngine::reset_phases() {
	phase = 0.0f;
	sub_phase = 0.0f;
	for (int i = 0; i < WaveHelper::SUPER_SAW_VOICES; i++) {
		super_phases[i] = WaveHelper::get_super_saw_start_phase(i);
	}
}

void VAOscillatorEngine::advance_phases(float phase_increment) {
	phase += phase_increment;
	if (phase >= 1.0f) {
		phase -= 1.0f;
	}
	sub_phase += phase_increment * 0.5f;
	if (sub_phase >= 1.0f) {
		sub_phase -= 1.0f;
	}
	for (int i = 0; i < WaveHelper::SUPER_SAW_VOICES; i++) {
		super_phases[i] += phase_increment * WaveHelper::get_super_saw_ratio(i);
		if (super_phases[i] >= 1.0f) {
			super_phases[i] -= 1.0f;
		}
	}
}

float VAOscillatorEngine::get_wave_sample(WaveHelper::WaveType type, float pulse_width) const {
	// Band-limited (PolyBLEP) on the waveforms with hard steps.
	switch (type) {
		case WaveHelper::SUB_SQUARE:
			return WaveHelper::get_wave_sample_bl(sub_phase, WaveHelper::SUB_SQUARE, pulse_width, phase_dt * 0.5f);
		case WaveHelper::SUPER_SAW:
			return WaveHelper::get_super_saw_sample_bl(super_phases, pulse_width, phase_dt);
		default:
			return WaveHelper::get_wave_sample_bl(phase, type, pulse_width, phase_dt);
	}
}

float VAOscillatorEngine::get_morphed_sample(float morph_position, float pulse_width) const {
	float bottom_sample = get_wave_sample(bottom_waveform, pulse_width);
	float middle_sample = get_wave_sample(middle_waveform, pulse_width);
	float top_sample = get_wave_sample(top_waveform, pulse_width);

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

	ModulatedParameter *ptr = param.is_valid() ? param.ptr() : nullptr;
	if (name == VASynthConfiguration::PARAM_WAVEFORM) {
		param_waveform = ptr;
	} else if (name == VASynthConfiguration::PARAM_AMPLITUDE) {
		param_amplitude = ptr;
	} else if (name == VASynthConfiguration::PARAM_PITCH) {
		param_pitch = ptr;
	} else if (name == VASynthConfiguration::PARAM_PULSE_WIDTH) {
		param_pulse_width = ptr;
	}
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

PackedFloat32Array VAOscillatorEngine::process_block(int buffer_size, const Ref<SynthNoteContext> &context, const bool &use_fast_pitch) {
	// Scripting entry point. The mixer calls render() directly and doesn't allocate.
	PackedFloat32Array output_buffer;
	if (buffer_size <= 0) {
		return output_buffer;
	}
	output_buffer.resize(buffer_size);
	render(output_buffer.ptrw(), buffer_size, context, use_fast_pitch);
	return output_buffer;
}

void VAOscillatorEngine::render(float *out, int buffer_size, const Ref<SynthNoteContext> &context, bool use_fast_pitch) {
	// No note playing (or no context): silence.
	if (!context.is_valid() || context->get_note() < 0 || context->get_velocity() <= 0.0f) {
		std::fill(out, out + buffer_size, 0.0f);
		return;
	}
	SynthNoteContext *ctx = context.ptr();

	// The sample rate can change after construction (set_sample_rate).
	sample_rate_inv = 1.0f / sample_rate;

	// Note plus pitch modulation, in semitones relative to A4 (MIDI 69).
	float semitones = ctx->get_note() - 69.0f;
	if (param_pitch) {
		semitones += param_pitch->get_value(context);
	}
	float frequency = use_fast_pitch
			? 440.0f * PitchHelper::fast_pitch_extended(semitones)
			: 440.0f * std::pow(2.0f, semitones / 12.0f);

	float phase_increment = frequency * sample_rate_inv;
	phase_dt = phase_increment;

	// Calculate time increment per sample
	double time_increment = 1.0 * sample_rate_inv;
	double current_time = ctx->get_absolute_time();

	// Parameter values for the first sample. They are then updated every
	// mod_update_rate samples rather than every sample.
	cached_morph_position = param_waveform ? param_waveform->get_value(context) : 0.5f;
	cached_amplitude = param_amplitude ? param_amplitude->get_value(context) : 0.0f;
	cached_pulse_width = param_pulse_width ? param_pulse_width->get_value(context) : 0.5f;

	EffectChain *chain = effect_chain.is_valid() ? effect_chain.ptr() : nullptr;
	const float velocity = ctx->get_velocity();

	for (int i = 0; i < buffer_size; i++) {
		// Update context time for this sample
		ctx->update_time(current_time);

		// Only update modulation values periodically to save CPU
		if (i % mod_update_rate == 0) {
			if (param_waveform) {
				cached_morph_position = param_waveform->get_value(context);
			}
			if (param_amplitude) {
				cached_amplitude = param_amplitude->get_value(context); // ADSR
			}
			if (param_pulse_width) {
				cached_pulse_width = param_pulse_width->get_value(context);
			}
		}

		float sample = get_morphed_sample(cached_morph_position, cached_pulse_width);
		// Apply amplitude (including ADSR envelope)
		float output_sample = sample * cached_amplitude * velocity;
		if (chain) {
			output_sample = chain->process_sample(output_sample, context);
		}
		out[i] = output_sample;

		advance_phases(phase_increment);

		// Increment time for next sample
		current_time += time_increment;
	}
}

void VAOscillatorEngine::reset() {
	reset_phases();
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
	new_engine->set_mod_update_rate(mod_update_rate);

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

void VAOscillatorEngine::set_mod_update_rate(int p_rate) {
	// Used as a modulus in process_block, so it must be at least 1.
	mod_update_rate = MAX(1, p_rate);
}

int VAOscillatorEngine::get_mod_update_rate() const {
	return mod_update_rate;
}

} // namespace godot
