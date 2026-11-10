// expect: E_UNKNOWN_CONTROL 5:10
param danger = 0
state main:
  s("pad")
bind pad.wobble <- danger
