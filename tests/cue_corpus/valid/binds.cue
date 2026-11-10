// every bind form
param danger 0..1 = 0
param depth -1..1 = 0
param bright 200..8000 = 1000
param level = 0.5

state main:
  s("pad")
  s("bass")
  s("lead")

bind pad.lpf <- danger
bind bass.gain <- level 0.2..1
bind lead.attack <- depth 0..0.5
bind pad.pan <- depth -1..1
bind hat.hpf <- bright
