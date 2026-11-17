// danger_param_bind.cue
tempo 100
seed 5
param danger 0..1 = 0
param depth = 0.5

let pulse = n("0 3 0 5").scale("A2:minor").s("bass")

state tension:
  pulse // steady bass pulse
  n("<0 2 4 [6 4]>").scale("A3:minor").s("pad").slow(2)
  // the game's danger value drives the hat level
  s("hat*8").gain(game("danger")).hpf(7000)
  n("0 2 4 7").scale("A3:minor").s("lead")

bind pad.lpf <- danger 300..6000
bind lead.gain <- depth
