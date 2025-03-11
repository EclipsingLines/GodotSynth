#pragma once
#include "synth_note_context.h" // Include the full definition instead of forward declaration
#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>

namespace godot {

class AudioStreamGeneratorEngine;

class SynthVoice : public Resource {
	GDCLASS(SynthVoice, Resource);

private:
	bool active;
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

	void reset() {
		active = false;
		if (context.is_valid()) {
			context->reset();
		}
	}

	PackedFloat32Array process_block(int buffer_size, double p_time);
};

} // namespace godot
