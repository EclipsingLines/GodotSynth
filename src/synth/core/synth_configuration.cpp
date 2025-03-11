#include "synth_configuration.h"
#include "audio_stream_generator_engine.h"
#include "modulated_parameter.h"
#include <godot_cpp/classes/audio_server.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

namespace godot {

void SynthConfiguration::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_parameter", "name", "param"), &SynthConfiguration::set_parameter);
	ClassDB::bind_method(D_METHOD("get_parameter", "name"), &SynthConfiguration::get_parameter);
	ClassDB::bind_method(D_METHOD("get_parameters"), &SynthConfiguration::get_parameters);

	ClassDB::bind_method(D_METHOD("set_output_bus", "bus"), &SynthConfiguration::set_output_bus);
	ClassDB::bind_method(D_METHOD("get_output_bus"), &SynthConfiguration::get_output_bus);

	ClassDB::bind_method(D_METHOD("create_engine"), &SynthConfiguration::create_engine);

	ADD_PROPERTY(PropertyInfo(Variant::STRING, "output_bus", PROPERTY_HINT_ENUM, ""), "set_output_bus", "get_output_bus");

	ADD_PROPERTY(PropertyInfo(Variant::DICTIONARY, "parameters", PROPERTY_HINT_NONE, "", PROPERTY_USAGE_STORAGE), "", "get_parameters");
}

SynthConfiguration::SynthConfiguration() {
	// Connect to AudioServer signals to update bus options when they change
	AudioServer::get_singleton()->connect("bus_layout_changed", Callable(this, "notify_property_list_changed"));
	AudioServer::get_singleton()->connect("bus_renamed", Callable(this, "notify_property_list_changed"));
}

SynthConfiguration::~SynthConfiguration() {
	// Disconnect from AudioServer signals
	if (AudioServer::get_singleton()) {
		AudioServer::get_singleton()->disconnect("bus_layout_changed", Callable(this, "notify_property_list_changed"));
		AudioServer::get_singleton()->disconnect("bus_renamed", Callable(this, "notify_property_list_changed"));
	}
}

void SynthConfiguration::set_parameter(const String &p_name, const Ref<ModulatedParameter> &p_param) {
	parameters[p_name] = p_param;
}

Ref<ModulatedParameter> SynthConfiguration::get_parameter(const String &p_name) const {
	if (parameters.has(p_name)) {
		return parameters[p_name];
	}
	return Ref<ModulatedParameter>();
}

Dictionary SynthConfiguration::get_parameters() const {
	return parameters;
}

void SynthConfiguration::set_effect_chain(const Ref<EffectChain> &p_chain) {
	effect_chain = p_chain;
}

Ref<EffectChain> SynthConfiguration::get_effect_chain() const {
	return effect_chain;
}

void SynthConfiguration::set_output_bus(const String &p_bus) {
	output_bus = p_bus;
	notify_property_list_changed();
}

String SynthConfiguration::get_output_bus() const {
	return output_bus;
}

Ref<AudioStreamGeneratorEngine> SynthConfiguration::create_engine() const {
	// Base implementation returns null - to be overridden by derived classes
	UtilityFunctions::print("Base SynthConfiguration::create_engine called");
	return Ref<AudioStreamGeneratorEngine>();
}

void SynthConfiguration::_validate_property(PropertyInfo &property) const {
	if (property.name == StringName("output_bus")) {
		String options;
		for (int i = 0; i < AudioServer::get_singleton()->get_bus_count(); i++) {
			if (i > 0) {
				options += ",";
			}
			String name = AudioServer::get_singleton()->get_bus_name(i);
			options += name;
		}
		property.hint_string = options;
	}
}

} // namespace godot
