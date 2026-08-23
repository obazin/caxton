// Commit 92904d6, end to end: a leading PGN %-escape line (e.g. ChessBase's
// "% BOOKTITLE = ...") must not crash caxton() -- the original regression
// was _split-games treating it as movetext since it precedes any tag,
// splitting off a bogus tagless "game" that then failed the SAN resolver on
// the literal "%" token.
#import "/lib.typ": caxton

#let pgn = "% BOOKTITLE = Some Book Title\n[Event \"?\"]\n[White \"W\"]\n[Black \"B\"]\n[Result \"*\"]\n\n1. e4 e5 *\n"
#caxton(pgn)
