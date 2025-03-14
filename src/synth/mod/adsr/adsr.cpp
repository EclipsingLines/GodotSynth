#include "adsr.h"
#include "../../core/synth_note_context.h"
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

constexpr float MIN_TIME = 0.00001f;

void ADSR::_bind_methods() {
	// Bind processing and note control methods.
	ClassDB::bind_method(D_METHOD("reset"), &ADSR::reset);

	// Bind parameter setters/getters.
	ClassDB::bind_method(D_METHOD("set_attack", "value"), &ADSR::set_attack);
	ClassDB::bind_method(D_METHOD("get_attack"), &ADSR::get_attack);
	ClassDB::bind_method(D_METHOD("set_decay", "value"), &ADSR::set_decay);
	ClassDB::bind_method(D_METHOD("get_decay"), &ADSR::get_decay);
	ClassDB::bind_method(D_METHOD("set_sustain", "value"), &ADSR::set_sustain);
	ClassDB::bind_method(D_METHOD("get_sustain"), &ADSR::get_sustain);
	ClassDB::bind_method(D_METHOD("set_release", "value"), &ADSR::set_release);
	ClassDB::bind_method(D_METHOD("get_release"), &ADSR::get_release);

	// Bind curve type setters/getters
	ClassDB::bind_method(D_METHOD("set_attack_type", "type"), &ADSR::set_attack_type);
	ClassDB::bind_method(D_METHOD("get_attack_type"), &ADSR::get_attack_type);
	ClassDB::bind_method(D_METHOD("set_decay_type", "type"), &ADSR::set_decay_type);
	ClassDB::bind_method(D_METHOD("get_decay_type"), &ADSR::get_decay_type);
	ClassDB::bind_method(D_METHOD("set_release_type", "type"), &ADSR::set_release_type);
	ClassDB::bind_method(D_METHOD("get_release_type"), &ADSR::get_release_type);

	// Expose properties.
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "attack", PROPERTY_HINT_RANGE, "0.00001,5.0,0.00001"), "set_attack", "get_attack");
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "decay", PROPERTY_HINT_RANGE, "0.00001,5.0,0.00001"), "set_decay", "get_decay");
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "sustain_level", PROPERTY_HINT_RANGE, "0.0,1.0,0.01"), "set_sustain", "get_sustain");
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "release", PROPERTY_HINT_RANGE, "0.00001,5.0,0.00001"), "set_release", "get_release");

	// Expose curve type properties with enum hints
	ADD_PROPERTY(PropertyInfo(Variant::INT, "attack_type", PROPERTY_HINT_ENUM, "Linear,Exponential,Logarithmic"), "set_attack_type", "get_attack_type");
	ADD_PROPERTY(PropertyInfo(Variant::INT, "decay_type", PROPERTY_HINT_ENUM, "Linear,Exponential,Logarithmic"), "set_decay_type", "get_decay_type");
	ADD_PROPERTY(PropertyInfo(Variant::INT, "release_type", PROPERTY_HINT_ENUM, "Linear,Exponential,Logarithmic"), "set_release_type", "get_release_type");

	// Expose enum constants.
	BIND_ENUM_CONSTANT(ATTACK);
	BIND_ENUM_CONSTANT(DECAY);
	BIND_ENUM_CONSTANT(SUSTAIN);
	BIND_ENUM_CONSTANT(RELEASE);
	BIND_ENUM_CONSTANT(OFF);

	// Expose curve type enum constants
	BIND_ENUM_CONSTANT(LINEAR);
	BIND_ENUM_CONSTANT(EXPONENTIAL);
	BIND_ENUM_CONSTANT(LOGARITHMIC);
}

ADSR::ADSR() {
	// Default ADSR values.
	attack = 0.1f;
	decay = 0.3f;
	sustain_level = 0.7f;
	release = 0.5f;
	release_level = 0.0f;
	release_start_level = 0.0f;
	// For display we assume a fixed sustain duration.
	default_sustain_time = 1.0f;

	// Default curve types
	attack_type = LINEAR;
	decay_type = LINEAR;
	release_type = LINEAR;

	// Initialize state
	current_level = 0.0f;
	current_stage = OFF;
	stage_start_time = 0.0;
}

ADSR::~ADSR() {
}

