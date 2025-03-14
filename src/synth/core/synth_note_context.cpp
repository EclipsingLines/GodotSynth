#include "synth_note_context.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

namespace godot {

/**
 * Constructor for SynthNoteContext.
 * Initializes a new note context in the READY state.
 */
SynthNoteContext::SynthNoteContext() {
	is_note_triggered = false;
	note_state = NOTE_STATE_READY;
	has_active_tail = false;
}

/**
 * Destructor for SynthNoteContext.
 */
SynthNoteContext::~SynthNoteContext() {
}

void SynthNoteContext::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_absolute_time", "time"), &SynthNoteContext::set_absolute_time);
	ClassDB::bind_method(D_METHOD("get_absolute_time"), &SynthNoteContext::get_absolute_time);

	ClassDB::bind_method(D_METHOD("set_note_time", "time"), &SynthNoteContext::set_note_time);
	ClassDB::bind_method(D_METHOD("get_note_time"), &SynthNoteContext::get_note_time);

	ClassDB::bind_method(D_METHOD("set_note", "note"), &SynthNoteContext::set_note);
	ClassDB::bind_method(D_METHOD("get_note"), &SynthNoteContext::get_note);

	ClassDB::bind_method(D_METHOD("set_velocity", "velocity"), &SynthNoteContext::set_velocity);
	ClassDB::bind_method(D_METHOD("get_velocity"), &SynthNoteContext::get_velocity);

	ClassDB::bind_method(D_METHOD("set_note_active", "on"), &SynthNoteContext::set_note_active);
	ClassDB::bind_method(D_METHOD("is_note_on"), &SynthNoteContext::get_is_note_on);
	ClassDB::bind_method(D_METHOD("is_note_triggered"), &SynthNoteContext::get_is_note_triggered);

	ClassDB::bind_method(D_METHOD("set_note_on_time", "time"), &SynthNoteContext::set_note_on_time);
	ClassDB::bind_method(D_METHOD("get_note_on_time"), &SynthNoteContext::get_note_on_time);

	ClassDB::bind_method(D_METHOD("set_note_off_time", "time"), &SynthNoteContext::set_note_off_time);
	ClassDB::bind_method(D_METHOD("get_note_off_time"), &SynthNoteContext::get_note_off_time);

	ClassDB::bind_method(D_METHOD("note_on", "note", "velocity"), &SynthNoteContext::note_on);
	ClassDB::bind_method(D_METHOD("note_off", "note_off_time"), &SynthNoteContext::note_off);
	ClassDB::bind_method(D_METHOD("update_time", "absolute_time"), &SynthNoteContext::update_time);

	// New release state methods
	ClassDB::bind_method(D_METHOD("start_release", "time"), &SynthNoteContext::start_release);
	ClassDB::bind_method(D_METHOD("update_amplitude", "amplitude"), &SynthNoteContext::update_amplitude);
	ClassDB::bind_method(D_METHOD("is_releasing"), &SynthNoteContext::is_releasing);
	ClassDB::bind_method(D_METHOD("is_fully_released"), &SynthNoteContext::is_fully_released);
	ClassDB::bind_method(D_METHOD("reset_release_state"), &SynthNoteContext::reset_release_state);

