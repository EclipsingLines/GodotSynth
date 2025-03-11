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
#include "va_configuration_prototype.h"

namespace godot {

class VASynthPreset : public SynthPreset {
	GDCLASS(VASynthPreset, SynthPreset);

protected:
	static void _bind_methods() { ; }

public:
	VASynthPreset() { ; }
	virtual ~VASynthPreset() { ; }
	virtual Ref<ConfigurationPrototype> get_configuration() override = 0;
};

class VADefaultPreset : public VASynthPreset {
	GDCLASS(VADefaultPreset, VASynthPreset);

protected:
	static void _bind_methods() {
		;
	}

public:
	// Static parameter names

	VADefaultPreset() { ; }
	virtual ~VADefaultPreset() { ; }

	// Override to apply VA-specific parameters
	virtual Ref<ConfigurationPrototype> get_configuration() override {
		Ref<VAConfigurationPrototype> va_config = memnew(VAConfigurationPrototype);

		va_config->bottom_wave = WaveHelper::SINE;
		va_config->middle_wave = WaveHelper::TRIANGLE;
		va_config->top_wave = WaveHelper::NOISE;

		Ref<ModulatedParameter> waveform_param = memnew(ModulatedParameter);
		waveform_param->set_base_value(0.5);
		waveform_param->set_mod_min(0.0f);
		waveform_param->set_mod_max(1.0f);
		va_config->waveform = waveform_param;

		Ref<ADSR> adsr = memnew(ADSR);

		// Create amplitude parameter for ADSR
		Ref<ModulatedParameter> amp_param = memnew(ModulatedParameter);
		amp_param->set_base_value(0.0f);
		amp_param->set_mod_min(0.0f);
		amp_param->set_mod_max(1.0f);
		amp_param->set_mod_type(ModulationType::MODULATION_ABSOLUTE);
		amp_param->set_mod_source(adsr);
		amp_param->set_mod_amount(1.0f); // Ensure full modulation amount
		va_config->amplitude = amp_param;

		// Create pitch parameter
		Ref<ModulatedParameter> pitch_param = memnew(ModulatedParameter);
		pitch_param->set_base_value(0.0f); // 0 semitones offset by default
		pitch_param->set_mod_min(-24.0f); // -24 semitones (2 octaves down)
		pitch_param->set_mod_max(24.0f); // +24 semitones (2 octaves up)
		va_config->pitch = pitch_param;

		return va_config;
	};
};

class UIAcceptPreset : public VASynthPreset {
	GDCLASS(UIAcceptPreset, VASynthPreset);

protected:
	static void _bind_methods() {
		;
	}

public:
	UIAcceptPreset() { ; }
	virtual ~UIAcceptPreset() { ; }

	// Override to apply UI Accept sound parameters
	virtual Ref<ConfigurationPrototype> get_configuration() override {
		Ref<VAConfigurationPrototype> va_config = memnew(VAConfigurationPrototype);

		// Bright ascending sound
		va_config->bottom_wave = WaveHelper::PULSE;
		va_config->middle_wave = WaveHelper::SINE;
		va_config->top_wave = WaveHelper::NOISE;

		// Waveform parameter
		Ref<ModulatedParameter> waveform_param = memnew(ModulatedParameter);
		waveform_param->set_base_value(0.5);
		waveform_param->set_mod_min(0.0f);
		waveform_param->set_mod_max(1.0f);
		va_config->waveform = waveform_param;

		// Quick envelope
		Ref<ADSR> adsr = memnew(ADSR);
		adsr->set_attack(0.03f);
		adsr->set_decay(0.15f);
		adsr->set_sustain(0.0f);
		adsr->set_release(0.05f);

		// Amplitude modulation
		Ref<ModulatedParameter> amp_param = memnew(ModulatedParameter);
		amp_param->set_base_value(0.0f);
		amp_param->set_mod_min(0.0f);
		amp_param->set_mod_max(1.0f);
		amp_param->set_mod_type(ModulationType::MODULATION_ABSOLUTE);
		amp_param->set_mod_source(adsr);
		amp_param->set_mod_amount(1.0f);
		va_config->amplitude = amp_param;

		// Pitch rise
		Ref<ModulatedParameter> pitch_param = memnew(ModulatedParameter);
		pitch_param->set_base_value(60.0f); // C4
		pitch_param->set_mod_min(-24.0f);
		pitch_param->set_mod_max(24.0f);

		Ref<NoteDurationModSource> pitch_mod = memnew(NoteDurationModSource);
		pitch_param->set_mod_source(pitch_mod);
		pitch_param->set_mod_type(ModulationType::MODULATION_ABSOLUTE);
		pitch_param->set_mod_amount(12.0f); // +1 octave
		va_config->pitch = pitch_param;

		return va_config;
	};
};

class UIDeclinePreset : public VASynthPreset {
	GDCLASS(UIDeclinePreset, VASynthPreset);

protected:
	static void _bind_methods() {
		;
	}

public:
	UIDeclinePreset() { ; }
	virtual ~UIDeclinePreset() { ; }

	// Override to apply UI Decline sound parameters
	virtual Ref<ConfigurationPrototype> get_configuration() override {
		Ref<VAConfigurationPrototype> va_config = memnew(VAConfigurationPrototype);

		// Dark waveform stack
		va_config->bottom_wave = WaveHelper::SQUARE;
		va_config->middle_wave = WaveHelper::SINE;
		va_config->top_wave = WaveHelper::NOISE;

		// Waveform parameter
		Ref<ModulatedParameter> waveform_param = memnew(ModulatedParameter);
		waveform_param->set_base_value(0.5);
		waveform_param->set_mod_min(0.0f);
		waveform_param->set_mod_max(1.0f);
		va_config->waveform = waveform_param;

		// ADSR with sustain
		Ref<ADSR> adsr = memnew(ADSR);
		adsr->set_attack(0.05f);
		adsr->set_decay(0.3f);
		adsr->set_sustain(0.2f);
		adsr->set_release(0.5f);

		// Amplitude setup
		Ref<ModulatedParameter> amp_param = memnew(ModulatedParameter);
		amp_param->set_base_value(0.0f);
		amp_param->set_mod_min(0.0f);
		amp_param->set_mod_max(1.0f);
		amp_param->set_mod_type(ModulationType::MODULATION_ABSOLUTE);
		amp_param->set_mod_source(adsr);
		amp_param->set_mod_amount(1.0f);
		va_config->amplitude = amp_param;

		// Descending pitch
		Ref<ModulatedParameter> pitch_param = memnew(ModulatedParameter);
		pitch_param->set_base_value(64.0f); // E4
		pitch_param->set_mod_min(-24.0f);
		pitch_param->set_mod_max(24.0f);

		Ref<NoteDurationModSource> pitch_mod = memnew(NoteDurationModSource);
		pitch_param->set_mod_source(pitch_mod);
		pitch_param->set_mod_type(ModulationType::MODULATION_ABSOLUTE);
		pitch_param->set_mod_amount(-12.0f); // -1 octave
		va_config->pitch = pitch_param;

		return va_config;
	};
};

// UI SOUND EFFECTS

class UIHoverPreset : public VASynthPreset {
	GDCLASS(UIHoverPreset, VASynthPreset);

protected:
	static void _bind_methods() { ; }

public:
	UIHoverPreset() { ; }
	virtual ~UIHoverPreset() { ; }

