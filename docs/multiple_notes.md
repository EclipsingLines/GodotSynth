# Playing Multiple Notes in the Same Frame

When using GodotSynth, you might want to play multiple notes simultaneously, such as when playing chords or complex musical passages. This document explains how to play multiple notes in the same frame.

## Background

Versions up to v0.95 had a bug ([#1](https://github.com/EclipsingLines/GodotSynth/issues/1)) where only the last note would play when several notes were started in the same frame:

```gdscript
# Before the fix only the last note played
play_note(65)
play_note(62)

func play_note(note: float) -> void:
    var context = synth.get_context()
    context.note_on(note, 1.0)
```

Each call to `get_context()` gave its voice an id taken from the current time in milliseconds, so notes started in the same millisecond got the same id and replaced each other. Voices now get unique ids, and the voice is handed to the audio thread through a note event queue, so the code above plays both notes.

Always get **one context per note**. A context represents a single note, and calling `note_on` several times on the same context retriggers that one note instead of adding new ones.

## Solution 1: Using the Queue System (Recommended)

`AudioSynthPlayer.play_note_on_context(context, note, velocity)` queues the note-on as an event. The audio thread applies all queued events at the start of the next audio block, in the order they were queued, so every note of a chord starts on the same sample.

```gdscript
# Get a context for each note
var context1 = synth.get_context()
var context2 = synth.get_context()
var context3 = synth.get_context()

# These are queued and all start together in the next audio block
synth.play_note_on_context(context1, 60, 1.0)  # C4
synth.play_note_on_context(context2, 64, 1.0)  # E4
synth.play_note_on_context(context3, 67, 1.0)  # G4
```

Release queued notes with `play_note_off_context`, so the note-off is applied after the note-on it belongs to:

```gdscript
synth.play_note_off_context(context1)
synth.play_note_off_context(context2)
synth.play_note_off_context(context3)
```

## Solution 2: Using note_on_deferred

`SynthNoteContext.note_on_deferred(note, velocity)` and `note_off_deferred()` do the same thing as the player methods, called on the context itself:

```gdscript
var notes = [60, 64, 67]  # C major chord
var contexts = []
for note in notes:
    var context = synth.get_context()
    context.note_on_deferred(note, 1.0)
    contexts.append(context)

# Later
for context in contexts:
    context.note_off_deferred()
```

If the context was not created by an `AudioSynthPlayer` (or that player has been freed), `note_on_deferred` and `note_off_deferred` fall back to the immediate `note_on` / `note_off`.

## Solution 3: Calling note_on directly

Calling `note_on` directly on each context also plays every note, as of the fix for #1:

```gdscript
for note in [60, 64, 67]:
    var context = synth.get_context()
    context.note_on(note, 1.0)
```

The difference is that `note_on` changes the context immediately on the main thread, while the queued methods apply the change on the audio thread at a block boundary. Prefer the queued methods when you also send note-offs in the same frame, or when the notes must start together.

## Older workarounds

On v0.95 and earlier, the only way to play several notes in the same frame was to spread them over frames, either with `call_deferred("play_note", 60)` or with `await get_tree().create_timer(0.0).timeout` between notes. These still work but are no longer needed.

## Timing

Queued events take effect at the start of the next audio block, so their timing is quantised to the audio buffer size. Sample-accurate scheduling of note-on and note-off at a given time is tracked in [#2](https://github.com/EclipsingLines/GodotSynth/issues/2); the queue is designed so that events can carry a timestamp later.

## Best Practices

1. **Get a context for each note** you want to play.
2. **Use `play_note_on_context` / `play_note_off_context`** (or `note_on_deferred` / `note_off_deferred`) to play chords and to send note-ons and note-offs in the same frame.
3. Keep a reference to each context for as long as you need to release or modulate its note.

## Example

`project/issue_1.gd` (scene `project/issue_1.tscn`) plays a three-note chord with direct `note_on` calls and then a second chord with `play_note_on_context`, all within a single frame each.
