#include "va_synth_configuration.h"
#include "../core/audio_stream_generator_engine.h"
#include "../core/modulated_parameter.h"
#include "../mod/adsr/adsr.h"
#include "va_configuration_prototype.h"
#include "va_oscillator_engine.h"
#include "va_synth_preset.h"
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

namespace godot {

// Define static parameter name constants
const char *VASynthConfiguration::PARAM_WAVEFORM = "waveform";
const char *VASynthConfiguration::PARAM_AMPLITUDE = "amplitude";
const char *VASynthConfiguration::PARAM_PITCH = "pitch";
const char *VASynthConfiguration::PARAM_PULSE_WIDTH = "pulse_width";

void VASynthConfiguration::_bind_methods() {
	// Bind waveform properties
	ClassDB::bind_method(D_METHOD("set_bottom_waveform", "type"), &VASynthConfiguration::set_bottom_waveform);
	ClassDB::bind_method(D_METHOD("get_bottom_waveform"), &VASynthConfiguration::get_bottom_waveform);
	ADD_PROPERTY(PropertyInfo(Variant::INT, "bottom_waveform", PROPERTY_HINT_ENUM, WAVE_ENUM_VALUES),
			"set_bottom_waveform", "get_bottom_waveform");

	ClassDB::bind_method(D_METHOD("set_middle_waveform", "type"), &VASynthConfiguration::set_middle_waveform);
	ClassDB::bind_method(D_METHOD("get_middle_waveform"), &VASynthConfiguration::get_middle_waveform);
	ADD_PROPERTY(PropertyInfo(Variant::INT, "middle_waveform", PROPERTY_HINT_ENUM, WAVE_ENUM_VALUES),
			"set_middle_waveform", "get_middle_waveform");

	ClassDB::bind_method(D_METHOD("set_top_waveform", "type"), &VASynthConfiguration::set_top_waveform);
	ClassDB::bind_method(D_METHOD("get_top_waveform"), &VASynthConfiguration::get_top_waveform);
	ADD_PROPERTY(PropertyInfo(Variant::INT, "top_waveform", PROPERTY_HINT_ENUM, WAVE_ENUM_VALUES), "set_top_waveform",
			"get_top_waveform");

	// Directly expose modulated parameters
	ClassDB::bind_method(D_METHOD("set_waveform_parameter", "param"), &VASynthConfiguration::set_waveform_parameter);
	ClassDB::bind_method(D_METHOD("get_waveform_parameter"), &VASynthConfiguration::get_waveform_parameter);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "waveform_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"), "set_waveform_parameter", "get_waveform_parameter");

	ClassDB::bind_method(D_METHOD("set_amplitude_parameter", "param"), &VASynthConfiguration::set_amplitude_parameter);
	ClassDB::bind_method(D_METHOD("get_amplitude_parameter"), &VASynthConfiguration::get_amplitude_parameter);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "amplitude_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"), "set_amplitude_parameter", "get_amplitude_parameter");

	ClassDB::bind_method(D_METHOD("set_pitch_parameter", "param"), &VASynthConfiguration::set_pitch_parameter);
	ClassDB::bind_method(D_METHOD("get_pitch_parameter"), &VASynthConfiguration::get_pitch_parameter);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "pitch_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"), "set_pitch_parameter", "get_pitch_parameter");

	ClassDB::bind_method(D_METHOD("set_pulse_width_parameter", "param"), &VASynthConfiguration::set_pulse_width_parameter);
	ClassDB::bind_method(D_METHOD("get_pulse_width_parameter"), &VASynthConfiguration::get_pulse_width_parameter);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "pulse_width_parameter", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"), "set_pulse_width_parameter", "get_pulse_width_parameter");

	ClassDB::bind_method(D_METHOD("set_effect_chain", "chain"), &SynthConfiguration::set_effect_chain);
	ClassDB::bind_method(D_METHOD("get_effect_chain"), &SynthConfiguration::get_effect_chain);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "effect_chain", PROPERTY_HINT_RESOURCE_TYPE, "EffectChain"), "set_effect_chain", "get_effect_chain");

	// Preset property
	ClassDB::bind_method(D_METHOD("set_preset", "preset"), &VASynthConfiguration::set_preset);
	ClassDB::bind_method(D_METHOD("get_preset"), &VASynthConfiguration::get_preset);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "preset", PROPERTY_HINT_RESOURCE_TYPE, "VASynthPreset"), "set_preset", "get_preset");
}

VASynthConfiguration::VASynthConfiguration() {
	// Only set default preset in the editor
	if (Engine::get_singleton()->is_editor_hint()) {
		Ref<VADefaultPreset> default_preset = memnew(VADefaultPreset);
		set_preset(default_preset);
	}
}