	virtual Ref<ConfigurationPrototype> get_configuration() override {
		Ref<VAConfigurationPrototype> va_config = memnew(VAConfigurationPrototype);

		// Light, subtle waveforms
		va_config->bottom_wave = WaveHelper::SINE;
		va_config->middle_wave = WaveHelper::TRIANGLE;
		va_config->top_wave = WaveHelper::SINE;

		// Waveform parameter
		Ref<ModulatedParameter> waveform_param = memnew(ModulatedParameter);
		waveform_param->set_base_value(0.3);
		va_config->waveform = waveform_param;

		// Very quick envelope
		Ref<ADSR> adsr = memnew(ADSR);
		adsr->set_attack(0.01f);
		adsr->set_decay(0.08f);
		adsr->set_sustain(0.0f);
		adsr->set_release(0.02f);

		// Amplitude setup
		Ref<ModulatedParameter> amp_param = memnew(ModulatedParameter);
		amp_param->set_base_value(0.0f);
		amp_param->set_mod_min(0.0f);
		amp_param->set_mod_max(0.7f); // Quieter than other UI sounds
		amp_param->set_mod_type(ModulationType::MODULATION_ABSOLUTE);
		amp_param->set_mod_source(adsr);
		amp_param->set_mod_amount(1.0f);
		va_config->amplitude = amp_param;

		// Slight upward pitch
		Ref<ModulatedParameter> pitch_param = memnew(ModulatedParameter);
		pitch_param->set_base_value(72.0f); // C5
		pitch_param->set_mod_min(-24.0f);
		pitch_param->set_mod_max(24.0f);

		Ref<NoteDurationModSource> pitch_mod = memnew(NoteDurationModSource);
		pitch_mod->set_attack_time(0.05f);
		pitch_mod->set_max_time(0.1f);
		pitch_param->set_mod_source(pitch_mod);
		pitch_param->set_mod_amount(2.0f); // Small pitch rise
		va_config->pitch = pitch_param;

		return va_config;
	};
};

class UIConfirmPreset : public VASynthPreset {
	GDCLASS(UIConfirmPreset, VASynthPreset);

protected:
	static void _bind_methods() { ; }

public:
	UIConfirmPreset() { ; }
	virtual ~UIConfirmPreset() { ; }

	virtual Ref<ConfigurationPrototype> get_configuration() override {
		Ref<VAConfigurationPrototype> va_config = memnew(VAConfigurationPrototype);

		// Bright, positive sound
		va_config->bottom_wave = WaveHelper::SINE;
		va_config->middle_wave = WaveHelper::TRIANGLE;
		va_config->top_wave = WaveHelper::PULSE;

		// Waveform parameter
		Ref<ModulatedParameter> waveform_param = memnew(ModulatedParameter);
		waveform_param->set_base_value(0.4);
		va_config->waveform = waveform_param;

		// Quick envelope with slight sustain
		Ref<ADSR> adsr = memnew(ADSR);
		adsr->set_attack(0.02f);
		adsr->set_decay(0.2f);
		adsr->set_sustain(0.1f);
		adsr->set_release(0.3f);

		// Amplitude setup
		Ref<ModulatedParameter> amp_param = memnew(ModulatedParameter);
		amp_param->set_base_value(0.0f);
		amp_param->set_mod_min(0.0f);
		amp_param->set_mod_max(1.0f);
		amp_param->set_mod_type(ModulationType::MODULATION_ABSOLUTE);
		amp_param->set_mod_source(adsr);
		amp_param->set_mod_amount(1.0f);
		va_config->amplitude = amp_param;

		// Two-note arpeggio effect
		Ref<ModulatedParameter> pitch_param = memnew(ModulatedParameter);
		pitch_param->set_base_value(60.0f); // C4
		pitch_param->set_mod_min(-24.0f);
		pitch_param->set_mod_max(24.0f);

		Ref<NoteDurationModSource> pitch_mod = memnew(NoteDurationModSource);
		pitch_mod->set_attack_time(0.1f);
		pitch_mod->set_max_time(0.2f);
		pitch_param->set_mod_source(pitch_mod);
		pitch_param->set_mod_amount(7.0f); // Perfect fifth
		va_config->pitch = pitch_param;

		// Add reverb for a more polished sound
		Ref<Reverb> reverb = memnew(Reverb);
		Ref<ModulatedParameter> room_size = memnew(ModulatedParameter);
		room_size->set_base_value(0.2f);
		reverb->set_parameter(Reverb::PARAM_ROOM_SIZE, room_size);

		Ref<ModulatedParameter> mix = memnew(ModulatedParameter);
		mix->set_base_value(0.15f);
		reverb->set_parameter(Reverb::PARAM_MIX, mix);

		Ref<EffectChain> effects = memnew(EffectChain);
		effects->add_effect(reverb);
		va_config->effects = effects;

		return va_config;
	};
};

class UIErrorPreset : public VASynthPreset {
	GDCLASS(UIErrorPreset, VASynthPreset);

protected:
	static void _bind_methods() { ; }

public:
	UIErrorPreset() { ; }
	virtual ~UIErrorPreset() { ; }

	virtual Ref<ConfigurationPrototype> get_configuration() override {
		Ref<VAConfigurationPrototype> va_config = memnew(VAConfigurationPrototype);

		// Harsh, dissonant sound
		va_config->bottom_wave = WaveHelper::SQUARE;
		va_config->middle_wave = WaveHelper::NOISE;
		va_config->top_wave = WaveHelper::PULSE;

		// Waveform parameter
		Ref<ModulatedParameter> waveform_param = memnew(ModulatedParameter);
		waveform_param->set_base_value(0.7);
		va_config->waveform = waveform_param;

		// Quick attack, medium decay
		Ref<ADSR> adsr = memnew(ADSR);
		adsr->set_attack(0.01f);
		adsr->set_decay(0.3f);
		adsr->set_sustain(0.0f);
		adsr->set_release(0.1f);

		// Amplitude setup
		Ref<ModulatedParameter> amp_param = memnew(ModulatedParameter);
		amp_param->set_base_value(0.0f);
		amp_param->set_mod_min(0.0f);
		amp_param->set_mod_max(1.0f);
		amp_param->set_mod_type(ModulationType::MODULATION_ABSOLUTE);
		amp_param->set_mod_source(adsr);
		amp_param->set_mod_amount(1.0f);
		va_config->amplitude = amp_param;

		// Dissonant pitch movement
		Ref<ModulatedParameter> pitch_param = memnew(ModulatedParameter);
		pitch_param->set_base_value(65.0f); // F4
		pitch_param->set_mod_min(-24.0f);
		pitch_param->set_mod_max(24.0f);

		Ref<NoteDurationModSource> pitch_mod = memnew(NoteDurationModSource);
		pitch_mod->set_attack_time(0.05f);
		pitch_mod->set_max_time(0.2f);
		pitch_param->set_mod_source(pitch_mod);
		pitch_param->set_mod_amount(-6.0f); // Descending tritone
		va_config->pitch = pitch_param;

		// Add distortion for harshness
		Ref<ClipDistortion> distortion = memnew(ClipDistortion);
		Ref<ModulatedParameter> drive = memnew(ModulatedParameter);
		drive->set_base_value(0.7f);
		distortion->set_parameter(ClipDistortion::PARAM_DRIVE, drive);

		Ref<ModulatedParameter> threshold = memnew(ModulatedParameter);
		threshold->set_base_value(0.3f);
		distortion->set_parameter(ClipDistortion::PARAM_THRESHOLD, threshold);

		Ref<EffectChain> effects = memnew(EffectChain);
		effects->add_effect(distortion);
		va_config->effects = effects;

		return va_config;
	};
};

class UINotificationPreset : public VASynthPreset {
	GDCLASS(UINotificationPreset, VASynthPreset);

protected:
	static void _bind_methods() { ; }

public:
	UINotificationPreset() { ; }
	virtual ~UINotificationPreset() { ; }

