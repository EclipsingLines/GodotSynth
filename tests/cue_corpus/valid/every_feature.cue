// every statement form and every mini-notation operator
tempo 90 3/4
seed 42
param danger 0..1 = 0.5
param depth -2..2 = -1
param mood = 0

let riff = n("0 ~ [2 4] <5 7>").scale("C:minor").s("lead")
let thin = lpf(1200).gain(0.7)
let kit = stack(s("kick(3,8,2)"), s("~ snare"), s("hat*2 hat/2"))

state calm:
  riff
  kit.every(2, thin)
  s("kick!3 hat! snare@3 hat?0.3 crash? bass:2 pad*<2 3>")
  s("kick snare | hat hat, crash [kick, snare] <hat, pad>")
  note("c4 eb3 f#5 a").s("pad").gain(game("danger"))
  n("0 -3 2.5").scale("C:major").s("lead").pan(game("mood"))

state tense: // trailing comment on a state line
  riff.fast(2)
  kit
  s("kick ! ").gain(0.5) // trailing comment on a layer

state boss:
  cat(s("kick"), s("snare"), silence)
  seq(s("hat"), s("crash")).slow(2)
  n(run(4)).scale("C:major").s("lead").velocity(0.9).legato(0.5)
  s("kick*4").iter(4).palindrome().ply(2).early(0.25).late(0.125)
  s("snare").lpq(0.2).hpf(200).attack(0.01).decay(0.1).sustain(0.5).release(0.3).detune(5)
  n("0 1").scale("C:major").s("lead").segment(4).transpose(12).add(2)

transition calm -> tense
transition tense -> calm on 2 beats fade 0.5 fill s("crash")
transition * -> boss on now
transition * -> calm on beat fade 2

stinger hit: s("snare")
stinger found on beat len 2: n("0 4 7").scale("C:major").s("lead")
stinger alarm on 2 bars: s("crash*2")

bind pad.lpf <- danger 400..4000
bind bass.release <- depth 0.1..2
