// Diagram marker detection: the two real-world conventions caxton honours
// (verified against ChessBase/RPB Chessboard and Scid docs directly -- see
// the lib.typ module comment), plus %cal/%csl stripped from the printed
// prose without affecting marker detection.
#import "/lib.typ": _strip-marker, _comment-info
#import "/vendor/staunton/lib.typ": game, movetext

// Bracket-hash-bracket form (ChessBase / RPB Chessboard), with prose
// alongside it -- the marker is stripped, the prose is kept.
#let r1 = _strip-marker("Some prose. [#] more prose.")
#assert(r1.has-marker, message: "[#] anywhere in the comment is a marker")
#assert(not r1.prose.contains("[#]"), message: "the marker itself is stripped from the prose: got " + repr(r1.prose))

// Leading-# form (Scid's own documented rule): only the LEADING # is
// stripped -- a # elsewhere in the same comment is ordinary text.
#let r2 = _strip-marker("# Some prose with a # in the middle too.")
#assert(r2.has-marker, message: "a comment starting with # is a marker")
#assert(not r2.prose.starts-with("#"), message: "the leading # is stripped: got " + repr(r2.prose))
#assert(r2.prose.contains("#"), message: "a # elsewhere in the prose is left alone")

// A plain comment carries no marker at all.
#let r3 = _strip-marker("Just a normal comment, no diagram marker here.")
#assert(not r3.has-marker, message: "no marker in a plain comment")
#assert(r3.prose == "Just a normal comment, no diagram marker here.", message: "prose unchanged: got " + repr(r3.prose))

// %cal/%csl are stripped from the prose this module prints, without being
// mistaken for prose content or affecting marker detection.
#let r4 = _strip-marker("[#] Wins material. [%cal Ge2e4,Gd2d4]")
#assert(r4.has-marker, message: "[#] still detected alongside a %cal annotation")
#assert(r4.prose == "Wins material.", message: "clean prose after stripping both the marker and %cal: got " + repr(r4.prose))

// _comment-info on a move with no comment at all.
#let g = game("1. e4 e5 *")
#let info = _comment-info(movetext(g).first())
#assert(not info.has-marker and not info.has-prose, message: "a move with no comment has neither a marker nor prose")

"Passed."
