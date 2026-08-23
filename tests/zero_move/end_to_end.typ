// Commit fc2e8b8, end to end: a zero-move game must render (its comment
// printed as prose, no diagram, no crash) instead of throwing "array index
// out of bounds" / "array is empty".
#import "/lib.typ": caxton

// A single zero-move game (PlyCount 0, just a standalone note).
#let note-only = "[Event \"?\"]\n[White \"A retenir\"]\n[Black \"?\"]\n[Result \"*\"]\n[PlyCount \"0\"]\n\n{Some closing thoughts with no moves at all.} *\n"
#caxton(note-only)

// The same, as the LAST game in a multi-game PGN -- the real-world shape
// this was found in (a book's closing "key takeaways" entry after real
// games).
#let mixed = "[Event \"A\"]\n[White \"W1\"]\n[Black \"B1\"]\n[Result \"*\"]\n\n1. e4 e5 *\n\n[Event \"?\"]\n[White \"A retenir\"]\n[Black \"?\"]\n[Result \"*\"]\n[PlyCount \"0\"]\n\n{Closing note.} *\n"
#caxton(mixed)
