#include "audio_synth_player.h"
#include "audio_stream_generator_engine.h"
#include "engine_factory.h"
#include "modulated_parameter.h"
#include "synth_audio_stream_playback.h" // Add this include
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
		Ref<AudioStreamPlayback> stream_playback = get_stream_playback();
		if (stream_playback.is_valid()) {
			playback = Ref<SynthAudioStreamPlayback>(Object::cast_to<SynthAudioStreamPlayback>(stream_playback.ptr()));
		}
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
		Ref<AudioStreamPlayback> stream_playback = get_stream_playback();
		if (stream_playback.is_valid()) {
			playback = Ref<SynthAudioStreamPlayback>(Object::cast_to<SynthAudioStreamPlayback>(stream_playback.ptr()));
		}
	}

	return playback.is_valid();
}

Ref<SynthNoteContext> AudioSynthPlayer::get_context() {
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

	if (!playback->add_voice(voice, context)) {
		UtilityFunctions::push_warning("AudioSynthPlayer: note event queue is full, note dropped.");
		return nullptr;
	}

	return context;
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

	// Release all active voices
	playback->release_all_voices();
}

void AudioSynthPlayer::set_parameter(const String &p_name, float p_value) {
	if (!configuration.is_valid()) {
		return;
	}

	Ref<ModulatedParameter> param = configuration->get_parameter(p_name);
	if (param.is_valid()) {
		param->set_base_value(p_value);
	}
}

} // namespace godot
