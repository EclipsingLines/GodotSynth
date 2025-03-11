# Virtual Analog (VA)

## Description

The Virtual Analog (VA) oscillator engine simulates classic analog synthesizer waveforms with digital precision. It provides multiple layered waveforms that can be mixed and modulated for rich, evolving sounds with the warmth and character of analog synthesis but without the instabilities.

## Parameters

*   **Bottom Waveform:** Selects the waveform type for the bottom layer (sine, triangle, saw, square, pulse)
*   **Middle Waveform:** Selects the waveform type for the middle layer
*   **Top Waveform:** Selects the waveform type for the top layer
*   **Bottom Mix:** Controls the level of the bottom waveform in the final output
*   **Middle Mix:** Controls the level of the middle waveform in the final output
*   **Top Mix:** Controls the level of the top waveform in the final output
*   **Detune:** Adjusts the frequency difference between the waveform layers for thicker sounds
*   **Pulse Width:** Controls the duty cycle of pulse/square waveforms
*   **Phase Offset:** Adjusts the starting phase of the waveforms for different timbral characteristics
*   **Sync:** Enables hard sync between oscillators for classic sync sounds

## Implementation Notes

The VA oscillator engine is implemented using efficient digital algorithms that accurately model analog waveforms while avoiding aliasing issues. Anti-aliasing techniques such as PolyBLEP (Polynomial Band-Limited Step Function) are used to minimize digital artifacts at high frequencies.

The engine supports three simultaneous waveform layers that can be independently selected and mixed, allowing for complex timbres. Each waveform is generated with phase accuracy to maintain consistent sound quality across the frequency spectrum.

## Integration with Modulation System

The VA oscillator engine is designed to work seamlessly with the modulation system. Key modulation targets include:

- Pulse Width: Modulating this parameter creates classic PWM (Pulse Width Modulation) sounds
- Mix levels: Dynamically changing the balance between waveforms creates evolving timbres
- Detune: Modulating detune creates chorus-like effects and dynamic thickness
- Phase Offset: Creates phasing effects when modulated

## Performance Considerations

The VA oscillator engine is optimized for SIMD processing, allowing efficient generation of multiple voices simultaneously. The implementation balances quality and performance, with special attention to anti-aliasing at higher frequencies.

## References

- [Efficient Anti-aliasing of a Complex Polygonal Oscillator](https://www.dafx.de/paper-archive/2017/papers/DAFx17_paper_26.pdf)
- [The Art of VA Filter Design](https://www.native-instruments.com/fileadmin/ni_media/downloads/pdf/VAFilterDesign_1.1.1.pdf)
- [Alias-Free Digital Synthesis of Classic Analog Waveforms](https://www.researchgate.net/publication/236629465_Alias-Free_Digital_Synthesis_of_Classic_Analog_Waveforms)
