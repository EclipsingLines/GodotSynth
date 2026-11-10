#ifndef SYNTH_OFFLINE_MIXER_H
#define SYNTH_OFFLINE_MIXER_H

#include "synth_audio_stream_playback.h"
#include "synth_configuration.h"
#include "synth_voice.h"
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <cstdint>
#include <vector>

namespace godot {

/**
 * @brief Mixes several frame-scheduled tracks without the audio server.
 *
 * Each track owns a SynthAudioStreamPlayback and a fixed voice pool, so the
 * output goes through the same mix path (voices, per-voice effects and master
 * effect chain) as AudioSynthPlayer. Notes are scheduled by absolute frame;
 * the whole schedule is known up front, so a voice is picked from the notes'
 * frames instead of round robin. Both paths steal a voice when the pool is full.
 *
 * Two mixers given the same calls produce bit-identical output. Splitting one
 * long render() into several calls is not guaranteed bit-identical, because the
 * engine's modulation update phase restarts per chunk. Frames are samples at
 * init()'s sample rate. Controls persist on the voice like in AudioSynthPlayer.
 */
class SynthOfflineMixer : public RefCounted {
	GDCLASS(SynthOfflineMixer, RefCounted)

private:
	struct Track {
		Ref<SynthConfiguration> config;
		Ref<SynthAudioStreamPlayback> playback;
		std::vector<Ref<SynthVoice>> voices;
		std::vector<int64_t> busy_until; // per voice: frame the last scheduled note is released at (INT64_MAX = held)
		std::vector<SynthNoteEvent> queue; // events not yet handed to the playback
		size_t queue_head = 0; // queue[0..queue_head) were already pushed
	};

	int sample_rate = 0;
	int64_t mixed_frames = 0;
	int64_t next_voice_id = 1;
	std::vector<Track> tracks;

	void push_due_events(Track &r_track, int64_t p_until_frame);

protected:
	static void _bind_methods();

public:
	bool init(int p_sample_rate);
	int add_track(const Ref<SynthConfiguration> &p_config, int p_polyphony = 16);
	bool schedule_note(int p_track, float p_note, float p_velocity, int64_t p_on_frame, int64_t p_off_frame, const Dictionary &p_controls = Dictionary());
	bool schedule_parameter(int p_track, const String &p_name, float p_value, int64_t p_frame);
	PackedVector2Array render(int p_frames);
	int64_t get_mixed_frames() const;
	int get_track_count() const;
	int64_t get_late_event_count() const; // sum over the tracks' playbacks
};

} // namespace godot

#endif // SYNTH_OFFLINE_MIXER_H
