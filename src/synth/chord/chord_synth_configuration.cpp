#include "chord_synth_configuration.h"
#include "../core/audio_stream_generator_engine.h"
#include "../core/modulated_parameter.h"
#include "../mod/adsr/adsr.h"
#include "chord_configuration_prototype.h"
#include "chord_oscillator_engine.h"
#include "chord_synth_preset.h"
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

namespace godot {

// Define static parameter name constants
const char *ChordSynthConfiguration::PARAM_CHORD_TYPE = "chord_type";
const char *ChordSynthConfiguration::PARAM_INVERSION = "inversion";
const char *ChordSynthConfiguration::PARAM_AMPLITUDE = "amplitude";
const char *ChordSynthConfiguration::PARAM_PITCH = "pitch";
const char *ChordSynthConfiguration::PARAM_PULSE_WIDTH = "pulse_width";
const char *ChordSynthConfiguration::PARAM_DETUNE = "detune";

void ChordSynthConfiguration::_bind_methods() {
	// Bind waveform property
	ClassDB::bind_method(D_METHOD("set_waveform", "type"), &ChordSynthConfiguration::set_waveform);
	ClassDB::bind_method(D_METHOD("get_waveform"), &ChordSynthConfiguration::get_waveform);
	ADD_PROPERTY(PropertyInfo(Variant::INT, "waveform", PROPERTY_HINT_ENUM, WAVE_ENUM_VALUES),
			"set_waveform", "get_waveform");

	// Directly expose modulated parameters
	ClassDB::bind_method(D_METHOD("set_chord_type_parameter", "param"), &ChordSynthConfiguration::set_chord_type_parameter);
	ClassDB::bind_method(D_METHOD("get_chord_type_parameter"), &ChordSynthConfiguration::get_chord_type_parameter);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "chord_type_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
			"set_chord_type_parameter", "get_chord_type_parameter");

	ClassDB::bind_method(D_METHOD("set_inversion_parameter", "param"), &ChordSynthConfiguration::set_inversion_parameter);
	ClassDB::bind_method(D_METHOD("get_inversion_parameter"), &ChordSynthConfiguration::get_inversion_parameter);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "inversion_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
			"set_inversion_parameter", "get_inversion_parameter");

	ClassDB::bind_method(D_METHOD("set_amplitude_parameter", "param"), &ChordSynthConfiguration::set_amplitude_parameter);
	ClassDB::bind_method(D_METHOD("get_amplitude_parameter"), &ChordSynthConfiguration::get_amplitude_parameter);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "amplitude_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
			"set_amplitude_parameter", "get_amplitude_parameter");

	ClassDB::bind_method(D_METHOD("set_pitch_parameter", "param"), &ChordSynthConfiguration::set_pitch_parameter);
	ClassDB::bind_method(D_METHOD("get_pitch_parameter"), &ChordSynthConfiguration::get_pitch_parameter);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "pitch_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
			"set_pitch_parameter", "get_pitch_parameter");

	ClassDB::bind_method(D_METHOD("set_pulse_width_parameter", "param"), &ChordSynthConfiguration::set_pulse_width_parameter);
	ClassDB::bind_method(D_METHOD("get_pulse_width_parameter"), &ChordSynthConfiguration::get_pulse_width_parameter);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "pulse_width_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
			"set_pulse_width_parameter", "get_pulse_width_parameter");

	ClassDB::bind_method(D_METHOD("set_detune_parameter", "param"), &ChordSynthConfiguration::set_detune_parameter);
	ClassDB::bind_method(D_METHOD("get_detune_parameter"), &ChordSynthConfiguration::get_detune_parameter);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "detune_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
			"set_detune_parameter", "get_detune_parameter");

	ClassDB::bind_method(D_METHOD("set_effect_chain", "chain"), &ChordSynthConfiguration::set_effect_chain);
	ClassDB::bind_method(D_METHOD("get_effect_chain"), &ChordSynthConfiguration::get_effect_chain);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "effect_chain", PROPERTY_HINT_RESOURCE_TYPE, "EffectChain"),
			"set_effect_chain", "get_effect_chain");

	// Preset property
	ClassDB::bind_method(D_METHOD("set_preset", "preset"), &ChordSynthConfiguration::set_preset);
	ClassDB::bind_method(D_METHOD("get_preset"), &ChordSynthConfiguration::get_preset);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "preset", PROPERTY_HINT_RESOURCE_TYPE, "ChordSynthPreset"),
			"set_preset", "get_preset");
	ClassDB::bind_method(D_METHOD("set_root_note_only", "enabled"), &ChordSynthConfiguration::set_root_note_only);
	ClassDB::bind_method(D_METHOD("get_root_note_only"), &ChordSynthConfiguration::get_root_note_only);
	ADD_PROPERTY(PropertyInfo(Variant::BOOL, "root_note_only"), "set_root_note_only", "get_root_note_only");
}

ChordSynthConfiguration::ChordSynthConfiguration() {
	// Only set default preset in the editor
	if (Engine::get_singleton()->is_editor_hint()) {
		Ref<ChordDefaultPreset> default_preset = memnew(ChordDefaultPreset);
		set_preset(default_preset);
	}
}

