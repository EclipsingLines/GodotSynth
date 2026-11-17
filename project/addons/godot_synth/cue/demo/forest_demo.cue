// forest_demo.cue: adaptive demo for the GodotSynth cue runtime (real catalog instruments only)
tempo 96
seed 7
param danger 0..1 = 0

let bass = n("0 ~ 0 3").scale("D:minor").s("bass")
let drums = stack(s("kick(3,8)"), s("~ snare").gain(0.8), s("hat*8").degradeBy(0.3))

state explore:
  bass.lpf(900)
  n("<0 2 4 [6 4]>").scale("D4:minor").s("pad").slow(2)
  s("hat*4").gain(game("danger"))

state tense:
  bass.fast(2).lpf(1400)
  n("<0 2 4 [6 4]>").scale("D4:minor").s("pad")
  s("hat*8").gain(0.6)

state combat:
  bass.fast(2)
  drums
  n("0 3 5 7").scale("D4:minor").s("lead")
    .every(4, rev())
    .gain(sine.range(0.5, 1).slow(4))

transition explore -> tense on bar fade 1
transition tense -> combat on bar fade 1 fill s("snare*8").gain(0.6)
transition * -> explore on 4 bars fade 2
transition * -> combat on bar fade 0.5 fill s("snare*4")

stinger found on beat: n("0 4 7 12").scale("D4:major").s("lead").fast(4)
stinger hit: s("snare kick").gain(0.9)

bind pad.lpf <- danger 400..4000
