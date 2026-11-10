#pragma once
#include "synth_audio_stream.h"
#include "synth_audio_stream_playback.h" // Add this include
#include "synth_note_context.h"
#include <godot_cpp/classes/audio_stream_player.hpp>

namespace godot {

class SynthConfiguration;
class SynthVoice;
class SynthPreset;

class AudioSynthPlayer : public AudioStreamPlayer {
	GDCLASS(AudioSynthPlayer, AudioStreamPlayer);

private:
	Ref<SynthConfiguration> configuration;
	Ref<SynthAudioStream> stream;
	Ref<SynthAudioStreamPlayback> playback;
	float sample_rate;

	// Voice pool management
	int polyphony = 8; // Default polyphony
	Vector<Ref<SynthVoice>> voice_pool;
	int next_voice_index = 0; // For round-robin allocation
	int64_t next_voice_id = 1; // Unique, monotonically increasing note/voice id

	// Helper methods for voice pool
	void initialize_voice_pool();
	Ref<SynthVoice> allocate_voice();
	bool ensure_playback();
	// Sends the configuration's master effect chain (or none) to the playback.
	// Called whenever the playback or the configuration changes.
	void sync_master_chain();
	// Takes a new playback from the stream after (re)starting it.
	void acquire_playback();
	// Allocates a voice and builds a context for a note (everything get_context()
	// did before queueing the START_VOICE event).
	Ref<SynthNoteContext> prepare_note(Ref<SynthVoice> &r_voice);
	bool queue_context_event(const Ref<SynthNoteContext> &p_context, int p_type, float p_note, float p_velocity);

protected:
	static void _bind_methods();

public:
	AudioSynthPlayer();
	~AudioSynthPlayer();

	void _ready() override;
	virtual void _process(double delta) override;

	void set_configuration(const Ref<SynthConfiguration> &p_config);
	Ref<SynthConfiguration> get_configuration() const;

	// Polyphony management
	void set_polyphony(int p_polyphony);
	int get_polyphony() const;

	Ref<SynthNoteContext> get_context();

	// Frames the player's playback has mixed (the audio clock). 0 until the playback exists.
	int64_t get_mixed_frames() const;
	// Allocates a voice now (round robin / stealing at schedule time) and queues, in this order:
	// START_VOICE at p_on_frame, one SET_PARAMETER at p_on_frame per entry of p_controls,
	// NOTE_ON at p_on_frame, and NOTE_OFF at p_off_frame when p_off_frame >= 0.
	// p_controls maps parameter name (String) to value (int or float). Returns null on error.
	// The voice is reserved from this call until the note ends, and a per-note control stays on
	// that voice for later notes until it is overwritten: send a control with every note.
	Ref<SynthNoteContext> schedule_note(int p_note, float p_velocity, int64_t p_on_frame, int64_t p_off_frame, const Dictionary &p_controls = Dictionary());
	// Queues a SET_PARAMETER at p_frame for the parameter p_name on every pooled voice engine.
	// Unlike set_parameter() it does not change the configuration's base value.
	void schedule_parameter(const String &p_name, float p_value, int64_t p_frame);
	// Stops and restarts the stream and re-acquires the new playback, so a caller can restart
	// several players inside one AudioServer.lock()/unlock() and have their counters equal.
	void restart_stream();

	void play_note_on_context(const Ref<SynthNoteContext> &p_context, float p_note, float p_velocity);
	void play_note_off_context(const Ref<SynthNoteContext> &p_context);
	void stop_all_notes();

	void set_parameter(const String &p_name, float p_value);
};

} // namespace godot
