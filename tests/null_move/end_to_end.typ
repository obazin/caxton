// Commit 92904d6: PGN null moves ("--") anywhere in the mainline must not
// crash caxton(). The actual fix lives upstream (typst-shakmaty-engine's
// WASM plugin + the vendored staunton fork -- see their own test suites),
// but this is caxton's OWN regression guard at the package level, so a
// future re-vendor that accidentally reintroduces the old,
// null-move-rejecting engine is caught here too, not just discovered again
// against a real-world PGN.
#import "/lib.typ": caxton

#let pgn = "[Event \"?\"]\n[White \"W\"]\n[Black \"B\"]\n[Result \"*\"]\n\n1. e4 e5 2. Nf3 -- 3. Bb5 a6 *\n"
#caxton(pgn)
