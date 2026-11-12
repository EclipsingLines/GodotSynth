#include "audio_synth_player.h"
#include "audio_stream_generator_engine.h"
#include "engine_factory.h"
#include "modulated_parameter.h"
#include "../effects/effect_chain.h"
#include "synth_audio_stream_playback.h"
#include "synth_configuration.h"
#include "synth_voice.h"
#include <godot_cpp/classes/audio_server.hpp>
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/time.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

namespace godot {

void AudioSynthPlayer::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_configuration", "config"), &AudioSynthPlayer::set_configuration);
	ClassDB::bind_method(D_METHOD("get_configuration"), &AudioSynthPlayer::get_configuration);

	ClassDB::bind_method(D_METHOD("get_context"), &AudioSynthPlayer::get_context);
	ClassDB::bind_method(D_METHOD("get_mixed_frames"), &AudioSynthPlayer::get_mixed_frames);
	ClassDB::bind_method(D_METHOD("schedule_note", "note", "velocity", "on_frame", "off_frame", "controls"), &AudioSynthPlayer::schedule_note, DEFVAL(Dictionary()));
	ClassDB::bind_method(D_METHOD("schedule_parameter", "name", "value", "frame"), &AudioSynthPlayer::schedule_parameter);
	ClassDB::bind_method(D_METHOD("schedule_gain_ramp", "gain", "frame", "ramp_frames"), &AudioSynthPlayer::schedule_gain_ramp);
	ClassDB::bind_method(D_METHOD("has_parameter", "name"), &AudioSynthPlayer::has_parameter);
	ClassDB::bind_method(D_METHOD("restart_stream"), &AudioSynthPlayer::restart_stream);
	ClassDB::bind_method(D_METHOD("play_note_on_context", "context", "note", "velocity"), &AudioSynthPlayer::play_note_on_context);
	ClassDB::bind_method(D_METHOD("play_note_off_context", "context"), &AudioSynthPlayer::play_note_off_context);
	ClassDB::bind_method(D_METHOD("stop_all_notes"), &AudioSynthPlayer::stop_all_notes);

	ClassDB::bind_method(D_METHOD("set_parameter", "name", "value"), &AudioSynthPlayer::set_parameter);

	// Add polyphony property
	ClassDB::bind_method(D_METHOD("set_polyphony", "polyphony"), &AudioSynthPlayer::set_polyphony);
	ClassDB::bind_method(D_METHOD("get_polyphony"), &AudioSynthPlayer::get_polyphony);
	ADD_PROPERTY(PropertyInfo(Variant::INT, "polyphony", PROPERTY_HINT_RANGE, "1,32,1"),
			"set_polyphony", "get_polyphony");

	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "configuration", PROPERTY_HINT_RESOURCE_TYPE, "SynthConfiguration"), "set_configuration", "get_configuration");
}

AudioSynthPlayer::AudioSynthPlayer() :
		sample_rate(44100.0f) {
	// Create the audio stream
	stream.instantiate();
	sample_rate = AudioServer::get_singleton()->get_mix_rate();
	stream->set_mix_rate(sample_rate);

	// Connect to AudioServer signals to update bus options when they change
	AudioServer::get_singleton()->connect("bus_layout_changed", Callable(this, "notify_property_list_changed"));
	AudioServer::get_singleton()->connect("bus_renamed", Callable(this, "notify_property_list_changed"));
}

AudioSynthPlayer::~AudioSynthPlayer() {
	// Disconnect from AudioServer signals
	if (AudioServer::get_singleton()) {
		AudioServer::get_singleton()->disconnect("bus_layout_changed", Callable(this, "notify_property_list_changed"));
		AudioServer::get_singleton()->disconnect("bus_renamed", Callable(this, "notify_property_list_changed"));
	}
}

void AudioSynthPlayer::_ready() {
	// Set the stream when the node enters the tree
	set_stream(stream);

	// Start playback with explicit volume
	set_volume_db(0.0); // Ensure volume is at 0 dB (full volume)
	play();

	// Get the playback interface after starting playback
	playback.unref();
	ensure_playback();

	// Initialize the voice pool
	initialize_voice_pool();
}

