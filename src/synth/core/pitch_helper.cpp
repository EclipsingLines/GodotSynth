#include "pitch_helper.h"
#include <cmath>
#include <godot_cpp/core/class_db.hpp>

namespace godot {

void PitchHelper::_bind_methods() {
	// Bind static methods to make them accessible from GDScript
	ClassDB::bind_static_method("PitchHelper", D_METHOD("fast_pitch", "semitones"), &PitchHelper::fast_pitch);
	ClassDB::bind_static_method("PitchHelper", D_METHOD("fast_pitch_extended", "semitones"), &PitchHelper::fast_pitch_extended);
	ClassDB::bind_static_method("PitchHelper", D_METHOD("midi_to_freq", "midi"), &PitchHelper::midi_to_freq);
	ClassDB::bind_static_method("PitchHelper", D_METHOD("freq_to_midi", "freq"), &PitchHelper::freq_to_midi);
}

PitchHelper::PitchHelper() {
	// Constructor
}

PitchHelper::~PitchHelper() {
	// Destructor
}

// Polynomial approximation of 2^(semitones/12), i.e. exp(a * x) with
// a = ln(2)/12 and x in semitones (5th-order Taylor series, Horner form).
// Relative error: < 3e-6 for |x| <= 6, < 1.5e-4 (0.3 cents) for |x| <= 12.
float PitchHelper::fast_pitch(float semitones) {
	const float x = semitones;
	const float c1 = 5.7762265047e-02f;
	const float c2 = 1.6682396317e-03f;
	const float c3 = 3.2120433255e-05f;
	const float c4 = 4.6383724477e-07f;
	const float c5 = 5.3584579742e-09f;
	return 1.0f + x * (c1 + x * (c2 + x * (c3 + x * (c4 + x * c5))));
}

// Version with octave handling for extended range
float PitchHelper::fast_pitch_extended(float semitones) {
	// Split into whole octaves and a remainder in [-6, 6) semitones, where
	// fast_pitch is most accurate.
	float octaves = floorf(semitones / 12.0f + 0.5f);
	float remainder = semitones - 12.0f * octaves;

	// Calculate base frequency multiplier
	float base = fast_pitch(remainder);

	// Apply octave shift
	return base * exp2f(octaves);
}

// Convert MIDI note number to frequency in Hz
float PitchHelper::midi_to_freq(float midi) {
	// A4 = MIDI note 69 = 440Hz
	return 440.0f * fast_pitch_extended(midi - 69.0f);
}

// Convert frequency in Hz to MIDI note number
float PitchHelper::freq_to_midi(float freq) {
	// Inverse of midi_to_freq
	if (freq <= 0.0f)
		return 0.0f;
	return 69.0f + 12.0f * log2f(freq / 440.0f);
}

} // namespace godot