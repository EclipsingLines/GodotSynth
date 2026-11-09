#include "synth_offline_renderer.h"
#include "audio_stream_generator_engine.h"
#include "engine_factory.h"
#include "synth_configuration.h"
#include "synth_note_context.h"
#include "synth_voice.h"
#include <godot_cpp/core/class_db.hpp>

namespace godot {

void SynthOfflineRenderer::_bind_methods() {
	ClassDB::bind_static_method("SynthOfflineRenderer",
			D_METHOD("render_note", "config", "note", "velocity", "duration", "release_at", "sample_rate", "block_size"),
			&SynthOfflineRenderer::render_note, DEFVAL(-1.0), DEFVAL(44100.0f), DEFVAL(512));
}

PackedFloat32Array SynthOfflineRenderer::render_note(const Ref<SynthConfiguration> &p_config, float p_note, float p_velocity, double p_duration, double p_release_at, float p_sample_rate, int p_block_size) {
	PackedFloat32Array output;
	ERR_FAIL_COND_V_MSG(p_config.is_null(), output, "SynthOfflineRenderer: config is null.");
	ERR_FAIL_COND_V_MSG(p_sample_rate <= 0.0f, output, "SynthOfflineRenderer: sample_rate must be positive.");
	ERR_FAIL_COND_V_MSG(p_block_size <= 0, output, "SynthOfflineRenderer: block_size must be positive.");
	ERR_FAIL_COND_V_MSG(p_duration <= 0.0, output, "SynthOfflineRenderer: duration must be positive.");

	Ref<AudioStreamGeneratorEngine> engine = EngineFactory::create_engine_from_config(p_config);
	ERR_FAIL_COND_V_MSG(engine.is_null(), output, "SynthOfflineRenderer: the configuration produced no engine.");
	engine->set_sample_rate(p_sample_rate);

	Ref<SynthVoice> voice;
	voice.instantiate();
	voice->set_engine(engine);

	Ref<SynthNoteContext> context;
	context.instantiate();
	voice->start(context);
	context->note_on(p_note, p_velocity);

	const int64_t total = (int64_t)(p_duration * (double)p_sample_rate);
	output.resize(total);
	float *dst = output.ptrw();

	const double seconds_per_sample = 1.0 / (double)p_sample_rate;
	bool released = false;
	int64_t written = 0;
	while (written < total) {
		const int frames = (int)MIN((int64_t)p_block_size, total - written);
		const double block_start = (double)written * seconds_per_sample;

		if (!released && p_release_at >= 0.0 && block_start >= p_release_at) {
			context->note_off(context->get_absolute_time());
			released = true;
		}

		PackedFloat32Array block = voice->process_block(frames, block_start);
		const float *src = block.ptr();
		const int count = MIN(frames, (int)block.size());
		for (int i = 0; i < count; i++) {
			dst[written + i] = src[i];
		}
		for (int i = count; i < frames; i++) {
			dst[written + i] = 0.0f;
		}
		written += frames;
	}

	return output;
}

} // namespace godot
