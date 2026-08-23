// Commit 5633e94: [%eval ..]/[%clk ..] PGN command annotations are stripped
// before parsing (pure telemetry, no meaning in a printed book); %cal/%csl
// (arrows / highlighted squares) are deliberately left alone so staunton can
// still draw them on diagrams.
#import "/lib.typ": _strip-pgn-commands, _comment-info
#import "/vendor/staunton/lib.typ": game, movetext

#let raw = "1. e4 {[%eval 0.09] [%clk 0:08:53] A solid start. [%cal Ge2e4]} e5 *"
#let cleaned = _strip-pgn-commands(raw)
#assert(not cleaned.contains("%eval"), message: "%eval stripped")
#assert(not cleaned.contains("%clk"), message: "%clk stripped")
#assert(cleaned.contains("%cal"), message: "%cal left alone for staunton's own board rendering")
#assert(cleaned.contains("A solid start."), message: "surrounding prose untouched")

// A mate-score eval ("[%eval #3]") contains a literal "#" -- once stripped,
// what's left must not be mistaken for a "#"-led Scid diagram marker (the
// exact failure mode the module doc comment calls out).
#let mate-eval = "1. Qh6+ {[%eval #3]} Kg8 *"
#let g = game(_strip-pgn-commands(mate-eval))
#let info = _comment-info(movetext(g).first())
#assert(not info.has-marker, message: "a stripped mate-score eval must not look like a diagram marker")
#assert(info.prose == "", message: "nothing left to print once the eval annotation is gone: got " + repr(info.prose))

"Passed."
