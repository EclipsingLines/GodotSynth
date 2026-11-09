#pragma once
#ifndef WAVE_HELPER_H
#define WAVE_HELPER_H

#include <cmath>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

namespace godot {

class WaveHelper {
public:
	enum WaveType {
		SINE = 0,
		SQUARE,
		TRIANGLE,
		SAW,
		LOG_SAW,
		EXP_SAW,
		PULSE,
		NOISE,
		SUPER_SAW,
		SUB_SQUARE,
		PULSE_TRAIN,
		SINE_FOLD,
		ADDITIVE,
		SYNC_SAW,
		WAVE_TYPE_MAX
	};

#define WAVE_ENUM_VALUES "Sine,Square,Triangle,Saw,Log Saw,Exp Saw,Pulse,Noise,Super Saw,Sub Square,Pulse Train,Sine Fold,Additive,Sync Saw"

	static float get_wave_sample(float phase, WaveType wave_type, float pulse_width = 0.5f, bool unipolar = false) {
		phase = Math::fposmod(phase, 1.0f); // Ensure phase is 0-1
		pulse_width = Math::clamp(pulse_width, 0.01f, 0.99f); // Keep pulse width in valid range

		switch (wave_type) {
			case SINE: {
				// Apply pulse width by stretching/compressing the sine wave
				float adjusted_phase = phase < pulse_width ? (phase / pulse_width) * 0.5f : 0.5f + ((phase - pulse_width) / (1.0f - pulse_width)) * 0.5f;
				return unipolar ? 0.5f * (1.0f + std::sin(2.0f * Math::PI * adjusted_phase))
								: std::sin(2.0f * Math::PI * adjusted_phase);
			}

			case SQUARE:
				return (phase < pulse_width) ? (unipolar ? 1.0f : 1.0f)
											 : (unipolar ? 0.0f : -1.0f);

			case TRIANGLE: {
				// Adjust triangle wave based on pulse width
				float tri_phase = phase < pulse_width ? (phase / pulse_width) * 0.5f : 0.5f + ((phase - pulse_width) / (1.0f - pulse_width)) * 0.5f;
				return unipolar ? Math::abs(2.0f * tri_phase - 1.0f)
								: 4.0f * Math::abs(tri_phase - 0.5f) - 1.0f;
			}

			case SAW: {
				// Adjust saw wave based on pulse width
				float saw_phase = phase < pulse_width ? (phase / pulse_width) * 0.5f : 0.5f + ((phase - pulse_width) / (1.0f - pulse_width)) * 0.5f;
				return unipolar ? saw_phase : 2.0f * saw_phase - 1.0f;
			}

			case LOG_SAW: {
				// Adjust logarithmic saw based on pulse width
				float log_phase = phase < pulse_width ? (phase / pulse_width) * 0.5f : 0.5f + ((phase - pulse_width) / (1.0f - pulse_width)) * 0.5f;
				return unipolar ? std::log(1.0f + 9.0f * log_phase) / std::log(10.0f)
								: 2.0f * (std::log(1.0f + 9.0f * log_phase) / std::log(10.0f)) - 1.0f;
			}

			case EXP_SAW: {
				// Adjust exponential saw based on pulse width
				float exp_phase = phase < pulse_width ? (phase / pulse_width) * 0.5f : 0.5f + ((phase - pulse_width) / (1.0f - pulse_width)) * 0.5f;
				return unipolar ? std::exp(exp_phase) / std::exp(1.0f)
								: 2.0f * (std::exp(exp_phase) / std::exp(1.0f)) - 1.0f;
			}

			case PULSE:
				return (phase < pulse_width) ? (unipolar ? 1.0f : 1.0f)
											 : (unipolar ? 0.0f : -1.0f);

			case NOISE:
				return unipolar ? (float)rand() / RAND_MAX
								: 2.0f * ((float)rand() / RAND_MAX) - 1.0f;

			case SUPER_SAW: {
				// Super saw - multiple detuned saw waves
				// pulse_width controls how many saws (1-7)
				int num_saws = 1 + static_cast<int>(6.0f * pulse_width); // 1 to 7 saws
				float detune_amount = 0.01f; // Amount of detuning between saws
				float result = 0.0f;

				for (int i = 0; i < num_saws; i++) {
					// Calculate detune factor, centered around original phase
					float detune = (i - (num_saws - 1) / 2.0f) * detune_amount;
					float detuned_phase = Math::fposmod(phase + detune, 1.0f);

					// Get basic saw wave
					float saw_phase = detuned_phase;
					float saw_value = unipolar ? saw_phase : 2.0f * saw_phase - 1.0f;

					// Add to result with slight amplitude reduction for more saws
					result += saw_value / std::sqrt(static_cast<float>(num_saws));
				}

				return result;
			}

			case SUB_SQUARE: {
				// Sub square: a square an octave below the note. A stateless
				// phase can't run at half rate (phase * 0.5 only covers the first
				// half of the sub cycle, which is a DC offset), so the caller
				// passes the sub-oscillator's own phase here. The VA engine keeps
				// a separate half-rate accumulator for it.
				return (phase < pulse_width) ? 1.0f
											 : (unipolar ? 0.0f : -1.0f);
			}

			case PULSE_TRAIN: {
				// Pulse train - series of narrow pulses at regular intervals
				// pulse_width controls pulse density (0.01 = sparse, 0.99 = dense)
				float pulse_period = 1.0f / (1.0f + 9.0f * pulse_width); // Maps 0.01-0.99 to 0.1-0.01 period
				float pulse_duration = pulse_period * 0.2f; // Each pulse is 20% of the period
				float local_phase = Math::fposmod(phase, pulse_period);
				return (local_phase < pulse_duration) ? (unipolar ? 1.0f : 1.0f)
													  : (unipolar ? 0.0f : -1.0f);
			}

			case SINE_FOLD: {
				// Sine fold - sine wave that folds back when exceeding threshold
				// pulse_width controls folding threshold (lower = more folding)
				float threshold = 0.1f + 0.8f * pulse_width; // Maps 0.01-0.99 to 0.108-0.892
				float sine_val = std::sin(2.0f * Math::PI * phase);

				// Apply folding
				while (std::abs(sine_val) > threshold) {
					if (sine_val > threshold) {
						sine_val = 2.0f * threshold - sine_val;
					} else if (sine_val < -threshold) {
						sine_val = -2.0f * threshold - sine_val;
					}
				}

				// Normalize to full range
				sine_val = sine_val / threshold;

				return unipolar ? 0.5f * (sine_val + 1.0f) : sine_val;
			}

			case ADDITIVE: {
				// Additive harmonic - fundamental plus harmonics
				// pulse_width controls harmonic content (more width = more harmonics)
				int num_harmonics = 1 + static_cast<int>(15.0f * pulse_width); // 1-16 harmonics
				float result = 0.0f;
				float amp_sum = 0.0f;

				for (int i = 1; i <= num_harmonics; i++) {
					// Amplitude decreases for higher harmonics
					float harmonic_amp = 1.0f / i;
					result += harmonic_amp * std::sin(2.0f * Math::PI * phase * i);
					amp_sum += harmonic_amp;
				}

				// Normalize
				result /= amp_sum;

				return unipolar ? 0.5f * (result + 1.0f) : result;
			}

			case SYNC_SAW: {
				// Sync saw - hard-sync sawtooth oscillator
				// pulse_width controls the sync ratio (1.0 to 10.0)
				float sync_ratio = 1.0f + 9.0f * pulse_width; // Maps 0.01-0.99 to 1.09-9.91
				float master_phase = phase;
				float slave_phase = Math::fposmod(phase * sync_ratio, 1.0f);

				// Reset slave oscillator when master completes a cycle
				if (master_phase < 0.01f) {
					slave_phase = 0.0f;
				}

				// Generate sawtooth wave from slave oscillator
				float saw_value = unipolar ? slave_phase : 2.0f * slave_phase - 1.0f;

				return saw_value;
			}

			default:
				return 0.0f;
		}
	}

