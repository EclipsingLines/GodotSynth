#ifndef FORMANT_FILTER_H
#define FORMANT_FILTER_H

#include "filter_effect.h"

namespace godot {

class FormantFilter : public FilterEffect {
	GDCLASS(FormantFilter, FilterEffect)

public:
	static const char *PARAM_VOWEL_POSITION;

private:
	// Vowel types
	enum VowelType {
		VOWEL_A,
		VOWEL_E,
		VOWEL_I,
		VOWEL_O,
		VOWEL_U,
		VOWEL_COUNT
	};

	// Filter state for each formant band
	struct FormantBand {
		float a1, a2, b0, b1, b2;
		float x1, x2, y1, y2;
	};

	// Three formant bands per vowel
	FormantBand bands[3];

	// Formant frequencies and bandwidths for each vowel
	static const float formant_freqs[VOWEL_COUNT][3];
	static const float formant_bandwidths[VOWEL_COUNT][3];

	// Update coefficients based on vowel position
	void update_coefficients(float sample_rate);

protected:
	static void _bind_methods();

public:
	FormantFilter();
	~FormantFilter();

	float process_sample(float sample, const Ref<SynthNoteContext> &context) override;
	void reset() override;

	// Vowel position parameter accessors
	void set_vowel_position_parameter(const Ref<ModulatedParameter> &param);
	Ref<ModulatedParameter> get_vowel_position_parameter() const;
	void set_vowel_position_base_value(float p_value);
	float get_vowel_position_base_value() const;

	Ref<SynthAudioEffect> duplicate() const override;
};

} // namespace godot

#endif // FORMANT_FILTER_H