	virtual Ref<ConfigurationPrototype> get_configuration() override {
		Ref<VAConfigurationPrototype> va_config = memnew(VAConfigurationPrototype);

		// Bright, attention-grabbing sound
		va_config->bottom_wave = WaveHelper::TRIANGLE;
		va_config->middle_wave = WaveHelper::SINE;
		va_config->top_wave = WaveHelper::PULSE;

		// Waveform parameter
		Ref<ModulatedParameter> waveform_param = memnew(ModulatedParameter);
		waveform_param->set_base_value(0.4);
		va_config->waveform = waveform_param;

		// Quick attack, medium decay
		Ref<ADSR> adsr = memnew(ADSR);
		adsr->set_attack(0.01f);
		adsr->set_decay(0.25f);
		adsr->set_sustain(0.1f);
		adsr->set_release(0.2f);

		// Amplitude setup
		Ref<ModulatedParameter> amp_param = memnew(ModulatedParameter);
		amp_param->set_base_value(0.0f);
		amp_param->set_mod_min(0.0f);
		amp_param->set_mod_max(1.0f);
		amp_param->set_mod_type(ModulationType::MODULATION_ABSOLUTE);
		amp_param->set_mod_source(adsr);
		amp_param->set_mod_amount(1.0f);
		va_config->amplitude = amp_param;

		// Two-note pattern
		Ref<ModulatedParameter> pitch_param = memnew(ModulatedParameter);
		pitch_param->set_base_value(72.0f); // C5
		pitch_param->set_mod_min(-24.0f);
		pitch_param->set_mod_max(24.0f);

		Ref<NoteDurationModSource> pitch_mod = memnew(NoteDurationModSource);
		pitch_mod->set_attack_time(0.1f);
		pitch_mod->set_max_time(0.2f);
		pitch_param->set_mod_source(pitch_mod);
		pitch_param->set_mod_amount(4.0f); // Major third up
		va_config->pitch = pitch_param;

		// Add ping pong delay for attention
		Ref<PingPongDelay> delay = memnew(PingPongDelay);
		Ref<ModulatedParameter> delay_time = memnew(ModulatedParameter);
		delay_time->set_base_value(0.15f);
		delay->set_parameter(PingPongDelay::PARAM_DELAY_TIME, delay_time);

		Ref<ModulatedParameter> feedback = memnew(ModulatedParameter);
		feedback->set_base_value(0.3f);
		delay->set_parameter(PingPongDelay::PARAM_FEEDBACK, feedback);

		Ref<ModulatedParameter> mix = memnew(ModulatedParameter);
		mix->set_base_value(0.2f);
		delay->set_parameter(PingPongDelay::PARAM_MIX, mix);

		Ref<EffectChain> effects = memnew(EffectChain);
		effects->add_effect(delay);
		va_config->effects = effects;

		return va_config;
	};
};

// ENVIRONMENTAL SOUND EFFECTS

class WindPreset : public VASynthPreset {
	GDCLASS(WindPreset, VASynthPreset);

protected:
	static void _bind_methods() { ; }

public:
	WindPreset() { ; }
	virtual ~WindPreset() { ; }

	virtual Ref<ConfigurationPrototype> get_configuration() override {
		Ref<VAConfigurationPrototype> va_config = memnew(VAConfigurationPrototype);

		// Noise-based wind sound
		va_config->bottom_wave = WaveHelper::NOISE;
		va_config->middle_wave = WaveHelper::NOISE;
		va_config->top_wave = WaveHelper::SINE;

		// Waveform parameter
		Ref<ModulatedParameter> waveform_param = memnew(ModulatedParameter);
		waveform_param->set_base_value(0.2);
		va_config->waveform = waveform_param;

		// Slow attack and release for natural wind
		Ref<ADSR> adsr = memnew(ADSR);
		adsr->set_attack(1.5f);
		adsr->set_decay(2.0f);
		adsr->set_sustain(0.7f);
		adsr->set_release(3.0f);

		// Amplitude setup with LFO modulation for gusts
		Ref<ModulatedParameter> amp_param = memnew(ModulatedParameter);
		amp_param->set_base_value(0.0f);
		amp_param->set_mod_min(0.0f);
		amp_param->set_mod_max(0.8f);
		amp_param->set_mod_type(ModulationType::MODULATION_ABSOLUTE);
		amp_param->set_mod_source(adsr);
		amp_param->set_mod_amount(1.0f);

		// Add LFO for wind gusts
		Ref<LFO> amp_lfo = memnew(LFO);
		amp_lfo->set_rate(0.3f); // Slow modulation
		amp_lfo->set_wave_type(WaveHelper::SINE);
		amp_param->set_mod_source(amp_lfo);
		amp_param->set_mod_amount(0.3f);

		va_config->amplitude = amp_param;

		// Low pitch for wind rumble
		Ref<ModulatedParameter> pitch_param = memnew(ModulatedParameter);
		pitch_param->set_base_value(36.0f); // C2
		pitch_param->set_mod_min(-12.0f);
		pitch_param->set_mod_max(12.0f);

		// Add slow LFO for pitch variation
		Ref<LFO> pitch_lfo = memnew(LFO);
		pitch_lfo->set_rate(0.2f);
		pitch_lfo->set_wave_type(WaveHelper::SINE);
		pitch_param->set_mod_source(pitch_lfo);
		pitch_param->set_mod_amount(3.0f);

		va_config->pitch = pitch_param;

		// Add filter to shape the noise
		Ref<LowPassFilter> filter = memnew(LowPassFilter);
		Ref<ModulatedParameter> cutoff = memnew(ModulatedParameter);
		cutoff->set_base_value(0.2f);

		// Modulate filter cutoff with LFO
		Ref<LFO> filter_lfo = memnew(LFO);
		filter_lfo->set_rate(0.15f);
		filter_lfo->set_wave_type(WaveHelper::SINE);
		cutoff->set_mod_source(filter_lfo);
		cutoff->set_mod_amount(0.15f);

		filter->set_parameter("cutoff", cutoff);

		Ref<ModulatedParameter> resonance = memnew(ModulatedParameter);
		resonance->set_base_value(0.1f);
		filter->set_parameter("resonance", resonance);

		// Add reverb for spaciousness
		Ref<Reverb> reverb = memnew(Reverb);
		Ref<ModulatedParameter> room_size = memnew(ModulatedParameter);
		room_size->set_base_value(0.8f);
		reverb->set_parameter(Reverb::PARAM_ROOM_SIZE, room_size);

		Ref<ModulatedParameter> mix = memnew(ModulatedParameter);
		mix->set_base_value(0.7f);
		reverb->set_parameter(Reverb::PARAM_MIX, mix);

		Ref<EffectChain> effects = memnew(EffectChain);
		effects->add_effect(filter);
		effects->add_effect(reverb);
		va_config->effects = effects;

		return va_config;
	};
};

class FootstepPreset : public VASynthPreset {
	GDCLASS(FootstepPreset, VASynthPreset);

protected:
	static void _bind_methods() { ; }

public:
	FootstepPreset() { ; }
	virtual ~FootstepPreset() { ; }

	virtual Ref<ConfigurationPrototype> get_configuration() override {
		Ref<VAConfigurationPrototype> va_config = memnew(VAConfigurationPrototype);

		// Noise-based footstep sound
		va_config->bottom_wave = WaveHelper::NOISE;
		va_config->middle_wave = WaveHelper::NOISE;
		va_config->top_wave = WaveHelper::PULSE;

		// Waveform parameter
		Ref<ModulatedParameter> waveform_param = memnew(ModulatedParameter);
		waveform_param->set_base_value(0.1);
		va_config->waveform = waveform_param;

		// Very quick attack and decay
		Ref<ADSR> adsr = memnew(ADSR);
		adsr->set_attack(0.001f);
		adsr->set_decay(0.15f);
		adsr->set_sustain(0.0f);
		adsr->set_release(0.05f);

		// Amplitude setup
		Ref<ModulatedParameter> amp_param = memnew(ModulatedParameter);
		amp_param->set_base_value(0.0f);
		amp_param->set_mod_min(0.0f);
		amp_param->set_mod_max(1.0f);
		amp_param->set_mod_type(ModulationType::MODULATION_ABSOLUTE);
		amp_param->set_mod_source(adsr);
		amp_param->set_mod_amount(1.0f);
		va_config->amplitude = amp_param;

		// Low pitch for thud
		Ref<ModulatedParameter> pitch_param = memnew(ModulatedParameter);
		pitch_param->set_base_value(30.0f); // Very low
		pitch_param->set_mod_min(-12.0f);
		pitch_param->set_mod_max(12.0f);

		// Quick pitch drop
		Ref<NoteDurationModSource> pitch_mod = memnew(NoteDurationModSource);
		pitch_mod->set_attack_time(0.01f);
		pitch_mod->set_max_time(0.1f);
		pitch_param->set_mod_source(pitch_mod);
		pitch_param->set_mod_amount(-5.0f);

		va_config->pitch = pitch_param;

		// Add filter to shape the noise
		Ref<LowPassFilter> filter = memnew(LowPassFilter);
		Ref<ModulatedParameter> cutoff = memnew(ModulatedParameter);
		cutoff->set_base_value(0.3f);

		// Filter envelope
		Ref<NoteDurationModSource> filter_env = memnew(NoteDurationModSource);
		filter_env->set_attack_time(0.001f);
		filter_env->set_max_time(0.1f);
		cutoff->set_mod_source(filter_env);
		cutoff->set_mod_amount(-0.2f);

		filter->set_parameter("cutoff", cutoff);

		Ref<ModulatedParameter> resonance = memnew(ModulatedParameter);
		resonance->set_base_value(0.2f);
		filter->set_parameter("resonance", resonance);

		// Add reverb for space
		Ref<Reverb> reverb = memnew(Reverb);
		Ref<ModulatedParameter> room_size = memnew(ModulatedParameter);
		room_size->set_base_value(0.3f);
		reverb->set_parameter(Reverb::PARAM_ROOM_SIZE, room_size);

		Ref<ModulatedParameter> mix = memnew(ModulatedParameter);
		mix->set_base_value(0.2f);
		reverb->set_parameter(Reverb::PARAM_MIX, mix);

		Ref<EffectChain> effects = memnew(EffectChain);
		effects->add_effect(filter);
		effects->add_effect(reverb);
		va_config->effects = effects;

		return va_config;
	};
};

class WaterDropPreset : public VASynthPreset {
	GDCLASS(WaterDropPreset, VASynthPreset);

protected:
	static void _bind_methods() { ; }

public:
	WaterDropPreset() { ; }
	virtual ~WaterDropPreset() { ; }

