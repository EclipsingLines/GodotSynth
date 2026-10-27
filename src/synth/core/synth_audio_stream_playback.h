#ifndef SYNTH_AUDIO_STREAM_PLAYBACK_H
#define SYNTH_AUDIO_STREAM_PLAYBACK_H

#include "synth_note_context.h" // Add this include
#include "synth_voice.h"
#include <godot_cpp/classes/audio_stream_generator.hpp>
#include <godot_cpp/classes/audio_stream_playback.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/typed_array.hpp>
#include <atomic>
#include <mutex>

namespace godot {

/**
 * @brief A note event handed from the main thread to the audio thread.
 *
 * Events are pushed by AudioSynthPlayer (main thread) and applied by
 * SynthAudioStreamPlayback::_mix (audio thread) at the start of the next
 * mixed block, in the order they were pushed.
 *
 * `frame` is reserved for sample-accurate scheduling (issue #2). It is the
 * absolute mixer frame at which the event should take effect; a negative
 * value means "at the start of the next block". Only -1 is used today. To add
 * scheduling, the drain step would keep events whose frame lies beyond the
 * current block and split the block at the frames of the events it applies.
 */
struct SynthNoteEvent {
	enum Type {
		START_VOICE, ///< Attach `context` to `voice` and add the voice to the mix.
		NOTE_ON, ///< Call context->note_on(note, velocity).
		NOTE_OFF, ///< Call context->note_off(context->get_absolute_time()).
	};

	Type type = START_VOICE;
	int64_t frame = -1;
	Ref<SynthVoice> voice;
	Ref<SynthNoteContext> context;
	float note = 0.0f;
	float velocity = 0.0f;
};

class SynthAudioStreamPlayback : public AudioStreamPlayback {
	GDCLASS(SynthAudioStreamPlayback, AudioStreamPlayback)

public:
	static const int MAX_ACTIVE_VOICES = 64;
	static const int EVENT_QUEUE_SIZE = 1024; // Must be a power of two.

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

	std::atomic<double> current_time{ 0.0 };
	PackedFloat32Array mix_buffer;
	float sample_rate = 44100.0f;
	bool active = false;

	// Helper function to check if a voice has active delay tails
	bool has_active_tail(const Ref<SynthVoice> &voice) const;

	// Audio thread helpers
	void process_events();
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
	bool add_voice(const Ref<SynthVoice> &p_voice, const Ref<SynthNoteContext> &p_context);
	void release_all_voices();
	int get_active_voice_count() const;
};

} // namespace godot

#endif // SYNTH_AUDIO_STREAM_PLAYBACK_H
