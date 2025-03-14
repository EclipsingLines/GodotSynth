#include "modulated_parameter.h"
#include "modulation_source.h"
#include "synth_note_context.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

namespace godot {

// Register the ModulationType enum with Godot

ModulatedParameter::ModulatedParameter() {
}

ModulatedParameter::~ModulatedParameter() {
}

void ModulatedParameter::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_base_value", "value"), &ModulatedParameter::set_base_value);
	ClassDB::bind_method(D_METHOD("get_base_value"), &ModulatedParameter::get_base_value);

	ClassDB::bind_method(D_METHOD("set_mod_amount", "amount"), &ModulatedParameter::set_mod_amount);
	ClassDB::bind_method(D_METHOD("get_mod_amount"), &ModulatedParameter::get_mod_amount);

	ClassDB::bind_method(D_METHOD("set_mod_min", "min"), &ModulatedParameter::set_mod_min);
	ClassDB::bind_method(D_METHOD("get_mod_min"), &ModulatedParameter::get_mod_min);

	ClassDB::bind_method(D_METHOD("set_mod_max", "max"), &ModulatedParameter::set_mod_max);
	ClassDB::bind_method(D_METHOD("get_mod_max"), &ModulatedParameter::get_mod_max);

	ClassDB::bind_method(D_METHOD("set_mod_source", "source"), &ModulatedParameter::set_mod_source);
	ClassDB::bind_method(D_METHOD("get_mod_source"), &ModulatedParameter::get_mod_source);

	ClassDB::bind_method(D_METHOD("set_mod_type", "type"), &ModulatedParameter::set_mod_type);
	ClassDB::bind_method(D_METHOD("get_mod_type"), &ModulatedParameter::get_mod_type);

	ClassDB::bind_method(D_METHOD("set_invert_mod", "invert"), &ModulatedParameter::set_invert_mod);
	ClassDB::bind_method(D_METHOD("get_invert_mod"), &ModulatedParameter::get_invert_mod);

	ClassDB::bind_method(D_METHOD("get_value", "context"), &ModulatedParameter::get_value);
	ClassDB::bind_method(D_METHOD("duplicate"), &ModulatedParameter::duplicate);

	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "base_value"), "set_base_value", "get_base_value");
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "modulation/mod_amount"), "set_mod_amount", "get_mod_amount");
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "modulation/mod_min"), "set_mod_min", "get_mod_min");
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "modulation/mod_max"), "set_mod_max", "get_mod_max");
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "modulation/mod_source", PROPERTY_HINT_RESOURCE_TYPE, "ModulationSource"), "set_mod_source", "get_mod_source");
	ADD_PROPERTY(PropertyInfo(Variant::INT, "modulation/mod_type", PROPERTY_HINT_ENUM, "Additive,Multiplicative,Absolute,Gate"), "set_mod_type", "get_mod_type");
	ADD_PROPERTY(PropertyInfo(Variant::BOOL, "invert_mod"), "set_invert_mod", "get_invert_mod");
}

void ModulatedParameter::set_base_value(float p_value) {
	base_value = p_value;
	emit_changed();
}

float ModulatedParameter::get_base_value() const {
	return base_value;
}

void ModulatedParameter::set_mod_amount(float p_amount) {
	mod_amount = p_amount;
}

float ModulatedParameter::get_mod_amount() const {
	return mod_amount;
}

void ModulatedParameter::set_mod_min(float p_min) {
	mod_min = p_min;
}

float ModulatedParameter::get_mod_min() const {
	return mod_min;
}

void ModulatedParameter::set_mod_max(float p_max) {
	mod_max = p_max;
}

float ModulatedParameter::get_mod_max() const {
	return mod_max;
}

void ModulatedParameter::set_mod_source(const Ref<ModulationSource> &p_source) {
	mod_source = p_source;
}

Ref<ModulationSource> ModulatedParameter::get_mod_source() const {
	return mod_source;
}

void ModulatedParameter::set_mod_type(ModulationType p_type) {
	mod_type = p_type;
}

ModulationType ModulatedParameter::get_mod_type() const {
	return mod_type;
}

void ModulatedParameter::set_invert_mod(bool p_invert) {
	invert_mod = p_invert;
}

bool ModulatedParameter::get_invert_mod() const {
	return invert_mod;
}

float ModulatedParameter::get_value(const Ref<SynthNoteContext> &context) const {
	float value = base_value;
	// Debug base value
	if (get_mod_source().is_valid() && context.is_valid()) {
		float mod_value = get_mod_source()->get_value(context);

		// Apply inversion if needed
		if (invert_mod) {
			mod_value = 1.0f - mod_value;
		}

		// Apply modulation based on selected type
		switch (mod_type) {
			case MODULATION_ADDITIVE:
				value += mod_value * mod_amount;
				break;
			case MODULATION_MULTIPLICATIVE:
				value *= 1.0f + (mod_value * mod_amount);
				break;
			case MODULATION_ABSOLUTE:
				value = mod_value * mod_amount;
				break;
			case MODULATION_GATE:
				value = (mod_value > 0.5f) ? base_value + mod_amount : base_value;
				break;
		}
	}

	return Math::clamp(value, mod_min, mod_max);
}

Ref<ModulatedParameter> ModulatedParameter::duplicate() const {
	Ref<ModulatedParameter> new_param = memnew(ModulatedParameter);

	// Copy all properties
	new_param->set_base_value(base_value);
	new_param->set_mod_amount(mod_amount);
	new_param->set_mod_min(mod_min);
	new_param->set_mod_max(mod_max);
	new_param->set_mod_type(mod_type);
	new_param->set_invert_mod(invert_mod);

	// Copy the modulation source if it exists
	if (mod_source.is_valid()) {
		new_param->set_mod_source(mod_source->duplicate());
	}

	return new_param;
}

} // namespace godot

VARIANT_ENUM_CAST(ModulationType);
