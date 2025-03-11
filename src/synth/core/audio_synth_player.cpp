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

	// Debug playback state
	UtilityFunctions::print("Started playback, is_playing=" + String(is_playing() ? "true" : "false") +
			", volume_db=" + String::num(get_volume_db()));

	// Get the playback interface after starting playback
	Ref<AudioStreamPlayback> stream_playback = get_stream_playback();
	if (stream_playback.is_valid()) {
		playback = static_cast<Ref<SynthAudioStreamPlayback>>(stream_playback.ptr());
		if (playback.is_valid()) {
			UtilityFunctions::print("Successfully got SynthAudioStreamPlayback");
		} else {
			UtilityFunctions::printerr("Failed to cast to SynthAudioStreamPlayback");
		}
	} else {
		UtilityFunctions::printerr("Failed to get stream playback");
	}

	// Initialize the voice pool
	initialize_voice_pool();

	UtilityFunctions::print("AudioSynthPlayer ready - Sample rate: " + String::num(sample_rate));
}

void AudioSynthPlayer::_process(double delta) {
	// Try to get the playback interface if it's not already set
	if (!playback.is_valid()) {
		Ref<AudioStreamPlayback> stream_playback = get_stream_playback();
		if (stream_playback.is_valid()) {
			playback = static_cast<Ref<SynthAudioStreamPlayback>>(stream_playback.ptr());
			if (playback.is_valid()) {
				UtilityFunctions::print("_process: Successfully got SynthAudioStreamPlayback");
			}
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
	UtilityFunctions::print("Voice pool initialized with " + String::num_int64(polyphony) + " voices");
}

Ref<SynthVoice> AudioSynthPlayer::allocate_voice() {
	if (voice_pool.size() == 0) {
		initialize_voice_pool();
	}

	// Find the next available voice using round-robin
	int start_index = next_voice_index;
	bool found_inactive = false;

	do {
		Ref<SynthVoice> voice = voice_pool[next_voice_index];

		// Move to next voice for next allocation
		next_voice_index = (next_voice_index + 1) % polyphony;

		// If voice is not active, use it
		if (!voice->is_active()) {
			found_inactive = true;
			return voice;
		}

	} while (next_voice_index != start_index);

	// If we get here, all voices are active, so take the next one (voice stealing)
	UtilityFunctions::print("All voices active, stealing voice " + String::num_int64(next_voice_index));
	Ref<SynthVoice> voice = voice_pool[next_voice_index];
	voice->reset(); // Reset the voice before reusing it
	next_voice_index = (next_voice_index + 1) % polyphony;
	return voice;
}

Ref<SynthNoteContext> AudioSynthPlayer::get_context() {
	if (!configuration.is_valid()) {
		return nullptr;
	}

	// Try to get the playback interface if it's not already set
	if (!playback.is_valid()) {
		Ref<AudioStreamPlayback> stream_playback = get_stream_playback();
		if (stream_playback.is_valid()) {
			playback = static_cast<Ref<SynthAudioStreamPlayback>>(stream_playback.ptr());
			if (!playback.is_valid()) {
				UtilityFunctions::printerr("get_context: Failed to cast to SynthAudioStreamPlayback");
				return nullptr;
			}
		}
	}

	if (!playback.is_valid()) {
		return nullptr;
	}

	// Make sure we're playing with proper volume
	if (!is_playing()) {
		set_volume_db(0.0); // Ensure volume is at 0 dB (full volume)
		play();
	}

	// Get a voice from the pool
	Ref<SynthVoice> voice = allocate_voice();

	// If the voice doesn't have an engine (or it's invalid), create one
	if (!voice->get_engine().is_valid()) {
		Ref<AudioStreamGeneratorEngine> engine = EngineFactory::create_engine_from_config(configuration);
		if (engine.is_valid()) {
			engine->set_sample_rate(sample_rate);
			voice->set_engine(engine);
		} else {
			return nullptr;
		}
	}

	// Get the context from the voice - this will create a fresh context
	Ref<SynthNoteContext> context = voice->get_context();

	// Get the current playback time instead of system time
	double current_time = playback->get_current_time();
	context->set_absolute_time(current_time);
	context->set_note_time(0.0);
	context->set_note_on_time(current_time);

	// Make sure the context is in the READY state
	context->set_note_state(SynthNoteContext::NOTE_STATE_READY);

	// Generate a unique ID for this voice
	int64_t voice_id = Time::get_singleton()->get_ticks_msec();

	// Add to active voices in the playback
	playback->add_voice(voice_id, voice);
	context->set_voice_id(voice_id);

	UtilityFunctions::print("Allocated voice with ID: " + String::num_int64(voice_id) + " at time: " + String::num(current_time));
	return context;
}

void AudioSynthPlayer::stop_all_notes() {
	if (!playback.is_valid()) {
		return;
	}

	// Release all active voices
	playback->release_all_voices();
	UtilityFunctions::print("Stopped all notes");
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
