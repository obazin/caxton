// Commit dee0fee: a heavily-annotated move (>=180 chars of prose) only gets
// an EXTRA diagram past full move 8 -- opening-theory notes citing a whole
// line rarely need a diagram of their own; automatic placement is meant to
// surface middlegame/endgame positions.
#import "/lib.typ": _diagram-points
#import "_fixture.typ": infos-and-start

// 20 full moves (40 plies). Heavy prose on black's move 5 (index 9, full
// move 5 -- still "the opening") must NOT add a point; heavy prose on
// black's move 12 (index 23, full move 12 -- past the opening) MUST add
// one, on top of the fixed-interval points at index 15 (ply 16) and index
// 31 (ply 32), plus the final position (index 39).
#let cycle = ("Nf3", "Nf6", "Ng1", "Ng8")
#let long-prose = "x" * 200
#let tokens = range(40).map(i => cycle.at(calc.rem(i, 4)))
#let pairs = range(20).map(fm => {
  let w = tokens.at(fm * 2)
  let b = tokens.at(fm * 2 + 1)
  let b-tok = if fm == 4 or fm == 11 { b + " {" + long-prose + "}" } else { b }
  str(fm + 1) + ". " + w + " " + b-tok
})
#let pgn = pairs.join(" ") + " *"
#let fx = infos-and-start(pgn)
#let pts = _diagram-points(fx.infos, fx.start)
#assert(pts == (15, 23, 31, 39), message: "interval (15, 31) + late heavy-prose extra (23) + final (39); early heavy-prose at index 9 excluded: got " + repr(pts))

"Passed."
