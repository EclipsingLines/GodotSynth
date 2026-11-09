#pragma once
#include <godot_cpp/classes/ref_counted.hpp>

namespace godot {

class PitchHelper : public RefCounted {
	GDCLASS(PitchHelper, RefCounted);

private:
	static void _bind_methods();

public:
	PitchHelper();
	~PitchHelper();

	// Static methods for pitch calculations
	static float fast_pitch(float semitones);
	static float fast_pitch_extended(float semitones);

	static float midi_to_freq(float midi);
	static float freq_to_midi(float freq);
};

} // namespace godot