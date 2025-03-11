#include "keyboard_tracking_mod_source.h"
#include "../../core/synth_note_context.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

namespace godot {

void KeyboardTrackingModSource::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_center_note", "note"), &KeyboardTrackingModSource::set_center_note);
	ClassDB::bind_method(D_METHOD("get_center_note"), &KeyboardTrackingModSource::get_center_note);
	
	ClassDB::bind_method(D_METHOD("set_note_range", "range"), &KeyboardTrackingModSource::set_note_range);
	ClassDB::bind_method(D_METHOD("get_note_range"), &KeyboardTrackingModSource::get_note_range);
	
	ClassDB::bind_method(D_METHOD("set_min_value", "min"), &KeyboardTrackingModSource::set_min_value);
	ClassDB::bind_method(D_METHOD("get_min_value"), &KeyboardTrackingModSource::get_min_value);
	
	ClassDB::bind_method(D_METHOD("set_max_value", "max"), &KeyboardTrackingModSource::set_max_value);
	ClassDB::bind_method(D_METHOD("get_max_value"), &KeyboardTrackingModSource::get_max_value);

	ADD_PROPERTY(PropertyInfo(Variant::INT, "center_note"), "set_center_note", "get_center_note");
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "note_range"), "set_note_range", "get_note_range");
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "min_value"), "set_min_value", "get_min_value");
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "max_value"), "set_max_value", "get_max_value");
}

KeyboardTrackingModSource::KeyboardTrackingModSource() {
	center_note = 60; // Middle C
	note_range = 24.0f; // Two octaves
	min_value = 0.0f;
	max_value = 1.0f;
}

KeyboardTrackingModSource::~KeyboardTrackingModSource() {
}

float KeyboardTrackingModSource::get_value(const Ref<SynthNoteContext> &context) const {
	if (context.is_null()) {
		return 0.0f;
	}

	// Get the MIDI note number from the context
	int note = context->get_note();
	
	// Calculate the normalized position relative to center note
	float normalized_position = (note - center_note) / note_range;
	
	// Clamp to -1.0 to 1.0 range
	normalized_position = normalized_position < -1.0f ? -1.0f : (normalized_position > 1.0f ? 1.0f : normalized_position);
	
	// Map to output range
	// For notes below center, map -1.0-0.0 to min_value-center_value
	// For notes above center, map 0.0-1.0 to center_value-max_value
	float center_value = (min_value + max_value) * 0.5f;
	
	if (normalized_position < 0.0f) {
		return center_value + normalized_position * (center_value - min_value);
	} else {
		return center_value + normalized_position * (max_value - center_value);
	}
}

void KeyboardTrackingModSource::reset() {
	// Nothing to reset for keyboard tracking (stateless)
}

void KeyboardTrackingModSource::set_center_note(int p_note) {
	center_note = p_note;
}

int KeyboardTrackingModSource::get_center_note() const {
	return center_note;
}

void KeyboardTrackingModSource::set_note_range(float p_range) {
	note_range = p_range > 0.0f ? p_range : 1.0f; // Ensure positive range
}

float KeyboardTrackingModSource::get_note_range() const {
	return note_range;
}

void KeyboardTrackingModSource::set_min_value(float p_min) {
	min_value = p_min;
}

float KeyboardTrackingModSource::get_min_value() const {
	return min_value;
}

void KeyboardTrackingModSource::set_max_value(float p_max) {
	max_value = p_max;
}

float KeyboardTrackingModSource::get_max_value() const {
	return max_value;
}

Ref<ModulationSource> KeyboardTrackingModSource::duplicate() const {
	Ref<KeyboardTrackingModSource> dup = memnew(KeyboardTrackingModSource);
	dup->set_center_note(center_note);
	dup->set_note_range(note_range);
	dup->set_min_value(min_value);
	dup->set_max_value(max_value);
	return dup;
}

} // namespace godot
