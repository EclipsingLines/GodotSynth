# Waveshaping (WS)

## Description

Waveshaping is a synthesis technique that distorts a signal by applying a non-linear transfer function to it. This creates new harmonics and timbral variations.

## Parameters

*   **Shape:** [Description of the waveshaping function. This could be a selection of different curves or a continuous parameter that morphs between them.]
*   **Amount:** [The amount of distortion applied to the signal.]
*   **Pre-gain:** [Gain applied to the signal before waveshaping.]
*   **Post-gain:** [Gain applied to the signal after waveshaping.]

## Implementation Notes

[The waveshaping function can be implemented using a lookup table or a mathematical function. Consider using Chebyshev polynomials or other common waveshaping functions. Optimization is important for real-time performance.]

## References

[https://dafx.de/paper_archives/DAFX11_Proceedings/papers/DAFX11_49.pdf]
