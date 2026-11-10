// newlines are allowed inside parentheses
let kit = stack(
  s("kick"),
  s("hat")
)

state main:
  kit
  stack(
    s("kick"),
    s("snare")
      .gain(0.8),
    s("hat*4")
  )
  s("kick").every(
    4,
    rev()
  )
  (
    s("pad")
  ).gain(0.5)
  s("hat*8").gain(
    sine.range(
      0.2,
      0.9
    )
  )
