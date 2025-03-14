#include "synth_audio_stream.h"
#include "synth_voice.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

namespace godot {

void SynthAudioStream::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_mix_rate", "mix_rate"), &SynthAudioStream::set_mix_rate);
	ClassDB::bind_method(D_METHOD("get_mix_rate"), &SynthAudioStream::get_mix_rate);

	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "mix_rate", PROPERTY_HINT_RANGE, "8000,192000,1"), "set_mix_rate", "get_mix_rate");
}

SynthAudioStream::SynthAudioStream() :
		mix_rate(44100.0f) {
}

SynthAudioStream::~SynthAudioStream() {
}

void SynthAudioStream::set_mix_rate(float p_mix_rate) {
	mix_rate = p_mix_rate;
}

float SynthAudioStream::get_mix_rate() const {
	return mix_rate;
}

Ref<AudioStreamPlayback> SynthAudioStream::_instantiate_playback() const {
	Ref<SynthAudioStreamPlayback> playback;
	playback.instantiate();
	playback->set_sample_rate(mix_rate);
	return playback;
}

String SynthAudioStream::_get_stream_name() const {
	return "SynthAudioStream";
}

double SynthAudioStream::_get_length() const {
	return 0.0; // Infinite stream
}

bool SynthAudioStream::_is_monophonic() const {
	return false;
}

} // namespace godot
