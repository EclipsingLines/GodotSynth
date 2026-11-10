// leading comment

   // indented comment
	
tempo	100 // trailing comment after a statement
// between statements
seed 3

state alpha: // after the state header
  s("kick") // after a layer

  // comment between layers
  s("snare")
   
  s("hat")
// a comment at column zero between states
state beta:
  s("crash")

transition alpha -> beta // trailing comment on a transition