void AudioSynthPlayer::_process(double delta) {
	// Try to get the playback interface if it's not already set
	if (!playback.is_valid() && is_playing()) {
		acquire_playback();
	}
}

void AudioSynthPlayer::acquire_playback() {
	Ref<AudioStreamPlayback> stream_playback = get_stream_playback();
	if (stream_playback.is_valid()) {
		playback = Ref<SynthAudioStreamPlayback>(Object::cast_to<SynthAudioStreamPlayback>(stream_playback.ptr()));
		if (playback.is_valid()) {
			// A new playback starts without a master chain.
			sync_master_chain();
		}
	}
}

void AudioSynthPlayer::sync_master_chain() {
	if (!playback.is_valid()) {
		return;
	}
	Ref<EffectChain> chain;
	if (configuration.is_valid()) {
		chain = configuration->get_master_effect_chain();
	}
	if (!playback->set_master_effect_chain(chain)) {
		UtilityFunctions::push_warning("AudioSynthPlayer: note event queue is full, master effect chain not updated.");
	}
}

void AudioSynthPlayer::set_configuration(const Ref<SynthConfiguration> &p_config) {
	configuration = p_config;

	// Stop all current voices when configuration changes
	stop_all_notes();

	// Set the output bus if specified in the configuration
	if (configuration.is_valid()) {
		String bus_name = configuration->get_output_bus();
		// Validate that the bus exists
		bool bus_found = false;
		for (int i = 0; i < AudioServer::get_singleton()->get_bus_count(); i++) {
			if (AudioServer::get_singleton()->get_bus_name(i) == bus_name) {
				bus_found = true;
				break;
			}
		}
		// If bus not found, default to "Master"
		set_bus(bus_found ? bus_name : "Master");
	}

	sync_master_chain();

	// Reinitialize the voice pool with the new configuration
	initialize_voice_pool();
}

Ref<SynthConfiguration> AudioSynthPlayer::get_configuration() const {
	return configuration;
}

void AudioSynthPlayer::set_polyphony(int p_polyphony) {
	polyphony = Math::clamp(p_polyphony, 1, 32);
	initialize_voice_pool();
}

int AudioSynthPlayer::get_polyphony() const {
	return polyphony;
}

void AudioSynthPlayer::initialize_voice_pool() {
	// Clear existing pool
	voice_pool.clear();

	// Create new voices
	for (int i = 0; i < polyphony; i++) {
		Ref<SynthVoice> voice;
		voice.instantiate();

		// If we have a configuration, create an engine for this voice
		if (configuration.is_valid()) {
			Ref<AudioStreamGeneratorEngine> engine = EngineFactory::create_engine_from_config(configuration);
			if (engine.is_valid()) {
				engine->set_sample_rate(sample_rate);
				voice->set_engine(engine);
			}
		}

		voice_pool.push_back(voice);
	}

	next_voice_index = 0;
}

Ref<SynthVoice> AudioSynthPlayer::allocate_voice() {
	if (voice_pool.size() == 0) {
		initialize_voice_pool();
	}

	const int pool_size = voice_pool.size();
	if (next_voice_index >= pool_size) {
		next_voice_index = 0;
	}

	// Find the next free voice using round-robin. A voice counts as busy from
	// the moment it is reserved here, so several get_context() calls in the
	// same frame (before the audio thread has started any of them) each get
	// a different voice.
	for (int n = 0; n < pool_size; n++) {
		Ref<SynthVoice> voice = voice_pool[next_voice_index];
		next_voice_index = (next_voice_index + 1) % pool_size;

		if (!voice->is_active()) {
			voice->reserve();
			return voice;
		}
	}

	// All voices are busy: steal the next one in round-robin order. The audio
	// thread swaps its context when it applies the START_VOICE event, so the
	// voice is not touched here while it may still be mixing.
	Ref<SynthVoice> voice = voice_pool[next_voice_index];
	next_voice_index = (next_voice_index + 1) % pool_size;
	voice->reserve();
	return voice;
}

