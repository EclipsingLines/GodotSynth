#include "articulation_mod_source.h"
#include "../../core/synth_note_context.h"
#include <godot_cpp/core/class_db.hpp>

namespace godot {

void ArticulationModSource::_bind_methods() {
	ClassDB::bind_method(D_METHOD("get_value", "context"), &ArticulationModSource::get_value);

	ClassDB::bind_method(D_METHOD("set_min_value", "min"), &ArticulationModSource::set_min_value);
	ClassDB::bind_method(D_METHOD("get_min_value"), &ArticulationModSource::get_min_value);

	ClassDB::bind_method(D_METHOD("set_max_value", "max"), &ArticulationModSource::set_max_value);
	ClassDB::bind_method(D_METHOD("get_max_value"), &ArticulationModSource::get_max_value);

	ClassDB::bind_method(D_METHOD("set_bipolar", "bipolar"), &ArticulationModSource::set_bipolar);
	ClassDB::bind_method(D_METHOD("get_bipolar"), &ArticulationModSource::get_bipolar);

	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "min_value"), "set_min_value", "get_min_value");
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "max_value"), "set_max_value", "get_max_value");
	ADD_PROPERTY(PropertyInfo(Variant::BOOL, "bipolar"), "set_bipolar", "get_bipolar");
}
void ArticulationModSource::reset() {
	// Nothing to reset for velocity (stateless)
}

ArticulationModSource::ArticulationModSource() {
	min_value = 0.0f;
	max_value = 1.0f;
	bipolar = false;
}
ArticulationModSource::~ArticulationModSource() {
}

float ArticulationModSource::get_value(const Ref<SynthNoteContext> &context) const {
	ERR_FAIL_COND_V(context.is_null(), 1.0f);
	return context->get_articulation();
}

void ArticulationModSource::set_min_value(float p_min) {
	min_value = p_min;
}

float ArticulationModSource::get_min_value() const {
	return min_value;
}

void ArticulationModSource::set_max_value(float p_max) {
	max_value = p_max;
}

float ArticulationModSource::get_max_value() const {
	return max_value;
}

void ArticulationModSource::set_bipolar(bool p_bipolar) {
	bipolar = p_bipolar;
}

bool ArticulationModSource::get_bipolar() const {
	return bipolar;
}

Ref<ModulationSource> ArticulationModSource::duplicate() const {
	Ref<ArticulationModSource> dup = memnew(ArticulationModSource);
	dup->set_min_value(min_value);
	dup->set_max_value(max_value);
	dup->set_bipolar(bipolar);
	return dup;
}
} //namespace godot