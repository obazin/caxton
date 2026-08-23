// Commit 33f1793: fixed-interval and heavy-prose placement are ADDITIVE, not
// mutually exclusive. Before that fix, a game with ANY comment at all
// (however short) fell through to the heavy-prose-only path, found no
// candidate past the 180-char threshold, and got just the final-position
// diagram -- exactly what real engine-annotated PGNs look like ("Blunder.
// dxe5 was best." on every misstep). This must produce the SAME points as
// fixed_interval.typ's no-comment case, proving short comments don't
// suppress the interval placement.
#import "/lib.typ": _diagram-points
#import "_fixture.typ": infos-and-start

#let cycle = ("Nf3", "Nf6", "Ng1", "Ng8")
#let tokens = range(24).map(i => cycle.at(calc.rem(i, 4)))
#let pairs = range(12).map(fm => {
  let w = tokens.at(fm * 2) + " {short}"
  let b = tokens.at(fm * 2 + 1) + " {short}"
  str(fm + 1) + ". " + w + " " + b
})
#let pgn = pairs.join(" ") + " *"
#let fx = infos-and-start(pgn)
#let pts = _diagram-points(fx.infos, fx.start)
#assert(pts == (15, 23), message: "fixed-interval diagrams still appear despite every move having a short comment: got " + repr(pts))

"Passed."
