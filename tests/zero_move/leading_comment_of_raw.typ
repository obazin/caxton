// Commit fc2e8b8: a zero-move game's leading comment is dropped entirely by
// staunton's own parser (see lib.typ's comment on _leading-comment-of-raw),
// so caxton recovers it straight from the game's raw movetext text.
#import "/lib.typ": _leading-comment-of-raw

#let r1 = _leading-comment-of-raw("{A standalone note with no moves at all.} *")
#assert(r1 == "A standalone note with no moves at all.", message: "leading comment extracted: got " + repr(r1))

// No leading comment at all (a normal game) -> none.
#let r2 = _leading-comment-of-raw("1. e4 e5 *")
#assert(r2 == none, message: "no leading comment -> none")

// Leading whitespace before the comment is tolerated.
#let r3 = _leading-comment-of-raw("  \n {Indented note.} *")
#assert(r3 == "Indented note.", message: "leading whitespace before the comment tolerated: got " + repr(r3))

// A move (not a comment) as the very first token -> none, even if a comment
// appears later in the text.
#let r4 = _leading-comment-of-raw("1. e4 {a comment AFTER the first move} *")
#assert(r4 == none, message: "a comment that isn't LEADING is not picked up: got " + repr(r4))

"Passed."
