# Cue prompt pack

This folder holds a provider-neutral prompt pack that teaches a chat-style language model to write cue files for the adaptive game-music engine. It contains no vendor-specific markup, tool calls or model configuration: it is plain text that any chat endpoint can take.

## Files

- `system.md`: the system prompt, with the language rules and examples of common mistakes.
- `examples/`: six request and cue pairs, one `.cue` file per request.
- `pack.json`: the manifest. It names the system file, says whether to append the instrument catalog table, and lists the examples in prompt order.
- `README.md`: this file.

The instrument table is not copied into `system.md`. The assembler appends the table from the real catalog, so the prompt follows the catalog when instruments or controls change.

## Using the pack

Build the whole prompt with `CuePrompt` from GDScript:

```gdscript
const PromptScript = preload("res://addons/godot_synth/cue/cue_prompt.gd")
var prompt: Dictionary = PromptScript.build("A calm forest at night.")
```

`prompt.system` is the system message and `prompt.messages` is the conversation: alternating user and assistant example messages, ending with the new request. Send `system` as the system message and `messages` as the conversation.

To use a plain text box instead, print the whole packed prompt as one block:

```bash
godot --headless --path project -s ../tools/cue_prompt.gd -- --request "A calm forest at night."
```

Godot prints its version banner first. The block starts with `=== SYSTEM ===` and ends with the request. Paste it into the text box.

## Checking a reply

Save the reply as a `.cue` file and check it against the real catalog:

```bash
godot --headless --path project -s ../tools/cue_check.gd -- <file.cue>
```

Render it to audio with `tools/cue_render.gd` when you want to hear it.

## Adding an example

1. Add a `.cue` file under `examples/`. It must pass the checker with no diagnostics.
2. Add its request and file name to `pack.json` in the order it should appear.
3. Run `bash tests/verify.sh --no-build tests/test_cue_prompt.gd` from the repository root.
