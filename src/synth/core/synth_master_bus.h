#ifndef SYNTH_MASTER_BUS_H
#define SYNTH_MASTER_BUS_H

#include "../effects/effect_chain.h"
#include "synth_note_context.h"

namespace godot {

/**
 * @brief Runs a configuration's master effect chain on the mix of all voices.
 *
 * Plain C++ helper (not a Godot class), shared by SynthAudioStreamPlayback
 * and SynthOfflineRenderer so both use the same code. The chain is a private
 * copy made by prepare_chain() on the main thread; process() runs on the
 * audio thread and doesn't allocate.
 */
class SynthMasterBus {
	Ref<EffectChain> chain;
	// Context the master effects read their modulation from. Its note is
	// held forever (an ADSR sits at sustain, LFOs run on absolute time).
	Ref<SynthNoteContext> context;
	int64_t tail_frames = 0;
	int64_t tail_frames_left = 0;

public:
	SynthMasterBus();

	// Main thread: returns a playable stereo copy of p_source for this
	// sample rate (allocates), or null if p_source is null or empty. Writes
	// the chain's tail length in seconds to r_tail_seconds.
	static Ref<EffectChain> prepare_chain(const Ref<EffectChain> &p_source, float p_sample_rate, float &r_tail_seconds);

	// Audio thread: installs p_chain (from prepare_chain) and hands the
	// previous chain back through p_chain, so the caller can release it
	// somewhere other than the audio thread.
	void swap_chain(Ref<EffectChain> &p_chain, float p_tail_seconds, float p_sample_rate);

	bool has_chain() const;

	// True while the chain still has a tail to play after the voices stopped.
	bool is_ringing() const;

	// Audio thread: mono voice mix in, stereo out. p_voices_playing restarts
	// the tail countdown.
	void process(const float *p_mono, float *r_left, float *r_right, int p_frames, double p_start_time, double p_seconds_per_frame, bool p_voices_playing);
};

} // namespace godot

#endif // SYNTH_MASTER_BUS_H
