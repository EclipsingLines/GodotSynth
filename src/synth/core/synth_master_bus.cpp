#include "synth_master_bus.h"

namespace godot {

SynthMasterBus::SynthMasterBus() {
	context.instantiate();
	context->note_on(60.0f, 1.0f);
}

Ref<EffectChain> SynthMasterBus::prepare_chain(const Ref<EffectChain> &p_source, float p_sample_rate, float &r_tail_seconds) {
	r_tail_seconds = 0.0f;
	if (p_source.is_null() || p_source->get_effects().is_empty()) {
		return Ref<EffectChain>();
	}

	Ref<EffectChain> copy = p_source->duplicate();
	copy->set_sample_rate(p_sample_rate);
	copy->prepare_stereo();

	// Run one silent frame and the tail query here, on the main thread, so
	// the effects' first parameter lookups (which allocate once) don't happen
	// on the audio thread. Then clear any state that frame left behind.
	Ref<SynthNoteContext> warmup;
	warmup.instantiate();
	warmup->note_on(60.0f, 1.0f);
	float left = 0.0f;
	float right = 0.0f;
	copy->process_stereo(left, right, warmup);
	r_tail_seconds = copy->get_max_tail_length();
	copy->reset();

	return copy;
}

void SynthMasterBus::swap_chain(Ref<EffectChain> &p_chain, float p_tail_seconds, float p_sample_rate) {
	Ref<EffectChain> previous = chain;
	chain = p_chain;
	p_chain = previous;
	tail_frames = (int64_t)(MAX(0.0f, p_tail_seconds) * p_sample_rate);
	tail_frames_left = 0;
}

bool SynthMasterBus::has_chain() const {
	return chain.is_valid();
}

bool SynthMasterBus::is_ringing() const {
	return chain.is_valid() && tail_frames_left > 0;
}

void SynthMasterBus::process(const float *p_mono, float *r_left, float *r_right, int p_frames, double p_start_time, double p_seconds_per_frame, bool p_voices_playing) {
	if (chain.is_null()) {
		for (int i = 0; i < p_frames; i++) {
			r_left[i] = p_mono[i];
			r_right[i] = p_mono[i];
		}
		return;
	}

	EffectChain *fx = chain.ptr();
	SynthNoteContext *ctx = context.ptr();
	double time = p_start_time;
	for (int i = 0; i < p_frames; i++) {
		ctx->update_time(time);
		float left = p_mono[i];
		float right = p_mono[i];
		fx->process_stereo(left, right, context);
		r_left[i] = left;
		r_right[i] = right;
		time += p_seconds_per_frame;
	}

	if (p_voices_playing) {
		tail_frames_left = tail_frames;
	} else {
		tail_frames_left = MAX((int64_t)0, tail_frames_left - p_frames);
	}
}

} // namespace godot
