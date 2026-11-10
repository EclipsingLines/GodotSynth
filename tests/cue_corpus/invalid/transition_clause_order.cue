// expect: E_SYNTAX 6:26
state a:
  s("kick")
state b:
  s("snare")
transition a -> b fade 1 on bar
