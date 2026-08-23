// Commit fc2e8b8: a zero-move game (e.g. a text-only closing note,
// PlyCount 0) must not crash. _diagram-points on an empty infos array
// returns no diagram points, rather than computing
// `last = infos.len() - 1 == -1` and indexing with it -- the original
// crash was "array index out of bounds (index: -1, len: 0)".
#import "/lib.typ": _diagram-points

#assert(_diagram-points((), (turn: "w", fullmove: 1)) == (), message: "empty infos -> no diagram points, no crash")

"Passed."
