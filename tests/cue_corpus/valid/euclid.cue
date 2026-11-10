// euclidean rhythms in strings and as functions
state main:
  s("kick(3,8)")
  s("snare(5,8,2)")
  s("hat(3, 8, 1)")
  s("kick(3,8)*2 snare(3,8)?")
  s("[kick snare](3,8)")
  s("<kick snare>(3,8)")
  s("kick").euclid(3, 8)
  s("snare").euclidRot(3, 8, 2)
  s("hat").struct("x ~ x x")
  s("hat").mask("1 0")