float ADSR::get_value(const Ref<SynthNoteContext> &context) const {
	if (!context.is_valid()) {
		UtilityFunctions::printerr("ADSR::get_value returning: 0 - Context not valid");
		return 0.0f;
	}

	const double abs_time = context->get_note_time();
	const bool is_note_on = context->get_is_note_on();

	//UtilityFunctions::print("ADSR note time: " + String::num(abs_time));

	// State machine transitions
	switch (current_stage) {
		case ADSR::OFF:
			if (is_note_on) {
				current_stage = ADSR::ATTACK;
				stage_start_time = abs_time;
				UtilityFunctions::print("ADSR | Stage: OFF -> ATTACK");
			}
			break;

		case ADSR::ATTACK:
			if (!is_note_on) {
				current_stage = ADSR::RELEASE;
				stage_start_time = abs_time;
				release_start_level = current_level; // Store the level at the start of release
				UtilityFunctions::print("ADSR | Stage: ATTACK -> RELEASE | Start Level: " + String::num(release_start_level));
			} else if (abs_time - stage_start_time >= attack) {
				current_stage = ADSR::DECAY;
				stage_start_time = abs_time;
				UtilityFunctions::print("ADSR | Stage: ATTACK -> DECAY");
			}
			break;

		case ADSR::DECAY:
			if (!is_note_on) {
				current_stage = ADSR::RELEASE;
				stage_start_time = abs_time;
				release_start_level = current_level; // Store the level at the start of release
				UtilityFunctions::print("ADSR | Stage: DECAY -> RELEASE | Start Level: " + String::num(release_start_level));
			} else if (abs_time - stage_start_time >= decay) {
				current_stage = ADSR::SUSTAIN;
				UtilityFunctions::print("ADSR | Stage: DECAY -> SUSTAIN");
			}
			break;

		case ADSR::SUSTAIN:
			if (!is_note_on) {
				current_stage = ADSR::RELEASE;
				stage_start_time = abs_time;
				release_start_level = current_level; // Store the level at the start of release
				UtilityFunctions::print("ADSR | Stage: SUSTAIN -> RELEASE | Start Level: " + String::num(release_start_level));
			}
			break;

		case ADSR::RELEASE:
			if (is_note_on) {
				// Retrigger
				current_stage = ADSR::ATTACK;
				stage_start_time = abs_time;
				UtilityFunctions::print("ADSR | Stage: RELEASE -> ATTACK (retrigger)");
			} else if (abs_time - stage_start_time >= release) {
				current_stage = ADSR::OFF;
				UtilityFunctions::print("ADSR | Stage: RELEASE -> OFF");
			}
			break;
	}

	// Calculate value based on current stage
	float prev_level = current_level;

	switch (current_stage) {
		case ADSR::ATTACK: {
			float t = CLAMP((abs_time - stage_start_time) / attack, 0.0f, 1.0f);

			// Apply the selected curve type for attack
			switch (attack_type) {
				case LINEAR:
					current_level = t;
					break;
				case EXPONENTIAL:
					current_level = t * t; // Simple exponential curve: t^2
					break;
				case LOGARITHMIC:
					current_level = Math::sqrt(t); // Simple logarithmic curve: sqrt(t)
					break;
			}
			break;
		}
		case ADSR::DECAY: {
			float t = CLAMP((abs_time - stage_start_time) / decay, 0.0f, 1.0f);

			// Apply the selected curve type for decay
			float decay_curve;
			switch (decay_type) {
				case LINEAR:
					decay_curve = t;
					break;
				case EXPONENTIAL:
					decay_curve = t * t; // Simple exponential curve: t^2
					break;
				case LOGARITHMIC:
					decay_curve = Math::sqrt(t); // Simple logarithmic curve: sqrt(t)
					break;
			}

			current_level = Math::lerp(1.0f, sustain_level, decay_curve);
			break;
		}
		case ADSR::SUSTAIN:
			current_level = sustain_level;
			break;
		case ADSR::RELEASE: {
			float t = CLAMP((abs_time - stage_start_time) / release, 0.0f, 1.0f);

			// Apply the selected curve type for release
			float release_curve;
			switch (release_type) {
				case LINEAR:
					release_curve = t;
					break;
				case EXPONENTIAL:
					release_curve = t * t; // Simple exponential curve: t^2
					break;
				case LOGARITHMIC:
					release_curve = Math::sqrt(t); // Simple logarithmic curve: sqrt(t)
					break;
			}

			// Use the stored release start level for consistent release behavior
			current_level = Math::lerp(release_start_level, 0.0f, release_curve);
			break;
		}
		case ADSR::OFF:
			current_level = 0.0f;
			break;
	}

	// Debug output if level changed significantly
	if (ABS(current_level - prev_level) > 0.05f) {
		UtilityFunctions::print(vformat("ADSR | Stage: %s | Level: %.2f",
				current_stage == ADSR::ATTACK ? "ATTACK" : current_stage == ADSR::DECAY ? "DECAY"
						: current_stage == ADSR::SUSTAIN								? "SUSTAIN"
						: current_stage == ADSR::RELEASE								? "RELEASE"
																						: "OFF",
				current_level));
	}

	context->update_amplitude(current_level);
	return current_level;
}

void ADSR::reset() {
	// Reset all state variables to initial values
	current_level = 0.0f;
	current_stage = OFF;
	stage_start_time = 0.0;
	UtilityFunctions::print("ADSR | Reset called - Stage: OFF | Level: 0.00");
}

void ADSR::set_attack(float p_attack) {
	attack = std::max(p_attack, MIN_TIME);
}

float ADSR::get_attack() const {
	return attack;
}

void ADSR::set_decay(float p_decay) {
	decay = std::max(p_decay, MIN_TIME);
}

float ADSR::get_decay() const {
	return decay;
}

void ADSR::set_sustain(float p_sustain) {
	sustain_level = CLAMP(p_sustain, 0.0f, 1.0f);
}

float ADSR::get_sustain() const {
	return sustain_level;
}

void ADSR::set_release(float p_release) {
	release = std::max(p_release, MIN_TIME);
}

float ADSR::get_release() const {
	return release;
}

void ADSR::set_attack_type(CurveType p_type) {
	attack_type = p_type;
}

ADSR::CurveType ADSR::get_attack_type() const {
	return attack_type;
}

void ADSR::set_decay_type(CurveType p_type) {
	decay_type = p_type;
}

ADSR::CurveType ADSR::get_decay_type() const {
	return decay_type;
}

void ADSR::set_release_type(CurveType p_type) {
	release_type = p_type;
}

ADSR::CurveType ADSR::get_release_type() const {
	return release_type;
}
