// Auto-subtitle construction from Event/Date tags, and the same
// auto-strip-empty-title-fields gating applied to Event (commit 7d6cb16;
// stripping the "?" placeholder specifically predates that commit and must
// still hold either way -- only the BLANK case is new).
#import "/lib.typ": _auto-subtitle

#let mk(event, date) = {
  let t = (:)
  if event != none { t.insert("Event", event) }
  if date != none { t.insert("Date", date) }
  (tags: t)
}

// Event + year.
#assert(_auto-subtitle(mk("World Championship", "2024.05.01"), true) == "World Championship, 2024", message: "event + year: got " + repr(_auto-subtitle(mk("World Championship", "2024.05.01"), true)))

// Event "?" is dropped under BOTH switch values (pre-existing behavior).
#assert(_auto-subtitle(mk("?", "2024.05.01"), false) == "2024", message: "\"?\" event dropped even under strip=false (pre-existing behavior)")
#assert(_auto-subtitle(mk("?", "2024.05.01"), true) == "2024", message: "\"?\" event dropped: strip=true")

// A BLANK (not "?") event is dropped only under strip=true (new); under
// strip=false it's still literally included as an empty part.
#assert(_auto-subtitle(mk("", "2024.05.01"), true) == "2024", message: "blank event dropped: strip=true")
#assert(_auto-subtitle(mk("", "2024.05.01"), false) == ", 2024", message: "blank event printed verbatim (as an empty part): strip=false")

// No event, no year at all -> none.
#assert(_auto-subtitle(mk(none, none), true) == none, message: "neither -> none")

// Year alone (no event tag at all).
#assert(_auto-subtitle(mk(none, "1972.09.01"), true) == "1972", message: "year alone: got " + repr(_auto-subtitle(mk(none, "1972.09.01"), true)))

"Passed."
