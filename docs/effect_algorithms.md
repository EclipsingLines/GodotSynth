# Synth Effect Algorithms

This document provides a comprehensive overview of the effect algorithms currently implemented in the Glaits synth engine.

## Distortion Effects

*   **Clip Distortion:** A simple distortion effect that clips the input signal at a defined threshold, creating a harsh, digital distortion.
    *   *Parameters:* drive, mix, output_gain, threshold, hardness
    *   *Implementation:* Uses a configurable hard clipping algorithm with adjustable threshold and hardness parameters for fine control over the distortion character.

*   **Foldback Distortion:** Creates distortion by "folding back" the signal when it exceeds a certain threshold, resulting in a unique, often metallic sound.
    *   *Parameters:* drive, mix, output_gain, threshold, iterations
    *   *Implementation:* Repeatedly folds the signal back when it exceeds the threshold, with the number of iterations controlling the complexity of the resulting waveform.

## Delay Effects

*   **Ping Pong Delay:** A stereo delay effect that alternates the delayed signal between the left and right channels, creating a wide, bouncing sound.
    *   *Parameters:* delay_time, feedback, mix, cross_feedback, offset
    *   *Implementation:* Uses dual delay lines with cross-feedback between channels and configurable offset for creating rhythmic patterns.

*   **Tape Delay:** Simulates the characteristics of a vintage tape delay, including tape saturation, wow and flutter, and filtering.
    *   *Parameters:* delay_time, feedback, mix, saturation, wow_amount, filtering
    *   *Implementation:* Combines a standard delay with saturation, low-frequency modulation for wow/flutter effects, and filtering to emulate the frequency response of tape.

*   **Reverse Delay:** Plays the delayed signal in reverse.
    *   *Parameters:* delay_time, feedback, mix, crossfade
    *   *Implementation:* Stores the input signal in a buffer and plays it back in reverse order after the specified delay time, with crossfading to smooth transitions between playback segments.

## Filter Effects

*   **State Variable Filter:** A versatile multi-mode filter that can function as low-pass, high-pass, band-pass, or notch filter.
    *   *Parameters:* cutoff, resonance, filter type
    *   *Implementation:* Uses a state variable filter topology that maintains consistent resonance behavior across different filter modes.

## Spatial Effects

*   **Reverb:** Simulates the sound of a space by creating reflections and reverberations.
    *   *Parameters:* room_size, damping, width, mix, pre_delay, diffusion
    *   *Implementation:* Uses a combination of early reflections and a feedback delay network (FDN) with damping filters for realistic room simulation.

## Future Developments

The following effects are planned for future releases:

*   **Chorus/Flanger/Phaser:** Modulation effects for creating movement and depth
*   **Compressor/Limiter:** Dynamic processing for controlling signal levels
*   **Spectral Effects:** Frequency-domain processing for unique sound transformations
*   **Granular Effects:** Grain-based processing for textural sound design

Each effect in the Glaits engine is designed with modulation in mind, allowing parameters to be controlled by LFOs, envelopes, and other modulation sources for dynamic, evolving sounds.
