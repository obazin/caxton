// No two diagrams closer than _min-diagram-gap (6 plies), whichever source
// they came from, and the final position always wins that collision rather
// than being dropped or duplicated.
#import "/lib.typ": _diagram-points
#import "_fixture.typ": infos-and-start

// 10 full moves (20 plies): the only interval candidate is index 15 (ply
// 16), just 4 plies before the final position (index 19) -- under the gap
// of 6, so it's dropped in favour of the final position alone (never both,
// never neither).
#let cycle = ("Nf3", "Nf6", "Ng1", "Ng8")
#let tokens = range(20).map(i => cycle.at(calc.rem(i, 4)))
#let pairs = range(10).map(fm => str(fm + 1) + ". " + tokens.at(fm * 2) + " " + tokens.at(fm * 2 + 1))
#let pgn = pairs.join(" ") + " *"
#let fx = infos-and-start(pgn)
#let pts = _diagram-points(fx.infos, fx.start)
#assert(pts == (19,), message: "near-final interval point dropped in favour of the final position alone: got " + repr(pts))

// 16 full moves (32 plies), with heavy prose on both white's and black's
// move 13 (indices 24, 25 -- 1 ply apart, well clear of the interval point
// at 15 and of the final position at 31): only the FIRST of the two close
// candidates survives.
#let long-prose = "x" * 200
#let tokens2 = range(32).map(i => cycle.at(calc.rem(i, 4)))
#let pairs2 = range(16).map(fm => {
  let w = tokens2.at(fm * 2)
  let b = tokens2.at(fm * 2 + 1)
  if fm == 12 {
    str(fm + 1) + ". " + w + " {" + long-prose + "} " + b + " {" + long-prose + "}"
  } else {
    str(fm + 1) + ". " + w + " " + b
  }
})
#let pgn2 = pairs2.join(" ") + " *"
#let fx2 = infos-and-start(pgn2)
#let pts2 = _diagram-points(fx2.infos, fx2.start)
#assert(pts2.contains(24), message: "the first of two close heavy-prose candidates is kept: got " + repr(pts2))
#assert(not pts2.contains(25), message: "the second, too close to the first, is dropped: got " + repr(pts2))
#assert(pts2.last() == 31, message: "the final position is still included: got " + repr(pts2))

"Passed."
