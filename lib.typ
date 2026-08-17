// ===========================================================================
// caxton -- typeset an annotated PGN chess game as a print-ready book page.
//
// Built on top of the `staunton` chess package (@preview/staunton). Renders
// figurine move notation with bold mainline moves, nested variations, NAGs
// and comments, with diagrams embedded exactly where the PGN itself marks
// them -- not at arbitrary fixed intervals.
//
// Diagram placement follows the two markers real chess software actually
// writes into PGN comments. These were verified against ChessBase, Scid and
// RPB Chessboard documentation directly -- NOT against staunton's own built-in
// marker set, which turns out to differ from real-world practice on two of
// its four forms (see notes below):
//   - `[#]` anywhere in a comment       (ChessBase / RPB Chessboard)
//   - a comment that STARTS with `#`     (Scid's own documented rule)
// The marker is stripped before the surrounding comment is printed as prose.
// If a game carries no markers at all, one diagram is drawn at the final
// position instead, so output is never diagram-less.
//
// (staunton's `notation(diagrams: true)` recognises a bare `#`, an
// `#[caption]` form, and `[d]`/`[D]`, plus `\diagram`/`%%diagram` -- of these,
// only bare `#` overlaps with a REAL convention (Scid's "starts with #"), and
// even that only by coincidence: Scid's rule is about the comment's own
// leading character, not a marker anywhere in it. `#[caption]`, `[d]`/`[D]`
// as a literal bracket form, and `\diagram`/`%%diagram` could not be
// confirmed against any real tool's documentation or output. staunton's
// mechanism is also unsafe here for another reason -- seeded further down.)
// ===========================================================================

#import "@preview/staunton:2.0.0": game, notation, board, movetext, game-start, set-board-defaults, color-theme, with-comments

// ---- diagram marker detection ---------------------------------------------

// Strip a diagram marker from a raw comment string, returning whether one was
// found and the remaining prose (trimmed). Two independent forms, per the
// module doc comment above; either (or both) may be present.
#let _strip-marker(raw) = {
  let has-bracket = raw.contains("[#]")
  let has-leading = raw.trim().starts-with("#")
  let text = raw
  if has-bracket { text = text.replace("[#]", "") }
  text = text.trim()
  if has-leading and text.starts-with("#") { text = text.slice(1) }
  (has-marker: has-bracket or has-leading, prose: text.trim())
}

// A mainline node's comment, reduced to what this module needs: whether it
// carries a diagram marker, whether any prose remains once the marker (if
// any) is removed, and that prose itself.
#let _comment-info(node) = {
  let raw = node.at("comment-after", default: none)
  if raw == none { return (has-marker: false, has-prose: false, prose: "") }
  let r = _strip-marker(raw)
  (has-marker: r.has-marker, has-prose: r.prose != "", prose: r.prose)
}

// ---- locator arithmetic ----------------------------------------------------

// 0-based mainline ply index -> a "Nw"/"Nb" locator, honouring the game's own
// starting move number and side to move (so this works for a game beginning
// mid-position via a `[FEN]` tag, not just a standard from-move-1 game).
#let _locator-of-index(i, start) = {
  let start-ply = if start.turn == "w" { 2 * start.fullmove - 1 } else { 2 * start.fullmove }
  let raw = (i + 1) + start-ply - 1
  str(int((raw + 1) / 2)) + (if calc.odd(raw) { "w" } else { "b" })
}

// ---- title / subtitle auto-detection from PGN tags -------------------------