bool AudioSynthPlayer::ensure_playback() {
	// AudioStreamPlayer::play() creates a new playback, so re-fetch it after
	// (re)starting the stream.
	if (!is_playing()) {
		set_volume_db(0.0); // Ensure volume is at 0 dB (full volume)
		play();
		playback.unref();
	}

	if (!playback.is_valid()) {
		acquire_playback();
	}

	return playback.is_valid();
}

Ref<SynthNoteContext> AudioSynthPlayer::prepare_note(Ref<SynthVoice> &r_voice) {
	if (!configuration.is_valid()) {
		return nullptr;
	}

	if (!ensure_playback()) {
		return nullptr;
	}

	// Get a voice from the pool
	Ref<SynthVoice> voice = allocate_voice();

	// If the voice doesn't have an engine (or it's invalid), create one.
	// Safe here: a voice without an engine never produces sound, so the audio
	// thread does not use its engine.
	if (!voice->get_engine().is_valid()) {
		Ref<AudioStreamGeneratorEngine> engine = EngineFactory::create_engine_from_config(configuration);
		if (engine.is_valid()) {
			engine->set_sample_rate(sample_rate);
			voice->set_engine(engine);
		} else {
			return nullptr;
		}
	}

	// Every note gets a fresh context. The audio thread attaches it to the
	// voice (START_VOICE event), so the caller can configure it and call
	// note_on() right away without racing the mixer.
	Ref<SynthNoteContext> context;
	context.instantiate();

	double current_time = playback->get_current_time();
	context->set_absolute_time(current_time);
	context->set_note_time(0.0);
	context->set_note_on_time(current_time);
	context->set_note_state(SynthNoteContext::NOTE_STATE_READY);

	// Unique per note. This used to be Time::get_ticks_msec(), which gave
	// every note started in the same millisecond the same id, and the voice
	// map then kept only the last of them (issue #1).
	context->set_voice_id(next_voice_id++);
	context->set_player_id(get_instance_id());

	r_voice = voice;
	return context;
}

Ref<SynthNoteContext> AudioSynthPlayer::get_context() {
	Ref<SynthVoice> voice;
	Ref<SynthNoteContext> context = prepare_note(voice);
	if (context.is_null()) {
		return nullptr;
	}

	if (!playback->add_voice(voice, context)) {
		UtilityFunctions::push_warning("AudioSynthPlayer: note event queue is full, note dropped.");
		return nullptr;
	}

	return context;
}

int64_t AudioSynthPlayer::get_mixed_frames() const {
	return playback.is_valid() ? playback->get_mixed_frames() : 0;
}

