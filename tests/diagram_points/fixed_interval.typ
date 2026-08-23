// A game with no comments at all (or, per additive_short_comments.typ, only
// short ones): diagrams every 16 plies (8 full moves), plus the final
// position -- the baseline automatic-placement rule from 324c1b9.
#import "/lib.typ": _diagram-points
#import "_fixture.typ": infos-and-start

// 12 full moves (24 plies): one fixed-interval point at ply 16 (index 15)
// clear of the final position (index 23), so both survive as distinct
// points (min_gap_and_final.typ covers the case where they'd collide).
#let cycle = ("Nf3", "Nf6", "Ng1", "Ng8")
#let tokens = range(24).map(i => cycle.at(calc.rem(i, 4)))
#let pairs = range(12).map(fm => str(fm + 1) + ". " + tokens.at(fm * 2) + " " + tokens.at(fm * 2 + 1))
#let pgn = pairs.join(" ") + " *"
#let fx = infos-and-start(pgn)
#let pts = _diagram-points(fx.infos, fx.start)
#assert(pts == (15, 23), message: "fixed interval (index 15) plus the final position (index 23): got " + repr(pts))

"Passed."
