#include "synth_voice.h"
#include "../effects/effect_chain.h"
#include "../effects/synth_audio_effect.h"
#include "audio_stream_generator_engine.h"
#include "modulated_parameter.h"
#include "modulation_source.h"
#include "synth_note_context.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

namespace godot {

void SynthVoice::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_engine", "engine"), &SynthVoice::set_engine);
	ClassDB::bind_method(D_METHOD("get_engine"), &SynthVoice::get_engine);

	ClassDB::bind_method(D_METHOD("is_active"), &SynthVoice::is_active);
	ClassDB::bind_method(D_METHOD("is_finished"), &SynthVoice::is_finished);
	ClassDB::bind_method(D_METHOD("has_active_tail"), &SynthVoice::has_active_tail);
	ClassDB::bind_method(D_METHOD("get_context"), &SynthVoice::get_context);
	ClassDB::bind_method(D_METHOD("get_current_context"), &SynthVoice::get_current_context);
	ClassDB::bind_method(D_METHOD("clear_context"), &SynthVoice::clear_context);

	ClassDB::bind_method(D_METHOD("process_block", "buffer", "time"), &SynthVoice::process_block);

	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "engine", PROPERTY_HINT_RESOURCE_TYPE, "AudioStreamGeneratorEngine"), "set_engine", "get_engine");
}

SynthVoice::SynthVoice() :
		active(false) {
	context.instantiate();
}

SynthVoice::~SynthVoice() {
}

void SynthVoice::set_engine(const Ref<AudioStreamGeneratorEngine> &p_engine) {
	engine = p_engine;
}

Ref<AudioStreamGeneratorEngine> SynthVoice::get_engine() const {
	return engine;
}

bool SynthVoice::is_active() const {
	return active;
}

bool SynthVoice::is_finished() const {
	if (!active) {
		return true;
	}

	if (!context.is_valid()) {
		return false;
	}

	// Simply check if the note is in FINISHED state
	return context->is_note_finished();
}

bool SynthVoice::has_active_tail() const {
	if (active || !context.is_valid()) {
		return false;
	}

	if (engine.is_valid()) {
		return engine->has_active_tail(context);
	}

	return false;
}

PackedFloat32Array SynthVoice::process_block(int buffer_size, double p_time) {
	PackedFloat32Array output_buffer;
	if (!active || !engine.is_valid() || !context.is_valid()) {
		// Return empty buffer if voice is not active
		output_buffer.resize(buffer_size);
		for (int i = 0; i < buffer_size; i++) {
			output_buffer[i] = 0.0f;
		}
		return output_buffer;
	}

	// Check for active tails and update context
	bool has_tail = false;
	if (engine.is_valid()) {
		has_tail = engine->has_active_tail(context);
	}
	context->set_has_active_tail(has_tail);

	// Process audio through the engine and get the output buffer
	output_buffer = engine->process_block(buffer_size, context);

	// Check if we should deactivate the voice
	if (context->is_note_finished()) {
		active = false;
	}

	return output_buffer;
}

} // namespace godot
