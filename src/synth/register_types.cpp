#pragma once
#include "register_types.h"
#include <gdextension_interface.h>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

// Include core classes
#include "core/audio_stream_generator_engine.h"
#include "core/audio_synth_player.h"
#include "core/engine_factory.h"
#include "core/modulated_parameter.h"
#include "core/modulation_source.h"
#include "core/synth_audio_stream.h"
#include "core/synth_configuration.h"
#include "core/synth_note_context.h"
#include "core/synth_voice.h"
#include "core/wave_helper_cache.h"

// Include modulation sources
#include "mod/adsr/adsr.h"
#include "mod/lfo/lfo.h"
// Include our new modulation sources
#include "mod/duration/note_duration_mod_source.h"
#include "mod/keyboard/keyboard_tracking_mod_source.h"
#include "mod/velocity/velocity_mod_source.h"

#include "effects/filter/band_pass_filter.h"
#include "effects/filter/filter_effect.h"
#include "effects/filter/formant_filter.h"
#include "effects/filter/high_pass_filter.h"
#include "effects/filter/low_pass_filter.h"
#include "effects/filter/moog_filter.h"
#include "effects/filter/ms20_filter.h"
#include "effects/filter/notch_filter.h"
#include "effects/filter/shelf_filter.h"
#include "effects/filter/state_variable_filter.h"
#include "effects/filter/steiner_parker_filter.h"

#include "effects/delay/comb_filter_delay.h"
#include "effects/delay/delay_effect.h"
#include "effects/delay/filtered_delay.h"
#include "effects/delay/multi_tap_delay.h"
#include "effects/delay/ping_pong_delay.h"
#include "effects/delay/reverse_delay.h"
#include "effects/delay/tape_delay.h"

#include "effects/distortion/bitcrush_distortion.h"
#include "effects/distortion/clip_distortion.h"
#include "effects/distortion/distortion_effect.h"
#include "effects/distortion/foldback_distortion.h"
#include "effects/distortion/fuzz_distortion.h"
#include "effects/distortion/overdrive_distortion.h"
#include "effects/distortion/rectifier_distortion.h"
#include "effects/distortion/wave_shaper_distortion.h"

#include "effects/effect_chain.h"
#include "effects/spatial/reverb.h"
#include "effects/synth_audio_effect.h"

// Include VA synth classes
#include "va/va_oscillator_engine.h"
#include "va/va_synth_configuration.h"
#include "va/va_synth_preset.h"

// Include Chord synth classes
#include "chord/chord_oscillator_engine.h"
#include "chord/chord_synth_configuration.h"
#include "chord/chord_synth_preset.h"

// Include wave helper
#include "core/wave_helper.h"

using namespace godot;

void register_core_classes() {
	// Register core classes
	GDREGISTER_CLASS(WaveHelperCache);
	GDREGISTER_CLASS(SynthNoteContext);
	GDREGISTER_ABSTRACT_CLASS(ModulationSource);
	GDREGISTER_CLASS(ModulatedParameter);
	GDREGISTER_ABSTRACT_CLASS(SynthAudioEffect);
	GDREGISTER_CLASS(EffectChain);
	GDREGISTER_ABSTRACT_CLASS(AudioStreamGeneratorEngine);
	GDREGISTER_CLASS(SynthVoice);
	GDREGISTER_ABSTRACT_CLASS(ConfigurationPrototype);
	GDREGISTER_ABSTRACT_CLASS(SynthPreset);
	GDREGISTER_ABSTRACT_CLASS(SynthConfiguration);
	GDREGISTER_CLASS(SynthAudioStream);
	GDREGISTER_CLASS(SynthAudioStreamPlayback);
	GDREGISTER_CLASS(AudioSynthPlayer);
}

void register_filters() {
	GDREGISTER_ABSTRACT_CLASS(FilterEffect);
	GDREGISTER_ABSTRACT_CLASS(StateVariableFilter);
	GDREGISTER_CLASS(LowPassFilter);
	GDREGISTER_CLASS(HighPassFilter);
	GDREGISTER_CLASS(BandPassFilter);
	GDREGISTER_CLASS(ShelfFilter);
	GDREGISTER_CLASS(MoogFilter);
	GDREGISTER_CLASS(SteinerParkerFilter);
	GDREGISTER_CLASS(MS20Filter);
	GDREGISTER_CLASS(FormantFilter);
	GDREGISTER_CLASS(NotchFilter);
}

