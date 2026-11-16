---
layout: custom_default
title: Cue Language Reference
---

# Cue Language Reference

A cue is a text file that describes adaptive game music. It writes patterns in a Strudel-style mini-notation, combines them into states, and switches between states with quantized transitions, stingers, game params and binds. One cycle is one bar. Check a file with `tools/cue_check.gd` and render it with `tools/cue_render.gd`.

## 1. A complete example

```cue
// forest.cue
tempo 96
seed 7
param danger 0..1 = 0
param depth = 0

let bass = n("0 ~ 0 3").scale("D:minor").s("bass").lpf(900)
let drums = stack(s("kick(3,8)"), s("~ snare").gain(0.8), s("hat*8").degradeBy(0.3))

state explore:
  bass
  n("<0 2 4 [6 4]>").scale("D4:minor").s("pad").slow(2)
  s("hat*4").gain(game("danger"))

state combat:
  bass.fast(2)
  drums
  n("0 3 5 7").scale("D4:minor").s("lead")
    .every(4, rev())
    .gain(sine.range(0.5, 1).slow(4))

transition explore -> combat on bar fade 1 fill s("hat")
transition * -> explore on 4 bars fade 2

stinger found on beat: n("0 4 7 12").scale("D4:major").s("lead").fast(4)
bind pad.lpf <- danger 400..4000
```

- The initial state is the first state declared, `explore`; `combat` replaces it when the transition fires.
- `bass` is a `let`, so both states reuse the same pattern, and `combat` plays it faster.
- `game("danger")` reads the numeric param `danger` at query time, so the hats follow the game.
- Two transitions: `explore -> combat` on the next bar with a one-cycle crossfade and a hat fill, and any state back to `explore` every four bars.
- A stinger, `found`, plays once on the next beat, while `bind` maps `danger` onto the pad's low-pass cutoff.

## 2. Lexical rules

- The language is line-oriented: a statement ends at a newline. The loader appends a final newline to the file and strips `\r`.
- A comment starts with `//` and runs to the end of the line. There are no block comments.
- Identifiers match `[a-zA-Z_][a-zA-Z0-9_]*`. Function names are camelCase (`degradeBy`), and user names (let, state, param, stinger) match `[a-z_][a-z0-9_]*` and must not be a keyword or a library function (`E_RESERVED`).
- Keywords are `tempo seed let param state transition stinger bind on fade fill len now beat bar bars beats`.
- Numbers match `-?[0-9]+(\.[0-9]+)?`.
- Strings are double-quoted, have no escapes and no newlines, and every string is mini-notation: a name such as `"danger"` or a scale such as `"C:minor"` is a one-atom mini sequence.
- Whitespace between tokens is free, but newlines are only allowed inside `( ... )` and before a continuation line that starts with `.`.

## 3. Statements

| Statement | Form | Meaning |
|---|---|---|
| `tempo` | `tempo 120` or `tempo 90 3/4` | BPM with an optional meter. One cycle is one bar, the default is `tempo 120 4/4`, and cps = bpm / 60 / beats per bar. The denominator is informational. At most one per file. |
| `seed` | `seed 42` | Seed of every random function (default 0). At most one per file. |
| `let` | `let name = expr` | Binds a pattern or a transform. Lets are resolved in file order, so a forward reference is an error (`E_UNKNOWN_IDENT`). |
| `param` | `param name lo..hi = default` or `param name = default` | A numeric game param. The range defaults to `0..1`, and the default must lie inside it (`E_RANGE`). |
| `state` | `state name:` then layer lines | Each layer line is exactly two spaces and then an expression. Blank and comment lines may sit between layers. The state plays the `stack` of its layers. A file needs at least one state (`E_NO_STATE`), and the first state declared is the initial one. |
| `transition` | `transition from -> to [on Q] [fade F] [fill expr]` | A switch rule. `from` is a state name or `*`; the clauses are optional and in that order. |
| `stinger` | `stinger name [on Q] [len L]: expr` | A one-shot quantized pattern played for `len` cycles (default 1). |
| `bind` | `bind inst.control <- param [lo..hi]` | Continuously maps a param onto an instrument control. The control range defaults to the catalog's range for that control. |

