#include "velocity_mod_source.h"
#include "../../core/synth_note_context.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

namespace godot {

void VelocityModSource::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_min_value", "min"), &VelocityModSource::set_min_value);
	ClassDB::bind_method(D_METHOD("get_min_value"), &VelocityModSource::get_min_value);
	
	ClassDB::bind_method(D_METHOD("set_max_value", "max"), &VelocityModSource::set_max_value);
	ClassDB::bind_method(D_METHOD("get_max_value"), &VelocityModSource::get_max_value);
	
	ClassDB::bind_method(D_METHOD("set_bipolar", "bipolar"), &VelocityModSource::set_bipolar);
	ClassDB::bind_method(D_METHOD("get_bipolar"), &VelocityModSource::get_bipolar);

	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "min_value"), "set_min_value", "get_min_value");
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "max_value"), "set_max_value", "get_max_value");
	ADD_PROPERTY(PropertyInfo(Variant::BOOL, "bipolar"), "set_bipolar", "get_bipolar");
}

VelocityModSource::VelocityModSource() {
	min_value = 0.0f;
	max_value = 1.0f;
	bipolar = false;
}

VelocityModSource::~VelocityModSource() {
}

float VelocityModSource::get_value(const Ref<SynthNoteContext> &context) const {
	if (context.is_null()) {
		return 0.0f;
	}

	// Get the velocity from the context (0.0 to 1.0)
	float velocity = context->get_velocity();
	
	// Map velocity to our range
	float value;
	if (bipolar) {
		// For bipolar, map 0.5 velocity to 0.0 output
		// 0.0 velocity -> min_value, 1.0 velocity -> max_value
		if (velocity <= 0.5f) {
			// Map 0.0-0.5 to min_value-0.0
			value = min_value + (0.0f - min_value) * (velocity / 0.5f);
		} else {
			// Map 0.5-1.0 to 0.0-max_value
			value = (max_value) * ((velocity - 0.5f) / 0.5f);
		}
	} else {
		// Simple linear mapping for unipolar
		value = min_value + (max_value - min_value) * velocity;
	}
	
	return value;
}

void VelocityModSource::reset() {
	// Nothing to reset for velocity (stateless)
}

void VelocityModSource::set_min_value(float p_min) {
	min_value = p_min;
}

float VelocityModSource::get_min_value() const {
	return min_value;
}

void VelocityModSource::set_max_value(float p_max) {
	max_value = p_max;
}

float VelocityModSource::get_max_value() const {
	return max_value;
}

void VelocityModSource::set_bipolar(bool p_bipolar) {
	bipolar = p_bipolar;
}

bool VelocityModSource::get_bipolar() const {
	return bipolar;
}

Ref<ModulationSource> VelocityModSource::duplicate() const {
	Ref<VelocityModSource> dup = memnew(VelocityModSource);
	dup->set_min_value(min_value);
	dup->set_max_value(max_value);
	dup->set_bipolar(bipolar);
	return dup;
}

} // namespace godot
