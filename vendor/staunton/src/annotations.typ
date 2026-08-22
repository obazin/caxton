// ===========================================================================
// PGN comment interpretation + NAG symbols.
//
// Parsing stays lossless (pgn.typ stores comments verbatim and NAGs as raw
// values). This module INTERPRETS that stored data at render time, gated by the
// `default-pgn-style` switches. Two pieces:
//
//   * `interpret-comment(comment)` -> (diagram, arrows, highlights, text):
//       splits a comment into an embedded diagram marker (+ optional caption),
//       %cal arrows, %csl highlights, and the residual prose.
//   * NAG symbols: map the numeric NAG value to its conventional glyph.
//
// Recognised diagram markers -- NOTE: the ambiguous "{d}"/"{D}"
// (no brackets) are deliberately NOT recognised:
//   #  /  #[<caption>]   ChessBase (caption optional)
//   [d] / [D]            Scid
//   \diagram             LaTeX
//   %%diagram            Markdown/HTML converters
// ===========================================================================

// ---- NAG -> symbol --------------------------------------------------------
// Conventional move/position assessment glyphs. Stored NAG values are the digits
// after "$" (a string). Unknown codes pass through as "$<n>".
#let nag-symbols = (
  "1": "!", "2": "?", "3": "!!", "4": "??", "5": "!?", "6": "?!",
  "7": "\u{25A1}", "10": "=", "11": "=", "12": "=", "13": "\u{221E}",
  "14": "\u{2A72}", "15": "\u{2A71}", "16": "\u{00B1}", "17": "\u{2213}",
  "18": "+\u{2212}", "19": "\u{2212}+", "20": "+\u{2212}", "21": "\u{2212}+",
  "22": "\u{2A00}", "23": "\u{2A00}", "36": "\u{2192}", "40": "\u{2192}",
  "132": "\u{21C6}", "133": "\u{21C6}",
)
#let nag-symbol(n) = nag-symbols.at(n, default: "$" + n)

// ---- move-quality glyph <-> NAG code ---------------------------------------
// The six move-quality codes ($1..$6), and their glyph reversed out of
// nag-symbols above -- the ONE table both directions derive from, so a SAN
// suffix glyph ("Nf3!"), an explicit "$1", and a programmatic "!" all resolve
// to the same stored code everywhere (pgn.typ's parser, game.typ's badge,
// notation.typ's bare-SAN path, and `with-nags`'s glyph input).
#let quality-nag-codes = ("1", "2", "3", "4", "5", "6")
#let glyph-to-nag = {
  let m = (:)
  for code in quality-nag-codes { m.insert(nag-symbols.at(code), code) }
  m
}

// ---- comment interpretation -----------------------------------------------
// All of interpret-comment's regexes, hoisted to module level: it runs once
// per commented node per notation render plus once per diagram, and compiling
// its ~8 regexes per call was measurable (same lesson as pgn.typ's hoisted
// token regexes).
#let _cal-re = regex("\[%cal\s+([^\]]+)\]")
#let _csl-re = regex("\[%csl\s+([^\]]+)\]")
#let _cb-marker-re = regex("#(\[([^\]]*)\])?")
#let _scid-marker-re = regex("\[[dD]\]")
#let _strip-cal-re = regex("\[%cal\s+[^\]]+\]")
#let _strip-csl-re = regex("\[%csl\s+[^\]]+\]")
#let _strip-cb-re = regex("#(\[[^\]]*\])?")
#let _ws-collapse-re = regex("\s+")

/// Interpret a PGN move comment: extract a diagram marker, `%cal` arrows, `%csl`
/// highlights, and the remaining prose. Returns `(diagram, arrows, highlights,
/// text)`.
///
/// - comment (str, none): the raw comment string, or `none`.
/// -> dictionary
#let interpret-comment(comment) = {
  if comment == none or comment == "" {
    return (diagram: none, arrows: (), highlights: (), text: "")
  }
  let c = comment

  // %cal arrows: tokens are <Color><from><to>, e.g. "Gf3e5".
  let arrows = ()
  let mcal = c.match(_cal-re)
  if mcal != none {
    for tok in mcal.captures.at(0).split(",") {
      let t = tok.trim()
      if t.len() >= 5 { arrows.push((t.slice(1, 3), t.slice(3, 5), t.slice(0, 1))) }
    }
  }
  // %csl highlights: tokens are <Color><square>, e.g. "Re5".
  let highlights = ()
  let mcsl = c.match(_csl-re)
  if mcsl != none {
    for tok in mcsl.captures.at(0).split(",") {
      let t = tok.trim()
      if t.len() >= 3 { highlights.push((t.slice(1, 3), t.slice(0, 1))) }
    }
  }

  // diagram marker. ChessBase "#" (optionally "#[caption]") first; then the
  // bracketed Scid form and the literal LaTeX / Markdown forms.
  let diagram = none
  let mcb = c.match(_cb-marker-re)
  if mcb != none {
    diagram = (caption: mcb.captures.at(1))
  } else if c.match(_scid-marker-re) != none {
    diagram = (caption: none)
  } else if c.contains("\\diagram") {
    diagram = (caption: none)
  } else if c.contains("%%diagram") {
    diagram = (caption: none)
  }

  // residual prose: strip every command/marker, collapse whitespace.
  let text = c
  text = text.replace(_strip-cal-re, "")
  text = text.replace(_strip-csl-re, "")
  text = text.replace(_strip-cb-re, "")
  text = text.replace(_scid-marker-re, "")
  text = text.replace("\\diagram", "")
  text = text.replace("%%diagram", "")
  text = text.replace(_ws-collapse-re, " ").trim()

  (diagram: diagram, arrows: arrows, highlights: highlights, text: text)
}
