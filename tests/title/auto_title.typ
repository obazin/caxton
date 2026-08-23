// Baseline auto-title construction from White/Black tags (auto-strip-empty-
// title-fields semantics covered separately in strip_gating.typ).
#import "/lib.typ": _auto-title

// Built as a plain (tags: ..) dict, matching exactly what _auto-title reads
// off a parsed game -- no PGN parsing needed for this.
#let mk(white, black) = {
  let t = (:)
  if white != none { t.insert("White", white) }
  if black != none { t.insert("Black", black) }
  (tags: t)
}

#assert(_auto-title(mk("Kasparov", "Karpov"), false) == [Kasparov #sym.dash.en Karpov], message: "both present")
#assert(_auto-title(mk("Kasparov", none), false) == [Kasparov], message: "white only")
#assert(_auto-title(mk(none, "Karpov"), false) == [Karpov], message: "black only")
#assert(_auto-title(mk(none, none), false) == none, message: "neither present -> none")

"Passed."
