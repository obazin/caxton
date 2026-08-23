// _field-present: what counts as "no real information" in a PGN tag value
// (commit 7d6cb16) -- absent, blank/whitespace-only, or PGN's own "?"
// placeholder, exactly, and nothing broader.
#import "/lib.typ": _field-present

#assert(not _field-present(none), message: "none is not present")
#assert(not _field-present(""), message: "empty string is not present")
#assert(not _field-present("   "), message: "whitespace-only string is not present")
#assert(not _field-present("?"), message: "\"?\" is not present")
#assert(not _field-present(" ? "), message: "\"?\" with surrounding whitespace is not present")
#assert(_field-present("Kasparov"), message: "a real value is present")
#assert(_field-present("0"), message: "a falsy-looking but non-empty value is still present")
#assert(_field-present("??"), message: "\"??\" is NOT the \"?\" placeholder -- it's a real (if odd) value")

"Passed."
