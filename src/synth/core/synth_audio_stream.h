#pragma once
#include <godot_cpp/classes/audio_stream.hpp>
#include <godot_cpp/classes/audio_stream_playback.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include "synth_note_context.h" // Add this include
#include "synth_audio_stream_playback.h" // Include the standalone header

namespace godot {

class SynthVoice;
class SynthConfiguration;

class SynthAudioStream : public AudioStream {
    GDCLASS(SynthAudioStream, AudioStream);

private:
    float mix_rate;

protected:
    static void _bind_methods();

public:
    SynthAudioStream();
    ~SynthAudioStream();

    void set_mix_rate(float p_mix_rate);
    float get_mix_rate() const;

    // AudioStream implementation
    virtual Ref<AudioStreamPlayback> _instantiate_playback() const override;
    virtual String _get_stream_name() const override;
    virtual double _get_length() const override;
    virtual bool _is_monophonic() const override;
};

} // namespace godot
