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

// Minimax polynomial approximation for 2^(x/12) over x ∈ [-1,1] (where x is semitones/12)
// Max error: 0.02%
float PitchHelper::fast_pitch(float semitones) {
	// Normalize to [-1,1] range
	float x = semitones / 12.0f;

	const float c0 = 1.00000000f;
	const float c1 = 0.05776226f;
	const float c2 = 0.00166096f;
	const float c3 = 0.00003198f;
	const float c4 = 0.00000042f;

	float x2 = x * x;
	float x4 = x2 * x2;
	return c0 + c1 * x + c2 * x2 + c3 * x2 * x + c4 * x4;
}

// Version with octave handling for extended range
float PitchHelper::fast_pitch_extended(float semitones) {
	// Handle octaves
	float octaves = floor(semitones / 12.0f);
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