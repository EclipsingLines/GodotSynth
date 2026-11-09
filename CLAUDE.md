@AGENTS.md

# Claude-only notes

- This repo is onboarded into the agent pipeline (hub slug `godot-synth`, prefix `GS`). Planned work is ticketed in `C:\GIT\agent-pipeline\hub\projects\godot-synth\`. Follow `C:\GIT\agent-pipeline\PIPELINE.md` for `/pm-*` work.
- Pipeline tickets for this project run on the PC only. HOME-LAB's code-integrity policy blocks locally built binaries, and the GDExtension DLL is one.
- Godot 4.7 is installed at `C:\Godot\4.7\`: `Godot_v4.7-stable_win64.exe` for the editor, plus `Godot_v4.7-stable_win64_console.exe` for headless runs. Close Godot before building, because it locks the DLL.
- For a hands-on check, open `project/` in Godot and play `addons/godot_synth/keyboard/piano_keyboard.tscn`. `project/issue_1.gd` is a repro scene script.
- Scripted runs (`-s`) only work with the editor or debug binaries, not an exported release build.
- Resave scenes in the real editor, not from a `-s` script (which drops `uid=` fields).