Quantization `Q` is one of: `now` (the next scheduler window edge), `beat` (the next multiple of 1 / beats-per-bar cycle), `bar` (the next whole cycle), `N bars` (the next global cycle that is a multiple of N, counted from cue start), or `N beats`. Transitions default to `on bar` and stingers to `on beat`.

## 4. Mini-notation

| Syntax | Meaning |
|---|---|
| `a b c` | A sequence; the steps share the cycle equally. |
| `~` | A rest. |
| `[a b]` | A subsequence crammed into one step. |
| `<a b c>` | One item per cycle. |
| `a*2`, `a*<2 3>` | Fast: repeat the step, or cycle through the factors. |
| `a/2` | Slow. |
| `a!3`, `a !` | Replicate (`a!` is `a!2`; a bare `!` step repeats the previous step). |
| `a@3` | Weight: give the step more of the cycle. |
| `a?`, `a?0.3` | Drop the step with probability 0.5 or 0.3, seeded. |
| `a b \| c d` | Pick one alternative per cycle, seeded. |
| `a b, c d` | Stack, at the top level or inside `[]` or `<>`. |
| `a(3,8)`, `a(3,8,2)` | Euclidean rhythm: k onsets over n steps, rotated left by r. |
| `bd:3`, `C:minor` | The `:` suffix, used as a variant index or a scale mode. |
| `c4 eb3 f#5 a` | Note names, with octave default 3. |
| `0 -3 2.5` | Numbers. |

Not in v1: `_` elongation, `.` foot grouping, `{}` polymeter, `%` steps per cycle, and nested modifiers on factors other than a number or `<seq>`.

Euclid test vectors: `(3,8)` = `1 0 0 1 0 0 1 0`, `(5,8)` = `1 0 1 1 0 1 1 0`, `(3,8,2)` = `0 1 0 0 1 0 1 0`.

Atom typing: in `s()` the atom `kick:2` gives `{s: "kick", n: 2}`; in `note()` a name gives a MIDI note (`c4` = 60, accidentals `#`, `s` = sharp, `b` = flat) and a number is MIDI; in `n()` an atom is a number, either a scale degree or a semitone offset from C4 when there is no scale (with warning `W_N_WITHOUT_SCALE`); in a numeric argument an atom is a number; in `scale()` an atom is `root[octave]:mode`.

## 5. Expressions and functions

A grammar sketch:

```
expr := primary ( "." call )*
primary := call | name | string | number | "(" expr ")"
```

A chain link always has parentheses (`.rev()`).

A constructor called free returns a pattern (`s("kick")`, `stack(a, b)`). A method called free returns a *transform*, a function from pattern to pattern (`fast(2)`, `rev()`), and a chain on a transform composes (`fast(2).rev()`). A transform appears only where a function expects one (`every(4, fast(2))`), which replaces JS arrow functions. A bare name is a let, a no-argument constructor (`silence`, `sine`, `rand`) or a no-argument transform (`rev`, `degrade`). Kinds are checked by the validator (`E_KIND`).

