#include "chord_oscillator_engine.h"
#include "../core/modulated_parameter.h"
#include "../core/synth_note_context.h"
#include "../core/wave_helper_cache.h"
#include "chord_synth_configuration.h"
#include <cmath>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/templates/pair.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

namespace godot {

void ChordOscillatorEngine::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_waveform", "type"), &ChordOscillatorEngine::set_waveform);
	ClassDB::bind_method(D_METHOD("get_waveform"), &ChordOscillatorEngine::get_waveform);

	ClassDB::bind_method(D_METHOD("set_parameter", "name", "param"), &ChordOscillatorEngine::set_parameter);
	ClassDB::bind_method(D_METHOD("get_parameter", "name"), &ChordOscillatorEngine::get_parameter);
	ClassDB::bind_method(D_METHOD("get_parameters"), &ChordOscillatorEngine::get_parameters);
	
	ClassDB::bind_method(D_METHOD("set_root_note_only", "enabled"), &ChordOscillatorEngine::set_root_note_only);
	ClassDB::bind_method(D_METHOD("get_root_note_only"), &ChordOscillatorEngine::get_root_note_only);
	ADD_PROPERTY(PropertyInfo(Variant::BOOL, "root_note_only"), "set_root_note_only", "get_root_note_only");
}

ChordOscillatorEngine::ChordOscillatorEngine() :
		waveform(WaveHelper::SINE),
		phase(0.0f),
		cached_chord_type(0.0f),
		cached_inversion(0.0f),
		cached_amplitude(0.0f),
		cached_pulse_width(0.5f),
		cached_detune(0.0f),
		cached_output_gain(0.7f), // Reduce default gain to avoid clipping
		root_note_only(false) { // Default to normal chord mode
}

ChordOscillatorEngine::~ChordOscillatorEngine() {
}

float ChordOscillatorEngine::get_frequency_for_note(int note) const {
	// A4 = 440Hz = MIDI note 69
	return 440.0f * std::pow(2.0f, (note - 69) / 12.0f);
}

std::vector<int> ChordOscillatorEngine::get_chord_intervals(int chord_type) const {
	std::vector<int> intervals;

	// Root note is always included (0 semitones from root)
	intervals.push_back(0);

	// Add intervals based on chord type
	switch (chord_type) {
		case CHORD_MAJOR:
			intervals.push_back(4); // Major third
			intervals.push_back(7); // Perfect fifth
			break;
		case CHORD_MINOR:
			intervals.push_back(3); // Minor third
			intervals.push_back(7); // Perfect fifth
			break;
		case CHORD_DIMINISHED:
			intervals.push_back(3); // Minor third
			intervals.push_back(6); // Diminished fifth
			break;
		case CHORD_AUGMENTED:
			intervals.push_back(4); // Major third
			intervals.push_back(8); // Augmented fifth
			break;
		case CHORD_SUSPENDED_2:
			intervals.push_back(2); // Major second
			intervals.push_back(7); // Perfect fifth
			break;
		case CHORD_SUSPENDED_4:
			intervals.push_back(5); // Perfect fourth
			intervals.push_back(7); // Perfect fifth
			break;
		case CHORD_MAJOR_7:
			intervals.push_back(4); // Major third
			intervals.push_back(7); // Perfect fifth
			intervals.push_back(11); // Major seventh
			break;
		case CHORD_MINOR_7:
			intervals.push_back(3); // Minor third
			intervals.push_back(7); // Perfect fifth
			intervals.push_back(10); // Minor seventh
			break;
		case CHORD_DOMINANT_7:
			intervals.push_back(4); // Major third
			intervals.push_back(7); // Perfect fifth
			intervals.push_back(10); // Minor seventh
			break;
		case CHORD_DIMINISHED_7:
			intervals.push_back(3); // Minor third
			intervals.push_back(6); // Diminished fifth
			intervals.push_back(9); // Diminished seventh
			break;
		case CHORD_HALF_DIMINISHED_7:
			intervals.push_back(3); // Minor third
			intervals.push_back(6); // Diminished fifth
			intervals.push_back(10); // Minor seventh
			break;
		case CHORD_AUGMENTED_7:
			intervals.push_back(4); // Major third
			intervals.push_back(8); // Augmented fifth
			intervals.push_back(10); // Minor seventh
			break;
		case CHORD_MINOR_MAJOR_7:
			intervals.push_back(3); // Minor third
			intervals.push_back(7); // Perfect fifth
			intervals.push_back(11); // Major seventh
			break;
		case CHORD_MAJOR_6:
			intervals.push_back(4); // Major third
			intervals.push_back(7); // Perfect fifth
			intervals.push_back(9); // Major sixth
			break;
		case CHORD_MINOR_6:
			intervals.push_back(3); // Minor third
			intervals.push_back(7); // Perfect fifth
			intervals.push_back(9); // Major sixth
			break;
		case CHORD_DOMINANT_9:
			intervals.push_back(4); // Major third
			intervals.push_back(7); // Perfect fifth
			intervals.push_back(10); // Minor seventh
			intervals.push_back(14); // Major ninth
			break;
		case CHORD_MAJOR_9:
			intervals.push_back(4); // Major third
			intervals.push_back(7); // Perfect fifth
			intervals.push_back(11); // Major seventh
			intervals.push_back(14); // Major ninth
			break;
		case CHORD_MINOR_9:
			intervals.push_back(3); // Minor third
			intervals.push_back(7); // Perfect fifth
			intervals.push_back(10); // Minor seventh
			intervals.push_back(14); // Major ninth
			break;
		case CHORD_ADD_9:
			intervals.push_back(4); // Major third
			intervals.push_back(7); // Perfect fifth
			intervals.push_back(14); // Major ninth (without seventh)
			break;
		default:
			// Default to major triad
			intervals.push_back(4); // Major third
			intervals.push_back(7); // Perfect fifth
			break;
	}

	return intervals;
}

