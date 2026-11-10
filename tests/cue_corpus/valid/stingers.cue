// every stinger form
state main:
  s("kick")

stinger hit: s("snare")
stinger found on beat len 2: n("0 4 7 12").scale("D4:major").s("lead").fast(4)
stinger alarm on 2 bars: s("crash*2")
stinger boom on now len 0.5: s("kick")
stinger tail len 4: s("hat*8")
stinger swell on bar len 2: s("pad")
  .slow(2)
