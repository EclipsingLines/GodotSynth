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
    .lpf(sine.range(800, 3000).slow(4))

transition explore -> combat on bar fade 1 fill s("crash")
transition * -> explore on 4 bars fade 2

stinger found on beat: n("0 4 7 12").scale("D4:major").s("lead").fast(4)
bind pad.lpf <- danger 400..4000