VASynthConfiguration::~VASynthConfiguration() {
}

Ref<AudioStreamGeneratorEngine> VASynthConfiguration::create_engine() const {
	// Create a VA engine instance
	Ref<VAOscillatorEngine> engine = memnew(VAOscillatorEngine);

	// Set the sample rate
	engine->set_sample_rate(44100.0f); // Use a default sample rate

	// Configure the engine with our parameters
	engine->set_bottom_waveform(bottom_waveform);
	engine->set_middle_waveform(middle_waveform);
	engine->set_top_waveform(top_waveform);

	// Debug output - using String::num_int64 to convert enum values to strings
	UtilityFunctions::print("Creating engine with waveforms: " +
			String::num_int64((int64_t)bottom_waveform) + ", " +
			String::num_int64((int64_t)middle_waveform) + ", " +
			String::num_int64((int64_t)top_waveform));

	// Transfer all parameters to the engine
	Dictionary params = get_parameters();
	Array param_names = params.keys();
	for (int i = 0; i < param_names.size(); i++) {
		String name = param_names[i];
		Ref<ModulatedParameter> param = static_cast<Ref<ModulatedParameter>>(params[name])->duplicate();
		if (param.is_valid()) {
			engine->set_parameter(name, param);
		}
	}

	// Set effect chain if available
	if (get_effect_chain().is_valid()) {
		engine->set_effect_chain(get_effect_chain()->duplicate());
	}

	return engine;
}

// Implement the setters and getters
void VASynthConfiguration::set_bottom_waveform(WaveHelper::WaveType p_type) {
	bottom_waveform = p_type;
}

WaveHelper::WaveType VASynthConfiguration::get_bottom_waveform() const {
	return bottom_waveform;
}

void VASynthConfiguration::set_middle_waveform(WaveHelper::WaveType p_type) {
	middle_waveform = p_type;
}

WaveHelper::WaveType VASynthConfiguration::get_middle_waveform() const {
	return middle_waveform;
}

void VASynthConfiguration::set_top_waveform(WaveHelper::WaveType p_type) {
	top_waveform = p_type;
}

WaveHelper::WaveType VASynthConfiguration::get_top_waveform() const {
	return top_waveform;
}

// Direct modulated parameter accessors
void VASynthConfiguration::set_waveform_parameter(const Ref<ModulatedParameter> &p_param) {
	if (p_param.is_valid()) {
		// Store the current waveform position
		waveform_position = p_param->get_base_value();
		set_parameter(PARAM_WAVEFORM, p_param);
	}
}

Ref<ModulatedParameter> VASynthConfiguration::get_waveform_parameter() const {
	return get_parameter(PARAM_WAVEFORM);
}

void VASynthConfiguration::set_amplitude_parameter(const Ref<ModulatedParameter> &p_param) {
	if (p_param.is_valid()) {
		set_parameter(PARAM_AMPLITUDE, p_param);
	}
}

Ref<ModulatedParameter> VASynthConfiguration::get_amplitude_parameter() const {
	return get_parameter(PARAM_AMPLITUDE);
}

void VASynthConfiguration::set_pitch_parameter(const Ref<ModulatedParameter> &p_param) {
	if (p_param.is_valid()) {
		set_parameter(PARAM_PITCH, p_param);
	}
}

Ref<ModulatedParameter> VASynthConfiguration::get_pitch_parameter() const {
	return get_parameter(PARAM_PITCH);
}

void VASynthConfiguration::set_pulse_width_parameter(const Ref<ModulatedParameter> &p_param) {
	if (p_param.is_valid()) {
		set_parameter(PARAM_PULSE_WIDTH, p_param);
	}
}

Ref<ModulatedParameter> VASynthConfiguration::get_pulse_width_parameter() const {
	return get_parameter(PARAM_PULSE_WIDTH);
}

// Preset management
void VASynthConfiguration::set_preset(const Ref<VASynthPreset> &p_preset) {
	if (p_preset.is_valid()) {
		Ref<VAConfigurationPrototype> source = p_preset->get_configuration();

		if (source.is_valid()) {
			// Apply the preset to this configuration
			// Copy waveform settings
			set_bottom_waveform(source->bottom_wave);
			set_middle_waveform(source->middle_wave);
			set_top_waveform(source->top_wave);

			// Copy parameters
			set_waveform_parameter(source->waveform);
			set_amplitude_parameter(source->amplitude);
			set_pitch_parameter(source->pitch);
			set_pulse_width_parameter(source->pulse_width);

			// Copy other properties as needed
			set_effect_chain(source->effects);
		}
	}
}

Ref<VASynthPreset> VASynthConfiguration::get_preset() const {
	return preset;
}

} // namespace godot
