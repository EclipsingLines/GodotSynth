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

	// Bind base value properties
	ClassDB::bind_method(D_METHOD("set_waveform_base_value", "value"), &VASynthConfiguration::set_waveform_base_value);
	ClassDB::bind_method(D_METHOD("get_waveform_base_value"), &VASynthConfiguration::get_waveform_base_value);
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "waveform", PROPERTY_HINT_RANGE, "0,1,0.01"),
			"set_waveform_base_value", "get_waveform_base_value");

	ClassDB::bind_method(D_METHOD("set_waveform_parameter", "param"), &VASynthConfiguration::set_waveform_parameter);
	ClassDB::bind_method(D_METHOD("get_waveform_parameter"), &VASynthConfiguration::get_waveform_parameter);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "waveform_modulation", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
			"set_waveform_parameter", "get_waveform_parameter");

	ClassDB::bind_method(D_METHOD("set_amplitude_base_value", "value"), &VASynthConfiguration::set_amplitude_base_value);
	ClassDB::bind_method(D_METHOD("get_amplitude_base_value"), &VASynthConfiguration::get_amplitude_base_value);
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "amplitude", PROPERTY_HINT_RANGE, "0,1,0.01"),
			"set_amplitude_base_value", "get_amplitude_base_value");

	ClassDB::bind_method(D_METHOD("set_amplitude_parameter", "param"), &VASynthConfiguration::set_amplitude_parameter);
	ClassDB::bind_method(D_METHOD("get_amplitude_parameter"), &VASynthConfiguration::get_amplitude_parameter);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "amplitude_modulation", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
			"set_amplitude_parameter", "get_amplitude_parameter");

	ClassDB::bind_method(D_METHOD("set_pitch_base_value", "value"), &VASynthConfiguration::set_pitch_base_value);
	ClassDB::bind_method(D_METHOD("get_pitch_base_value"), &VASynthConfiguration::get_pitch_base_value);
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "pitch", PROPERTY_HINT_RANGE, "0,1,0.01"),
			"set_pitch_base_value", "get_pitch_base_value");

	ClassDB::bind_method(D_METHOD("set_pitch_parameter", "param"), &VASynthConfiguration::set_pitch_parameter);
	ClassDB::bind_method(D_METHOD("get_pitch_parameter"), &VASynthConfiguration::get_pitch_parameter);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "pitch_modulation", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
			"set_pitch_parameter", "get_pitch_parameter");

	ClassDB::bind_method(D_METHOD("set_pulse_width_base_value", "value"), &VASynthConfiguration::set_pulse_width_base_value);
	ClassDB::bind_method(D_METHOD("get_pulse_width_base_value"), &VASynthConfiguration::get_pulse_width_base_value);
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "pulse_width", PROPERTY_HINT_RANGE, "0,1,0.01"),
			"set_pulse_width_base_value", "get_pulse_width_base_value");

	ClassDB::bind_method(D_METHOD("set_pulse_width_parameter", "param"), &VASynthConfiguration::set_pulse_width_parameter);
	ClassDB::bind_method(D_METHOD("get_pulse_width_parameter"), &VASynthConfiguration::get_pulse_width_parameter);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "pulse_width_modulation", PROPERTY_HINT_RESOURCE_TYPE, "ModulatedParameter"),
			"set_pulse_width_parameter", "get_pulse_width_parameter");

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

void VASynthConfiguration::set_waveform_base_value(float p_value) {
	Ref<ModulatedParameter> param = get_waveform_parameter();
	if (param.is_valid()) {
		param->set_base_value(p_value);
		waveform_position = p_value; // Update stored position
	}
}

float VASynthConfiguration::get_waveform_base_value() const {
	Ref<ModulatedParameter> param = get_waveform_parameter();
	if (param.is_valid()) {
		return param->get_base_value();
	}
	return 0.0f;
}

void VASynthConfiguration::set_amplitude_parameter(const Ref<ModulatedParameter> &p_param) {
	if (p_param.is_valid()) {
		set_parameter(PARAM_AMPLITUDE, p_param);
	}
}

Ref<ModulatedParameter> VASynthConfiguration::get_amplitude_parameter() const {
	return get_parameter(PARAM_AMPLITUDE);
}

void VASynthConfiguration::set_amplitude_base_value(float p_value) {
	Ref<ModulatedParameter> param = get_amplitude_parameter();
	if (param.is_valid()) {
		param->set_base_value(p_value);
	}
}

float VASynthConfiguration::get_amplitude_base_value() const {
	Ref<ModulatedParameter> param = get_amplitude_parameter();
	if (param.is_valid()) {
		return param->get_base_value();
	}
	return 0.0f;
}

void VASynthConfiguration::set_pitch_parameter(const Ref<ModulatedParameter> &p_param) {
	if (p_param.is_valid()) {
		set_parameter(PARAM_PITCH, p_param);
	}
}

Ref<ModulatedParameter> VASynthConfiguration::get_pitch_parameter() const {
	return get_parameter(PARAM_PITCH);
}

void VASynthConfiguration::set_pitch_base_value(float p_value) {
	Ref<ModulatedParameter> param = get_pitch_parameter();
	if (param.is_valid()) {
		param->set_base_value(p_value);
	}
}

float VASynthConfiguration::get_pitch_base_value() const {
	Ref<ModulatedParameter> param = get_pitch_parameter();
	if (param.is_valid()) {
		return param->get_base_value();
	}
	return 0.0f;
}

void VASynthConfiguration::set_pulse_width_parameter(const Ref<ModulatedParameter> &p_param) {
	if (p_param.is_valid()) {
		set_parameter(PARAM_PULSE_WIDTH, p_param);
	}
}

Ref<ModulatedParameter> VASynthConfiguration::get_pulse_width_parameter() const {
	return get_parameter(PARAM_PULSE_WIDTH);
}

void VASynthConfiguration::set_pulse_width_base_value(float p_value) {
	Ref<ModulatedParameter> param = get_pulse_width_parameter();
	if (param.is_valid()) {
		param->set_base_value(p_value);
	}
}

float VASynthConfiguration::get_pulse_width_base_value() const {
	Ref<ModulatedParameter> param = get_pulse_width_parameter();
	if (param.is_valid()) {
		return param->get_base_value();
	}
	return 0.0f;
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