Ref<SynthNoteContext> AudioSynthPlayer::schedule_note(int p_note, float p_velocity, int64_t p_on_frame, int64_t p_off_frame, const Dictionary &p_controls) {
	ERR_FAIL_COND_V_MSG(p_on_frame < 0, Ref<SynthNoteContext>(), "AudioSynthPlayer: on_frame must be >= 0.");
	ERR_FAIL_COND_V_MSG(p_off_frame >= 0 && p_off_frame < p_on_frame, Ref<SynthNoteContext>(), "AudioSynthPlayer: off_frame must be >= on_frame, or -1 for no note-off.");

	Ref<SynthVoice> voice;
	Ref<SynthNoteContext> context = prepare_note(voice);
	if (context.is_null()) {
		UtilityFunctions::push_warning("AudioSynthPlayer: cannot schedule a note without a configuration and a playback.");
		return nullptr;
	}

	if (!playback->add_voice(voice, context, p_on_frame)) {
		UtilityFunctions::push_warning("AudioSynthPlayer: note event queue is full, note dropped.");
		return nullptr;
	}

	// Per-note controls go to this voice's own engine parameters, on the note-on frame.
	Array keys = p_controls.keys();
	for (int i = 0; i < keys.size(); i++) {
		Variant key = keys[i];
		Variant value = p_controls[key];
		if (key.get_type() != Variant::STRING && key.get_type() != Variant::STRING_NAME) {
			UtilityFunctions::push_warning("AudioSynthPlayer: control names must be strings, control skipped.");
			continue;
		}
		if (value.get_type() != Variant::INT && value.get_type() != Variant::FLOAT) {
			UtilityFunctions::push_warning("AudioSynthPlayer: control values must be numbers, control skipped.");
			continue;
		}

		String name = key;
		Ref<ModulatedParameter> engine_param = voice->get_engine()->resolve_parameter(name);
		if (!engine_param.is_valid()) {
			UtilityFunctions::push_warning("AudioSynthPlayer: unknown control '" + name + "'");
			continue;
		}

		SynthNoteEvent event;
		event.type = SynthNoteEvent::SET_PARAMETER;
		event.parameter = engine_param;
		event.value = value;
		event.frame = p_on_frame;
		if (!playback->push_event(event)) {
			UtilityFunctions::push_warning("AudioSynthPlayer: note event queue is full, control '" + name + "' dropped.");
		}
	}

	SynthNoteEvent on_event;
	on_event.type = SynthNoteEvent::NOTE_ON;
	on_event.context = context;
	on_event.note = p_note;
	on_event.velocity = p_velocity;
	on_event.frame = p_on_frame;
	if (!playback->push_event(on_event)) {
		UtilityFunctions::push_warning("AudioSynthPlayer: note event queue is full, note_on dropped.");
	}

	if (p_off_frame >= 0) {
		SynthNoteEvent off_event;
		off_event.type = SynthNoteEvent::NOTE_OFF;
		off_event.context = context;
		off_event.frame = p_off_frame;
		if (!playback->push_event(off_event)) {
			UtilityFunctions::push_warning("AudioSynthPlayer: note event queue is full, note_off dropped.");
		}
	}

	return context;
}

void AudioSynthPlayer::schedule_parameter(const String &p_name, float p_value, int64_t p_frame) {
	if (!ensure_playback()) {
		UtilityFunctions::push_warning("AudioSynthPlayer: cannot schedule a parameter without a playback.");
		return;
	}

	// Engines in the pool own duplicates of the parameter. The audio thread may
	// be reading them, so the change is queued at p_frame; the configuration's
	// base value is left alone (unlike set_parameter()).
	for (int i = 0; i < voice_pool.size(); i++) {
		const Ref<SynthVoice> &voice = voice_pool[i];
		if (!voice.is_valid() || !voice->get_engine().is_valid()) {
			continue;
		}
		Ref<ModulatedParameter> engine_param = voice->get_engine()->resolve_parameter(p_name);
		if (!engine_param.is_valid()) {
			continue;
		}
		SynthNoteEvent event;
		event.type = SynthNoteEvent::SET_PARAMETER;
		event.parameter = engine_param;
		event.value = p_value;
		event.frame = p_frame;
		if (!playback->push_event(event)) {
			UtilityFunctions::push_warning("AudioSynthPlayer: note event queue is full, schedule_parameter dropped.");
			return;
		}
	}
}

void AudioSynthPlayer::schedule_gain_ramp(float p_gain, int64_t p_frame, int p_ramp_frames) {
	ERR_FAIL_COND_MSG(p_frame < 0, "AudioSynthPlayer: frame must be >= 0.");
	if (!ensure_playback()) {
		UtilityFunctions::push_warning("AudioSynthPlayer: no playback, gain ramp dropped.");
		return;
	}
	if (!playback->queue_gain_ramp(p_gain, p_frame, p_ramp_frames)) {
		UtilityFunctions::push_warning("AudioSynthPlayer: note event queue is full, gain ramp dropped.");
	}
}

