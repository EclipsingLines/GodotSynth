#pragma once
#include <godot_cpp/classes/resource.hpp>

namespace godot {

/**
 * @brief Manages the state and timing information for a synthesizer note.
 *
 * SynthNoteContext tracks the lifecycle of a note from creation through
 * active playing, release, and eventual cleanup. It provides timing information
 * for modulation sources and maintains the note's current state.
 */
class SynthNoteContext : public Resource {
	GDCLASS(SynthNoteContext, Resource);

public:
	/**
	 * @brief States in the note lifecycle.
	 *
	 * Represents the different states a note can be in during its lifecycle:
	 * - READY: Initial state, note is ready to be played
	 * - ACTIVE: Note is currently playing
	 * - RELEASING: Note has been released and is in release phase
	 * - RELEASED: Note has completed its release phase
	 * - FINISHED: Note is completely finished and can be removed
	 */
	enum NoteState {
		NOTE_STATE_READY,
		NOTE_STATE_ACTIVE,
		NOTE_STATE_RELEASING,
		NOTE_STATE_RELEASED,
		NOTE_STATE_FINISHED
	};

private:
	int64_t voice_id; ///< Unique identifier for the voice playing this note
	double absolute_time = 0.0; ///< Current absolute time in seconds
	double note_time = 0.0; ///< Time in seconds since note_on was called
	int note = 60; ///< MIDI note number (0-127)
	float velocity = 1.0f; ///< Note velocity (0.0-1.0)
	float articulation = 1.0f; ///< Note articulation (freely assignable)
	bool is_note_active = false; ///< Whether the note is currently active (not released)
	bool is_note_triggered = false; ///< Tracks if a note has just been triggered (true for first frame only)
	double note_on_time = 0.0; ///< Absolute time when note_on was called
	double note_off_time = -1.0; ///< Absolute time when note_off was called
	bool _is_releasing = false; ///< Whether the note is in release phase
	bool _is_fully_released = false; ///< Whether the note has fully released (amplitude below threshold)
	float release_level = 0.0f; ///< Amplitude level at the start of release
	float release_threshold = 0.001f; ///< When amplitude falls below this, consider fully released
	float current_amplitude = 1.0f; ///< Current amplitude of the note
	NoteState note_state = NOTE_STATE_READY; ///< Current state in the note lifecycle
	bool has_active_tail = false; ///< Whether the note has active effect tails (e.g., reverb, delay)

protected:
	static void _bind_methods();

public:
	/**
	 * @brief Constructor for SynthNoteContext.
	 *
	 * Initializes a new note context in the READY state.
	 */
	SynthNoteContext();

	/**
	 * @brief Destructor for SynthNoteContext.
	 */
	~SynthNoteContext();

	/**
	 * @brief Sets the voice ID for this note context.
	 * @param p_voice_id The unique identifier for the voice.
	 */
	void set_voice_id(const int64_t p_voice_id);

	/**
	 * @brief Gets the voice ID for this note context.
	 * @return The voice ID.
	 */
	int64_t get_voice_id() const;

	/**
	 * @brief Sets the absolute time for this context.
	 * @param p_time The absolute time in seconds.
	 */
	void set_absolute_time(double p_time);

	/**
	 * @brief Gets the absolute time for this context.
	 * @return The absolute time in seconds.
	 */
	double get_absolute_time() const;

	/**
	 * @brief Sets the note time (time since note_on).
	 * @param p_time The note time in seconds.
	 */
	void set_note_time(double p_time);

	/**
	 * @brief Gets the note time (time since note_on).
	 * @return The note time in seconds.
	 */
	double get_note_time() const;

	/**
	 * @brief Sets the release level (amplitude at start of release).
	 * @param p_release_level The release level (0.0-1.0).
	 */
	void set_release_level(float p_release_level);

	/**
	 * @brief Gets the release level.
	 * @return The release level (0.0-1.0).
	 */
	float get_release_level() const;

	/**
	 * @brief Sets the MIDI note number.
	 * @param p_note The MIDI note number (0-127).
	 */
	void set_note(int p_note);

	/**
	 * @brief Gets the MIDI note number.
	 * @return The MIDI note number.
	 */
	int get_note() const;

	/**
	 * @brief Sets the note velocity.
	 * @param p_velocity The velocity (0.0-1.0).
	 */
	void set_velocity(float p_velocity);

	/**
	 * @brief Gets the note velocity.
	 * @return The velocity (0.0-1.0).
	 */
	float get_velocity() const;

	/**
	 * @brief Sets the note articulation.
	 * @param p_articulation The articulation value.
	 */
	void set_articulation(float p_articulation);

	/**
	 * @brief Gets the note articulation.
	 * @return The articulation value.
	 */
	float get_articulation() const;

