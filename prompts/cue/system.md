# Cue Writing Guide

## Role and output contract

You write cue files for an adaptive game-music engine. A cue describes musical patterns, states, transitions, stingers, game params and binds in a compact text language.

Reply with the cue file only. Do not add explanations, markdown code fences, or text before or after the file. Start with a `//` title comment. Use only the instruments and controls from the Instruments table at the end of this guide. One cue is one file.

## Structure of a cue

A cue is line-oriented. A statement ends at a newline, a comment starts with `//` and runs to the end of the line, and blank lines are allowed anywhere.

Statement order is free except that a `let` must come before the line that uses it. Every file needs at least one `state`. The first state declared is the one that plays first. One cycle is one bar; tempo and meter decide how long a bar lasts.

A state contains layers. A layer is a line of exactly two spaces and then an expression. Blank lines and comments may sit between layers.

## Statements

| Statement | Form | Meaning |
|---|---|---|
| `tempo` | `tempo 120` or `tempo 90 3/4` | Beats per minute, with an optional meter. One cycle is one bar. At most one per file. |
| `seed` | `seed 42` | Seed for every random choice. At most one per file. |
| `let` | `let name = expr` | A reusable pattern or transform. Lets are read in file order, so declare before use. |
| `param` | `param name lo..hi = default` or `param name = default` | A numeric game parameter. The range defaults to `0..1`, and the default must be inside the range. |
| `state` | `state name:` then layer lines | A named section. Each layer line is exactly two spaces and an expression. The state plays the stack of its layers. |
| `transition` | `transition from -> to [on Q] [fade F] [fill expr]` | A switch rule. `from` is a state name or `*`. The optional clauses appear in the order `on`, `fade`, `fill`. |
| `stinger` | `stinger name [on Q] [len L]: expr` | A one-shot pattern played for `L` cycles (default 1). |
| `bind` | `bind inst.control <- param [lo..hi]` | Maps a game param continuously onto an instrument control. The range defaults to the catalog range. |

Quantization `Q` is one of `now`, `beat`, `bar`, `N bars` or `N beats`. Transitions default to `on bar`; stingers default to `on beat`. `now` means the next scheduler window edge, `beat` the next beat, and `bar` the next whole cycle. `N bars` waits for the next global cycle that is a multiple of N.

A small but complete cue:

```cue
// night_loop.cue
tempo 96
seed 4
param danger = 0

let bass = n("0 ~ 0 3").scale("D2:minor").s("bass").lpf(900)

state explore:
  bass
  n("<0 2 4>").scale("D3:minor").s("pad").slow(2)

state combat:
  bass.fast(2)
  s("kick(3,8)").gain(0.9)
  s("hat*8").gain(0.4).hpf(6000)

transition explore -> combat on bar fade 1 fill s("snare")
stinger found on beat: n("0 4 7").scale("D4:major").s("lead")
bind pad.lpf <- danger 400..4000
```

The examples after this guide follow the same shape. Keep the first state simple and add energy in later states with more layers, faster rhythms or a filter that opens.

## Mini-notation

Every string is mini-notation, even a single word such as `"pad"` or `"D:minor"`.

| Syntax | Meaning |
|---|---|
| `a b c` | A sequence; the steps share the cycle equally. |
| `~` | A rest. |
| `[a b]` | A subsequence crammed into one step. |
| `<a b c>` | One item per cycle. |
| `a*2`, `a*<2 3>` | Faster: repeat the step, or cycle through the factors. |
| `a/2` | Slower. |
| `a!3`, `a !` | Repeat a step; a bare `!` repeats the previous step. |
| `a@3` | Give a step more of the cycle. |
| `a?`, `a?0.3` | Drop a step with probability 0.5 or 0.3, seeded. |
| `a b \| c d` | Pick one alternative per cycle, seeded. |
| `a b, c d` | Stack, at the top level or inside `[]` or `<>`. |
| `a(3,8)`, `a(3,8,2)` | Euclidean rhythm: k onsets over n steps, rotated left by r. |
| `bd:3`, `C:minor` | The `:` suffix, used as a variant index or a scale mode. |
| `c4 eb3 f#5 a` | Note names, with octave default 3. |
| `0 -3 2.5` | Numbers. |

