#ifndef SYNTH_AUDIO_STREAM_PLAYBACK_H
#define SYNTH_AUDIO_STREAM_PLAYBACK_H

#include "synth_note_context.h" // Add this include
#include "synth_voice.h"
#include <godot_cpp/classes/audio_stream_generator.hpp>
#include <godot_cpp/classes/audio_stream_playback.hpp>
#include <godot_cpp/templates/hash_map.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/typed_array.hpp>

namespace godot {

class SynthAudioStreamPlayback : public AudioStreamPlayback {
	GDCLASS(SynthAudioStreamPlayback, AudioStreamPlayback)

private:
	Ref<AudioStreamGenerator> generator;
	HashMap<int64_t, Ref<SynthVoice>> active_voices;
	double current_time = 0.0;
	int max_polyphony = 16;
	PackedFloat32Array mix_buffer;
	float sample_rate = 44100.0f;
	bool active = false;

	// Helper function to check if a voice has active delay tails
	bool has_active_tail(const Ref<SynthVoice> &voice) const;

protected:
	static void _bind_methods();

public:
	SynthAudioStreamPlayback();
	~SynthAudioStreamPlayback();

	void set_generator(const Ref<AudioStreamGenerator> &p_generator);
	void set_sample_rate(float p_sample_rate);
	
	// Clock management
	double get_current_time() const;
	void sync_context_time(const Ref<SynthNoteContext> &context);
	Ref<SynthVoice> get_voice(int64_t voice_id) const;

	// AudioStreamPlayback implementation
	virtual void _start(double p_from_pos = 0.0) override;
	virtual void _stop() override;
	virtual bool _is_playing() const override;
	virtual int _get_loop_count() const;
	virtual double _get_playback_position() const override;
	virtual void _seek(double p_time) override;
	virtual int _mix(AudioFrame *p_buffer, float p_rate_scale, int p_frames) override;

	// Voice management
	void add_voice(int64_t id, const Ref<SynthVoice> &voice);
	void remove_voice(int64_t id);
	void release_voice(const Ref<SynthVoice> &voice);
	void release_all_voices();
	void clear_voices();
	int get_active_voice_count() const;
};

} // namespace godot

#endif // SYNTH_AUDIO_STREAM_PLAYBACK_H
