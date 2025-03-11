#pragma once

#include "../core/modulated_parameter.h"
#include "../core/synth_configuration.h"
#include "../core/synth_preset.h"
#include "../core/wave_helper.h"
#include "../effects/effect_chain.h"

namespace godot {

class ChordConfigurationPrototype : public ConfigurationPrototype {
    GDCLASS(ChordConfigurationPrototype, ConfigurationPrototype);

protected:
    static void _bind_methods() {}

public:
    // Waveform setting
    WaveHelper::WaveType wave_type;

    // Parameters
    Ref<ModulatedParameter> chord_type;
    Ref<ModulatedParameter> inversion;
    Ref<ModulatedParameter> amplitude;
    Ref<ModulatedParameter> pitch;
    Ref<ModulatedParameter> pulse_width;
    Ref<ModulatedParameter> detune;

    // Effects
    Ref<EffectChain> effects;

    ChordConfigurationPrototype() {
        wave_type = WaveHelper::SINE;
    }
};

} // namespace godot
