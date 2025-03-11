# Grain (GRAIN)

## Description

The Grain engine generates sound by playing back short segments of audio called "grains." These grains can be manipulated in various ways to create a wide range of textures and effects.

## Parameters

*   **Grain Size:** [The duration of each grain in milliseconds.]
*   **Grain Rate:** [The rate at which grains are played back.]
*   **Pitch:** [The pitch of the grains.]
*   **Pan:** [The panning of the grains.]
*   **Randomization:** [The amount of randomization applied to the grain parameters.]
*   **Source:** [The audio source for the grains.]

## Implementation Notes

[This engine requires a buffer of audio data to draw grains from. The grain parameters can be modulated to create dynamic and evolving textures. Consider using windowing functions to smooth the edges of the grains and avoid clicks.]

## References

[https://en.wikipedia.org/wiki/Granular_synthesis]
