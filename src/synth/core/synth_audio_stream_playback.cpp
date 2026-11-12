#include "synth_audio_stream_playback.h"
#include "audio_stream_generator_engine.h"
#include "engine_factory.h"
#include "synth_configuration.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <vector>

namespace godot {

void SynthAudioStreamPlayback::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_sample_rate", "sample_rate"), &SynthAudioStreamPlayback::set_sample_rate);
	ClassDB::bind_method(D_METHOD("get_sample_rate"), &SynthAudioStreamPlayback::get_sample_rate);
	ClassDB::bind_method(D_METHOD("get_mixed_frames"), &SynthAudioStreamPlayback::get_mixed_frames);
	ClassDB::bind_method(D_METHOD("get_late_event_count"), &SynthAudioStreamPlayback::get_late_event_count);
	ClassDB::bind_method(D_METHOD("get_pending_event_count"), &SynthAudioStreamPlayback::get_pending_event_count);
	ClassDB::bind_method(D_METHOD("get_active_voice_count"), &SynthAudioStreamPlayback::get_active_voice_count);
	ClassDB::bind_method(D_METHOD("render_offline", "frames"), &SynthAudioStreamPlayback::render_offline);
	ClassDB::bind_method(D_METHOD("queue_note", "config", "note", "velocity"), &SynthAudioStreamPlayback::queue_note);
	ClassDB::bind_method(D_METHOD("queue_note_at", "config", "note", "velocity", "on_frame", "off_frame"), &SynthAudioStreamPlayback::queue_note_at, DEFVAL(-1));
	ClassDB::bind_method(D_METHOD("queue_note_off", "context"), &SynthAudioStreamPlayback::queue_note_off);
	ClassDB::bind_method(D_METHOD("release_all", "frame"), &SynthAudioStreamPlayback::release_all_voices, DEFVAL(-1));
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "sample_rate"), "set_sample_rate", "get_sample_rate");
}