	virtual Ref<ConfigurationPrototype> get_configuration() override {
		Ref<VAConfigurationPrototype> va_config = memnew(VAConfigurationPrototype);

		// Sine-based water drop
		va_config->bottom_wave = WaveHelper::SINE;
		va_config->middle_wave = WaveHelper::SINE;
		va_config->top_wave = WaveHelper::SINE;

		// Waveform parameter
		Ref<ModulatedParameter> waveform_param = memnew(ModulatedParameter);
		waveform_param->set_base_value(0.0);
		va_config->waveform = waveform_param;

		// Quick attack, medium decay
		Ref<ADSR> adsr = memnew(ADSR);
		adsr->set_attack(0.001f);
		adsr->set_decay(0.2f);
		adsr->set_sustain(0.0f);
		adsr->set_release(0.1f);

		// Amplitude setup
		Ref<ModulatedParameter> amp_param = memnew(ModulatedParameter);
		amp_param->set_base_value(0.0f);
		amp_param->set_mod_min(0.0f);
		amp_param->set_mod_max(0.8f);
		amp_param->set_mod_type(ModulationType::MODULATION_ABSOLUTE);
		amp_param->set_mod_source(adsr);
		amp_param->set_mod_amount(1.0f);
		va_config->amplitude = amp_param;

		// High pitch with quick drop
		Ref<ModulatedParameter> pitch_param = memnew(ModulatedParameter);
		pitch_param->set_base_value(84.0f); // C6
		pitch_param->set_mod_min(-24.0f);
		pitch_param->set_mod_max(24.0f);

		// Quick pitch drop
		Ref<NoteDurationModSource> pitch_mod = memnew(NoteDurationModSource);
		pitch_mod->set_attack_time(0.001f);
		pitch_mod->set_max_time(0.15f);
		pitch_param->set_mod_source(pitch_mod);
		pitch_param->set_mod_amount(-12.0f);

		va_config->pitch = pitch_param;

		// Add reverb for wet sound
		Ref<Reverb> reverb = memnew(Reverb);
		Ref<ModulatedParameter> room_size = memnew(ModulatedParameter);
		room_size->set_base_value(0.4f);
		reverb->set_parameter(Reverb::PARAM_ROOM_SIZE, room_size);

		Ref<ModulatedParameter> mix = memnew(ModulatedParameter);
		mix->set_base_value(0.3f);
		reverb->set_parameter(Reverb::PARAM_MIX, mix);

		Ref<ModulatedParameter> damping = memnew(ModulatedParameter);
		damping->set_base_value(0.7f);
		reverb->set_parameter(Reverb::PARAM_DAMPING, damping);

		Ref<EffectChain> effects = memnew(EffectChain);
		effects->add_effect(reverb);
		va_config->effects = effects;

		return va_config;
	};
};

// CHARACTER SOUND EFFECTS

class LaserBeamPreset : public VASynthPreset {
	GDCLASS(LaserBeamPreset, VASynthPreset);

protected:
	static void _bind_methods() { ; }

public:
	LaserBeamPreset() { ; }
	virtual ~LaserBeamPreset() { ; }

	virtual Ref<ConfigurationPrototype> get_configuration() override {
		Ref<VAConfigurationPrototype> va_config = memnew(VAConfigurationPrototype);

		// Sine and square for laser sound
		va_config->bottom_wave = WaveHelper::SINE;
		va_config->middle_wave = WaveHelper::SQUARE;
		va_config->top_wave = WaveHelper::NOISE;

		// Waveform parameter
		Ref<ModulatedParameter> waveform_param = memnew(ModulatedParameter);
		waveform_param->set_base_value(0.2);
		va_config->waveform = waveform_param;

		// Quick attack, medium decay
		Ref<ADSR> adsr = memnew(ADSR);
		adsr->set_attack(0.01f);
		adsr->set_decay(0.15f);
		adsr->set_sustain(0.6f);
		adsr->set_release(0.1f);

		// Amplitude setup
		Ref<ModulatedParameter> amp_param = memnew(ModulatedParameter);
		amp_param->set_base_value(0.0f);
		amp_param->set_mod_min(0.0f);
		amp_param->set_mod_max(1.0f);
		amp_param->set_mod_type(ModulationType::MODULATION_ABSOLUTE);
		amp_param->set_mod_source(adsr);
		amp_param->set_mod_amount(1.0f);
		va_config->amplitude = amp_param;

		// High pitch with rise
		Ref<ModulatedParameter> pitch_param = memnew(ModulatedParameter);
		pitch_param->set_base_value(72.0f); // C5
		pitch_param->set_mod_min(-24.0f);
		pitch_param->set_mod_max(24.0f);

		// Quick pitch rise
		Ref<NoteDurationModSource> pitch_mod = memnew(NoteDurationModSource);
		pitch_mod->set_attack_time(0.05f);
		pitch_mod->set_max_time(0.1f);
		pitch_param->set_mod_source(pitch_mod);
		pitch_param->set_mod_amount(12.0f);

		va_config->pitch = pitch_param;

		// Add filter for laser sound
		Ref<BandPassFilter> filter = memnew(BandPassFilter);
		Ref<ModulatedParameter> cutoff = memnew(ModulatedParameter);
		cutoff->set_base_value(0.6f);

		// Filter sweep
		Ref<NoteDurationModSource> filter_env = memnew(NoteDurationModSource);
		filter_env->set_attack_time(0.05f);
		filter_env->set_max_time(0.2f);
		cutoff->set_mod_source(filter_env);
		cutoff->set_mod_amount(0.3f);

		filter->set_parameter("cutoff", cutoff);

		Ref<ModulatedParameter> resonance = memnew(ModulatedParameter);
		resonance->set_base_value(0.7f);
		filter->set_parameter("resonance", resonance);

		// Add distortion for edge
		Ref<ClipDistortion> distortion = memnew(ClipDistortion);
		Ref<ModulatedParameter> drive = memnew(ModulatedParameter);
		drive->set_base_value(0.4f);
		distortion->set_parameter(ClipDistortion::PARAM_DRIVE, drive);

		Ref<ModulatedParameter> threshold = memnew(ModulatedParameter);
		threshold->set_base_value(0.5f);
		distortion->set_parameter(ClipDistortion::PARAM_THRESHOLD, threshold);

		Ref<EffectChain> effects = memnew(EffectChain);
		effects->add_effect(filter);
		effects->add_effect(distortion);
		va_config->effects = effects;

		return va_config;
	};
};

class ExplosionPreset : public VASynthPreset {
	GDCLASS(ExplosionPreset, VASynthPreset);

protected:
	static void _bind_methods() { ; }

public:
	ExplosionPreset() { ; }
	virtual ~ExplosionPreset() { ; }

