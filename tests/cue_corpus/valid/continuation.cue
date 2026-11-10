// continuation lines start with a dot
let lead_line = n("0 3 5 7")
  .scale("D4:minor")
	.s("lead")

state main:
  lead_line
  n("0 2 4")
    .scale("C:major")
    .s("pad")
  s("kick")
	.gain(0.5)
    .fast(2)
