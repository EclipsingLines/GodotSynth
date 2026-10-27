# Playing Multiple Notes in the Same Frame

When using GodotSynth, you might want to play multiple notes simultaneously, such as when playing chords or complex musical passages. This document explains how to properly play multiple notes in the same frame.

## The Issue

Some users have reported an issue where only the last note would play when trying to play multiple notes in the same frame:

```gdscript
# This doesn't work as expected - only the last note plays
play_note(65)
play_note(62)
```

This happens because each call to `get_context()` allocates a new voice with the same timestamp, and only the last one effectively gets processed by the audio system.

## Solution 1: Using the Queue System (Recommended)

GodotSynth now includes a note queue system that handles multiple note activations within the same frame. This ensures that all notes are processed in the correct order, even if they were activated simultaneously.

To use this system, get a context for each note you want to play, and then use the `play_note_on_context` method:

```gdscript
# Get contexts for each note
var context1 = synth.get_context()
var context2 = synth.get_context()
var context3 = synth.get_context()

# Play notes on each context
# These will all be queued and processed in the next audio frame
synth.play_note_on_context(context1, 60, 1.0)  # C4
synth.play_note_on_context(context2, 64, 1.0)  # E4
synth.play_note_on_context(context3, 67, 1.0)  # G4

# All three notes will play simultaneously
```

This approach is recommended as it's more direct and clearly expresses the intent to play multiple notes.

## Solution 2: Using note_on_deferred

An alternative approach is to use the `note_on_deferred` method on the context, which defers the function call to the end of the frame:

```gdscript
# Get a context
var context = synth.get_context()

# Play notes using note_on_deferred
context.note_on_deferred(60, 1.0)  # C4
context.note_on_deferred(64, 1.0)  # E4
context.note_on_deferred(67, 1.0)  # G4
```

This approach also works and is simpler than using the queue system directly.

## Solution 3: Using call_deferred

Another approach is to use Godot's `call_deferred` method, which defers the function call to the end of the frame:

```gdscript
call_deferred("play_note", 60)  # C4
call_deferred("play_note", 64)  # E4
call_deferred("play_note", 67)  # G4

func play_note(note: int) -> void:
    var context = synth.get_context()
    context.note_on(note, 1.0)
```

This approach also works but is less direct than using the queue system or `note_on_deferred`.

## Solution 4: Using a Timer

Another approach is to add a tiny delay between note activations:

```gdscript
play_note(65)
await get_tree().create_timer(0.0).timeout
play_note(62)
```

This forces the engine to process the first note before starting the second one. While this works, it's less efficient than the queue system and can lead to timing issues in complex musical passages.

## Best Practices

1. **Use the queue system or `note_on_deferred`** for playing multiple notes in the same frame
2. **Get a context for each note** you want to play (when using the queue system)
3. **Use `play_note_on_context`** to queue each note for activation (when using the queue system)
4. **Avoid using `note_on` directly** on contexts when playing multiple notes in the same frame

## Example

See the `multiple_notes_example.gd` file in the project directory for a complete example of how to use the queue system and `note_on_deferred` to play multiple notes in the same frame.
