#include "synth_audio_stream_playback.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

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
	return current_time.load(std::memory_order_relaxed);
}

// ---------------------------------------------------------------------------
// Event queue
// ---------------------------------------------------------------------------

bool SynthAudioStreamPlayback::push_event(const SynthNoteEvent &p_event) {
	// Producers are serialised so the queue is safe to use from any
	// non-audio thread. The audio thread never takes this lock.
	std::lock_guard<std::mutex> lock(producer_mutex);

	const uint32_t write = event_write_index.load(std::memory_order_relaxed);
	const uint32_t read = event_read_index.load(std::memory_order_acquire);
	if (write - read >= (uint32_t)EVENT_QUEUE_SIZE) {
		return false; // Full: the audio thread is not draining (stream stopped?)
	}

	event_queue[write & (EVENT_QUEUE_SIZE - 1)] = p_event;
	event_write_index.store(write + 1, std::memory_order_release);
	return true;
}

// Audio thread. Applies every queued event in FIFO order. No allocation and no
// locking: Ref copies only touch reference counts.
void SynthAudioStreamPlayback::process_events() {
	uint32_t read = event_read_index.load(std::memory_order_relaxed);
	const uint32_t write = event_write_index.load(std::memory_order_acquire);

	while (read != write) {
		SynthNoteEvent &event = event_queue[read & (EVENT_QUEUE_SIZE - 1)];

		switch (event.type) {
			case SynthNoteEvent::START_VOICE:
				start_voice(event.voice, event.context);
				break;
			case SynthNoteEvent::NOTE_ON:
				if (event.context.is_valid()) {
					event.context->note_on(event.note, event.velocity);
				}
				break;
			case SynthNoteEvent::NOTE_OFF:
				if (event.context.is_valid()) {
					event.context->note_off(event.context->get_absolute_time());
				}
				break;
		}

		// Drop the slot's references so the slot holds nothing between uses.
		event.voice.unref();
		event.context.unref();

		read++;
		event_read_index.store(read, std::memory_order_release);
	}
}

void SynthAudioStreamPlayback::start_voice(const Ref<SynthVoice> &p_voice, const Ref<SynthNoteContext> &p_context) {
	if (!p_voice.is_valid()) {
		return;
	}

	p_voice->start(p_context);

	// The voice may already be in the mix (stolen voice, or a voice still
	// ringing out). Never add it twice, or it would be processed twice per block.
	for (int i = 0; i < active_voice_count; i++) {
		if (active_voices[i] == p_voice) {
			// Move it to the end so it counts as the newest voice.
			remove_active_voice_at(i);
			break;
		}
	}

	if (active_voice_count >= MAX_ACTIVE_VOICES) {
		// Out of mix slots: drop the oldest voice.
		remove_active_voice_at(0);
	}

	active_voices[active_voice_count++] = p_voice;
}

void SynthAudioStreamPlayback::remove_active_voice_at(int p_index) {
	for (int i = p_index; i < active_voice_count - 1; i++) {
		active_voices[i] = active_voices[i + 1];
	}
	active_voice_count--;
	active_voices[active_voice_count].unref();
}

int SynthAudioStreamPlayback::_mix(AudioFrame *p_buffer, float p_rate_scale, int p_frames) {
	// Apply note events queued by the main thread since the last block.
	process_events();

	if (active_voice_count == 0) {
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
	float *mix = mix_buffer.ptrw();
	for (int i = 0; i < p_frames; i++) {
		mix[i] = 0.0f;
	}

	// Update current time
	double time_per_frame = 1.0 / sample_rate;
	double now = current_time.load(std::memory_order_relaxed) + time_per_frame * p_frames;
	current_time.store(now, std::memory_order_relaxed);

	// Process each voice, removing the ones that are completely finished
	int i = 0;
	while (i < active_voice_count) {
		const Ref<SynthVoice> &voice = active_voices[i];

		if (voice.is_valid()) {
			// Process the voice
			PackedFloat32Array voice_buffer = voice->process_block(p_frames, now);

			// Mix the voice into the output buffer
			const float *src = voice_buffer.ptr();
			const int count = MIN(p_frames, (int)voice_buffer.size());
			for (int j = 0; j < count; j++) {
				mix[j] += src[j];
			}

			// Keep the voice while it is playing or has an effect tail
			if (voice->is_active() || has_active_tail(voice)) {
				i++;
				continue;
			}
		}

		remove_active_voice_at(i);
	}

	// Convert mono mix buffer to stereo output and apply limiting
	for (int j = 0; j < p_frames; j++) {
		float sample = CLAMP(mix[j], -1.0f, 1.0f);
		p_buffer[j].left = sample;
		p_buffer[j].right = sample;
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
	return get_current_time();
}

void SynthAudioStreamPlayback::_seek(double p_time) {
	current_time.store(p_time, std::memory_order_relaxed);
}

void SynthAudioStreamPlayback::_start(double p_from_pos) {
	current_time.store(p_from_pos, std::memory_order_relaxed);
	active = true;
}

void SynthAudioStreamPlayback::_stop() {
	active = false;
	// Release all voices
	release_all_voices();
}

bool SynthAudioStreamPlayback::add_voice(const Ref<SynthVoice> &p_voice, const Ref<SynthNoteContext> &p_context) {
	if (!p_voice.is_valid()) {
		return false;
	}

	SynthNoteEvent event;
	event.type = SynthNoteEvent::START_VOICE;
	event.voice = p_voice;
	event.context = p_context;
	return push_event(event);
}

void SynthAudioStreamPlayback::release_all_voices() {
	// Not implemented yet (unchanged behaviour): voices finish on their own.
}

int SynthAudioStreamPlayback::get_active_voice_count() const {
	return active_voice_count;
}

bool SynthAudioStreamPlayback::has_active_tail(const Ref<SynthVoice> &voice) const {
	if (!voice.is_valid()) {
		return false;
	}

	return voice->has_active_tail();
}

} // namespace godot
