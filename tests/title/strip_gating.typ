// Commit 7d6cb16: auto-strip-empty-title-fields gates whether a blank/"?"
// White or Black tag is left out of the auto-built title.
#import "/lib.typ": _auto-title

#let mk(white, black) = {
  let t = (:)
  if white != none { t.insert("White", white) }
  if black != none { t.insert("Black", black) }
  (tags: t)
}

// strip-empty: true (the default) -- "?" and blank fields are left out.
#assert(_auto-title(mk("Kasparov", "?"), true) == [Kasparov], message: "\"?\" black field dropped: strip=true")
#assert(_auto-title(mk("", "Karpov"), true) == [Karpov], message: "blank white field dropped: strip=true")
#assert(_auto-title(mk("   ", "Karpov"), true) == [Karpov], message: "whitespace-only white field dropped: strip=true")
#assert(_auto-title(mk("?", "?"), true) == none, message: "both \"?\" -> none: strip=true")
#assert(_auto-title(mk("", ""), true) == none, message: "both blank -> none: strip=true")

// strip-empty: false -- printed verbatim, "?" included as-is (the
// pre-existing behavior, unchanged from before this switch existed).
#assert(_auto-title(mk("Kasparov", "?"), false) == [Kasparov #sym.dash.en ?], message: "\"?\" printed verbatim: strip=false")

"Passed."
