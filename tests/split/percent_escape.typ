// PGN's own "escape mechanism" (spec section 4): a line starting with "%" is
// skipped entirely by any conforming reader. Regression for the bug fixed in
// commit 92904d6, where a leading "% BOOKTITLE = ..." line (ChessBase-style
// file metadata) was mistaken for movetext by _split-games, splitting off a
// bogus tagless leading "game" that then crashed the SAN resolver on "%".
#import "/lib.typ": _strip-percent-escapes, _split-games

// A leading %-escape line ahead of the first game is removed entirely, with
// nothing left before the real tag section.
#let pgn1 = "% BOOKTITLE = My Great Predecessors (part 1)\n[Event \"?\"]\n[White \"A\"]\n[Black \"B\"]\n[Result \"*\"]\n\n1. e4 *\n"
#let cleaned1 = _strip-percent-escapes(pgn1)
#assert(not cleaned1.contains("BOOKTITLE"), message: "percent-escape line removed")
#assert(cleaned1.starts-with("[Event"), message: "nothing left before the first real tag: got " + repr(cleaned1))
#let games1 = _split-games(cleaned1)
#assert(games1.len() == 1, message: "no bogus extra game from the escape line: got " + str(games1.len()))

// Multiple %-escape lines scattered between games are all removed, and don't
// perturb the game count.
#let pgn2 = "% header 1\n[Event \"A\"]\n[White \"W1\"]\n[Black \"B1\"]\n[Result \"*\"]\n\n1. e4 *\n\n% header 2\n[Event \"B\"]\n[White \"W2\"]\n[Black \"B2\"]\n[Result \"*\"]\n\n1. d4 *\n"
#let cleaned2 = _strip-percent-escapes(pgn2)
#assert(not cleaned2.contains("% header"), message: "all percent-escape lines removed")
#let games2 = _split-games(cleaned2)
#assert(games2.len() == 2, message: "game count unaffected by scattered escape lines: got " + str(games2.len()))

// A "%" that is NOT the first character of a line (e.g. inside prose, "a 50%
// chance") is not an escape line and must be left untouched.
#let pgn3 = "[Event \"A\"] a 50% chance, not an escape line"
#assert(_strip-percent-escapes(pgn3) == pgn3, message: "a mid-line % is not an escape line")

"Passed."
