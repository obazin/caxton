// Any real diagram marker anywhere switches placement to PURELY
// marker-driven: no automatic (interval/heavy-prose) points anywhere else,
// even at a move that would otherwise qualify on its own, and the final
// position is NOT automatically added either (the caller, caxton()'s own
// render loop, separately guarantees the marked points render -- but
// _diagram-points itself returns only what's actually marked).
#import "/lib.typ": _diagram-points
#import "_fixture.typ": infos-and-start

#let long-prose = "x" * 200
#let pgn = "1. e4 {" + long-prose + " [#]} e5 2. Nf3 {" + long-prose + "} Nc6 3. Bb5 a6 *"
#let fx = infos-and-start(pgn)
#let pts = _diagram-points(fx.infos, fx.start)
#assert(pts == (0,), message: "marker-only placement, ignoring the equally heavy-prose 2nd move entirely: got " + repr(pts))

"Passed."
