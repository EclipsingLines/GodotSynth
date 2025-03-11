#include "synth_audio_stream_playback.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <limits>

namespace godot {

void SynthAudioStreamPlayback::_bind_methods() {
}

SynthAudioStreamPlayback::SynthAudioStreamPlayback() {
	// Initialize mix buffer with a reasonable size
	mix_buffer.resize(1024);
}

SynthAudioStreamPlayback::~SynthAudioStreamPlayback() {
}

void SynthAudioStreamPlayback::set_generator(const Ref<AudioStreamGenerator> &p_generator) {
	generator = p_generator;
}

void SynthAudioStreamPlayback::set_sample_rate(float p_sample_rate) {
	sample_rate = p_sample_rate;
}

// Clock management methods
double SynthAudioStreamPlayback::get_current_time() const {
	return current_time;
}

void SynthAudioStreamPlayback::sync_context_time(const Ref<SynthNoteContext> &context) {
	if (context.is_valid()) {
		context->set_absolute_time(current_time);
	}
}

Ref<SynthVoice> SynthAudioStreamPlayback::get_voice(int64_t voice_id) const {
	if (active_voices.has(voice_id)) {
		return active_voices[voice_id];
	}
	return Ref<SynthVoice>();
}

int SynthAudioStreamPlayback::_mix(AudioFrame *p_buffer, float p_rate_scale, int p_frames) {
	if (active_voices.size() == 0) {
		// Fill with silence
		for (int i = 0; i < p_frames; i++) {
			p_buffer[i] = AudioFrame(); // Default constructor creates a silent frame
		}
		return p_frames;
	}

	// Ensure mix buffer is large enough
	if (mix_buffer.size() < p_frames) {
		mix_buffer.resize(p_frames);
	}

	// Clear the mix buffer
	for (int i = 0; i < p_frames; i++) {
		mix_buffer[i] = 0.0f;
	}

	// Update current time
	float time_per_frame = 1.0 / sample_rate;
	current_time += time_per_frame * p_frames;

	// Process each voice
	Vector<int64_t> finished_voices;

	for (const auto &E : active_voices) {
		int64_t voice_id = E.key;
		Ref<SynthVoice> voice = E.value;

		if (voice.is_valid()) {
			// Process the voice
			PackedFloat32Array voice_buffer = voice->process_block(p_frames, current_time);

			// Mix the voice into the output buffer
			for (int i = 0; i < p_frames && i < voice_buffer.size(); i++) {
				mix_buffer[i] += voice_buffer[i];
			}

			// Check if the voice is completely finished (including tails)
			if (!voice->is_active() && !has_active_tail(voice)) {
				finished_voices.push_back(voice_id);
			}
		}
	}

	// Remove completely finished voices
	for (int i = 0; i < finished_voices.size(); i++) {
		int64_t voice_id = finished_voices[i];
		// Get the voice before erasing it
		Ref<SynthVoice> voice = active_voices[voice_id];
		if (voice.is_valid()) {
			// Clear the context reference in the voice
			voice->clear_context();
		}
		active_voices.erase(voice_id);
		UtilityFunctions::print("Removed finished voice with ID: " + String::num(voice_id));
	}

	// Convert mono mix buffer to stereo output and apply limiting
	for (int i = 0; i < p_frames; i++) {
		float sample = CLAMP(mix_buffer[i], -1.0f, 1.0f);
		p_buffer[i].left = sample;
		p_buffer[i].right = sample;
	}

	return p_frames;
}

bool SynthAudioStreamPlayback::_is_playing() const {
	return active;
}

int SynthAudioStreamPlayback::_get_loop_count() const {
	return 0; // No looping
}

double SynthAudioStreamPlayback::_get_playback_position() const {
	return current_time;
}

void SynthAudioStreamPlayback::_seek(double p_time) {
	current_time = p_time;
}

void SynthAudioStreamPlayback::_start(double p_from_pos) {
	current_time = p_from_pos;
	active = true;
}

void SynthAudioStreamPlayback::_stop() {
	active = false;
	// Release all voices
	release_all_voices();
}

void SynthAudioStreamPlayback::add_voice(int64_t id, const Ref<SynthVoice> &voice) {
	if (!voice.is_valid()) {
		UtilityFunctions::printerr("Cannot add invalid voice");
		return;
	}

	// Sync the voice's context with our current time
	Ref<SynthNoteContext> context = voice->get_current_context();
	if (context.is_valid()) {
		sync_context_time(context);
	}

	// Add the voice to the active voices
	active_voices[id] = voice;
	UtilityFunctions::print("Added voice with ID " + String::num(id) + ", total voices: " +
			String::num(active_voices.size()));

	// If we exceed max polyphony, we might need to remove the oldest voice
	// But only if it doesn't have active delay tails
	if (active_voices.size() > max_polyphony) {
		int64_t oldest_id = 0;
		double oldest_time = std::numeric_limits<double>::max();
		bool found_removable = false;

		// Find the oldest voice without active tails
		for (const auto &E : active_voices) {
			Ref<SynthVoice> current_voice = E.value;
			if (!current_voice->is_active() && !has_active_tail(current_voice)) {
				// We can't directly access SynthNoteContext methods here
				// Just use the voice ID as a proxy for age
				if (E.key < oldest_id || oldest_id == 0) {
					oldest_id = E.key;
					found_removable = true;
				}
			}
		}

		// If we found an eligible voice to remove
		if (found_removable) {
			active_voices.erase(oldest_id);
		}
	}
}

void SynthAudioStreamPlayback::remove_voice(int64_t id) {
	active_voices.erase(id);
}

void SynthAudioStreamPlayback::release_voice(const Ref<SynthVoice> &voice) {
	if (voice.is_valid()) {
	}
}

void SynthAudioStreamPlayback::release_all_voices() {
	for (const auto &E : active_voices) {
		Ref<SynthVoice> voice = E.value;
		if (voice.is_valid() && voice->is_active()) {
		}
	}
}

void SynthAudioStreamPlayback::clear_voices() {
	active_voices.clear();
}

int SynthAudioStreamPlayback::get_active_voice_count() const {
	return active_voices.size();
}

bool SynthAudioStreamPlayback::has_active_tail(const Ref<SynthVoice> &voice) const {
	if (!voice.is_valid()) {
		return false;
	}

	return voice->has_active_tail();
}

} // namespace godot
