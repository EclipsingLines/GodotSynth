// seeded random functions and signals
seed 11

state main:
  s("hat*8").degrade()
  s("hat*8").degradeBy(0.3)
  s("kick snare").sometimesBy(0.4, fast(2))
  s("kick snare").sometimes(rev())
  s("kick snare").often(rev())
  s("kick snare").rarely(rev())
  s("kick snare").almostNever(rev())
  s("kick snare").almostAlways(rev())
  s("kick snare").someCyclesBy(0.3, rev())
  s("kick snare").someCycles(rev())
  s("hat*8?").gain(rand.range(0.4, 1))
  s("hat*8").gain(perlin.range(0.2, 0.9).slow(4))
  s("hat*8").pan(irand(8))
  s("hat*4 | kick*4 | snare*4")
  s("hat?0.7*8")
  s("hat*8").gain(saw.range(0.2, 0.8).segment(8))
  s("hat*8").gain(tri)
  s("hat*8").gain(square)
