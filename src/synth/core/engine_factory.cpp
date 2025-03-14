#include "engine_factory.h"
#include "../chord/chord_oscillator_engine.h"
#include "../chord/chord_synth_configuration.h"
#include "../effects/effect_chain.h"
#include "../effects/synth_audio_effect.h"
#include "../va/va_oscillator_engine.h"
#include "../va/va_synth_configuration.h"
#include "synth_configuration.h"
#include <godot_cpp/variant/utility_functions.hpp>

namespace godot {

Ref<AudioStreamGeneratorEngine> EngineFactory::create_engine_from_config(const Ref<SynthConfiguration> &config) {
	if (!config.is_valid()) {
		return nullptr;
	}

	// Create the appropriate engine type based on configuration
	Ref<AudioStreamGeneratorEngine> engine;

	// Check the configuration type and create the appropriate engine
	if (static_cast<Ref<VASynthConfiguration>>(config) != nullptr) {
		Ref<VAOscillatorEngine> va_engine;
		va_engine.instantiate();
		engine = va_engine;
	} else if (static_cast<Ref<ChordSynthConfiguration>>(config) != nullptr) {
		Ref<ChordOscillatorEngine> chord_engine;
		chord_engine.instantiate();
		engine = chord_engine;
	} else {
		// Default to VA engine if type is unknown
		Ref<VAOscillatorEngine> va_engine;
		va_engine.instantiate();
		engine = va_engine;
	}

	if (!engine.is_valid()) {
		return nullptr;
	}

	// Create a NEW effect chain for this engine
	Ref<EffectChain> effect_chain;

	// Add effects from the configuration
	Ref<EffectChain> config_chain = config->get_effect_chain();
	if (config_chain.is_valid()) {
		effect_chain = config_chain->duplicate();
	}

	engine->set_effect_chain(effect_chain);

	// Copy parameters from configuration
	Dictionary config_params = config->get_parameters();
	Array param_names = config_params.keys();
	for (int i = 0; i < param_names.size(); i++) {
		String name = param_names[i];
		Ref<ModulatedParameter> param = config_params[name];
		if (param.is_valid()) {
			// Create a new parameter instance
			Ref<ModulatedParameter> new_param = param->duplicate();
			engine->set_parameter(name, new_param);
		}
	}

	return engine;
}

Ref<AudioStreamGeneratorEngine> EngineFactory::duplicate_engine(const Ref<AudioStreamGeneratorEngine> &engine) {
	if (!engine.is_valid()) {
		return nullptr;
	}

	// Use the engine's duplicate method
	return engine->duplicate();
}

} // namespace godot
