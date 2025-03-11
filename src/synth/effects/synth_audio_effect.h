#ifndef AUDIO_EFFECT_H
#define AUDIO_EFFECT_H

#include "../core/modulated_parameter.h"
#include "../core/synth_note_context.h"
#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>

namespace godot {

class SynthAudioEffect : public Resource {
	GDCLASS(SynthAudioEffect, Resource)

protected:
	// Assuming you have a container for parameters, for example:
	Dictionary parameters;

public:
	// Add this declaration:
	void add_parameter(const String &p_name, const Ref<ModulatedParameter> &p_param);
	static void _bind_methods();

public:
	SynthAudioEffect();
	virtual ~SynthAudioEffect();

	virtual float process_sample(float sample, const Ref<SynthNoteContext> &context);
	virtual void reset();

	// Returns the tail length in seconds (how long the effect continues after input stops)
	virtual float get_tail_length() const;

	// Create a duplicate of this effect with the same parameters
	virtual Ref<SynthAudioEffect> duplicate() const;

	void set_parameter(const String &name, const Ref<ModulatedParameter> &param);
	Ref<ModulatedParameter> get_parameter(const String &name) const;
	Dictionary get_parameters() const;
};

} // namespace godot

#endif // AUDIO_EFFECT_H
