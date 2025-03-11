#pragma once
#include "modulation_source.h"
#include "synth_note_context.h"
#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/variant/variant.hpp>

namespace godot {

// Enum for modulation types
enum ModulationType {
	MODULATION_ADDITIVE,
	MODULATION_MULTIPLICATIVE,
	MODULATION_ABSOLUTE,
	MODULATION_GATE
};

class ModulatedParameter : public Resource {
	GDCLASS(ModulatedParameter, Resource);

private:
	float base_value = 0.0f;
	float mod_amount = 0.0f;
	float mod_min = 0.0f;
	float mod_max = 1.0f;
	Ref<ModulationSource> mod_source;
	ModulationType mod_type = MODULATION_ADDITIVE;
	bool invert_mod = false;

protected:
	static void _bind_methods();

public:
	ModulatedParameter();
	~ModulatedParameter();

	void set_base_value(float p_value);
	float get_base_value() const;

	void set_mod_amount(float p_amount);
	float get_mod_amount() const;

	void set_mod_min(float p_min);
	float get_mod_min() const;

	void set_mod_max(float p_max);
	float get_mod_max() const;

	void set_mod_source(const Ref<ModulationSource> &p_source);
	Ref<ModulationSource> get_mod_source() const;

	void set_mod_type(ModulationType p_type);
	ModulationType get_mod_type() const;

	void set_invert_mod(bool p_invert);
	bool get_invert_mod() const;

	float get_value(const Ref<SynthNoteContext> &context) const;

	// Creates a deep copy of this modulated parameter
	Ref<ModulatedParameter> duplicate() const;
};

} // namespace godot
