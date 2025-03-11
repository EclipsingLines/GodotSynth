#pragma once
#include "synth_configuration.h"
#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/variant/dictionary.hpp>

namespace godot {

class ConfigurationPrototype : public Resource {
	GDCLASS(ConfigurationPrototype, Resource);

protected:
	static void _bind_methods() { ; }

public:
	Ref<ModulatedParameter> pitch;
	Ref<ModulatedParameter> amplitude;

	Ref<EffectChain> effects;
};
class SynthPreset : public Resource {
	GDCLASS(SynthPreset, Resource);

protected:
	static void _bind_methods() {
		ClassDB::bind_method(D_METHOD("get_configuration"), &SynthPreset::get_configuration);
	}

public:
	SynthPreset() { ; }
	virtual ~SynthPreset() { ; }

	// Apply this preset to a configuration
	virtual Ref<ConfigurationPrototype> get_configuration() = 0;
};

} // namespace godot