	virtual Ref<ConfigurationPrototype> get_configuration() override {
		Ref<VAConfigurationPrototype> va_config = memnew(VAConfigurationPrototype);

		// Noise-based explosion
		va_config->bottom_wave = WaveHelper::NOISE;
		va_config->middle_wave = WaveHelper::SQUARE;
		va_config->top_wave = WaveHelper::NOISE;

		// Waveform parameter
		Ref<ModulatedParameter> waveform_param = memnew(ModulatedParameter);
		waveform_param->set_base_value(0.8);
		va_config->waveform = waveform_param;

		// Very quick attack, long decay
		Ref<ADSR> adsr = memnew(ADSR);
		adsr->set_attack(0.001f);
		adsr->set_decay(1.5f);
		adsr->set_sustain(0.0f);
		adsr->set_release(0.5f);

		// Amplitude setup
		Ref<ModulatedParameter> amp_param = memnew(ModulatedParameter);
		amp_param->set_base_value(0.0f);
		amp_param->set_mod_min(0.0f);
		amp_param->set_mod_max(1.0f);
		amp_param->set_mod_type(ModulationType::MODULATION_ABSOLUTE);
		amp_param->set_mod_source(adsr);
		amp_param->set_mod_amount(1.0f);
		va_config->amplitude = amp_param;

		// Low pitch with quick drop
		Ref<ModulatedParameter> pitch_param = memnew(ModulatedParameter);
		pitch_param->set_base_value(36.0f); // C2
		pitch_param->set_mod_min(-24.0f);
		pitch_param->set_mod_max(24.0f);

		// Quick pitch drop
		Ref<NoteDurationModSource> pitch_mod = memnew(NoteDurationModSource);
		pitch_mod->set_attack_time(0.001f);
		pitch_mod->set_max_time(0.5f);
		pitch_param->set_mod_source(pitch_mod);
		pitch_param->set_mod_amount(-12.0f);

		va_config->pitch = pitch_param;

		// Add filter for explosion shape
		Ref<LowPassFilter> filter = memnew(LowPassFilter);
		Ref<ModulatedParameter> cutoff = memnew(ModulatedParameter);
		cutoff->set_base_value(0.8f);

		// Filter envelope
		Ref<NoteDurationModSource> filter_env = memnew(NoteDurationModSource);
		filter_env->set_attack_time(0.001f);
		filter_env->set_max_time(0.7f);
		cutoff->set_mod_source(filter_env);
		cutoff->set_mod_amount(-0.7f);

		filter->set_parameter("cutoff", cutoff);

		Ref<ModulatedParameter> resonance = memnew(ModulatedParameter);
		resonance->set_base_value(0.1f);
		filter->set_parameter("resonance", resonance);

		// Add distortion for impact
		Ref<ClipDistortion> distortion = memnew(ClipDistortion);
		Ref<ModulatedParameter> drive = memnew(ModulatedParameter);
		drive->set_base_value(0.8f);
		distortion->set_parameter(ClipDistortion::PARAM_DRIVE, drive);

		Ref<ModulatedParameter> threshold = memnew(ModulatedParameter);
		threshold->set_base_value(0.3f);
		distortion->set_parameter(ClipDistortion::PARAM_THRESHOLD, threshold);

		// Add reverb for size
		Ref<Reverb> reverb = memnew(Reverb);
		Ref<ModulatedParameter> room_size = memnew(ModulatedParameter);
		room_size->set_base_value(0.9f);
		reverb->set_parameter(Reverb::PARAM_ROOM_SIZE, room_size);

		Ref<ModulatedParameter> mix = memnew(ModulatedParameter);
		mix->set_base_value(0.4f);
		reverb->set_parameter(Reverb::PARAM_MIX, mix);

		Ref<EffectChain> effects = memnew(EffectChain);
		effects->add_effect(filter);
		effects->add_effect(distortion);
		effects->add_effect(reverb);
		va_config->effects = effects;

		return va_config;
	};
};

class GunShotPreset : public VASynthPreset {
	GDCLASS(GunShotPreset, VASynthPreset);

protected:
	static void _bind_methods() { ; }

public:
	GunShotPreset() { ; }
	virtual ~GunShotPreset() { ; }

	virtual Ref<ConfigurationPrototype> get_configuration() override {
		Ref<VAConfigurationPrototype> va_config = memnew(VAConfigurationPrototype);

		// Noise-based gunshot
		va_config->bottom_wave = WaveHelper::NOISE;
		va_config->middle_wave = WaveHelper::PULSE;
		va_config->top_wave = WaveHelper::NOISE;

		// Waveform parameter
		Ref<ModulatedParameter> waveform_param = memnew(ModulatedParameter);
		waveform_param->set_base_value(0.9);
		va_config->waveform = waveform_param;

		// Extremely quick attack, short decay
		Ref<ADSR> adsr = memnew(ADSR);
		adsr->set_attack(0.001f);
		adsr->set_decay(0.1f);
		adsr->set_sustain(0.0f);
		adsr->set_release(0.3f);

		// Amplitude setup
		Ref<ModulatedParameter> amp_param = memnew(ModulatedParameter);
		amp_param->set_base_value(0.0f);
		amp_param->set_mod_min(0.0f);
		amp_param->set_mod_max(1.0f);
		amp_param->set_mod_type(ModulationType::MODULATION_ABSOLUTE);
		amp_param->set_mod_source(adsr);
		amp_param->set_mod_amount(1.0f);
		va_config->amplitude = amp_param;

		// Mid-low pitch with quick drop
		Ref<ModulatedParameter> pitch_param = memnew(ModulatedParameter);
		pitch_param->set_base_value(48.0f); // C3
		pitch_param->set_mod_min(-24.0f);
		pitch_param->set_mod_max(24.0f);

		// Quick pitch drop
		Ref<NoteDurationModSource> pitch_mod = memnew(NoteDurationModSource);
		pitch_mod->set_attack_time(0.001f);
		pitch_mod->set_max_time(0.1f);
		pitch_param->set_mod_source(pitch_mod);
		pitch_param->set_mod_amount(-8.0f);

		va_config->pitch = pitch_param;

		// Add distortion for impact
		Ref<ClipDistortion> distortion = memnew(ClipDistortion);
		Ref<ModulatedParameter> drive = memnew(ModulatedParameter);
		drive->set_base_value(1.0f);
		distortion->set_parameter(ClipDistortion::PARAM_DRIVE, drive);

		Ref<ModulatedParameter> threshold = memnew(ModulatedParameter);
		threshold->set_base_value(0.2f);
		distortion->set_parameter(ClipDistortion::PARAM_THRESHOLD, threshold);

		// Add reverb for echo
		Ref<Reverb> reverb = memnew(Reverb);
		Ref<ModulatedParameter> room_size = memnew(ModulatedParameter);
		room_size->set_base_value(0.7f);
		reverb->set_parameter(Reverb::PARAM_ROOM_SIZE, room_size);

		Ref<ModulatedParameter> mix = memnew(ModulatedParameter);
		mix->set_base_value(0.3f);
		reverb->set_parameter(Reverb::PARAM_MIX, mix);

		Ref<EffectChain> effects = memnew(EffectChain);
		effects->add_effect(distortion);
		effects->add_effect(reverb);
		va_config->effects = effects;

		return va_config;
	};
};

// MUSIC SOUND PRESETS

class BassPreset : public VASynthPreset {
	GDCLASS(BassPreset, VASynthPreset);

protected:
	static void _bind_methods() { ; }

public:
	BassPreset() { ; }
	virtual ~BassPreset() { ; }