	/**
	 * @brief Sets whether the note is active.
	 * @param p_on True if the note is active, false otherwise.
	 */
	void set_note_active(bool p_on);

	/**
	 * @brief Checks if the note is on (active).
	 * @return True if the note is on, false otherwise.
	 */
	bool get_is_note_on() const;

	/**
	 * @brief Checks if the note was just triggered.
	 * @return True if the note was just triggered, false otherwise.
	 */
	bool get_is_note_triggered() const;

	/**
	 * @brief Sets whether the note is on.
	 * @param p_on True if the note is on, false otherwise.
	 */
	void set_is_note_on(bool p_on) { is_note_active = p_on; }

	/**
	 * @brief Sets whether the note was just triggered.
	 * @param p_triggered True if the note was just triggered, false otherwise.
	 */
	void set_is_note_triggered(bool p_triggered) { is_note_triggered = p_triggered; }

	/**
	 * @brief Checks if the note is off.
	 * @return True if the note is off, false otherwise.
	 */
	bool is_note_off() const { return !is_note_active; }

	/**
	 * @brief Sets the note-on time.
	 * @param p_time The absolute time when note_on was called.
	 */
	void set_note_on_time(double p_time);

	/**
	 * @brief Gets the note-on time.
	 * @return The absolute time when note_on was called.
	 */
	double get_note_on_time() const;

	/**
	 * @brief Sets the note-off time.
	 * @param p_time The absolute time when note_off was called.
	 */
	void set_note_off_time(double p_time);

	/**
	 * @brief Gets the note-off time.
	 * @return The absolute time when note_off was called.
	 */
	double get_note_off_time() const;

	/**
	 * @brief Activates a note with the specified parameters.
	 * @param p_note The MIDI note number (0-127).
	 * @param p_velocity The velocity (0.0-1.0).
	 */
	void note_on(int p_note, float p_velocity);

	/**
	 * @brief Releases a note at the specified time.
	 * @param p_time The absolute time to release the note.
	 */
	void note_off(float p_time);

	/**
	 * @brief Updates the context's time and handles state transitions.
	 * @param p_absolute_time The new absolute time.
	 */
	void update_time(double p_absolute_time);

	/**
	 * @brief Starts the release phase for this note.
	 * @param p_time The absolute time to start the release.
	 */
	void start_release(double p_time);

	/**
	 * @brief Gets the current amplitude of the note.
	 * @return The current amplitude (0.0-1.0).
	 */
	float get_amplitude() const;

	/**
	 * @brief Updates the current amplitude of the note.
	 * @param amplitude The new amplitude value (0.0-1.0).
	 */
	void update_amplitude(float amplitude);

	/**
	 * @brief Checks if the note is in the release phase.
	 * @return True if the note is releasing, false otherwise.
	 */
	bool is_releasing() const;

	/**
	 * @brief Checks if the note has fully released.
	 * @return True if the note has fully released, false otherwise.
	 */
	bool is_fully_released() const;

	/**
	 * @brief Resets the release state of the note.
	 */
	void reset_release_state();

	/**
	 * @brief Resets the context to its initial state.
	 */
	void reset();

	/**
	 * @brief Sets the current state of the note.
	 * @param p_state The new state.
	 */
	void set_note_state(NoteState p_state);

	/**
	 * @brief Gets the current state of the note.
	 * @return The current state.
	 */
	NoteState get_note_state() const;

	/**
	 * @brief Gets the name of the current state as a string.
	 * @return The state name.
	 */
	String get_note_state_name() const;

	/**
	 * @brief Checks if the note is in the READY state.
	 * @return True if the note is ready, false otherwise.
	 */
	bool is_note_ready() const;

	/**
	 * @brief Checks if the note is in the ACTIVE state.
	 * @return True if the note is active, false otherwise.
	 */
	bool is_note_active_state() const; // Renamed to avoid conflict with existing is_note_active

	/**
	 * @brief Checks if the note is in the RELEASING state.
	 * @return True if the note is releasing, false otherwise.
	 */
	bool is_note_releasing() const;

	/**
	 * @brief Checks if the note is in the RELEASED state.
	 * @return True if the note is released, false otherwise.
	 */
	bool is_note_released() const;

	/**
	 * @brief Checks if the note is in the FINISHED state.
	 * @return True if the note is finished, false otherwise.
	 */
	bool is_note_finished() const;

	/**
	 * @brief Sets whether the note has active effect tails.
	 * @param p_has_tail True if the note has active tails, false otherwise.
	 */
	void set_has_active_tail(bool p_has_tail);

	/**
	 * @brief Checks if the note has active effect tails.
	 * @return True if the note has active tails, false otherwise.
	 */
	bool get_has_active_tail() const;
};

} // namespace godot
VARIANT_ENUM_CAST(SynthNoteContext::NoteState);
