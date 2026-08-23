// The core 324c1b9 feature: a PGN holding several games splits into one
// string per game, and the brace-comment state machine keeps a hard-wrapped
// comment line that happens to start with "[" from being mistaken for a new
// game's tag section.
#import "/lib.typ": _split-games

#let three = "[Event \"A\"]\n[White \"W1\"]\n[Black \"B1\"]\n[Result \"*\"]\n\n1. e4 *\n\n[Event \"B\"]\n[White \"W2\"]\n[Black \"B2\"]\n[Result \"*\"]\n\n1. d4 *\n\n[Event \"C\"]\n[White \"W3\"]\n[Black \"B3\"]\n[Result \"*\"]\n\n1. c4 *\n"
#let games = _split-games(three)
#assert(games.len() == 3, message: "three games split into three: got " + str(games.len()))
#for (i, g) in games.enumerate() {
  assert(g.trim().starts-with("[Event"), message: "game " + str(i) + " starts with its own tag section: got " + repr(g.trim().slice(0, calc.min(20, g.trim().len()))))
}

// A hard-wrapped comment line starting with "[" must stay inside the game
// whose comment it belongs to, not start a bogus new game.
#let wrapped = "[Event \"A\"]\n[White \"W1\"]\n[Black \"B1\"]\n[Result \"*\"]\n\n1. e4 {a comment that wraps onto\n[a line that looks like a tag] but isn't one} e5\n\n[Event \"B\"]\n[White \"W2\"]\n[Black \"B2\"]\n[Result \"*\"]\n\n1. d4 *\n"
#let wgames = _split-games(wrapped)
#assert(wgames.len() == 2, message: "wrapped comment line starting with [ does not start a bogus 3rd game: got " + str(wgames.len()))
#assert(wgames.at(0).contains("a line that looks like a tag"), message: "the wrapped comment line stayed inside game 1")
#assert(wgames.at(1).contains("[Event \"B\""), message: "game 2 still starts at its own real tag section")

// A ";"-to-end-of-line comment must not open brace-comment state (PGN's two
// comment forms are independent).
#let semicolon = "[Event \"A\"]\n[White \"W1\"]\n[Black \"B1\"]\n[Result \"*\"]\n\n1. e4 ; a rest-of-line comment, not a { } comment\ne5 *\n"
#let sgames = _split-games(semicolon)
#assert(sgames.len() == 1, message: "a single game with a ;-comment stays a single game: got " + str(sgames.len()))

"Passed."
