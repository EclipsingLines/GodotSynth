#ifndef STEINER_PARKER_FILTER_H
#define STEINER_PARKER_FILTER_H

#include "filter_effect.h"

namespace godot {

class SteinerParkerFilter : public FilterEffect {
	GDCLASS(SteinerParkerFilter, FilterEffect)
public:
	static const char *PARAM_DRIVE;

private:
	// Filter state variables
	float hp1 = 0.0f;
	float bp1 = 0.0f;
	float lp1 = 0.0f;
	float hp = 0.0f;
	float bp = 0.0f;
	float lp = 0.0f;

	// Nonlinearity amount (0.0 = clean, 1.0 = heavily saturated)
	float drive = 0.0f;

	// Tanh approximation for saturation
	float fast_tanh(float x) const;

protected:
	static void _bind_methods();

public:
	SteinerParkerFilter();
	~SteinerParkerFilter();

	float process_sample(float sample, const Ref<SynthNoteContext> &context) override;
	void reset() override;

	// Drive parameter
	void set_drive(float p_drive);
	float get_drive() const;

	Ref<SynthAudioEffect> duplicate() const override;
};

} // namespace godot

#endif // STEINER_PARKER_FILTER_H
