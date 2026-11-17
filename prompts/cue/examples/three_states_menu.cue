// three_states_menu.cue
tempo 96
seed 14

let menu_pad = n("<0 2 4>").scale("C3:major").s("pad").slow(2)

state menu:
  menu_pad
  n("0 4 7 12").scale("C4:major").s("arp").every(2, rev())

state loading:
  cat(s("hat*8").gain(0.3), s("kick(3,8)").gain(0.6), s("~ snare"))

state credits:
  n("0 2 4 6").scale("C3:major").s("pad").slow(4)
  n("0 3 5 7").scale("C4:major").s("lead")
    .sometimesBy(0.25, fast(2))

transition menu -> loading on now
transition loading -> menu on 2 beats fade 1
transition * -> credits on bar fade 2 fill s("hat*8")

stinger click on now: s("hat")
