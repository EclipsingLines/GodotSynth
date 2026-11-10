// expect: E_SYNTAX 4:23
state main:
  s("kick")
  s("hat").every(4, x => x.fast(2))