std::vector<int> ChordOscillatorEngine::apply_inversion(const std::vector<int> &intervals, int inversion) const {
	std::vector<int> inverted = intervals;

	// Apply inversion (move notes up an octave)
	if (inversion > 0 && inversion < intervals.size()) {
		for (int i = 0; i < inversion; i++) {
			inverted[i] += 12; // Move up an octave
		}

		// Sort to maintain ascending order
		std::sort(inverted.begin(), inverted.end());
	}

	return inverted;
}

void ChordOscillatorEngine::set_parameter(const String &name, const Ref<ModulatedParameter> &param) {
	parameters[name] = param;
}

Ref<ModulatedParameter> ChordOscillatorEngine::get_parameter(const String &name) const {
	if (parameters.has(name)) {
		return parameters[name];
	}
	return Ref<ModulatedParameter>();
}

Dictionary ChordOscillatorEngine::get_parameters() const {
	return parameters;
}

PackedFloat32Array ChordOscillatorEngine::process_block(int buffer_size, const Ref<SynthNoteContext> &context) {
	// Create output buffer
	PackedFloat32Array output_buffer;
	output_buffer.resize(buffer_size);

	if (!context.is_valid()) {
		// Fill buffer with silence
		std::fill(output_buffer.ptrw(), output_buffer.ptrw() + buffer_size, 0.0f);
		UtilityFunctions::print("Silence buffer - No Context");
		return output_buffer;
	}

	// If no note is playing, return silence
	if (context->get_note() < 0 || context->get_velocity() <= 0.0f) {
		std::fill(output_buffer.ptrw(), output_buffer.ptrw() + buffer_size, 0.0f);
		UtilityFunctions::print("Silence buffer - note: " + String::num(context->get_note()) +
				" velocity: " + String::num(context->get_velocity()));
		return output_buffer;
	}

	// Calculate base frequency for the current note
	float base_frequency = get_frequency_for_note(context->get_note());

	// Apply pitch modulation if available
	if (parameters.has(ChordSynthConfiguration::PARAM_PITCH)) {
		Ref<ModulatedParameter> pitch_param = parameters[ChordSynthConfiguration::PARAM_PITCH];
		if (pitch_param.is_valid()) {
			float pitch_offset = pitch_param->get_value(context);
			// Convert semitone offset to frequency multiplier
			float pitch_multiplier = std::pow(2.0f, pitch_offset / 12.0f);
			base_frequency *= pitch_multiplier;
		}
	}

	// Calculate time increment per sample
	double time_increment = 1.0 / sample_rate;
	double current_time = context->get_absolute_time();

	// Pre-fetch parameter values
	float chord_type_value = 0.0f; // Default to major chord
	if (parameters.has(ChordSynthConfiguration::PARAM_CHORD_TYPE)) {
		Ref<ModulatedParameter> chord_param = parameters[ChordSynthConfiguration::PARAM_CHORD_TYPE];
		if (chord_param.is_valid()) {
			chord_type_value = chord_param->get_value(context);
		}
	}

	float inversion_value = 0.0f; // Default to root position
	if (parameters.has(ChordSynthConfiguration::PARAM_INVERSION)) {
		Ref<ModulatedParameter> inversion_param = parameters[ChordSynthConfiguration::PARAM_INVERSION];
		if (inversion_param.is_valid()) {
			inversion_value = inversion_param->get_value(context);
		}
	}

	float amplitude = 0.0f;
	if (parameters.has(ChordSynthConfiguration::PARAM_AMPLITUDE)) {
		Ref<ModulatedParameter> amp_param = parameters[ChordSynthConfiguration::PARAM_AMPLITUDE];
		if (amp_param.is_valid()) {
			amplitude = amp_param->get_value(context);
		}
	}

	float pulse_width = 0.5f; // Default to 50% duty cycle
	if (parameters.has(ChordSynthConfiguration::PARAM_PULSE_WIDTH)) {
		Ref<ModulatedParameter> pw_param = parameters[ChordSynthConfiguration::PARAM_PULSE_WIDTH];
		if (pw_param.is_valid()) {
			pulse_width = pw_param->get_value(context);
		}
	}

	// Store these values in the cache
	cached_chord_type = chord_type_value;
	cached_inversion = inversion_value;
	cached_amplitude = amplitude;
	cached_pulse_width = pulse_width;

	// Convert chord type value to integer index (0 to CHORD_MAX-1)
	int chord_type_index = static_cast<int>(chord_type_value * (CHORD_MAX - 1) + 0.5f);
	chord_type_index = std::max(0, std::min(chord_type_index, CHORD_MAX - 1));

	// Debug output for chord type
	static int chord_debug_counter = 0;
	if (chord_debug_counter++ % 100 == 0) {
		UtilityFunctions::print("Chord type value: " + String::num(chord_type_value) + 
				", index: " + String::num(chord_type_index));
	}

	// Get chord intervals
	std::vector<int> intervals;
	
	if (root_note_only) {
		// If root_note_only is enabled, only use the root note (0 semitones)
		intervals.push_back(0);
		UtilityFunctions::print("Root note only mode enabled - using only the root note");
	} else {
		intervals = get_chord_intervals(chord_type_index);
	}

	// Convert inversion value to integer (0 to max possible inversions)
	int max_inversions = intervals.size() - 1;
	int inversion_index = static_cast<int>(inversion_value * max_inversions + 0.5f);
	inversion_index = std::max(0, std::min(inversion_index, max_inversions));

	// Apply inversion
	std::vector<int> chord_notes = apply_inversion(intervals, inversion_index);

	// Get detune parameter
	float detune = 0.0f; // Default to no detune
	if (parameters.has(ChordSynthConfiguration::PARAM_DETUNE)) {
		Ref<ModulatedParameter> detune_param = parameters[ChordSynthConfiguration::PARAM_DETUNE];
		if (detune_param.is_valid()) {
			detune = detune_param->get_value(context);
		}
	}
	cached_detune = detune;

	// Calculate frequencies for all notes in the chord
	std::vector<float> frequencies;
	std::vector<float> phases;
	phases.resize(chord_notes.size(), 0.0f);

	// Initialize all phases to 0 - we'll use different waveforms instead of phase offsets
	for (size_t i = 0; i < chord_notes.size(); i++) {
		phases[i] = 0.0f;
	}

	for (size_t i = 0; i < chord_notes.size(); i++) {
		// Calculate the semitone offset from the root note
		float semitone_offset = static_cast<float>(chord_notes[i]);

		// Calculate the frequency for this note in the chord
		float note_freq = base_frequency * std::pow(2.0f, semitone_offset / 12.0f);

		// Apply a more significant detune to each note for richness and to prevent cancellation
		float fixed_detune = 3.0f + (i * 2.0f); // Larger fixed detune in cents per note
		float user_detune = cached_detune * 5.0f * (i + 1); // Amplified user controlled detune
		float detune_amount = fixed_detune + user_detune;
		float detune_multiplier = std::pow(2.0f, detune_amount / 1200.0f); // Convert cents to multiplier

		frequencies.push_back(note_freq * detune_multiplier);
	}

	// Debug output for frequencies
	if (chord_debug_counter % 100 == 0) {
		String freq_debug = "Chord notes: ";
		for (size_t i = 0; i < chord_notes.size(); i++) {
			freq_debug += String::num(chord_notes[i]) + " ";
		}
		UtilityFunctions::print(freq_debug);
		
		freq_debug = "Frequencies: ";
		for (size_t i = 0; i < frequencies.size(); i++) {
			freq_debug += String::num(frequencies[i]) + " Hz, ";
		}
		UtilityFunctions::print(freq_debug);
		
		UtilityFunctions::print("Chord type: " + String::num(chord_type_index) + 
				", Inversion: " + String::num(inversion_index));
	}

	// Debug output - only print occasionally to avoid flooding the console
	static int chord_freq_debug = 0;
	if (chord_freq_debug++ % 100 == 0) {
		UtilityFunctions::print("Root note: " + String::num(context->get_note()) +
				" Base frequency: " + String::num(base_frequency));
		for (size_t i = 0; i < frequencies.size(); i++) {
			UtilityFunctions::print("Chord note offset: " + String::num(chord_notes[i]) +
					" semitones, Frequency[" + String::num(i) + "]: " + String::num(frequencies[i]) +
					" Hz, Phase[" + String::num(i) + "]: " + String::num(phases[i]));
		}
	}

	// How often to update modulation values (every N samples)
	const int mod_update_rate = 1; // Update every 8 samples

	// Generate audio samples
	for (int i = 0; i < buffer_size; i++) {
		// Update context time for this sample
		context->update_time(current_time);

		// Only update modulation values periodically to save CPU
		if (i % mod_update_rate == 0) {
			// Get the amplitude parameter (controlled by ADSR)
			if (parameters.has(ChordSynthConfiguration::PARAM_AMPLITUDE)) {
				Ref<ModulatedParameter> amp_param = parameters[ChordSynthConfiguration::PARAM_AMPLITUDE];
				if (amp_param.is_valid()) {
					cached_amplitude = amp_param->get_value(context);
				}
			}

			// Get the pulse width parameter
			if (parameters.has(ChordSynthConfiguration::PARAM_PULSE_WIDTH)) {
				Ref<ModulatedParameter> pw_param = parameters[ChordSynthConfiguration::PARAM_PULSE_WIDTH];
				if (pw_param.is_valid()) {
					cached_pulse_width = pw_param->get_value(context);
				}
			}
		}

		// Mix all notes in the chord
		float mixed_sample = 0.0f;
		WaveHelperCache *cache = WaveHelperCache::get_singleton();

		// Scale factor to prevent clipping - reduce volume as more notes are added
		// Use a fixed scale factor to ensure consistent volume
		float scale_factor = 0.5f; // Increased for better audibility

		// Debug the first few samples of the first buffer
		bool debug_samples = (chord_debug_counter <= 1 && i < 5);
		
		if (debug_samples) {
			UtilityFunctions::print("--- Sample " + String::num(i) + " ---");
		}

		for (size_t j = 0; j < frequencies.size(); j++) {
			float phase_increment = frequencies[j] / sample_rate;
			phases[j] += phase_increment;
			if (phases[j] >= 1.0f) {
				phases[j] -= 1.0f;
			}

			// Use a different waveform for each note in the chord to prevent cancellation
			WaveHelper::WaveType note_waveform = waveform;
			
			// For sine waves, use different waveforms for each note to prevent cancellation
			if (waveform == WaveHelper::SINE) {
				// Use a different waveform for each note in the chord
				switch (j % 3) {
					case 0: note_waveform = WaveHelper::SINE; break;
					case 1: note_waveform = WaveHelper::TRIANGLE; break;
					case 2: note_waveform = WaveHelper::SINE; break;
				}
			}
			
			// Get sample for this note
			float note_sample;
			if (cache) {
				note_sample = cache->get_sample(phases[j], note_waveform, cached_pulse_width);
			} else {
				note_sample = WaveHelper::get_wave_sample(phases[j], note_waveform, cached_pulse_width);
			}
			
			// Debug waveform type occasionally
			if (i == 0 && j == 0 && chord_debug_counter % 100 == 0) {
				UtilityFunctions::print("Using waveform types: " + String::num_int64(waveform) + 
						" (base) and " + String::num_int64(note_waveform) + " (note " + String::num(j) + ")");
			}

			// Add to mix with proper scaling to avoid clipping
			mixed_sample += note_sample * scale_factor;
			
			if (debug_samples) {
				UtilityFunctions::print("  Note " + String::num(j) + ": phase=" + 
						String::num(phases[j]) + ", sample=" + String::num(note_sample));
			}
		}
		
		if (debug_samples) {
			UtilityFunctions::print("  Mixed sample: " + String::num(mixed_sample) + 
					", Amplitude: " + String::num(cached_amplitude));
		}

		// Apply amplitude (including ADSR envelope)
		float output_sample = mixed_sample * cached_amplitude * context->get_velocity();

		// Apply effects if available
		if (effect_chain.is_valid()) {
			output_sample = effect_chain->process_sample(output_sample, context);
		}

		output_buffer[i] = output_sample;

		// Increment time for next sample
		current_time += time_increment;
	}

	return output_buffer;
}