	// Super saw with real detune: each saw runs its own phase accumulator at
	// get_super_saw_ratio(i) times the note frequency. pulse_width picks how
	// many saws sound (1-7), as in the stateless version above.
	static const int SUPER_SAW_VOICES = 7;

	static int get_super_saw_count(float pulse_width) {
		pulse_width = Math::clamp(pulse_width, 0.01f, 0.99f);
		return 1 + static_cast<int>(6.0f * pulse_width);
	}

	// Frequency ratio of saw i: centre saw first, then pairs spreading out by
	// 8 cents per step (0, -8, +8, -16, +16, -24, +24 cents).
	static float get_super_saw_ratio(int i) {
		static const float ratios[SUPER_SAW_VOICES] = {
			1.0f,
			0.99538968f, // -8 cents
			1.00463167f, // +8 cents
			0.99080061f, // -16 cents
			1.00928480f, // +16 cents
			0.98623270f, // -24 cents
			1.01395948f, // +24 cents
		};
		return ratios[i];
	}

	// Fixed, spread start phases so the saws don't start perfectly aligned.
	static float get_super_saw_start_phase(int i) {
		static const float phases[SUPER_SAW_VOICES] = { 0.0f, 0.618f, 0.236f, 0.854f, 0.472f, 0.090f, 0.708f };
		return phases[i];
	}

	static float get_super_saw_sample(const float *phases, float pulse_width, bool unipolar = false) {
		int num_saws = get_super_saw_count(pulse_width);
		float result = 0.0f;
		for (int i = 0; i < num_saws; i++) {
			result += unipolar ? phases[i] : 2.0f * phases[i] - 1.0f;
		}
		return result / std::sqrt(static_cast<float>(num_saws));
	}
};

} // namespace godot

#endif // WAVE_HELPER_H
VARIANT_ENUM_CAST(godot::WaveHelper::WaveType);
