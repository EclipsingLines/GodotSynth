#ifndef SYNTH_AUDIO_STREAM_PLAYBACK_H
#define SYNTH_AUDIO_STREAM_PLAYBACK_H

#include "../effects/effect_chain.h"
#include "modulated_parameter.h"
#include "synth_master_bus.h"
#include "synth_note_context.h"
#include "synth_voice.h"
#include <godot_cpp/classes/audio_stream_generator.hpp>
#include <godot_cpp/classes/audio_stream_playback.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/typed_array.hpp>
#include <atomic>
#include <mutex>

namespace godot {

class SynthConfiguration;

/**
 * @brief A note event handed from the main thread to the audio thread.
 *
 * Events are pushed by AudioSynthPlayer (main thread) and applied by
 * SynthAudioStreamPlayback::_mix (audio thread), in the order they were pushed.
 *
 * `frame` is the absolute mixer frame (the `mixed_frames` scale) at which the
 * event takes effect. An event stamped mid-block is applied exactly on that
 * frame; -1 means "at the start of the next block".
 */
struct SynthNoteEvent {
	enum Type {
		START_VOICE, ///< Attach `context` to `voice` and add the voice to the mix.
		NOTE_ON, ///< Call context->note_on(note, velocity).
		NOTE_OFF, ///< Call context->note_off(context->get_absolute_time()).
		RELEASE_ALL, ///< Call note_off on the context of every voice in the mix.
		SET_PARAMETER, ///< Call parameter->set_base_value(value).
		SET_MASTER_CHAIN, ///< Install `chain` as the master chain (`value` = its tail in seconds).
	};

	Type type = START_VOICE;
	int64_t frame = -1;
	Ref<SynthVoice> voice;
	Ref<SynthNoteContext> context;
	Ref<ModulatedParameter> parameter;
	// SET_MASTER_CHAIN: the new chain going in. The audio thread leaves the
	// previous chain in this slot, so it's released by the next push into the
	// slot (on a producer thread), not on the audio thread.
	Ref<EffectChain> chain;
	float note = 0.0f;
	float velocity = 0.0f;
	float value = 0.0f;
};

class SynthAudioStreamPlayback : public AudioStreamPlayback {
	GDCLASS(SynthAudioStreamPlayback, AudioStreamPlayback)

public:
	static const int MAX_ACTIVE_VOICES = 64;
	static const int EVENT_QUEUE_SIZE = 1024; // Must be a power of two.
	static const int PENDING_EVENT_CAPACITY = 2048;
	// _mix renders in chunks of at most this many frames into fixed buffers,
	// so it never allocates whatever block size the mixer asks for.
	static const int MIX_CHUNK = 512;

private:
	Ref<AudioStreamGenerator> generator;

	// Voices currently being mixed. Owned by the audio thread only: the main
	// thread never touches this list, it pushes START_VOICE events instead.
	// Kept in start order (index 0 is the oldest), fixed size, no allocation.
	Ref<SynthVoice> active_voices[MAX_ACTIVE_VOICES];
	int active_voice_count = 0;

	// Note event ring buffer. Multiple producers (serialised by
	// `producer_mutex`, never taken on the audio thread), single lock-free
	// consumer (the audio thread in _mix).
	SynthNoteEvent event_queue[EVENT_QUEUE_SIZE];
	std::atomic<uint32_t> event_write_index{ 0 };
	std::atomic<uint32_t> event_read_index{ 0 };
	std::mutex producer_mutex;

	// Events whose frame is still ahead, sorted by frame ascending, stable for equal frames.
	// Audio thread only. Fixed size: nothing allocates.
	SynthNoteEvent pending_events[PENDING_EVENT_CAPACITY];
	int pending_count = 0;
	std::atomic<int64_t> late_events{ 0 };
	std::atomic<int> pending_count_published{ 0 }; // copy of pending_count for the main thread

