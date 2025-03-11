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

	// Helper methods for voice pool
	void initialize_voice_pool();
	Ref<SynthVoice> allocate_voice();

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
	void stop_all_notes();

	void set_parameter(const String &p_name, float p_value);
};

} // namespace godot
