#pragma once
#include "audio_stream_generator_engine.h"
#include "synth_configuration.h"

namespace godot {

class EngineFactory {
public:
	// Create an engine from a configuration
	static Ref<AudioStreamGeneratorEngine> create_engine_from_config(const Ref<SynthConfiguration> &config);
	
	// Create a duplicate of an existing engine
	static Ref<AudioStreamGeneratorEngine> duplicate_engine(const Ref<AudioStreamGeneratorEngine> &engine);
};

} // namespace godot
