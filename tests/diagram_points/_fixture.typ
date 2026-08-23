// Shared fixture for diagram_points tests (skipped by the runner -- files
// starting with "_" are fixtures, not tests, same convention as staunton's
// own tests/board/_fixture.typ). Builds (infos, start) from a plain PGN
// movetext string exactly the way caxton() itself does, so _diagram-points
// is exercised with the real shape it gets in production.
#import "/lib.typ": _comment-info
#import "/vendor/staunton/lib.typ": game, movetext, game-start

#let infos-and-start(pgn) = {
  let g = game(pgn)
  let nodes = movetext(g)
  (infos: nodes.map(_comment-info), start: game-start(g))
}