ChordSynthConfiguration::~ChordSynthConfiguration() {
}

Ref<AudioStreamGeneratorEngine> ChordSynthConfiguration::create_engine() const {
	// Create a Chord engine instance
	Ref<ChordOscillatorEngine> engine = memnew(ChordOscillatorEngine);

	// Set the sample rate
	engine->set_sample_rate(44100.0f); // Use a default sample rate

	// Configure the engine with our parameters
	engine->set_waveform(waveform);

	// Debug output
	UtilityFunctions::print("Creating chord engine with waveform: " + String::num_int64((int64_t)waveform));

	// Transfer all parameters to the engine
	Dictionary params = get_parameters();
	Array param_names = params.keys();
	// Debug parameters
	UtilityFunctions::print("Parameters being set on engine:");
	for (int i = 0; i < param_names.size(); i++) {
		String name = param_names[i];
		Ref<ModulatedParameter> param = params[name];
		if (param.is_valid()) {
			// Create a proper duplicate to avoid reference issues
			Ref<ModulatedParameter> param_copy = param->duplicate();
			engine->set_parameter(name, param_copy);

			// Debug output for parameter values
			UtilityFunctions::print("Setting parameter on engine: " + name +
					" with value: " + String::num(param_copy->get_base_value()));
		}
	}

	// Set effect chain if available
	if (get_effect_chain().is_valid()) {
		engine->set_effect_chain(get_effect_chain()->duplicate());
	}

	return engine;
}

// Implement the setters and getters
void ChordSynthConfiguration::set_waveform(WaveHelper::WaveType p_type) {
	waveform = p_type;
}

WaveHelper::WaveType ChordSynthConfiguration::get_waveform() const {
	return waveform;
}

// Direct modulated parameter accessors
void ChordSynthConfiguration::set_chord_type_parameter(const Ref<ModulatedParameter> &p_param) {
	if (p_param.is_valid()) {
		set_parameter(PARAM_CHORD_TYPE, p_param);
	}
}

Ref<ModulatedParameter> ChordSynthConfiguration::get_chord_type_parameter() const {
	return get_parameter(PARAM_CHORD_TYPE);
}

void ChordSynthConfiguration::set_inversion_parameter(const Ref<ModulatedParameter> &p_param) {
	if (p_param.is_valid()) {
		set_parameter(PARAM_INVERSION, p_param);
	}
}

Ref<ModulatedParameter> ChordSynthConfiguration::get_inversion_parameter() const {
	return get_parameter(PARAM_INVERSION);
}

void ChordSynthConfiguration::set_amplitude_parameter(const Ref<ModulatedParameter> &p_param) {
	if (p_param.is_valid()) {
		set_parameter(PARAM_AMPLITUDE, p_param);
	}
}

Ref<ModulatedParameter> ChordSynthConfiguration::get_amplitude_parameter() const {
	return get_parameter(PARAM_AMPLITUDE);
}

void ChordSynthConfiguration::set_pitch_parameter(const Ref<ModulatedParameter> &p_param) {
	if (p_param.is_valid()) {
		set_parameter(PARAM_PITCH, p_param);
	}
}

Ref<ModulatedParameter> ChordSynthConfiguration::get_pitch_parameter() const {
	return get_parameter(PARAM_PITCH);
}

void ChordSynthConfiguration::set_pulse_width_parameter(const Ref<ModulatedParameter> &p_param) {
	if (p_param.is_valid()) {
		set_parameter(PARAM_PULSE_WIDTH, p_param);
	}
}

Ref<ModulatedParameter> ChordSynthConfiguration::get_pulse_width_parameter() const {
	return get_parameter(PARAM_PULSE_WIDTH);
}

void ChordSynthConfiguration::set_detune_parameter(const Ref<ModulatedParameter> &p_param) {
	if (p_param.is_valid()) {
		set_parameter(PARAM_DETUNE, p_param);
	}
}

Ref<ModulatedParameter> ChordSynthConfiguration::get_detune_parameter() const {
	return get_parameter(PARAM_DETUNE);
}

// Preset management
void ChordSynthConfiguration::set_preset(const Ref<ChordSynthPreset> &p_preset) {
	if (p_preset.is_valid()) {
		Ref<ChordConfigurationPrototype> source = p_preset->get_configuration();

		if (source.is_valid()) {
			// Apply the preset to this configuration
			// Copy waveform setting
			set_waveform(source->wave_type);

			// Copy parameters
			set_chord_type_parameter(source->chord_type);
			set_inversion_parameter(source->inversion);
			set_amplitude_parameter(source->amplitude);
			set_pitch_parameter(source->pitch);
			set_pulse_width_parameter(source->pulse_width);
			set_detune_parameter(source->detune);

			// Copy other properties as needed
			set_effect_chain(source->effects);
		}
	}
}

Ref<ChordSynthPreset> ChordSynthConfiguration::get_preset() const {
	return preset;
}

} // namespace godot
