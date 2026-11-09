#ifndef SYNTH_OFFLINE_RENDERER_H
#define SYNTH_OFFLINE_RENDERER_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>

namespace godot {

class SynthConfiguration;

/**
 * @brief Renders notes from a SynthConfiguration without the audio server.
 *
 * Builds a voice the same way AudioSynthPlayer does (EngineFactory, SynthVoice,
 * SynthNoteContext) and runs it block by block on the calling thread. The
 * result is deterministic for deterministic configurations, so tests and
 * offline tools can inspect the exact samples a voice produces.
 */
class SynthOfflineRenderer : public RefCounted {
	GDCLASS(SynthOfflineRenderer, RefCounted)

protected:
	static void _bind_methods();

public:
	/**
	 * @brief Renders one note as mono samples.
	 * @param p_config Configuration to build the voice from.
	 * @param p_note MIDI note (fractional notes allowed).
	 * @param p_velocity Velocity (0.0-1.0).
	 * @param p_duration Total length to render, in seconds.
	 * @param p_release_at Time of note_off in seconds; negative holds the note.
	 * @param p_sample_rate Sample rate in Hz.
	 * @param p_block_size Samples per processing block (note_off lands on a block boundary).
	 */
	static PackedFloat32Array render_note(const Ref<SynthConfiguration> &p_config, float p_note, float p_velocity, double p_duration, double p_release_at = -1.0, float p_sample_rate = 44100.0f, int p_block_size = 512);

	/**
	 * @brief Renders one note as stereo frames (x = left, y = right), through
	 * the configuration's master_effect_chain like AudioSynthPlayer does.
	 * Same parameters as render_note(). render_note() leaves the master chain out.
	 */
	static PackedVector2Array render_note_stereo(const Ref<SynthConfiguration> &p_config, float p_note, float p_velocity, double p_duration, double p_release_at = -1.0, float p_sample_rate = 44100.0f, int p_block_size = 512);
};

} // namespace godot

#endif // SYNTH_OFFLINE_RENDERER_H