	// State management methods
	ClassDB::bind_method(D_METHOD("set_note_state", "state"), &SynthNoteContext::set_note_state);
	ClassDB::bind_method(D_METHOD("get_note_state"), &SynthNoteContext::get_note_state);
	ClassDB::bind_method(D_METHOD("get_note_state_name"), &SynthNoteContext::get_note_state_name);
	ClassDB::bind_method(D_METHOD("is_note_ready"), &SynthNoteContext::is_note_ready);
	ClassDB::bind_method(D_METHOD("is_note_active_state"), &SynthNoteContext::is_note_active_state);
	ClassDB::bind_method(D_METHOD("is_note_releasing"), &SynthNoteContext::is_note_releasing);
	ClassDB::bind_method(D_METHOD("is_note_released"), &SynthNoteContext::is_note_released);
	ClassDB::bind_method(D_METHOD("is_note_finished"), &SynthNoteContext::is_note_finished);
	ClassDB::bind_method(D_METHOD("set_has_active_tail", "has_tail"), &SynthNoteContext::set_has_active_tail);
	ClassDB::bind_method(D_METHOD("get_has_active_tail"), &SynthNoteContext::get_has_active_tail);

	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "absolute_time"), "set_absolute_time", "get_absolute_time");
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "note_time"), "set_note_time", "get_note_time");
	ADD_PROPERTY(PropertyInfo(Variant::INT, "note"), "set_note", "get_note");
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "velocity"), "set_velocity", "get_velocity");
	ADD_PROPERTY(PropertyInfo(Variant::BOOL, "note_active"), "set_note_active", "is_note_on");
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "note_on_time"), "set_note_on_time", "get_note_on_time");
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "note_off_time"), "set_note_off_time", "get_note_off_time");
}

void SynthNoteContext::set_voice_id(const int64_t p_voice_id) {
	voice_id = p_voice_id;
}
int64_t SynthNoteContext::get_voice_id() const {
	return voice_id;
}

void SynthNoteContext::set_absolute_time(double p_time) {
	absolute_time = p_time;
}

double SynthNoteContext::get_absolute_time() const {
	return absolute_time;
}

void SynthNoteContext::set_release_level(float p_release_level) {
	release_level = p_release_level;
}

float SynthNoteContext::get_release_level() const {
	return release_level;
}

void SynthNoteContext::set_note_time(double p_time) {
	note_time = p_time;
}

double SynthNoteContext::get_note_time() const {
	return note_time;
}

void SynthNoteContext::set_note(int p_note) {
	note = p_note;
}

int SynthNoteContext::get_note() const {
	return note;
}

void SynthNoteContext::set_velocity(float p_velocity) {
	velocity = p_velocity;
}

float SynthNoteContext::get_velocity() const {
	return velocity;
}

void SynthNoteContext::set_note_active(bool p_on) {
	is_note_active = p_on;
}

bool SynthNoteContext::get_is_note_on() const {
	return is_note_active;
}

bool SynthNoteContext::get_is_note_triggered() const {
	return is_note_triggered;
}

void SynthNoteContext::set_note_on_time(double p_time) {
	note_on_time = p_time;
}

double SynthNoteContext::get_note_on_time() const {
	return note_on_time;
}

void SynthNoteContext::set_note_off_time(double p_time) {
	note_off_time = p_time;
}

double SynthNoteContext::get_note_off_time() const {
	return note_off_time;
}

void SynthNoteContext::note_on(int p_note, float p_velocity) {
	reset();
	note = p_note;
	velocity = p_velocity;
	is_note_active = true;
	is_note_triggered = true;
	note_on_time = absolute_time; // Set note_on_time to current absolute_time
	note_off_time = 0.0; // Clear any previous note_off_time

	// Reset release state
	reset_release_state();

	// Set state to ACTIVE
	set_note_state(NOTE_STATE_ACTIVE);
}

void SynthNoteContext::note_off(float p_time) {
	if (!is_note_active) {
		// Already off, nothing to do
		return;
	}

	start_release(p_time);
}

