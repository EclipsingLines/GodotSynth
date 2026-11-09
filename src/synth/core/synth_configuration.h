#pragma once
#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/variant/dictionary.hpp>

namespace godot {

class ModulatedParameter;
class AudioStreamGeneratorEngine;
class EffectChain;

class SynthConfiguration : public Resource {
	GDCLASS(SynthConfiguration, Resource);

private:
	Dictionary parameters;
	Ref<EffectChain> effect_chain;
	String output_bus = "Master";
	int mod_update_rate = 8; // Default to 8 - controls how often modulation values are updated

protected:
	static void _bind_methods();
	void _validate_property(PropertyInfo &property) const;

public:
	SynthConfiguration();
	~SynthConfiguration();

	void set_parameter(const String &p_name, const Ref<ModulatedParameter> &p_param);
	Ref<ModulatedParameter> get_parameter(const String &p_name) const;
	Dictionary get_parameters() const;

	void set_effect_chain(const Ref<EffectChain> &p_chain);
	Ref<EffectChain> get_effect_chain() const;

	void set_output_bus(const String &p_bus);
	String get_output_bus() const;

	void set_mod_update_rate(int p_rate);
	int get_mod_update_rate() const;

	virtual Ref<AudioStreamGeneratorEngine> create_engine() const;
};

} // namespace godot
