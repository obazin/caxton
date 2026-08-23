// Commit 324c1b9, end to end: a multi-game PGN renders every game, each on
// its own fresh page, not just the first.
#import "/lib.typ": caxton

#let pgn = "[Event \"A\"]\n[White \"W1\"]\n[Black \"B1\"]\n[Result \"*\"]\n\n1. e4 e5 *\n\n[Event \"B\"]\n[White \"W2\"]\n[Black \"B2\"]\n[Result \"*\"]\n\n1. d4 d5 *\n\n[Event \"C\"]\n[White \"W3\"]\n[Black \"B3\"]\n[Result \"*\"]\n\n1. c4 c5 *\n"
#caxton(pgn)

// Each game starts on a fresh page (pagebreak between games), so 3 games
// must span at least 3 pages.
#context {
  let n = counter(page).final().first()
  assert(n >= 3, message: "at least 3 pages -- one fresh page per game: got " + str(n))
}