Not supported in this language: `_` elongation, `.` foot grouping, `{}` polymeter, `%` steps per cycle, and nested modifiers on factors other than a number or `<seq>`.

## Functions

Constructors make patterns: `s n note stack cat seq silence run game`.
Signals are continuous 0..1 sources: `sine saw tri square rand perlin irand`.
Time functions change when events happen: `fast slow early late ply rev palindrome iter segment range`.
Structure functions reshape rhythm: `struct mask euclid euclidRot`.
Random functions are seeded: `degrade degradeBy sometimesBy sometimes often rarely almostNever almostAlways someCyclesBy someCycles`.
Higher-order functions apply a transform: `every superimpose off`.
Pitch functions map notes: `scale transpose add`.
Controls set note values and instrument parameters: `gain velocity legato lpf hpf lpq`.

A chain link always has parentheses: `.rev()`, `.gain(0.7)`, `.fast(2)`. A transform goes only where a function expects one, for example `every(4, fast(2))`, `sometimesBy(0.3, rev())` or `off(0.25, add(7))`. Never write an arrow function. A method called on its own returns a transform; a constructor called on its own returns a pattern.

Numeric arguments may be numbers, mini strings or patterns and signals: `fast("<1 2>")`, `gain(sine.range(0.3, 1))`, `gain(game("danger"))`.

Scales are written `root[octave]:mode` with octave default 3. The modes are `major minor dorian phrygian lydian mixolydian locrian harmonicMinor melodicMinor majPent minPent blues chromatic`. Degrees index the scale and wrap into octaves both ways.

## Rules that keep a cue valid

- Use lowercase names for lets, states, params and stingers.
- Do not use a keyword or a function name as a user name.
- Use only instruments from the Instruments table, and only controls that instrument lists.
- Declare a param before `game("name")` or `bind` refers to it, and keep its default inside its range.
- Every atom in `s(...)` must be an instrument name.
- Every `n(...)` must have a `.scale(...)`.
- Use double quotes for every string; there are no single-quoted strings.
- Do not use `.` foot grouping or `_` elongation in mini strings.
- Do not use braces `{}` or `%`.
- Put one statement on a line; do not join two statements with semicolons.
- A layer is a line of exactly two spaces plus an expression, inside a state.
- Keep comments on their own line or after a complete statement.

## Common mistakes

| Wrong | Right | Why |
|---|---|---|
| `s("hat").every(4, x => x.rev())` | `s("hat").every(4, rev())` | Transforms are values, not arrow functions. |
| `s("kick") { s("hat") }` | `stack(s("kick"), s("hat"))` | Braces are not part of the language. |
| `s('kick')` | `s("kick")` | Strings use double quotes only. |
| `s("kick").rev` | `s("kick").rev()` | Every chain link has parentheses. |
| `s("kick [snare")` | `s("kick [snare]")` | Every `[` needs a closing `]`. |
| `s("kick")` at column 0 inside a state | `  s("kick")` | A layer needs exactly two spaces. |
| A tab before a layer | Two spaces before a layer | Tabs are not indentation in a cue. |
| `s("kick")` before any state | Put the layer inside a state | A layer outside a state is invalid. |
| `transition a -> b fade 1 on bar` | `transition a -> b on bar fade 1` | Clauses go `on`, then `fade`, then `fill`. |
| `gain(1.)` | `gain(1)` or `gain(1.0)` | A decimal point needs digits after it. |
| `s("lead").attack(0.1)` | `s("lead").gain(0.8)` | `attack` is not an available control. |

## Musical guidance

Choose a key and keep every pitched layer in it. Give states different energy through the number of layers, rhythmic density and tempo feel rather than through unrelated keys. Fades of 1 to 4 cycles sound natural. Use `param` plus `bind` for continuous intensity such as danger, speed or depth. Keep gains below 1 so stacked layers do not clip. Every state needs at least one layer.
