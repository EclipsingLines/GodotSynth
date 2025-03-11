#pragma once
#include "../effects/effect_chain.h"
#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>

namespace godot {

class SynthNoteContext;
class ModulatedParameter;

class AudioStreamGeneratorEngine : public Resource {
	GDCLASS(AudioStreamGeneratorEngine, Resource);

protected:
	static void _bind_methods();
	float sample_rate = 44100.0f;
	Dictionary parameters;
	Ref<EffectChain> effect_chain;

public:
	AudioStreamGeneratorEngine();
	virtual ~AudioStreamGeneratorEngine();

	virtual PackedFloat32Array process_block(int buffer_size, const Ref<SynthNoteContext> &context);
	virtual void reset();

	void set_sample_rate(float p_sample_rate);
	float get_sample_rate() const;

	// Parameter management
	virtual void set_parameter(const String &name, const Ref<ModulatedParameter> &param);
	virtual Ref<ModulatedParameter> get_parameter(const String &name) const;
	virtual Dictionary get_parameters() const;
	
	// Create a duplicate of this engine
	virtual Ref<AudioStreamGeneratorEngine> duplicate() const;
	
	// Get the maximum tail length from all effects
	float get_tail_length() const;
	
	// Check if this engine has an active tail
	bool has_active_tail(const Ref<SynthNoteContext> &context) const;

	// Effect chain management
	void set_effect_chain(const Ref<EffectChain> &p_chain);
	Ref<EffectChain> get_effect_chain() const;
};

} // namespace godot