	std::atomic<double> current_time{ 0.0 };
	// Frames mixed so far, advanced by every _mix call whether or not anything is playing.
	std::atomic<int64_t> mixed_frames{ 0 };
	float sample_rate = 44100.0f;
	bool active = false;

	// Audio thread scratch buffers (see MIX_CHUNK).
	float voice_buffer[MIX_CHUNK];
	float mono_mix[MIX_CHUNK];
	float out_left[MIX_CHUNK];
	float out_right[MIX_CHUNK];

	// Master effect chain on the mix (audio thread; installed by events).
	SynthMasterBus master_bus;

	// Renders one chunk (frames <= MIX_CHUNK) into p_buffer.
	void mix_chunk(AudioFrame *p_buffer, int p_frames);

	// Helper function to check if a voice has active delay tails
	bool has_active_tail(const Ref<SynthVoice> &voice) const;

	// Audio thread helpers
	void process_events(int64_t p_block_start);
	void apply_event(SynthNoteEvent &p_event);
	void apply_pending_until(int64_t p_frame);
	static void clear_event(SynthNoteEvent &p_event);
	void start_voice(const Ref<SynthVoice> &p_voice, const Ref<SynthNoteContext> &p_context);
	void remove_active_voice_at(int p_index);

protected:
	static void _bind_methods();

public:
	SynthAudioStreamPlayback();
	~SynthAudioStreamPlayback();

	void set_generator(const Ref<AudioStreamGenerator> &p_generator);
	void set_sample_rate(float p_sample_rate);

	// Clock management
	double get_current_time() const;
	int64_t get_mixed_frames() const;
	int64_t get_late_event_count() const;
	int get_pending_event_count() const;
	float get_sample_rate() const;

	// Mixes p_frames on the calling thread. Only for a playback that is NOT registered with
	// the AudioServer (one made with SynthAudioStreamPlayback.new()): it calls _mix directly.
	PackedVector2Array render_offline(int p_frames);
	// Test/offline helper: builds a voice and context from p_config (see Context), queues
	// START_VOICE then NOTE_ON (frame -1) and returns the context, or null on failure.
	Ref<SynthNoteContext> queue_note(const Ref<SynthConfiguration> &p_config, float p_note, float p_velocity);
	// Builds a voice/context like queue_note() and queues START_VOICE and NOTE_ON at p_on_frame,
	// then NOTE_OFF at p_off_frame when p_off_frame >= 0. GS-003 builds the player API on the same events.
	Ref<SynthNoteContext> queue_note_at(const Ref<SynthConfiguration> &p_config, float p_note, float p_velocity, int64_t p_on_frame, int64_t p_off_frame = -1);
	// Queues NOTE_OFF (frame -1) for p_context. Returns false if the queue is full or p_context is null.
	bool queue_note_off(const Ref<SynthNoteContext> &p_context);

	// AudioStreamPlayback implementation
	virtual void _start(double p_from_pos = 0.0) override;
	virtual void _stop() override;
	virtual bool _is_playing() const override;
	virtual int _get_loop_count() const;
	virtual double _get_playback_position() const override;
	virtual void _seek(double p_time) override;
	virtual int _mix(AudioFrame *p_buffer, float p_rate_scale, int p_frames) override;

	// Event queue (main thread side). Returns false if the queue is full.
	bool push_event(const SynthNoteEvent &p_event);

	// Voice management (main thread side, queued)
	bool add_voice(const Ref<SynthVoice> &p_voice, const Ref<SynthNoteContext> &p_context, int64_t p_frame = -1);
	// Queues a note_off for every voice in the mix (they ring out through their
	// release). Returns false if the queue is full.
	bool release_all_voices(int64_t p_frame = -1);
	// Main thread: queues a new master effect chain (a private copy of
	// p_source; null or empty removes it). Returns false if the queue is full.
	bool set_master_effect_chain(const Ref<EffectChain> &p_source);
	int get_active_voice_count() const;
};

} // namespace godot

#endif // SYNTH_AUDIO_STREAM_PLAYBACK_H