bool AudioSynthPlayer::has_parameter(const String &p_name) const {
	if (configuration.is_null()) {
		return false;
	}

	// A pooled voice engine is what schedule_note and schedule_parameter resolve
	// against, so prefer one; before any voice exists, ask a temporary engine.
	for (int i = 0; i < voice_pool.size(); i++) {
		const Ref<SynthVoice> &voice = voice_pool[i];
		if (voice.is_valid() && voice->get_engine().is_valid()) {
			return voice->get_engine()->resolve_parameter(p_name).is_valid();
		}
	}

	Ref<AudioStreamGeneratorEngine> engine = EngineFactory::create_engine_from_config(configuration);
	if (engine.is_null()) {
		return false;
	}
	return engine->resolve_parameter(p_name).is_valid();
}

void AudioSynthPlayer::restart_stream() {
	if (stream.is_null()) {
		return;
	}
	if (is_playing()) {
		stop();
	}
	set_volume_db(0.0);
	play();
	playback.unref();
	// The old playback is gone, so voices it was mixing are free again.
	for (int i = 0; i < voice_pool.size(); i++) {
		if (voice_pool[i].is_valid()) {
			voice_pool[i]->reset();
		}
	}
	acquire_playback(); // also re-sends the master chain
}

bool AudioSynthPlayer::queue_context_event(const Ref<SynthNoteContext> &p_context, int p_type, float p_note, float p_velocity) {
	ERR_FAIL_COND_V_MSG(p_context.is_null(), false, "AudioSynthPlayer: context is null.");
	if (!ensure_playback()) {
		return false;
	}

	SynthNoteEvent event;
	event.type = (SynthNoteEvent::Type)p_type;
	event.context = p_context;
	event.note = p_note;
	event.velocity = p_velocity;

	if (!playback->push_event(event)) {
		UtilityFunctions::push_warning("AudioSynthPlayer: note event queue is full, event dropped.");
		return false;
	}
	return true;
}

void AudioSynthPlayer::play_note_on_context(const Ref<SynthNoteContext> &p_context, float p_note, float p_velocity) {
	queue_context_event(p_context, SynthNoteEvent::NOTE_ON, p_note, p_velocity);
}

void AudioSynthPlayer::play_note_off_context(const Ref<SynthNoteContext> &p_context) {
	queue_context_event(p_context, SynthNoteEvent::NOTE_OFF, 0.0f, 0.0f);
}

void AudioSynthPlayer::stop_all_notes() {
	if (!playback.is_valid()) {
		return;
	}

	// Every voice in the mix releases (applied on the audio thread).
	if (!playback->release_all_voices()) {
		UtilityFunctions::push_warning("AudioSynthPlayer: note event queue is full, stop_all_notes dropped.");
	}
}

void AudioSynthPlayer::set_parameter(const String &p_name, float p_value) {
	if (!configuration.is_valid()) {
		return;
	}

	// The configuration's copy is what engines created from now on start from.
	Ref<ModulatedParameter> param = configuration->get_parameter(p_name);
	if (!param.is_valid()) {
		param = AudioStreamGeneratorEngine::resolve_effect_parameter(configuration->get_effect_chain(), p_name);
	}
	if (param.is_valid()) {
		param->set_base_value(p_value);
	}

	// Engines already in the pool own duplicates of the parameter. The audio
	// thread may be reading them, so the change is queued and applied there.
	for (int i = 0; i < voice_pool.size(); i++) {
		const Ref<SynthVoice> &voice = voice_pool[i];
		if (!voice.is_valid() || !voice->get_engine().is_valid()) {
			continue;
		}
		Ref<ModulatedParameter> engine_param = voice->get_engine()->resolve_parameter(p_name);
		if (!engine_param.is_valid()) {
			continue;
		}
		if (!playback.is_valid() || !is_playing()) {
			// Nothing is mixing (and a stopped playback is replaced on the next
			// play(), losing its queue), so set it directly.
			engine_param->set_base_value(p_value);
			continue;
		}
		SynthNoteEvent event;
		event.type = SynthNoteEvent::SET_PARAMETER;
		event.parameter = engine_param;
		event.value = p_value;
		if (!playback->push_event(event)) {
			UtilityFunctions::push_warning("AudioSynthPlayer: note event queue is full, set_parameter dropped.");
			return;
		}
	}
}

} // namespace godot