void ChordOscillatorEngine::initialize_chord_phases(std::vector<float> &phases, size_t count) {
	// Distribute phases evenly to avoid phase cancellation
	for (size_t i = 0; i < count; i++) {
		phases[i] = static_cast<float>(i) / count;
	}
}

void ChordOscillatorEngine::reset() {
	phase = 0.0f;
	cached_chord_type = 0.0f;
	cached_inversion = 0.0f;
	cached_amplitude = 0.0f;
	cached_pulse_width = 0.5f;
	cached_detune = 0.0f;

	// Reset the effect chain
	AudioStreamGeneratorEngine::reset();
}

void ChordOscillatorEngine::set_root_note_only(bool enabled) {
	root_note_only = enabled;
	UtilityFunctions::print("ChordOscillatorEngine: Root note only mode " + String(enabled ? "enabled" : "disabled"));
}

bool ChordOscillatorEngine::get_root_note_only() const {
	return root_note_only;
}

Ref<AudioStreamGeneratorEngine> ChordOscillatorEngine::duplicate() const {
	Ref<ChordOscillatorEngine> new_engine = memnew(ChordOscillatorEngine);

	// Copy waveform setting
	new_engine->set_waveform(waveform);
	
	// Copy root_note_only setting
	new_engine->set_root_note_only(root_note_only);

	// Copy sample rate
	new_engine->set_sample_rate(get_sample_rate());

	// Copy parameters
	Dictionary params = get_parameters();
	Array param_names = params.keys();
	for (int i = 0; i < param_names.size(); i++) {
		String name = param_names[i];
		Ref<ModulatedParameter> param = params[name];
		if (param.is_valid()) {
			Ref<ModulatedParameter> new_param = param->duplicate();
			UtilityFunctions::print("Copy Parameter: " + name);
			new_engine->set_parameter(name, new_param);
		}
	}

	// Duplicate the effect chain
	Ref<EffectChain> effect_chain = get_effect_chain();
	if (effect_chain.is_valid()) {
		Ref<EffectChain> new_chain = effect_chain->duplicate();
		new_engine->set_effect_chain(new_chain);
	}

	return new_engine;
}

void ChordOscillatorEngine::set_waveform(WaveHelper::WaveType p_type) {
	waveform = p_type;
}

WaveHelper::WaveType ChordOscillatorEngine::get_waveform() const {
	return waveform;
}

} // namespace godot
