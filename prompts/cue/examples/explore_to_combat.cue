// explore_to_combat.cue
tempo 110
seed 3

let drums = stack(s("kick(3,8)"), s("~ snare"), s("hat*8").gain(0.5))

state explore:
  n("0 ~ 0 3").scale("D2:minor").s("bass")
  n("<0 2 4 [6 4]>").scale("D3:minor").s("pad").slow(2)

state combat:
  n("0 ~ 0 3").scale("D2:minor").s("bass").fast(2) // the bass line, twice as fast
  drums
  n("0 3 5 7").scale("D3:minor").s("lead")
    .every(4, rev())
    .gain(0.7)

transition explore -> combat on bar fade 1 fill s("snare*4")
transition * -> explore on 4 bars fade 2
