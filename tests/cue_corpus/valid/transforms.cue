// free transforms: a method called without a receiver
let double = fast(2)
let flip = rev()
let chained = fast(2).rev().gain(0.5)
let sparse = degradeBy(0.3)

state main:
  s("kick snare").every(2, double)
  s("hat*4").every(3, rev)
  s("hat*4").sometimesBy(0.3, fast(2))
  s("kick").superimpose(fast(2).gain(0.5))
  s("snare").off(0.125, chained)
  s("hat").sometimes(flip)
  s("kick snare hat").every(4, degrade).every(2, sparse)
  s("crash").someCyclesBy(0.5, rev())
