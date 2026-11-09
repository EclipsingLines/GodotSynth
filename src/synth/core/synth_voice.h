#pragma once
#include "synth_note_context.h" // Include the full definition instead of forward declaration
#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <atomic>

namespace godot {

class AudioStreamGeneratorEngine;

class SynthVoice : public Resource {
	GDCLASS(SynthVoice, Resource);

private:
	// Written by the main thread (reserve) and the audio thread (start/finish).
	std::atomic<bool> active{ false };
	bool fast = false;
	Ref<AudioStreamGeneratorEngine> engine;
	Ref<SynthNoteContext> context;

protected:
	static void _bind_methods();

public:
	SynthVoice();
	~SynthVoice();

	void set_engine(const Ref<AudioStreamGeneratorEngine> &p_engine);
	Ref<AudioStreamGeneratorEngine> get_engine() const;
	bool is_active() const;
	bool is_finished() const;

	// Check if the voice has an active delay tail
	bool has_active_tail() const;

	Ref<SynthNoteContext> get_context() {
		// Create a fresh context if needed
		if (context.is_null()) {
			context.instantiate();
		} else {
			// Reset the existing context
			context->reset();
		}
		active = true;
		return context;
	}

	// Get the context without resetting it
	Ref<SynthNoteContext> get_current_context() const {
		return context;
	}

	// Clear the context reference
	void clear_context() {
		context.unref();
	}

	// Main thread: mark the voice as taken so the allocator skips it until the
	// audio thread starts it (see SynthAudioStreamPlayback::start_voice).
	void reserve() {
		active = true;
	}

	// Audio thread: attach a new note context and make the voice audible.
	void start(const Ref<SynthNoteContext> &p_context) {
		// If the voice was stolen, its previous note is cut off: mark it
		// finished so callers waiting on is_note_finished() are not stuck.
		if (context.is_valid() && context != p_context) {
			context->set_note_state(SynthNoteContext::NOTE_STATE_FINISHED);
		}
		context = p_context;
		active = true;
	}

	void reset() {
		active = false;
		if (context.is_valid()) {
			context->reset();
		}
	}

	PackedFloat32Array process_block(int buffer_size, double p_time);
};

} // namespace godot