	virtual Ref<ConfigurationPrototype> get_configuration() override {
		Ref<VAConfigurationPrototype> va_config = memnew(VAConfigurationPrototype);

		// Rich bass waveforms
		va_config->bottom_wave = WaveHelper::SQUARE;
		va_config->middle_wave = WaveHelper::SINE;
		va_config->top_wave = WaveHelper::TRIANGLE;

		// Waveform parameter
		Ref<ModulatedParameter> waveform_param = memnew(ModulatedParameter);
		waveform_param->set_base_value(0.3);
		va_config->waveform = waveform_param;

		// Medium attack, medium decay
		Ref<ADSR> adsr = memnew(ADSR);
		adsr->set_attack(0.05f);
		adsr->set_decay(0.3f);
		adsr->set_sustain(0.8f);
		adsr->set_release(0.4f);

		// Amplitude setup
		Ref<ModulatedParameter> amp_param = memnew(ModulatedParameter);
		amp_param->set_base_value(0.0f);
		amp_param->set_mod_min(0.0f);
		amp_param->set_mod_max(1.0f);
		amp_param->set_mod_type(ModulationType::MODULATION_ABSOLUTE);
		amp_param->set_mod_source(adsr);
		amp_param->set_mod_amount(1.0f);
		va_config->amplitude = amp_param;

		// Low pitch for bass
		Ref<ModulatedParameter> pitch_param = memnew(ModulatedParameter);
		pitch_param->set_base_value(36.0f); // C2
		pitch_param->set_mod_min(-24.0f);
		pitch_param->set_mod_max(24.0f);
		va_config->pitch = pitch_param;

		// Add filter for bass shape
		Ref<LowPassFilter> filter = memnew(LowPassFilter);
		Ref<ModulatedParameter> cutoff = memnew(ModulatedParameter);
		cutoff->set_base_value(0.3f);

		// Filter envelope
		Ref<ADSR> filter_env = memnew(ADSR);
		filter_env->set_attack(0.01f);
		filter_env->set_decay(0.5f);
		filter_env->set_sustain(0.3f);
		filter_env->set_release(0.3f);
		cutoff->set_mod_source(filter_env);
		cutoff->set_mod_amount(0.4f);

		filter->set_parameter("cutoff", cutoff);

		Ref<ModulatedParameter> resonance = memnew(ModulatedParameter);
		resonance->set_base_value(0.4f);
		filter->set_parameter("resonance", resonance);

		// Add subtle distortion for warmth
		Ref<OverdriveDistortion> distortion = memnew(OverdriveDistortion);
		Ref<ModulatedParameter> drive = memnew(ModulatedParameter);
		drive->set_base_value(0.3f);
		distortion->set_parameter(OverdriveDistortion::PARAM_DRIVE, drive);

		Ref<ModulatedParameter> tone = memnew(ModulatedParameter);
		tone->set_base_value(0.3f);
		distortion->set_parameter(OverdriveDistortion::PARAM_TONE, tone);

		Ref<ModulatedParameter> mix = memnew(ModulatedParameter);
		mix->set_base_value(0.2f);
		distortion->set_parameter(OverdriveDistortion::PARAM_MIX, mix);

		Ref<EffectChain> effects = memnew(EffectChain);
		effects->add_effect(filter);
		effects->add_effect(distortion);
		va_config->effects = effects;

		return va_config;
	};
};

class LeadSynthPreset : public VASynthPreset {
	GDCLASS(LeadSynthPreset, VASynthPreset);

protected:
	static void _bind_methods() { ; }

public:
	LeadSynthPreset() { ; }
	virtual ~LeadSynthPreset() { ; }

	virtual Ref<ConfigurationPrototype> get_configuration() override {
		Ref<VAConfigurationPrototype> va_config = memnew(VAConfigurationPrototype);

		// Bright lead waveforms
		va_config->bottom_wave = WaveHelper::PULSE;
		va_config->middle_wave = WaveHelper::SINE;
		va_config->top_wave = WaveHelper::TRIANGLE;

		// Waveform parameter
		Ref<ModulatedParameter> waveform_param = memnew(ModulatedParameter);
		waveform_param->set_base_value(0.4);
		va_config->waveform = waveform_param;

		// Medium attack, long sustain
		Ref<ADSR> adsr = memnew(ADSR);
		adsr->set_attack(0.1f);
		adsr->set_decay(0.2f);
		adsr->set_sustain(0.8f);
		adsr->set_release(0.3f);

		// Amplitude setup
		Ref<ModulatedParameter> amp_param = memnew(ModulatedParameter);
		amp_param->set_base_value(0.0f);
		amp_param->set_mod_min(0.0f);
		amp_param->set_mod_max(1.0f);
		amp_param->set_mod_type(ModulationType::MODULATION_ABSOLUTE);
		amp_param->set_mod_source(adsr);
		amp_param->set_mod_amount(1.0f);
		va_config->amplitude = amp_param;

		// Mid-high pitch for lead
		Ref<ModulatedParameter> pitch_param = memnew(ModulatedParameter);
		pitch_param->set_base_value(72.0f); // C5
		pitch_param->set_mod_min(-24.0f);
		pitch_param->set_mod_max(24.0f);

		// Add vibrato with LFO
		Ref<LFO> vibrato = memnew(LFO);
		vibrato->set_rate(5.0f);
		vibrato->set_wave_type(WaveHelper::SINE);
		pitch_param->set_mod_source(vibrato);
		pitch_param->set_mod_amount(0.3f);

		va_config->pitch = pitch_param;

		// Add filter for tone shaping
		Ref<BandPassFilter> filter = memnew(BandPassFilter);
		Ref<ModulatedParameter> cutoff = memnew(ModulatedParameter);
		cutoff->set_base_value(0.6f);

		// Filter envelope
		Ref<ADSR> filter_env = memnew(ADSR);
		filter_env->set_attack(0.05f);
		filter_env->set_decay(0.3f);
		filter_env->set_sustain(0.6f);
		filter_env->set_release(0.3f);
		cutoff->set_mod_source(filter_env);
		cutoff->set_mod_amount(0.3f);

		filter->set_parameter("cutoff", cutoff);

		Ref<ModulatedParameter> resonance = memnew(ModulatedParameter);
		resonance->set_base_value(0.5f);
		filter->set_parameter("resonance", resonance);

		// Add delay for space
		Ref<PingPongDelay> delay = memnew(PingPongDelay);
		Ref<ModulatedParameter> delay_time = memnew(ModulatedParameter);
		delay_time->set_base_value(0.3f);
		delay->set_parameter(PingPongDelay::PARAM_DELAY_TIME, delay_time);

		Ref<ModulatedParameter> feedback = memnew(ModulatedParameter);
		feedback->set_base_value(0.3f);
		delay->set_parameter(PingPongDelay::PARAM_FEEDBACK, feedback);

		Ref<ModulatedParameter> delay_mix = memnew(ModulatedParameter);
		delay_mix->set_base_value(0.2f);
		delay->set_parameter(PingPongDelay::PARAM_MIX, delay_mix);

		Ref<EffectChain> effects = memnew(EffectChain);
		effects->add_effect(filter);
		effects->add_effect(delay);
		va_config->effects = effects;

		return va_config;
	};
};

class PadSynthPreset : public VASynthPreset {
	GDCLASS(PadSynthPreset, VASynthPreset);

protected:
	static void _bind_methods() { ; }

public:
	PadSynthPreset() { ; }
	virtual ~PadSynthPreset() { ; }

