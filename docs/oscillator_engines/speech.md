# Speech (SPEECH)

## Description

The Speech engine synthesizes speech sounds by using a formant filter bank. It can be used to create vowel sounds, spoken words, or other vocalizations.

## Parameters

*   **Vowel:** [Selects the vowel sound to be synthesized.]
*   **Phoneme:** [Selects a specific phoneme (speech sound) to be synthesized.]
*   **Formant 1 Frequency:** [The frequency of the first formant filter.]
*   **Formant 2 Frequency:** [The frequency of the second formant filter.]
*   **Formant 3 Frequency:** [The frequency of the third formant filter.]
*   **Formant 1 Bandwidth:** [The bandwidth of the first formant filter.]
*   **Formant 2 Bandwidth:** [The bandwidth of the second formant filter.]
*   **Formant 3 Bandwidth:** [The bandwidth of the third formant filter.]
*   **Aspiration:** [The amount of aspiration noise added to the signal.]

## Implementation Notes

[This engine can be implemented using a series of bandpass filters to model the formants. The filter coefficients can be derived from recorded speech data or synthesized using a formant synthesizer model. Consider using linear prediction coding (LPC) to analyze speech and extract formant data.]

## References

[https://en.wikipedia.org/wiki/Formant]