void SynthNoteContext::update_time(double p_absolute_time) {
	absolute_time = p_absolute_time;
	if (note_on_time >= 0.0) {
		note_time = absolute_time - note_on_time;
	}

	// Reset the note_triggered flag after one update cycle
	// This ensures it's only true for the first processing cycle after note_on
	if (is_note_triggered) {
		is_note_triggered = false;
	}

	// Handle state transitions based on current state
	switch (note_state) {
		case NOTE_STATE_READY:
			// Nothing to do in READY state
			break;

		case NOTE_STATE_ACTIVE:
			// Nothing to do in ACTIVE state
			break;

		case NOTE_STATE_RELEASING:
			// Check if fully released
			if (_is_fully_released) {
				set_note_state(NOTE_STATE_RELEASED);
			}
			break;

		case NOTE_STATE_RELEASED:
			// Check if all tails are done
			if (!has_active_tail) {
				set_note_state(NOTE_STATE_FINISHED);
			}
			break;

		case NOTE_STATE_FINISHED:
			// Nothing to do in FINISHED state
			break;
	}

	// Additional time-based checks for safety
	if (note_state == NOTE_STATE_RELEASING) {
		double time_since_note_off = absolute_time - note_off_time;

		// Force transition to RELEASED if it's been too long (5 seconds)
		if (time_since_note_off > 5.0) {
			_is_fully_released = true;
			set_note_state(NOTE_STATE_RELEASED);
		}
	}
}

// New release state methods
void SynthNoteContext::start_release(double p_time) {
	note_off_time = p_time;
	is_note_active = false;
	_is_releasing = true;
	_is_fully_released = false;
	release_level = current_amplitude; // Capture current amplitude as release level

	// Set state to RELEASING
	set_note_state(NOTE_STATE_RELEASING);
}

float SynthNoteContext::get_amplitude() const {
	return current_amplitude;
}

void SynthNoteContext::update_amplitude(float amplitude) {
	current_amplitude = amplitude;

	// If we're releasing and amplitude has fallen below threshold, mark as fully released
	if (_is_releasing && current_amplitude < release_threshold) {
		_is_fully_released = true;
	}
}

bool SynthNoteContext::is_releasing() const {
	return _is_releasing;
}

bool SynthNoteContext::is_fully_released() const {
	return _is_fully_released;
}

void SynthNoteContext::reset_release_state() {
	_is_releasing = false;
	_is_fully_released = false;
	release_level = 0.0f;
	current_amplitude = 1.0f;
}

// State management methods
void SynthNoteContext::set_note_state(NoteState p_state) {
	if (note_state != p_state) {
		note_state = p_state;
	}
}

SynthNoteContext::NoteState SynthNoteContext::get_note_state() const {
	return note_state;
}

String SynthNoteContext::get_note_state_name() const {
	switch (note_state) {
		case NOTE_STATE_READY:
			return "READY";
		case NOTE_STATE_ACTIVE:
			return "ACTIVE";
		case NOTE_STATE_RELEASING:
			return "RELEASING";
		case NOTE_STATE_RELEASED:
			return "RELEASED";
		case NOTE_STATE_FINISHED:
			return "FINISHED";
		default:
			return "UNKNOWN";
	}
}

bool SynthNoteContext::is_note_ready() const {
	return note_state == NOTE_STATE_READY;
}

bool SynthNoteContext::is_note_active_state() const {
	return note_state == NOTE_STATE_ACTIVE;
}

bool SynthNoteContext::is_note_releasing() const {
	return note_state == NOTE_STATE_RELEASING;
}

bool SynthNoteContext::is_note_released() const {
	return note_state == NOTE_STATE_RELEASED;
}

bool SynthNoteContext::is_note_finished() const {
	return note_state == NOTE_STATE_FINISHED;
}

void SynthNoteContext::set_has_active_tail(bool p_has_tail) {
	has_active_tail = p_has_tail;
}

bool SynthNoteContext::get_has_active_tail() const {
	return has_active_tail;
}

void SynthNoteContext::reset() {
	absolute_time = 0.0;
	note_on_time = 0.0;
	note_time = 0.0;
	has_active_tail = false;
	is_note_triggered = false;

	// Reset to READY state
	set_note_state(NOTE_STATE_READY);

	// Reset amplitude tracking
	current_amplitude = 1.0f;
	release_level = 0.0f;
}

} // namespace godot