	virtual Ref<ConfigurationPrototype> get_configuration() override {
		Ref<VAConfigurationPrototype> va_config = memnew(VAConfigurationPrototype);

		// Smooth pad waveforms
		va_config->bottom_wave = WaveHelper::SINE;
		va_config->middle_wave = WaveHelper::TRIANGLE;
		va_config->top_wave = WaveHelper::SINE;

		// Waveform parameter
		Ref<ModulatedParameter> waveform_param = memnew(ModulatedParameter);
		waveform_param->set_base_value(0.3);
		va_config->waveform = waveform_param;

		// Slow attack, long sustain and release
		Ref<ADSR> adsr = memnew(ADSR);
		adsr->set_attack(1.5f);
		adsr->set_decay(1.0f);
		adsr->set_sustain(0.8f);
		adsr->set_release(2.0f);

		// Amplitude setup
		Ref<ModulatedParameter> amp_param = memnew(ModulatedParameter);
		amp_param->set_base_value(0.0f);
		amp_param->set_mod_min(0.0f);
		amp_param->set_mod_max(0.8f);
		amp_param->set_mod_type(ModulationType::MODULATION_ABSOLUTE);
		amp_param->set_mod_source(adsr);
		amp_param->set_mod_amount(1.0f);
		va_config->amplitude = amp_param;

		// Mid pitch for pad
		Ref<ModulatedParameter> pitch_param = memnew(ModulatedParameter);
		pitch_param->set_base_value(60.0f); // C4
		pitch_param->set_mod_min(-24.0f);
		pitch_param->set_mod_max(24.0f);

		// Add slow vibrato with LFO
		Ref<LFO> vibrato = memnew(LFO);
		vibrato->set_rate(0.5f);
		vibrato->set_wave_type(WaveHelper::SINE);
		pitch_param->set_mod_source(vibrato);
		pitch_param->set_mod_amount(0.2f);

		va_config->pitch = pitch_param;

		// Add filter for tone shaping
		Ref<LowPassFilter> filter = memnew(LowPassFilter);
		Ref<ModulatedParameter> cutoff = memnew(ModulatedParameter);
		cutoff->set_base_value(0.4f);

		// Slow filter modulation
		Ref<LFO> filter_lfo = memnew(LFO);
		filter_lfo->set_rate(0.3f);
		filter_lfo->set_wave_type(WaveHelper::SINE);
		cutoff->set_mod_source(filter_lfo);
		cutoff->set_mod_amount(0.2f);

		filter->set_parameter("cutoff", cutoff);

		Ref<ModulatedParameter> resonance = memnew(ModulatedParameter);
		resonance->set_base_value(0.2f);
		filter->set_parameter("resonance", resonance);

		// Add reverb for space
		Ref<Reverb> reverb = memnew(Reverb);
		Ref<ModulatedParameter> room_size = memnew(ModulatedParameter);
		room_size->set_base_value(0.9f);
		reverb->set_parameter(Reverb::PARAM_ROOM_SIZE, room_size);

		Ref<ModulatedParameter> mix = memnew(ModulatedParameter);
		mix->set_base_value(0.7f);
		reverb->set_parameter(Reverb::PARAM_MIX, mix);

		Ref<ModulatedParameter> width = memnew(ModulatedParameter);
		width->set_base_value(1.0f);
		reverb->set_parameter(Reverb::PARAM_WIDTH, width);

		Ref<EffectChain> effects = memnew(EffectChain);
		effects->add_effect(filter);
		effects->add_effect(reverb);
		va_config->effects = effects;

		return va_config;
	};
};

class KickDrumPreset : public VASynthPreset {
	GDCLASS(KickDrumPreset, VASynthPreset);

protected:
	static void _bind_methods() { ; }

public:
	KickDrumPreset() { ; }
	virtual ~KickDrumPreset() { ; }

	virtual Ref<ConfigurationPrototype> get_configuration() override {
		Ref<VAConfigurationPrototype> va_config = memnew(VAConfigurationPrototype);

		// Kick drum waveforms
		va_config->bottom_wave = WaveHelper::SINE;
		va_config->middle_wave = WaveHelper::SQUARE;
		va_config->top_wave = WaveHelper::NOISE;

		// Waveform parameter
		Ref<ModulatedParameter> waveform_param = memnew(ModulatedParameter);
		waveform_param->set_base_value(0.1);
		va_config->waveform = waveform_param;

		// Very quick attack, short decay
		Ref<ADSR> adsr = memnew(ADSR);
		adsr->set_attack(0.001f);
		adsr->set_decay(0.3f);
		adsr->set_sustain(0.0f);
		adsr->set_release(0.1f);

		// Amplitude setup
		Ref<ModulatedParameter> amp_param = memnew(ModulatedParameter);
		amp_param->set_base_value(0.0f);
		amp_param->set_mod_min(0.0f);
		amp_param->set_mod_max(1.0f);
		amp_param->set_mod_type(ModulationType::MODULATION_ABSOLUTE);
		amp_param->set_mod_source(adsr);
		amp_param->set_mod_amount(1.0f);
		va_config->amplitude = amp_param;

		// Low pitch with quick drop
		Ref<ModulatedParameter> pitch_param = memnew(ModulatedParameter);
		pitch_param->set_base_value(36.0f); // C2
		pitch_param->set_mod_min(-24.0f);
		pitch_param->set_mod_max(24.0f);

		// Quick pitch drop
		Ref<NoteDurationModSource> pitch_mod = memnew(NoteDurationModSource);
		pitch_mod->set_attack_time(0.001f);
		pitch_mod->set_max_time(0.15f);
		pitch_param->set_mod_source(pitch_mod);
		pitch_param->set_mod_amount(-24.0f);

		va_config->pitch = pitch_param;

		// Add filter for kick shape
		Ref<LowPassFilter> filter = memnew(LowPassFilter);
		Ref<ModulatedParameter> cutoff = memnew(ModulatedParameter);
		cutoff->set_base_value(0.4f);

		// Filter envelope
		Ref<NoteDurationModSource> filter_env = memnew(NoteDurationModSource);
		filter_env->set_attack_time(0.001f);
		filter_env->set_max_time(0.1f);
		cutoff->set_mod_source(filter_env);
		cutoff->set_mod_amount(-0.3f);

		filter->set_parameter("cutoff", cutoff);

		Ref<ModulatedParameter> resonance = memnew(ModulatedParameter);
		resonance->set_base_value(0.1f);
		filter->set_parameter("resonance", resonance);

		// Add distortion for punch
		Ref<ClipDistortion> distortion = memnew(ClipDistortion);
		Ref<ModulatedParameter> drive = memnew(ModulatedParameter);
		drive->set_base_value(0.3f);
		distortion->set_parameter(ClipDistortion::PARAM_DRIVE, drive);

		Ref<ModulatedParameter> threshold = memnew(ModulatedParameter);
		threshold->set_base_value(0.5f);
		distortion->set_parameter(ClipDistortion::PARAM_THRESHOLD, threshold);

		Ref<EffectChain> effects = memnew(EffectChain);
		effects->add_effect(filter);
		effects->add_effect(distortion);
		va_config->effects = effects;

		return va_config;
	};
};

class SnareDrumPreset : public VASynthPreset {
	GDCLASS(SnareDrumPreset, VASynthPreset);

protected:
	static void _bind_methods() { ; }

public:
	SnareDrumPreset() { ; }
	virtual ~SnareDrumPreset() { ; }

	virtual Ref<ConfigurationPrototype> get_configuration() override {
		Ref<VAConfigurationPrototype> va_config = memnew(VAConfigurationPrototype);

		// Snare drum waveforms
		va_config->bottom_wave = WaveHelper::NOISE;
		va_config->middle_wave = WaveHelper::SQUARE;
		va_config->top_wave = WaveHelper::NOISE;

		// Waveform parameter
		Ref<ModulatedParameter> waveform_param = memnew(ModulatedParameter);
		waveform_param->set_base_value(0.7);
		va_config->waveform = waveform_param;

		// Very quick attack, short decay
		Ref<ADSR> adsr = memnew(ADSR);
		adsr->set_attack(0.001f);
		adsr->set_decay(0.2f);
		adsr->set_sustain(0.0f);
		adsr->set_release(0.1f);

		// Amplitude setup
		Ref<ModulatedParameter> amp_param = memnew(ModulatedParameter);
		amp_param->set_base_value(0.0f);
		amp_param->set_mod_min(0.0f);
		amp_param->set_mod_max(1.0f);
		amp_param->set_mod_type(ModulationType::MODULATION_ABSOLUTE);
		amp_param->set_mod_source(adsr);
		amp_param->set_mod_amount(1.0f);
		va_config->amplitude = amp_param;

		// Mid-low pitch with quick drop
		Ref<ModulatedParameter> pitch_param = memnew(ModulatedParameter);
		pitch_param->set_base_value(48.0f); // C3
		pitch_param->set_mod_min(-24.0f);
		pitch_param->set_mod_max(24.0f);

		// Quick pitch drop
		Ref<NoteDurationModSource> pitch_mod = memnew(NoteDurationModSource);
		pitch_mod->set_attack_time(0.001f);
		pitch_mod->set_max_time(0.1f);
		pitch_param->set_mod_source(pitch_mod);
		pitch_param->set_mod_amount(-12.0f);

		va_config->pitch = pitch_param;

		// Add high pass filter for snare crack
		Ref<HighPassFilter> filter = memnew(HighPassFilter);
		Ref<ModulatedParameter> cutoff = memnew(ModulatedParameter);
		cutoff->set_base_value(0.4f);

		// Filter envelope
		Ref<NoteDurationModSource> filter_env = memnew(NoteDurationModSource);
		filter_env->set_attack_time(0.001f);
		filter_env->set_max_time(0.1f);
		cutoff->set_mod_source(filter_env);
		cutoff->set_mod_amount(-0.2f);

		filter->set_parameter("cutoff", cutoff);

		Ref<ModulatedParameter> resonance = memnew(ModulatedParameter);
		resonance->set_base_value(0.3f);
		filter->set_parameter("resonance", resonance);

		// Add distortion for snap
		Ref<ClipDistortion> distortion = memnew(ClipDistortion);
		Ref<ModulatedParameter> drive = memnew(ModulatedParameter);
		drive->set_base_value(0.5f);
		distortion->set_parameter(ClipDistortion::PARAM_DRIVE, drive);

		Ref<ModulatedParameter> threshold = memnew(ModulatedParameter);
		threshold->set_base_value(0.4f);
		distortion->set_parameter(ClipDistortion::PARAM_THRESHOLD, threshold);

		// Add reverb for space
		Ref<Reverb> reverb = memnew(Reverb);
		Ref<ModulatedParameter> room_size = memnew(ModulatedParameter);
		room_size->set_base_value(0.3f);
		reverb->set_parameter(Reverb::PARAM_ROOM_SIZE, room_size);

		Ref<ModulatedParameter> mix = memnew(ModulatedParameter);
		mix->set_base_value(0.2f);
		reverb->set_parameter(Reverb::PARAM_MIX, mix);

		Ref<EffectChain> effects = memnew(EffectChain);
		effects->add_effect(filter);
		effects->add_effect(distortion);
		effects->add_effect(reverb);
		va_config->effects = effects;

		return va_config;
	};
};

class HiHatPreset : public VASynthPreset {
	GDCLASS(HiHatPreset, VASynthPreset);

protected:
	static void _bind_methods() { ; }

public:
	HiHatPreset() { ; }
	virtual ~HiHatPreset() { ; }

