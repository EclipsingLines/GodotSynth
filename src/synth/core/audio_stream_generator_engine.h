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

	virtual PackedFloat32Array process_block(int buffer_size, const Ref<SynthNoteContext> &context, const bool &use_fast_pitch = true);

	// Audio thread: writes `frames` samples into `out`. This is what the mixer
	// calls. Engines should override it and not allocate. The default calls
	// process_block() and copies, which allocates, for engines that only
	// implement process_block().
	virtual void render(float *out, int frames, const Ref<SynthNoteContext> &context, bool use_fast_pitch);
	virtual void reset();

	void set_sample_rate(float p_sample_rate);
	float get_sample_rate() const;

	// Parameter management
	virtual void set_parameter(const String &name, const Ref<ModulatedParameter> &param);
	virtual Ref<ModulatedParameter> get_parameter(const String &name) const;
	virtual Dictionary get_parameters() const;

	// "fx<i>.<param>" -> parameter <param> of effect i of `p_chain`; invalid Ref if the name is not
	// of that form, i is out of range or the effect has no such parameter. Main thread only.
	static Ref<ModulatedParameter> resolve_effect_parameter(const Ref<EffectChain> &p_chain, const String &p_name);
	// Splits "fx<i>.<param>": returns true and fills r_index/r_param when p_name has the form
	// "fx" + 1..3 ASCII digits + "." + a non-empty parameter name. No other form matches
	// ("fx.cutoff", "fx0", "fx0.", "fxa.x", "fx1234.x", "FX0.cutoff" all return false).
	static bool parse_effect_name(const String &p_name, int &r_index, String &r_param);
	// get_parameter(p_name), and when that finds nothing and p_name is "fx<i>.<param>", the
	// effect parameter of this engine's own effect chain. THE lookup for controls and
	// schedule_parameter; do not call get_parameter(name) directly for user-supplied names.
	Ref<ModulatedParameter> resolve_parameter(const String &p_name) const;

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
