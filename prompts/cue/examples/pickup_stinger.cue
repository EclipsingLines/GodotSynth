// pickup_stinger.cue
tempo 90 3/4
seed 9

let bed = n("<0 2 4>").scale("G3:major").s("pad").slow(3)

state ambient:
  bed // quiet, slowly changing pad
  s("hat*3").gain(0.25).hpf(8000)

// lands on the next beat and rings for two cycles
stinger found on beat len 2: n("0 4 7 12").scale("G4:major").s("lead").fast(2)
stinger landing: n("0 2 4 7").scale("G4:major").s("arp")