	virtual Ref<ConfigurationPrototype> get_configuration() override {
		Ref<VAConfigurationPrototype> va_config = memnew(VAConfigurationPrototype);

		// Hi-hat waveforms
		va_config->bottom_wave = WaveHelper::NOISE;
		va_config->middle_wave = WaveHelper::SQUARE;
		va_config->top_wave = WaveHelper::NOISE;

		// Waveform parameter
		Ref<ModulatedParameter> waveform_param = memnew(ModulatedParameter);
		waveform_param->set_base_value(0.9);
		va_config->waveform = waveform_param;

		// Very quick attack, variable decay for open/closed
		Ref<ADSR> adsr = memnew(ADSR);
		adsr->set_attack(0.001f);
		adsr->set_decay(0.1f); // Closed hi-hat
		adsr->set_sustain(0.0f);
		adsr->set_release(0.05f);

		// Amplitude setup
		Ref<ModulatedParameter> amp_param = memnew(ModulatedParameter);
		amp_param->set_base_value(0.0f);
		amp_param->set_mod_min(0.0f);
		amp_param->set_mod_max(0.8f);
		amp_param->set_mod_type(ModulationType::MODULATION_ABSOLUTE);
		amp_param->set_mod_source(adsr);
		amp_param->set_mod_amount(1.0f);
		va_config->amplitude = amp_param;

		// High pitch
		Ref<ModulatedParameter> pitch_param = memnew(ModulatedParameter);
		pitch_param->set_base_value(84.0f); // C6
		pitch_param->set_mod_min(-24.0f);
		pitch_param->set_mod_max(24.0f);
		va_config->pitch = pitch_param;

		// Add high pass filter for hi-hat character
		Ref<HighPassFilter> filter = memnew(HighPassFilter);
		Ref<ModulatedParameter> cutoff = memnew(ModulatedParameter);
		cutoff->set_base_value(0.7f);
		filter->set_parameter("cutoff", cutoff);

		Ref<ModulatedParameter> resonance = memnew(ModulatedParameter);
		resonance->set_base_value(0.5f);
		filter->set_parameter("resonance", resonance);

		// Add distortion for metallic character
		Ref<BitcrushDistortion> distortion = memnew(BitcrushDistortion);
		Ref<ModulatedParameter> drive = memnew(ModulatedParameter);
		drive->set_base_value(0.3f);
		distortion->set_parameter(BitcrushDistortion::PARAM_DRIVE, drive);

		Ref<ModulatedParameter> bit_depth = memnew(ModulatedParameter);
		bit_depth->set_base_value(0.7f);
		distortion->set_parameter(BitcrushDistortion::PARAM_BIT_DEPTH, bit_depth);

		Ref<EffectChain> effects = memnew(EffectChain);
		effects->add_effect(filter);
		effects->add_effect(distortion);
		va_config->effects = effects;

		return va_config;
	};
};

class ArpeggiatorPreset : public VASynthPreset {
	GDCLASS(ArpeggiatorPreset, VASynthPreset);

protected:
	static void _bind_methods() { ; }

public:
	ArpeggiatorPreset() { ; }
	virtual ~ArpeggiatorPreset() { ; }

	virtual Ref<ConfigurationPrototype> get_configuration() override {
		Ref<VAConfigurationPrototype> va_config = memnew(VAConfigurationPrototype);

		// Bright arpeggiator waveforms
		va_config->bottom_wave = WaveHelper::PULSE;
		va_config->middle_wave = WaveHelper::TRIANGLE;
		va_config->top_wave = WaveHelper::SINE;

		// Waveform parameter
		Ref<ModulatedParameter> waveform_param = memnew(ModulatedParameter);
		waveform_param->set_base_value(0.3);
		va_config->waveform = waveform_param;

		// Quick attack, short decay
		Ref<ADSR> adsr = memnew(ADSR);
		adsr->set_attack(0.01f);
		adsr->set_decay(0.1f);
		adsr->set_sustain(0.0f);
		adsr->set_release(0.1f);

		// Amplitude setup
		Ref<ModulatedParameter> amp_param = memnew(ModulatedParameter);
		amp_param->set_base_value(0.0f);
		amp_param->set_mod_min(0.0f);
		amp_param->set_mod_max(0.9f);
		amp_param->set_mod_type(ModulationType::MODULATION_ABSOLUTE);
		amp_param->set_mod_source(adsr);
		amp_param->set_mod_amount(1.0f);
		va_config->amplitude = amp_param;

		// Mid-high pitch
		Ref<ModulatedParameter> pitch_param = memnew(ModulatedParameter);
		pitch_param->set_base_value(72.0f); // C5
		pitch_param->set_mod_min(-24.0f);
		pitch_param->set_mod_max(24.0f);
		va_config->pitch = pitch_param;

		// Add filter for tone shaping
		Ref<BandPassFilter> filter = memnew(BandPassFilter);
		Ref<ModulatedParameter> cutoff = memnew(ModulatedParameter);
		cutoff->set_base_value(0.6f);

		// Filter envelope
		Ref<ADSR> filter_env = memnew(ADSR);
		filter_env->set_attack(0.01f);
		filter_env->set_decay(0.2f);
		filter_env->set_sustain(0.0f);
		filter_env->set_release(0.1f);
		cutoff->set_mod_source(filter_env);
		cutoff->set_mod_amount(0.3f);

		filter->set_parameter("cutoff", cutoff);

		Ref<ModulatedParameter> resonance = memnew(ModulatedParameter);
		resonance->set_base_value(0.6f);
		filter->set_parameter("resonance", resonance);

		// Add delay for arpeggiator effect
		Ref<PingPongDelay> delay = memnew(PingPongDelay);
		Ref<ModulatedParameter> delay_time = memnew(ModulatedParameter);
		delay_time->set_base_value(0.25f);
		delay->set_parameter(PingPongDelay::PARAM_DELAY_TIME, delay_time);

		Ref<ModulatedParameter> feedback = memnew(ModulatedParameter);
		feedback->set_base_value(0.6f);
		delay->set_parameter(PingPongDelay::PARAM_FEEDBACK, feedback);

		Ref<ModulatedParameter> delay_mix = memnew(ModulatedParameter);
		delay_mix->set_base_value(0.5f);
		delay->set_parameter(PingPongDelay::PARAM_MIX, delay_mix);

		Ref<EffectChain> effects = memnew(EffectChain);
		effects->add_effect(filter);
		effects->add_effect(delay);
		va_config->effects = effects;

		return va_config;
	};
};

} // namespace godot
