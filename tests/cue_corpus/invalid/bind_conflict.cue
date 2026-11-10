// expect: E_BIND_CONFLICT 5:1
param danger = 0
state main:
  s("pad").lpf(500)
bind pad.lpf <- danger
