#pragma once

#include "../core/modulated_parameter.h"
#include "../core/synth_configuration.h"
#include "../core/synth_preset.h"
#include "../core/wave_helper.h"
#include "../effects/effect_chain.h"

namespace godot {

class VAConfigurationPrototype : public ConfigurationPrototype {
	GDCLASS(VAConfigurationPrototype, ConfigurationPrototype);

protected:
	static void _bind_methods() {}

public:
	// Waveform settings
	WaveHelper::WaveType bottom_wave;
	WaveHelper::WaveType middle_wave;
	WaveHelper::WaveType top_wave;

	// Parameters
	Ref<ModulatedParameter> waveform;
	Ref<ModulatedParameter> amplitude;
	Ref<ModulatedParameter> pitch;
	Ref<ModulatedParameter> pulse_width;

	// Effects
	Ref<EffectChain> effects;

	VAConfigurationPrototype() {
		bottom_wave = WaveHelper::SINE;
		middle_wave = WaveHelper::SINE;
		top_wave = WaveHelper::SINE;
	}
};

} // namespace godot