#let _auto-title(g) = {
  let w = g.tags.at("White", default: none)
  let b = g.tags.at("Black", default: none)
  if w != none and b != none { [#w #sym.dash.en #b] }
  else if w != none { [#w] }
  else if b != none { [#b] }
  else { none }
}

#let _year-of(g) = {
  let d = g.tags.at("Date", default: none)
  if d == none { return none }
  let m = d.match(regex("^(\d{4})"))
  if m != none { m.captures.at(0) } else { none }
}

#let _auto-subtitle(g) = {
  let ev = g.tags.at("Event", default: none)
  let yr = _year-of(g)
  let parts = ()
  if ev != none and ev != "?" { parts.push(ev) }
  if yr != none { parts.push(yr) }
  if parts.len() == 0 { none } else { parts.join(", ") }
}

/// Typeset a single annotated PGN game as a print-ready book page.
///
/// - pgn (str, content): the raw PGN text (a string, or a ```` ```raw block ````).
///   Hard-wrapped comment newlines are collapsed to spaces before parsing, so
///   a PGN wrapped at a fixed column doesn't force mid-sentence line breaks.
/// - title (auto, content, none): page header / title line. `auto` reads
///   "White -- Black" from the PGN's own tags; `none` omits it.
/// - subtitle (auto, content, none): line under the title. `auto` reads
///   "Event, Year" from the PGN's tags; `none` omits it.
/// - paper (str): page size, forwarded to `#set page(paper: ..)`.
/// - columns (int): column count, forwarded to `#set page(columns: ..)`.
/// - margin (auto, dictionary, length): page margin; `auto` picks a margin
///   proportioned for the default A5/2-column layout.
/// - board-size (length): each diagram's width. Tuned by default for a
///   two-column A5 page -- widen it if you change `paper`/`columns`.
/// - board-color-theme (dictionary): a `staunton` `color-theme(..)` value.
///   Defaults to a monochrome, diagonally-hatched look (white squares, a
///   `"stripes"` pattern marking the dark ones) echoing older chess book
///   engravings.
/// - board-labels (bool): show file/rank coordinates on each diagram.
/// - board-border (stroke): stroke around each diagram.
/// - font (str, array): body text font (with fallbacks). The fallback needs
///   to cover the Unicode chess-figurine block (U+2654-U+265F) for
///   `figurine: true` notation to render as pieces rather than tofu boxes;
///   "Arial Unicode MS" and "Apple Symbols" are the two known to on macOS,
///   with the former noticeably better-weighted and baseline-aligned.
/// - text-size (length): body text size.
/// - leading (length): line spacing, forwarded to `#set par(leading: ..)`.
/// - header-font (str): font for the running header (title + page number).
/// - to-move-marker (bool): draw a small hollow triangle outside each
///   diagram's bottom-right corner, in the old chess-book "side to move"
///   tradition. Purely decorative -- it does not indicate which side is
///   actually to move.
/// - marker-gap (length): horizontal gap between a diagram's right edge and
///   its triangle, when `to-move-marker` is on.
/// -> content
#let caxton(
  pgn,
  title: auto,
  subtitle: auto,
  paper: "a5",
  columns: 2,
  margin: auto,
  board-size: 46mm,
  board-color-theme: color-theme(light: white, dark: white, pattern: "stripes"),
  board-labels: false,
  board-border: 1pt + black,
  font: ("Avenir Next", "Arial Unicode MS"),
  text-size: 8.3pt,
  leading: 0.68em,
  header-font: "Baskerville",
  to-move-marker: true,
  marker-gap: auto,
) = {
  // Hard-wrapped comment newlines (common in exported/book PGNs) become plain
  // spaces before parsing, so justification -- not the source file's column
  // width -- decides where lines actually break.
  let pgn-text = {
    let t = if type(pgn) == str { pgn }
      else if type(pgn) == content and pgn.func() == raw { pgn.text }
      else { panic("caxton: `pgn` must be a string or a raw block") }
    t.replace(regex("\s+"), " ")
  }
  let g = game(pgn-text)
  let start = game-start(g)
  let loc-of(i) = _locator-of-index(i, start)

  let gap = if marker-gap == auto { board-size / 8 / 1.5 } else { marker-gap }
  let ttl = if title != auto { title } else { _auto-title(g) }
  let sub = if subtitle != auto { subtitle } else { _auto-subtitle(g) }

  set page(
    paper: paper,
    margin: if margin == auto { (top: 20mm, bottom: 16mm, x: 12mm) } else { margin },
    columns: columns,
    header: if ttl == none { none } else { context [
      #set text(font: header-font, style: "italic", size: 9.5pt)
      #grid(columns: (1fr, auto), ttl, align(right)[#counter(page).display()])
      #v(-2pt)
      #line(length: 100%, stroke: 0.4pt + luma(120))
    ] },
  )
  set text(font: font, size: text-size, hyphenate: true)
  set par(justify: true, leading: leading)
  set-board-defaults(
    size: board-size,
    labels: board-labels,
    border: board-border,
    color-theme: board-color-theme,
  )

  if ttl != none or sub != none {
    align(center)[
      #if ttl != none { text(size: 18pt, weight: "bold", ttl) }
      #if ttl != none and sub != none { v(0.2em) }
      #if sub != none { text(size: 12pt, style: "italic", sub) }
    ]
    v(1em)
  }

  // The triangle sits just outside the board's bottom-right corner --
  // `breakable: false` keeps the board and its marker together instead of
  // splitting across a column break.
  let with-marker(b) = block(breakable: false, width: board-size)[
    #b
    #if to-move-marker {
      place(bottom + right, dx: gap, text(size: 11pt)[#sym.triangle.stroked.t])
    }
  ]

  let nodes = movetext(g)
  let any-marker = nodes.any(n => _comment-info(n).has-marker)

  // A PGN comment BEFORE the very first move (e.g. an introductory note) is
  // carried as the first node's `comment-before` -- `notation()` never
  // renders that field (only `comment-after`), so it needs printing by hand.
  let intro = nodes.first().at("comment-before", default: none)
  if intro != none {
    [#intro.trim()]
    parbreak()
  }

  let run-start = 0
  for (i, node) in nodes.enumerate() {
    let loc = loc-of(i)
    let info = _comment-info(node)
    let is-last = i == nodes.len() - 1
    // Pure marker-driven placement when the game carries any; otherwise a
    // single diagram at the final position, so output is never diagram-less.
    let is-diagram-point = if any-marker { info.has-marker } else { is-last }
    if info.has-prose or info.has-marker or is-last {
      // `comments: true` is needed so prose nested INSIDE a variation still
      // renders -- not just this run's own trailing comment. But staunton's
      // `_move-token` concatenates a MAINLINE move's own trailing comment
      // into the same string as the move before `strong()` wraps it, so
      // printing it through `comments: true` here would bold the prose (and
      // the marker) along with the move -- variations dodge this because
      // they always render through a separate `bold: false` call. Blank out
      // just this run's own ending comment before rendering (nested-variation
      // comments elsewhere in the range are untouched), then print the
      // cleaned, marker-stripped text as its own ordinary-weight paragraph.
      let notation-source = if info.has-prose or info.has-marker {
        let overrides = (:)
        overrides.insert(loc, "")
        with-comments(g, comments: overrides)
      } else { g }
      notation(
        notation-source, from: loc-of(run-start), to: loc,
        figurine: true, nags: true, variations: true, comments: true, spaced: false,
        result: is-last,
      )
      parbreak()
      if info.has-prose {
        [#info.prose]
        parbreak()
      }
      if is-diagram-point {
        align(center, with-marker(board(g, at: loc)))
        v(2pt)
      }
      run-start = i + 1
    }
  }
}
