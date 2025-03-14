#include "note_duration_mod_source.h"
#include "../../core/synth_note_context.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

namespace godot {

void NoteDurationModSource::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_attack_time", "time"), &NoteDurationModSource::set_attack_time);
	ClassDB::bind_method(D_METHOD("get_attack_time"), &NoteDurationModSource::get_attack_time);

	ClassDB::bind_method(D_METHOD("set_max_time", "time"), &NoteDurationModSource::set_max_time);
	ClassDB::bind_method(D_METHOD("get_max_time"), &NoteDurationModSource::get_max_time);

	ClassDB::bind_method(D_METHOD("set_min_value", "min"), &NoteDurationModSource::set_min_value);
	ClassDB::bind_method(D_METHOD("get_min_value"), &NoteDurationModSource::get_min_value);

	ClassDB::bind_method(D_METHOD("set_max_value", "max"), &NoteDurationModSource::set_max_value);
	ClassDB::bind_method(D_METHOD("get_max_value"), &NoteDurationModSource::get_max_value);

	ClassDB::bind_method(D_METHOD("set_invert", "invert"), &NoteDurationModSource::set_invert);
	ClassDB::bind_method(D_METHOD("get_invert"), &NoteDurationModSource::get_invert);

	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "attack_time"), "set_attack_time", "get_attack_time");
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "max_time"), "set_max_time", "get_max_time");
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "min_value"), "set_min_value", "get_min_value");
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "max_value"), "set_max_value", "get_max_value");
	ADD_PROPERTY(PropertyInfo(Variant::BOOL, "invert"), "set_invert", "get_invert");
}

NoteDurationModSource::NoteDurationModSource() {
	attack_time = 0.1f; // 100ms initial attack time
	max_time = 5.0f; // 5 seconds to reach max value
	min_value = 0.0f;
	max_value = 1.0f;
	invert = false;
}

NoteDurationModSource::~NoteDurationModSource() {
}

float NoteDurationModSource::get_value(const Ref<SynthNoteContext> &context) const {
	if (context.is_null()) {
		return 0.0f;
	}

	// Get the note time from the context
	double note_time = context->get_note_time();

	// Check if this is a new note trigger
	if (context->get_is_note_triggered()) {
		// Reset any internal state if needed
	}

	// Calculate normalized time position
	float normalized_time;

	if (note_time < attack_time) {
		// During attack phase
		normalized_time = note_time / attack_time;
	} else {
		// After attack phase
		float remaining_time = max_time - attack_time;
		if (remaining_time <= 0.0f) {
			normalized_time = 1.0f;
		} else {
			normalized_time = attack_time / max_time +
					((note_time - attack_time) / remaining_time) * (1.0f - attack_time / max_time);
		}
	}

	// Clamp to 0.0-1.0 range
	normalized_time = normalized_time > 1.0f ? 1.0f : normalized_time;

	// Invert if needed
	if (invert) {
		normalized_time = 1.0f - normalized_time;
	}

	// Map to output range
	return min_value + normalized_time * (max_value - min_value);
}

void NoteDurationModSource::reset() {
	// Nothing to reset for note duration (stateless)
}

void NoteDurationModSource::set_attack_time(float p_time) {
	attack_time = p_time > 0.0f ? p_time : 0.001f; // Ensure positive time
}

float NoteDurationModSource::get_attack_time() const {
	return attack_time;
}

void NoteDurationModSource::set_max_time(float p_time) {
	max_time = p_time > attack_time ? p_time : attack_time; // Ensure max_time >= attack_time
}

float NoteDurationModSource::get_max_time() const {
	return max_time;
}

void NoteDurationModSource::set_min_value(float p_min) {
	min_value = p_min;
}

float NoteDurationModSource::get_min_value() const {
	return min_value;
}

void NoteDurationModSource::set_max_value(float p_max) {
	max_value = p_max;
}

float NoteDurationModSource::get_max_value() const {
	return max_value;
}

void NoteDurationModSource::set_invert(bool p_invert) {
	invert = p_invert;
}

bool NoteDurationModSource::get_invert() const {
	return invert;
}

Ref<ModulationSource> NoteDurationModSource::duplicate() const {
	Ref<NoteDurationModSource> dup = memnew(NoteDurationModSource);
	dup->set_attack_time(attack_time);
	dup->set_max_time(max_time);
	dup->set_min_value(min_value);
	dup->set_max_value(max_value);
	dup->set_invert(invert);
	return dup;
}

} // namespace godot