Patterned arguments: every numeric argument of a method accepts a number, a mini string (`fast("<1 2>")`) or a pattern or signal (`gain(sine.range(0.3, 1))`, `gain(game("danger"))`). Time-shaping functions (`fast slow early late ply segment iter euclid`) use innerJoin; controls use appLeft (structure from the receiver, the argument sampled at each hap's whole begin).

<!-- BEGIN GENERATED FUNCTIONS -->
| Name | Kind | Signature |
|---|---|---|
| `add` | method | `add(numeric)` |
| `almostAlways` | method | `almostAlways(transform)` |
| `almostNever` | method | `almostNever(transform)` |
| `attack` | method | `attack(numeric)` |
| `cat` | constructor | `cat(pattern...)` |
| `decay` | method | `decay(numeric)` |
| `degrade` | method | `degrade()` |
| `degradeBy` | method | `degradeBy(numeric)` |
| `detune` | method | `detune(numeric)` |
| `early` | method | `early(numeric)` |
| `euclid` | method | `euclid(numeric, numeric)` |
| `euclidRot` | method | `euclidRot(numeric, numeric, numeric)` |
| `every` | method | `every(numeric, transform)` |
| `fast` | method | `fast(numeric)` |
| `gain` | method | `gain(numeric)` |
| `game` | constructor | `game(string)` |
| `hpf` | method | `hpf(numeric)` |
| `irand` | signal | `irand(numeric)` |
| `iter` | method | `iter(numeric)` |
| `late` | method | `late(numeric)` |
| `legato` | method | `legato(numeric)` |
| `lpf` | method | `lpf(numeric)` |
| `lpq` | method | `lpq(numeric)` |
| `mask` | method | `mask(numeric)` |
| `n` | constructor, method | `n(numeric)` |
| `note` | constructor, method | `note(numeric)` |
| `off` | method | `off(numeric, transform)` |
| `often` | method | `often(transform)` |
| `palindrome` | method | `palindrome()` |
| `pan` | method | `pan(numeric)` |
| `perlin` | signal | `perlin` |
| `ply` | method | `ply(numeric)` |
| `rand` | signal | `rand` |
| `range` | method | `range(numeric, numeric)` |
| `rarely` | method | `rarely(transform)` |
| `release` | method | `release(numeric)` |
| `rev` | method | `rev()` |
| `run` | constructor | `run(numeric)` |
| `s` | constructor, method | `s(string)` |
| `saw` | signal | `saw` |
| `scale` | method | `scale(string)` |
| `segment` | method | `segment(numeric)` |
| `seq` | constructor | `seq(pattern...)` |
| `silence` | constructor | `silence` |
| `sine` | signal | `sine` |
| `slow` | method | `slow(numeric)` |
| `someCycles` | method | `someCycles(transform)` |
| `someCyclesBy` | method | `someCyclesBy(numeric, transform)` |
| `sometimes` | method | `sometimes(transform)` |
| `sometimesBy` | method | `sometimesBy(numeric, transform)` |
| `square` | signal | `square` |
| `stack` | constructor | `stack(pattern...)` |
| `struct` | method | `struct(numeric)` |
| `superimpose` | method | `superimpose(transform)` |
| `sustain` | method | `sustain(numeric)` |
| `transpose` | method | `transpose(numeric)` |
| `tri` | signal | `tri` |
| `velocity` | method | `velocity(numeric)` |
<!-- END GENERATED FUNCTIONS -->

What the groups do:

- Constructors: `s n note stack cat seq silence run game` make patterns, sounds, notes or stacks from their arguments.
- Signals: `sine saw tri square rand perlin irand` are 0..1 continuous signals; use them with `.range(lo, hi)`, `.segment(k)` and `.slow(k)`.
- Time: `fast slow early late ply rev palindrome iter segment range` change when and how often events happen.
- Structure: `struct mask euclid euclidRot` reshape the rhythm of a pattern.
- Random (seeded): `degrade degradeBy sometimesBy sometimes often rarely almostNever almostAlways someCyclesBy someCycles` drop or keep events; the `sometimes*` shortcuts use probabilities 0.5, 0.75, 0.25, 0.1 and 0.9, and `someCycles` uses 0.5.
- Higher-order: `every(k, t)` applies transform t when the cycle count mod k is 0, `superimpose(t)` layers t of the pattern on top of it, and `off(c, t)` superimposes t of a copy shifted late by c.
- Pitch: `scale transpose add` map scale degrees, transpose by semitones or add to numbers.
- Controls: `s n note gain velocity legato lpf hpf lpq attack decay sustain release pan detune` set notes and controls; which of them an instrument accepts is in section 8.

Scales are written `root[octave]:mode` with octave default 3: `major minor dorian phrygian lydian mixolydian locrian harmonicMinor melodicMinor majPent minPent blues chromatic`. Degrees index the scale and wrap into octaves both ways, so degree -1 in `C:major` is B2.

Hap values and scheduling: a note's length is its whole's duration times `legato` (default 1), `velocity` defaults to 0.8, `gain` multiplies velocity, and controls go through the instrument's control map. Randomness: every draw is a hash of the seed, the call site's ordinal in the file and the cycle position, so the same file, seed and time give the same events offline and live.

## 6. Runtime semantics

- The global cycle is 0 at play. Entering a state at switch point `t0` restarts its patterns: layers are queried at `cycle - t0`.
- `set_state(b)` picks the rule `a -> b`, else `* -> b`, else the default (`on bar`, no fade, no fill).
- The switch point is the next quant boundary at or after the end of the already scheduled window, so events already handed to the audio thread are never rewritten. A new request before the pending switch is applied replaces it (last request wins).
- Crossfade (`fade F` cycles): the old state keeps playing its own timeline, its group gain follows `cos(x*pi/2)` and the new state's `sin(x*pi/2)` for x in 0..1 over F cycles (approximated with 16 linear gain ramps), then the old state stops. `fade 0` is a hard cut, and notes already started still release normally.
- Fill: plays its first `max(1, F)` cycles from the switch point, layered on the new state.
- Stingers: `stinger(name)` plays at the next Q boundary for `len` cycles, layered. Retriggering restarts it, and a stinger does not change the state.
- Params: `set_param` clamps into the param's range, `game("name")` reads the value current at query time, and an unknown param name is a validator error.
- Binds: the bound value is `lerp(lo, hi, (v - pmin) / (pmax - pmin))`, applied once per scheduler window (only when it changed) to every player of that instrument. A pattern that sets a control also bound on that instrument is `E_BIND_CONFLICT`.
- Players are created per (group, instrument) at load, where the group is a state name, `transitions` or `stingers`.

## 7. Diagnostics

Every diagnostic is `{code, message, line, col, severity}` with 1-based line and col.

| Code | Meaning |
|---|---|
| `E_SYNTAX` | The source does not parse. |
| `E_UNKNOWN_IDENT` | A name is not a let and not a known function. |
| `E_UNKNOWN_FUNCTION` | A call names a function the library does not have. |
| `E_UNKNOWN_INSTRUMENT` | `s()` names an instrument that is not in the catalog. |
| `E_UNKNOWN_CONTROL` | A control is not available on that instrument. |
| `E_UNKNOWN_STATE` | A transition or `set_state` names a state that is not declared. |
| `E_UNKNOWN_PARAM` | `game()` or a bind names a param that is not declared. |
| `E_UNKNOWN_SCALE` | A `scale()` string names an unknown scale. |
| `E_ARITY` | A function is called with too few or too many arguments. |
| `E_ARG_TYPE` | An argument has the wrong type, for example a number where a string is required. |
| `E_KIND` | A pattern is used where a transform is required, or the other way round. |
| `E_DUPLICATE` | A name is declared twice. |
| `E_RESERVED` | A user name is a keyword or a library function. |
| `E_RANGE` | A param default, tempo or range is out of bounds. |
| `E_NO_STATE` | The file declares no state. |
| `E_BIND_CONFLICT` | A bind targets a control that a pattern also sets on the same instrument. |
| `E_MINI` | A mini-notation semantic error such as Euclidean `n = 0`. A mini syntax error is `E_SYNTAX` at the string's column plus the offset inside it. |
| `W_N_WITHOUT_SCALE` | `n()` is used without `scale()`. |
| `W_UNUSED_LET` | A let is never used. |

`tools/cue_check.gd` prints one JSON line per file, and `tools/cue_render.gd` renders a cue plus a scenario to WAV.

## 8. Instruments

Instruments come from the catalog. The table columns are `name | role | tags | controls | description`. The controls `gain velocity legato` work on every instrument, `lpf hpf lpq` exist only where the preset has that filter, and `attack decay sustain release pan detune` are not available and are reported as `E_UNKNOWN_CONTROL`.

<!-- BEGIN GENERATED INSTRUMENTS -->
```text
arp | arp | plucky, bright | gain, velocity, legato | Plucky arpeggio voice: pulse, triangle and sine layers, band-pass filter, ping-pong delay.
bass | bass | low, warm | gain, velocity, legato, lpf, lpq | Low bass: square, sine and triangle layers, low-pass filter, light overdrive.
hat | drums | bright, noisy, short | gain, velocity, legato, hpf | Closed hi-hat: noise and square layers, high-pass filter, bitcrush.
kick | drums | punchy, low | gain, velocity, legato, lpf, lpq | Kick drum: sine and square body with a noise click, fast pitch drop, low-pass filter, clip distortion.
lead | lead | bright, sustained | gain, velocity, legato | Bright lead: pulse, sine and triangle layers, band-pass filter, vibrato, ping-pong delay.
pad | pad | soft, slow, ambient | gain, velocity, legato, lpf, lpq | Slow pad: 1.5 s attack, 2 s release, sine and triangle layers, low-pass filter, reverb.
snare | drums | punchy, noisy | gain, velocity, legato, hpf | Snare drum: noise and square layers, high-pass filter, clip distortion, short reverb.
```
<!-- END GENERATED INSTRUMENTS -->
