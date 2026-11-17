// euclid_groove.cue
tempo 124
seed 21
param drive = 0.5

let bassline = n("0 0 3 5").scale("F2:minor").s("bass").lpf(1200)

state groove:
  s("kick(3,8)").gain(0.9)
  s("hat(5,8,2)").gain(0.45).hpf(7000)
  s("~ snare").gain(0.7)
  bassline
    .every(4, rev())
    .sometimesBy(0.3, fast(2))
  n("0 3 7 10").scale("F3:minor").s("lead")
    .off(0.25, add(7))
    .superimpose(rev())
    .gain(game("drive"))
