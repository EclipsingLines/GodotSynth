// calm_exploration.cue
tempo 80

let bass_line = n("0 ~ 0 3").scale("D2:minor").s("bass").lpf(900)
let chord_pad = n("<0 2 4 [6 4]>").scale("D3:minor").s("pad").slow(2)

state explore:
  bass_line // sparse root-and-fifth bass
  chord_pad // one chord per cycle, held long
  // soft hats keep the loop moving without adding weight
  s("hat*2").gain(0.35).hpf(6000)