SynthAudioStreamPlayback::SynthAudioStreamPlayback() {
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

int64_t SynthAudioStreamPlayback::get_mixed_frames() const {
	return mixed_frames.load(std::memory_order_acquire);
}

int64_t SynthAudioStreamPlayback::get_late_event_count() const {
	return late_events.load(std::memory_order_relaxed);
}

int SynthAudioStreamPlayback::get_pending_event_count() const {
	return pending_count_published.load(std::memory_order_relaxed);
}

float SynthAudioStreamPlayback::get_sample_rate() const {
	return sample_rate;
}

// Main thread only. Never call this on a playback the AudioServer is mixing:
// it runs the audio thread's _mix on the calling thread.
PackedVector2Array SynthAudioStreamPlayback::render_offline(int p_frames) {
	PackedVector2Array output;
	ERR_FAIL_COND_V_MSG(p_frames < 0 || p_frames > (1 << 26), output, "SynthAudioStreamPlayback: invalid frame count.");
	if (p_frames == 0) {
		return output;
	}

	// Main thread, so the allocation is fine (the audio thread's buffers are fixed).
	std::vector<AudioFrame> buffer(p_frames);
	_mix(buffer.data(), 1.0f, p_frames);

	output.resize(p_frames);
	Vector2 *dst = output.ptrw();
	for (int i = 0; i < p_frames; i++) {
		dst[i] = Vector2(buffer[i].left, buffer[i].right);
	}
	return output;
}

// Main thread. Builds the same voice/context pair SynthOfflineRenderer does, but
// feeds it through the event queue so _mix itself plays it.
Ref<SynthNoteContext> SynthAudioStreamPlayback::queue_note(const Ref<SynthConfiguration> &p_config, float p_note, float p_velocity) {
	ERR_FAIL_COND_V_MSG(p_config.is_null(), Ref<SynthNoteContext>(), "SynthAudioStreamPlayback: config is null.");

	Ref<AudioStreamGeneratorEngine> engine = EngineFactory::create_engine_from_config(p_config);
	ERR_FAIL_COND_V_MSG(engine.is_null(), Ref<SynthNoteContext>(), "SynthAudioStreamPlayback: the configuration produced no engine.");
	engine->set_sample_rate(sample_rate);

	Ref<SynthVoice> voice;
	voice.instantiate();
	voice->set_engine(engine);
	voice->reserve();

	Ref<SynthNoteContext> context;
	context.instantiate();

	if (!add_voice(voice, context)) {
		return Ref<SynthNoteContext>();
	}

	SynthNoteEvent event;
	event.type = SynthNoteEvent::NOTE_ON;
	event.context = context;
	event.note = p_note;
	event.velocity = p_velocity;
	if (!push_event(event)) {
		return Ref<SynthNoteContext>();
	}

	return context;
}

Ref<SynthNoteContext> SynthAudioStreamPlayback::queue_note_at(const Ref<SynthConfiguration> &p_config, float p_note, float p_velocity, int64_t p_on_frame, int64_t p_off_frame) {
	ERR_FAIL_COND_V_MSG(p_config.is_null(), Ref<SynthNoteContext>(), "SynthAudioStreamPlayback: config is null.");
	ERR_FAIL_COND_V_MSG(p_on_frame < 0, Ref<SynthNoteContext>(), "SynthAudioStreamPlayback: on_frame must be >= 0.");
	ERR_FAIL_COND_V_MSG(p_off_frame >= 0 && p_off_frame < p_on_frame, Ref<SynthNoteContext>(), "SynthAudioStreamPlayback: off_frame is before on_frame.");

	Ref<AudioStreamGeneratorEngine> engine = EngineFactory::create_engine_from_config(p_config);
	ERR_FAIL_COND_V_MSG(engine.is_null(), Ref<SynthNoteContext>(), "SynthAudioStreamPlayback: the configuration produced no engine.");
	engine->set_sample_rate(sample_rate);

	Ref<SynthVoice> voice;
	voice.instantiate();
	voice->set_engine(engine);
	voice->reserve();

	Ref<SynthNoteContext> context;
	context.instantiate();

	if (!add_voice(voice, context, p_on_frame)) {
		return Ref<SynthNoteContext>();
	}

	SynthNoteEvent event;
	event.type = SynthNoteEvent::NOTE_ON;
	event.context = context;
	event.note = p_note;
	event.velocity = p_velocity;
	event.frame = p_on_frame;
	if (!push_event(event)) {
		return Ref<SynthNoteContext>();
	}

	if (p_off_frame >= 0) {
		event.type = SynthNoteEvent::NOTE_OFF;
		event.context = context;
		event.frame = p_off_frame;
		if (!push_event(event)) {
			return Ref<SynthNoteContext>();
		}
	}

	return context;
}

bool SynthAudioStreamPlayback::queue_note_off(const Ref<SynthNoteContext> &p_context) {
	ERR_FAIL_COND_V_MSG(p_context.is_null(), false, "SynthAudioStreamPlayback: context is null.");

	SynthNoteEvent event;
	event.type = SynthNoteEvent::NOTE_OFF;
	event.context = p_context;
	return push_event(event);
}

bool SynthAudioStreamPlayback::queue_gain_ramp(float p_gain, int64_t p_frame, int p_ramp_frames) {
	SynthNoteEvent event;
	event.type = SynthNoteEvent::GAIN_RAMP;
	event.frame = p_frame;
	event.value = p_gain;
	event.ramp_frames = MAX(0, p_ramp_frames);
	return push_event(event);
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

// Audio thread. Applies one event's effect. Master-chain events are handled in
// process_events so the old chain stays in the ring slot for a producer thread
// to release.
void SynthAudioStreamPlayback::apply_event(SynthNoteEvent &p_event) {
	switch (p_event.type) {
		case SynthNoteEvent::START_VOICE:
			start_voice(p_event.voice, p_event.context);
			break;
		case SynthNoteEvent::NOTE_ON:
			if (p_event.context.is_valid()) {
				p_event.context->note_on(p_event.note, p_event.velocity);
			}
			break;
		case SynthNoteEvent::NOTE_OFF:
			if (p_event.context.is_valid()) {
				p_event.context->note_off(p_event.context->get_absolute_time());
			}
			break;
		case SynthNoteEvent::RELEASE_ALL:
			for (int i = 0; i < active_voice_count; i++) {
				if (active_voices[i].is_valid()) {
					Ref<SynthNoteContext> voice_context = active_voices[i]->get_context();
					if (voice_context.is_valid()) {
						voice_context->note_off(voice_context->get_absolute_time());
					}
				}
			}
			break;
		case SynthNoteEvent::SET_PARAMETER:
			if (p_event.parameter.is_valid()) {
				p_event.parameter->set_base_value(p_event.value);
			}
			break;
		case SynthNoteEvent::SET_MASTER_CHAIN:
			// Applied in process_events and never queued as pending.
			break;
		case SynthNoteEvent::GAIN_RAMP: {
			const float target = CLAMP(p_event.value, 0.0f, 4.0f);
			gain_start = gain_current;
			gain_target = target;
			if (p_event.ramp_frames <= 0) {
				gain_current = target;
				ramp_total = 0;
			} else {
				ramp_total = p_event.ramp_frames;
				ramp_pos = 0;
			}
		} break;
	}
}

void SynthAudioStreamPlayback::clear_event(SynthNoteEvent &p_event) {
	p_event.voice.unref();
	p_event.context.unref();
	p_event.parameter.unref();
	p_event.chain.unref();
}

// Audio thread. Drains the ring buffer into the pending array, sorted by frame.
// No allocation and no locking: Ref copies only touch reference counts.
//
// Late rule: frame == -1 or frame == block_start is on time, not late.
// 0 <= frame < block_start is applied at the block start and counted. A full
// pending array drops the event and counts it.
void SynthAudioStreamPlayback::process_events(int64_t p_block_start) {
	uint32_t read = event_read_index.load(std::memory_order_relaxed);
	const uint32_t write = event_write_index.load(std::memory_order_acquire);

	while (read != write) {
		SynthNoteEvent &event = event_queue[read & (EVENT_QUEUE_SIZE - 1)];

		if (event.type == SynthNoteEvent::SET_MASTER_CHAIN) {
			// Leaves the previous chain in event.chain (see SynthNoteEvent::chain),
			// so it is released by the next push into this slot, not on this thread.
			master_bus.swap_chain(event.chain, event.value, sample_rate);
			event.voice.unref();
			event.context.unref();
			event.parameter.unref();
			read++;
			event_read_index.store(read, std::memory_order_release);
			continue;
		}

		int64_t frame = event.frame;
		if (frame >= 0 && frame < p_block_start) {
			late_events.fetch_add(1, std::memory_order_relaxed);
		}
		if (frame < p_block_start) {
			frame = p_block_start;
		}

		if (pending_count >= PENDING_EVENT_CAPACITY) {
			late_events.fetch_add(1, std::memory_order_relaxed);
			clear_event(event);
			read++;
			event_read_index.store(read, std::memory_order_release);
			continue;
		}

		// Stable insertion: equal frames keep their push order.
		int i = pending_count;
		while (i > 0 && pending_events[i - 1].frame > frame) {
			pending_events[i] = pending_events[i - 1];
			i--;
		}
		pending_events[i] = event;
		pending_events[i].frame = frame;
		pending_count++;

		clear_event(event);
		read++;
		event_read_index.store(read, std::memory_order_release);
	}

	pending_count_published.store(pending_count, std::memory_order_release);
}

void SynthAudioStreamPlayback::apply_pending_until(int64_t p_frame) {
	int n = 0;
	while (n < pending_count && pending_events[n].frame <= p_frame) {
		n++;
	}
	if (n == 0) {
		return;
	}

	for (int i = 0; i < n; i++) {
		apply_event(pending_events[i]);
	}

	for (int i = 0; i < pending_count - n; i++) {
		pending_events[i] = pending_events[i + n];
	}
	for (int i = pending_count - n; i < pending_count; i++) {
		clear_event(pending_events[i]);
	}
	pending_count -= n;
	pending_count_published.store(pending_count, std::memory_order_release);
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
	const int64_t block_start = mixed_frames.load(std::memory_order_relaxed);
	process_events(block_start);

	int done = 0;
	while (done < p_frames) {
		const int64_t position = block_start + done;
		apply_pending_until(position);
		int frames = MIN(MIX_CHUNK, p_frames - done);
		if (pending_count > 0) {
			// After apply_pending_until every pending frame is > position, so this is >= 1.
			const int64_t until_next = pending_events[0].frame - position;
			if (until_next < frames) {
				frames = (int)until_next;
			}
		}
		mix_chunk(p_buffer + done, frames);
		done += frames;
	}
	// Every frame this call mixed, silent or not. Kept out of mix_chunk, which
	// returns early on silence.
	mixed_frames.fetch_add(p_frames, std::memory_order_release);
	return p_frames;
}

void SynthAudioStreamPlayback::mix_chunk(AudioFrame *p_buffer, int p_frames) {
	if (active_voice_count == 0 && !master_bus.is_ringing()) {
		// Fill with silence
		for (int i = 0; i < p_frames; i++) {
			p_buffer[i] = AudioFrame(); // Default constructor creates a silent frame
		}
		// A ramp keeps advancing through silence, or a fade-out covering a gap would stall.
		apply_gain(p_buffer, p_frames, true);
		return;
	}

	for (int i = 0; i < p_frames; i++) {
		mono_mix[i] = 0.0f;
	}

	// Update current time
	const double time_per_frame = 1.0 / sample_rate;
	const double start = current_time.load(std::memory_order_relaxed);
	const double now = start + time_per_frame * p_frames;
	current_time.store(now, std::memory_order_relaxed);

	// Process each voice, removing the ones that are completely finished
	const bool voices_playing = active_voice_count > 0;
	int i = 0;
	while (i < active_voice_count) {
		const Ref<SynthVoice> &voice = active_voices[i];

		if (voice.is_valid()) {
			voice->render(voice_buffer, p_frames, now);
			for (int j = 0; j < p_frames; j++) {
				mono_mix[j] += voice_buffer[j];
			}

			// Keep the voice while it is playing or has an effect tail
			if (voice->is_active() || has_active_tail(voice)) {
				i++;
				continue;
			}
		}

		remove_active_voice_at(i);
	}

	// Master effect chain (or a plain copy to both sides), then limiting.
	master_bus.process(mono_mix, out_left, out_right, p_frames, start, time_per_frame, voices_playing);
	for (int j = 0; j < p_frames; j++) {
		p_buffer[j].left = CLAMP(out_left[j], -1.0f, 1.0f);
		p_buffer[j].right = CLAMP(out_right[j], -1.0f, 1.0f);
	}

	apply_gain(p_buffer, p_frames, false);
}

// Audio thread. Applies the output gain after the master bus, so effect tails
// fade with it. Advances a running ramp by the chunk's frame count.
void SynthAudioStreamPlayback::apply_gain(AudioFrame *p_buffer, int p_frames, bool p_silent) {
	if (ramp_total == 0) {
		if (p_silent || gain_current == 1.0f) {
			return;
		}
		for (int j = 0; j < p_frames; j++) {
			p_buffer[j].left *= gain_current;
			p_buffer[j].right *= gain_current;
		}
		return;
	}

	// A ramp is running.
	const double delta = (double)gain_target - (double)gain_start;
	for (int j = 0; j < p_frames; j++) {
		const int pos = ramp_pos + j;
		float g;
		if (pos >= ramp_total) {
			g = gain_target;
		} else {
			g = (float)((double)gain_start + delta * (double)pos / (double)ramp_total);
		}
		if (!p_silent) {
			p_buffer[j].left *= g;
			p_buffer[j].right *= g;
		}
	}
	ramp_pos += p_frames;
	if (ramp_pos >= ramp_total) {
		ramp_total = 0;
		gain_current = gain_target;
	} else {
		gain_current = (float)((double)gain_start + delta * (double)ramp_pos / (double)ramp_total);
	}
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

bool SynthAudioStreamPlayback::add_voice(const Ref<SynthVoice> &p_voice, const Ref<SynthNoteContext> &p_context, int64_t p_frame) {
	if (!p_voice.is_valid()) {
		return false;
	}

	SynthNoteEvent event;
	event.type = SynthNoteEvent::START_VOICE;
	event.voice = p_voice;
	event.context = p_context;
	event.frame = p_frame;
	return push_event(event);
}

bool SynthAudioStreamPlayback::release_all_voices(int64_t p_frame) {
	SynthNoteEvent event;
	event.type = SynthNoteEvent::RELEASE_ALL;
	event.frame = p_frame;
	return push_event(event);
}

bool SynthAudioStreamPlayback::set_master_effect_chain(const Ref<EffectChain> &p_source) {
	SynthNoteEvent event;
	event.type = SynthNoteEvent::SET_MASTER_CHAIN;
	float tail_seconds = 0.0f;
	event.chain = SynthMasterBus::prepare_chain(p_source, sample_rate, tail_seconds);
	event.value = tail_seconds;
	return push_event(event);
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
