#ifndef FORMANT_FILTER_H
#define FORMANT_FILTER_H

#include "filter_effect.h"

namespace godot {

class FormantFilter : public FilterEffect {
    GDCLASS(FormantFilter, FilterEffect)

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
    
    // Current vowel position (0.0 = A, 1.0 = E, 2.0 = I, etc.)
    float vowel_position = 0.0f;
    
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
    
    // Vowel position parameter (0.0 to 4.0)
    void set_vowel_position(float p_position);
    float get_vowel_position() const;
    
    Ref<SynthAudioEffect> duplicate() const override;
};

} // namespace godot

#endif // FORMANT_FILTER_H