void register_delay_effects() {
	GDREGISTER_CLASS(DelayEffect);
	GDREGISTER_CLASS(PingPongDelay);
	GDREGISTER_CLASS(FilteredDelay);
	GDREGISTER_CLASS(MultiTapDelay);
	GDREGISTER_CLASS(TapeDelay);
	GDREGISTER_CLASS(ReverseDelay);
	GDREGISTER_CLASS(CombFilterDelay);
}

void register_distortion_effects() {
	GDREGISTER_ABSTRACT_CLASS(DistortionEffect);
	GDREGISTER_CLASS(ClipDistortion);
	GDREGISTER_CLASS(WaveShaperDistortion);
	GDREGISTER_CLASS(FoldbackDistortion);
	GDREGISTER_CLASS(BitcrushDistortion);
	GDREGISTER_CLASS(OverdriveDistortion);
	GDREGISTER_CLASS(FuzzDistortion);
	GDREGISTER_CLASS(RectifierDistortion);
}

void register_spatial_effects() {
	// TODO: Fix reverb
	//GDREGISTER_CLASS(Reverb);
}

void register_effects() {
	register_filters();
	register_delay_effects();
	register_distortion_effects();
	register_spatial_effects();
}

void register_modulation_sources() {
	// Register modulation sources
	GDREGISTER_CLASS(ADSR);
	GDREGISTER_CLASS(LFO);

	// Register our new modulation sources
	GDREGISTER_CLASS(VelocityModSource);
	GDREGISTER_CLASS(KeyboardTrackingModSource);
	GDREGISTER_CLASS(NoteDurationModSource);
}

void register_va_classes() {
	// Register VA synth classes
	GDREGISTER_CLASS(VAOscillatorEngine);
	GDREGISTER_CLASS(VAConfigurationPrototype);
	GDREGISTER_CLASS(VASynthConfiguration);
	GDREGISTER_ABSTRACT_CLASS(VASynthPreset);
	GDREGISTER_CLASS(VADefaultPreset);
	GDREGISTER_CLASS(UIAcceptPreset);
	GDREGISTER_CLASS(UIDeclinePreset);
	GDREGISTER_CLASS(UIHoverPreset);
	GDREGISTER_CLASS(UIConfirmPreset);
	GDREGISTER_CLASS(UIErrorPreset);
	GDREGISTER_CLASS(UINotificationPreset);
	GDREGISTER_CLASS(WindPreset);
	GDREGISTER_CLASS(FootstepPreset);
	GDREGISTER_CLASS(WaterDropPreset);
	GDREGISTER_CLASS(LaserBeamPreset);
	GDREGISTER_CLASS(ExplosionPreset);
	GDREGISTER_CLASS(GunShotPreset);
	GDREGISTER_CLASS(BassPreset);
	GDREGISTER_CLASS(LeadSynthPreset);
	GDREGISTER_CLASS(PadSynthPreset);
	GDREGISTER_CLASS(KickDrumPreset);
	GDREGISTER_CLASS(SnareDrumPreset);
	GDREGISTER_CLASS(HiHatPreset);
	GDREGISTER_CLASS(ArpeggiatorPreset);
}

void register_chord_classes() {
	// Register Chord synth classes
	GDREGISTER_CLASS(ChordOscillatorEngine);
	GDREGISTER_CLASS(ChordConfigurationPrototype);
	GDREGISTER_CLASS(ChordSynthConfiguration);
	GDREGISTER_ABSTRACT_CLASS(ChordSynthPreset);
	GDREGISTER_CLASS(ChordDefaultPreset);
}

void initialize_gdextension_types(ModuleInitializationLevel p_level) {
	if (p_level == MODULE_INITIALIZATION_LEVEL_SCENE) {
		// Register core classes
		register_core_classes();

		// Register modulation sources
		register_modulation_sources();

		// Register synthesizer audio effects
		register_effects();

		// Register VA synth classes
		register_va_classes();

		// Register Chord synth classes
		// TODO: fix chord engine
		// register_chord_classes();
	}
}

void uninitialize_gdextension_types(ModuleInitializationLevel p_level) {
	if (p_level == MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
}

extern "C" {
// Initialization
GDE_EXPORT GDExtensionBool synth_library_init(GDExtensionInterfaceGetProcAddress p_get_proc_address, GDExtensionClassLibraryPtr p_library, GDExtensionInitialization *r_initialization) {
	GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);
	init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
	init_obj.register_initializer(initialize_gdextension_types);
	init_obj.register_terminator(uninitialize_gdextension_types);

	return init_obj.init();
}
}
