#pragma once
#include "../core/modulated_parameter.h"
#include "../core/synth_preset.h"
#include "../core/wave_helper.h"
#include "../effects/spatial/reverb.h"
#include "../mod/duration/note_duration_mod_source.h"
#include "../mod/lfo/lfo.h"
#include "../effects/effect_chain.h"
#include "../effects/filter/low_pass_filter.h"
#include "../effects/filter/high_pass_filter.h"
#include "../effects/filter/band_pass_filter.h"
#include "../effects/delay/ping_pong_delay.h"
#include "../effects/distortion/clip_distortion.h"
#include "../effects/distortion/bitcrush_distortion.h"
#include "../effects/distortion/overdrive_distortion.h"
#include "chord_configuration_prototype.h"

namespace godot {

class ChordSynthPreset : public SynthPreset {
    GDCLASS(ChordSynthPreset, SynthPreset);

protected:
    static void _bind_methods() { ; }

public:
    ChordSynthPreset() { ; }
    virtual ~ChordSynthPreset() { ; }
    virtual Ref<ConfigurationPrototype> get_configuration() override = 0;
};

class ChordDefaultPreset : public ChordSynthPreset {
    GDCLASS(ChordDefaultPreset, ChordSynthPreset);

protected:
    static void _bind_methods() { ; }

public:
    ChordDefaultPreset() { ; }
    virtual ~ChordDefaultPreset() { ; }

    // Override to apply Chord-specific parameters
    virtual Ref<ConfigurationPrototype> get_configuration() override {
        Ref<ChordConfigurationPrototype> chord_config = memnew(ChordConfigurationPrototype);

        chord_config->wave_type = WaveHelper::SINE;

        // Chord type parameter (0.0 = Major, 1.0 = Minor9)
        Ref<ModulatedParameter> chord_type_param = memnew(ModulatedParameter);
        chord_type_param->set_base_value(0.0f); // Default to Major chord
        chord_type_param->set_mod_min(0.0f);
        chord_type_param->set_mod_max(1.0f);
        chord_config->chord_type = chord_type_param;

        // Inversion parameter (0.0 = root position, 1.0 = max inversion)
        Ref<ModulatedParameter> inversion_param = memnew(ModulatedParameter);
        inversion_param->set_base_value(0.0f); // Default to root position
        inversion_param->set_mod_min(0.0f);
        inversion_param->set_mod_max(1.0f);
        chord_config->inversion = inversion_param;

        // Create ADSR for amplitude
        Ref<ADSR> adsr = memnew(ADSR);
        adsr->set_attack(0.05f);
        adsr->set_decay(0.3f);
        adsr->set_sustain(0.7f);
        adsr->set_release(0.5f);

        // Create amplitude parameter for ADSR
        Ref<ModulatedParameter> amp_param = memnew(ModulatedParameter);
        amp_param->set_base_value(0.0f);
        amp_param->set_mod_min(0.0f);
        amp_param->set_mod_max(1.0f);
        amp_param->set_mod_type(ModulationType::MODULATION_ABSOLUTE);
        amp_param->set_mod_source(adsr);
        amp_param->set_mod_amount(1.0f); // Ensure full modulation amount
        chord_config->amplitude = amp_param;

        // Create pitch parameter
        Ref<ModulatedParameter> pitch_param = memnew(ModulatedParameter);
        pitch_param->set_base_value(0.0f); // 0 semitones offset by default
        pitch_param->set_mod_min(-24.0f); // -24 semitones (2 octaves down)
        pitch_param->set_mod_max(24.0f); // +24 semitones (2 octaves up)
        chord_config->pitch = pitch_param;

        // Create pulse width parameter
        Ref<ModulatedParameter> pulse_width_param = memnew(ModulatedParameter);
        pulse_width_param->set_base_value(0.5f); // 50% duty cycle by default
        pulse_width_param->set_mod_min(0.1f);
        pulse_width_param->set_mod_max(0.9f);
        chord_config->pulse_width = pulse_width_param;
        
        // Create detune parameter
        Ref<ModulatedParameter> detune_param = memnew(ModulatedParameter);
        detune_param->set_base_value(0.1f); // Slight detune by default for richer sound
        detune_param->set_mod_min(0.0f);
        detune_param->set_mod_max(0.5f); // Limit max detune to avoid extreme effects
        chord_config->detune = detune_param;

        // Add a reverb effect for richness
        Ref<Reverb> reverb = memnew(Reverb);
        Ref<ModulatedParameter> room_size = memnew(ModulatedParameter);
        room_size->set_base_value(0.3f);
        reverb->set_parameter(Reverb::PARAM_ROOM_SIZE, room_size);

        Ref<ModulatedParameter> mix = memnew(ModulatedParameter);
        mix->set_base_value(0.2f);
        reverb->set_parameter(Reverb::PARAM_MIX, mix);

        Ref<EffectChain> effects = memnew(EffectChain);
        effects->add_effect(reverb);
        chord_config->effects = effects;

        return chord_config;
    };
};

} // namespace godot
