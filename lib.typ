// ===========================================================================
// caxton -- typeset annotated PGN chess games as print-ready book pages.
//
// Built on top of a vendored copy of the `staunton` chess engine/rendering
// package (vendor/staunton/ -- see vendor/staunton/NOTICE.md for its
// provenance and licensing). Caxton is a single, self-contained Typst
// package: no `@preview`/`@local` imports anywhere, only this one relative
// file import plus whatever staunton's own code already imports from itself
// (unchanged, all relative, since before this vendoring). staunton's own
// engine internals (src/game.typ's mainline resolution) call out to a
// bundled WASM plugin (vendor/staunton/src/assets/engine/shakmaty.wasm,
// built from the Rust `shakmaty` crate) for chess move generation --
// dramatically faster than a pure-Typst engine on diagram-heavy documents;
// see vendor/staunton/NOTICE.md.
//
// Renders figurine move notation with bold mainline moves, nested
// variations, NAGs and comments, with diagrams embedded exactly where the
// PGN itself marks them -- not at arbitrary fixed intervals. A PGN holding
// several games is typeset game by game, each starting on a fresh page with
// its own title, subtitle and running header read from that game's tags.
//
// Diagram placement follows the two markers real chess software actually
// writes into PGN comments. These were verified against ChessBase, Scid and
// RPB Chessboard documentation directly -- NOT against staunton's own built-in
// marker set, which turns out to differ from real-world practice on two of
// its four forms (see notes below):
//   - `[#]` anywhere in a comment       (ChessBase / RPB Chessboard)
//   - a comment that STARTS with `#`     (Scid's own documented rule)
// The marker is stripped before the surrounding comment is printed as prose.
// If a game carries no markers at all, diagrams are placed automatically: at
// a fixed move interval throughout, plus extra ones after heavily-annotated
// mainline moves past the opening (with a minimum spacing between
// diagrams) -- and always at the final position, so output is never
// diagram-less.
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

#import "vendor/staunton/lib.typ": game, notation, board, movetext, game-start, set-board-defaults, color-theme, with-comments

// ---- diagram marker detection ---------------------------------------------

// Strip a diagram marker from a raw comment string, returning whether one was
// found and the remaining prose (trimmed). Two independent forms, per the
// module doc comment above; either (or both) may be present.
//
// `%cal`/`%csl` (arrows / highlighted squares) are also stripped from the
// prose here -- but only here, for what THIS module prints and measures.
// They stay untouched in the underlying game (`board(g, at: loc, ...)` reads
// straight from it), so they still draw on the diagram; `staunton`'s own
// `notation(..., comments: true)` likewise cleans them from any OTHER
// comment it renders (nested-variation prose) via its own
// `interpret-comment`. This module only needs its own copy because it
// prints one comment -- the run's own trailing one -- itself, outside
// `notation()`, to keep it out of the bolded mainline text.
// Hoisted: `_strip-marker` runs for every commented mainline node (via
// `_comment-info`), and Typst compiles a `regex(..)` literal on every
// evaluation -- same lesson as staunton's own hoisted token regexes.
#let _cal-csl-re = regex("\[%(cal|csl)[^\[\]]*\]")
#let _strip-marker(raw) = {
  let text = raw.replace(_cal-csl-re, "")
  let has-bracket = text.contains("[#]")
  let has-leading = text.trim().starts-with("#")
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

// A game with zero mainline moves (a PGN "game" that's really a standalone
// note -- e.g. `PlyCount "0"`, just `{some comment} *`) has no move node for
// a leading comment to attach to, so staunton's own parser drops it: its
// `_parse-movetext` only ever transfers a pending leading comment onto a
// node when a SAN token follows it, which never happens here (see
// vendor/staunton/src/pgn.typ). Recovered here straight from the game's raw
// movetext text, which `game(..)` preserves verbatim as `movetext-raw` --
// already run through caxton's own `_strip-pgn-commands`/whitespace-collapse
// by the time it gets there, same as every other comment. Not passed through
// `_strip-marker`, matching the existing (non-empty-game) intro-comment
// handling below, which never marker-strips it either.
#let _leading-comment-re = regex("^\{([^}]*)\}")
#let _leading-comment-of-raw(raw) = {
  let m = raw.trim().match(_leading-comment-re)
  if m == none { none } else { m.captures.at(0) }
}

// ---- locator arithmetic ----------------------------------------------------

// 0-based mainline ply index -> the game's own raw ply number, honouring its
// starting move number and side to move (so this works for a game beginning
// mid-position via a `[FEN]` tag, not just a standard from-move-1 game).
#let _raw-ply-of-index(i, start) = {
  let start-ply = if start.turn == "w" { 2 * start.fullmove - 1 } else { 2 * start.fullmove }
  (i + 1) + start-ply - 1
}

// 0-based mainline ply index -> a "Nw"/"Nb" locator.
#let _locator-of-index(i, start) = {
  let raw = _raw-ply-of-index(i, start)
  str(int((raw + 1) / 2)) + (if calc.odd(raw) { "w" } else { "b" })
}

// 0-based mainline ply index -> the full move number it falls in.
#let _full-move-of-index(i, start) = int((_raw-ply-of-index(i, start) + 1) / 2)

// ---- automatic diagram placement -------------------------------------------

// When a game carries no explicit diagram marker anywhere, diagrams are placed
// automatically instead: at a fixed interval of `_plain-interval` plies (8
// full moves) throughout, PLUS after each heavily-annotated mainline move
// past the opening (prose of `_heavy-prose-chars` characters or more, full
// move number > `_heavy-prose-min-move`) -- the two are additive, not
// alternatives, so a game whose comments are all short ("Blunder. dxe5 was
// best.", as engines/servers commonly emit) still gets a diagram every 8
// moves instead of falling through to just the final position; a game with
// no comments at all gets the same fixed spacing; a heavily-annotated move
// adds an extra diagram on top, wherever it falls. No two diagrams closer
// than `_min-diagram-gap` plies (whichever source they came from). Heavy
// prose is common in opening theory (a note on move 4 citing a whole line)
// where a diagram adds little; gating it to past move 8 keeps that EXTRA
// diagram concentrated on the middlegame/endgame, where a position is
// actually worth seeing (the fixed interval still covers the opening). The
// final position always gets a diagram; an auto point fewer than
// `_min-diagram-gap` plies before it is dropped in its favour, so output is
// never diagram-less and never near-duplicated at the end.
#let _heavy-prose-chars = 180
#let _heavy-prose-min-move = 8  // full move number; heavy-prose points only past this
#let _min-diagram-gap = 6
#let _plain-interval = 16  // plies between fixed-interval diagrams

// -> array of 0-based mainline node indexes after which to draw a diagram.
// `infos` is the per-node `_comment-info` array, computed ONCE by the caller
// and shared with the render loop -- three separate full passes re-deriving
// it (markers, heavy prose, rendering) was measurable on long games.
#let _diagram-points(infos, start) = {
  if infos.len() == 0 { return () }
  let marked = range(infos.len()).filter(i => infos.at(i).has-marker)
  if marked.len() > 0 { return marked }
  let heavy = range(infos.len()).filter(i => (
    infos.at(i).prose.len() >= _heavy-prose-chars
    and _full-move-of-index(i, start) > _heavy-prose-min-move
  ))
  let interval = range(infos.len()).filter(i => calc.rem(i + 1, _plain-interval) == 0)
  let candidates = (heavy + interval).dedup().sorted()
  let pts = ()
  for i in candidates {
    if pts.len() == 0 or i - pts.last() >= _min-diagram-gap { pts.push(i) }
  }
  let last = infos.len() - 1
  if pts.len() > 0 and pts.last() != last and last - pts.last() < _min-diagram-gap {
    let _ = pts.pop()
  }
  if pts.len() == 0 or pts.last() != last { pts.push(last) }
  pts
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

#let _year-re = regex("^(\d{4})")
#let _year-of(g) = {
  let d = g.tags.at("Date", default: none)
  if d == none { return none }
  let m = d.match(_year-re)
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

// ---- multi-game splitting ---------------------------------------------------

// Split raw (un-collapsed) PGN text into one string per game. A new game
// begins at a tag-pair line once the current game's movetext has been seen.
// Brace-comment state is tracked across lines so a hard-wrapped comment line
// that happens to start with `[` is never mistaken for a new tag section
// (PGN `{}` comments don't nest; `;` comments run to end of line).
// PGN's own "escape mechanism" (spec section 4): a line whose FIRST character
// is `%` is not part of the game at all -- the whole line is skipped by any
// conforming PGN reader. Real-world exporters use it for header/toolchain
// metadata ahead of the first game (e.g. ChessBase's `% BOOKTITLE = ...`), so
// this must run before `_split-games` walks the file, not per-game: a % line
// sitting before the first `[Event ..]` tag has no tags of its own yet, so
// `_split-games`'s "a tag line after movetext starts a new game" rule would
// otherwise treat it as movetext and split off a bogus tagless leading
// "game" -- which then fails in `game()`/the SAN resolver on the literal `%`
// token. `(?m)` makes `^` match after every `\n`, not just the string start.
#let _percent-escape-re = regex("(?m)^%[^\n]*\n?")
#let _strip-percent-escapes(text) = text.replace(_percent-escape-re, "")

#let _tag-rest-re = regex("^[A-Za-z0-9_]+\s*\"")
// The three characters that drive the comment-state machine below. Scanning a
// line for just these via one native regex pass (usually zero matches) beats
// an interpreted per-character `.clusters()` walk over the entire file.
#let _comment-delims-re = regex("[{};]")
#let _split-games(text) = {
  let games = ()
  let current = ()
  let in-comment = false
  let seen-movetext = false
  for line in text.split("\n") {
    let stripped = line.trim()
    if not in-comment and stripped != "" {
      let is-tag = stripped.starts-with("[") and stripped.slice(1).trim().match(_tag-rest-re) != none
      if is-tag and seen-movetext {
        games.push(current.join("\n"))
        current = ()
        seen-movetext = false
      } else if not is-tag {
        seen-movetext = true
      }
    }
    current.push(line)
    for m in line.matches(_comment-delims-re) {
      let c = m.text
      if in-comment {
        if c == "}" { in-comment = false }
      } else {
        if c == "{" { in-comment = true } else if c == ";" { break }
      }
    }
  }
  games.push(current.join("\n"))
  games.filter(g => g.trim() != "")
}

// ---- PGN command annotations -----------------------------------------------

// Chess GUIs and servers (lichess, chess.com, ChessBase, Scid, ...) embed
// machine-readable annotations directly inside `{}` comments, using the PGN
// "command" syntax `[%name args]`. Two of these are pure engine/clock
// telemetry with no meaning for a printed book -- `[%eval 0.09]` (or
// `[%eval #3]` for a mate score) and `[%clk 0:08:53]` -- and must never
// appear in rendered prose, nor feed into any decision meant for
// human-authored text: the "heavily annotated move" heuristic below, or
// `[#]`/leading-`#` diagram-marker detection (a raw comment of just
// `{[%eval #3]}` must not be mistaken for a `#`-led Scid diagram marker).
// Only these two are stripped, deliberately by name rather than by the
// generic `[%...]` shape -- `%cal` (arrows) and `%csl` (highlighted
// squares) are graphical annotations that `staunton` itself parses out of
// the same raw comment text to draw on the board (see its
// `interpret-comment`), so removing them here would silently kill that
// rendering. Stripped once, from each game's raw text, before it's handed
// to `game()` -- this clears mainline comments, comments nested inside
// variations, and the pre-first-move intro comment all in one pass, rather
// than requiring every downstream reader to know about it.
#let _eval-clk-re = regex("\[%(eval|clk)[^\[\]]*\]")
#let _strip-pgn-commands(text) = {
  text.replace(_eval-clk-re, "")
}
#let _ws-re = regex("\s+")

/// Typeset one or more annotated PGN games as print-ready book pages.
///
/// - pgn (str, content): the raw PGN text (a string, or a ```` ```raw block ````).
///   May contain several games back to back (the usual multi-game PGN file
///   layout); each game starts on a fresh page. Engine/clock PGN command
///   annotations inside comments (`[%eval ..]`, `[%clk ..]` -- written by
///   lichess, chess.com and similar tools) are stripped before parsing, so
///   they never appear in rendered prose and never affect diagram placement;
///   `[%cal ..]`/`[%csl ..]` (arrows / highlighted squares) are left alone
///   and still render on the diagrams as `staunton` supports. Hard-wrapped
///   comment newlines are collapsed to spaces before parsing, so a PGN
///   wrapped at a fixed column doesn't force mid-sentence line breaks.
/// - title (auto, content, none): page header / title line. `auto` reads
///   "White -- Black" from each game's own tags; `none` omits it. An explicit
///   value applies to every game in the PGN.
/// - subtitle (auto, content, none): line under the title. `auto` reads
///   "Event, Year" from each game's tags; `none` omits it. An explicit value
///   applies to every game in the PGN.
/// - paper (str): page size, forwarded to `#set page(paper: ..)`.
/// - columns (int): column count for the movetext. The title/subtitle block
///   spans the full page width, above the columns -- only the movetext
///   itself (and its diagrams) is split into columns.
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
  // Splitting into games is line-based, so it happens on the raw text --
  // before hard-wrapped newlines are collapsed away.
  let raw-text = if type(pgn) == str { pgn }
    else if type(pgn) == content and pgn.func() == raw { pgn.text }
    else { panic("caxton: `pgn` must be a string or a raw block") }
  let games = _split-games(_strip-percent-escapes(raw-text))

  let gap = if marker-gap == auto { board-size / 8 / 1.5 } else { marker-gap }

  // Columns are NOT set page-wide: the title/subtitle block below needs the
  // full page width. Instead, only the movetext body (after that block) is
  // wrapped in its own `std.columns(..)` call further down -- `std.` because
  // `columns` here is this function's own parameter, shadowing the built-in.
  set page(
    paper: paper,
    margin: if margin == auto { (top: 20mm, bottom: 16mm, x: 12mm) } else { margin },
  )
  set text(font: font, size: text-size, hyphenate: true)
  set par(justify: true, leading: leading)
  set-board-defaults(
    size: board-size,
    labels: board-labels,
    border: board-border,
    color-theme: board-color-theme,
  )

  // The triangle sits just outside the board's bottom-right corner --
  // `breakable: false` keeps the board and its marker together instead of
  // splitting across a column break.
  let with-marker(b) = block(breakable: false, width: board-size)[
    #b
    #if to-move-marker {
      place(bottom + right, dx: gap, text(size: 11pt)[#sym.triangle.stroked.t])
    }
  ]

  for (game-index, game-text) in games.enumerate() {
    // PGN command annotations (`[%eval ..]`, `[%clk ..]`, ...) are stripped
    // first, then hard-wrapped comment newlines (common in exported/book
    // PGNs) become plain spaces before parsing, so justification -- not the
    // source file's column width -- decides where lines actually break. The
    // whitespace collapse also mops up any doubled-up spaces left behind
    // where a command annotation was removed.
    let g = game(_strip-pgn-commands(game-text).replace(_ws-re, " "))
    let start = game-start(g)
    let loc-of(i) = _locator-of-index(i, start)

    let ttl = if title != auto { title } else { _auto-title(g) }
    let sub = if subtitle != auto { subtitle } else { _auto-subtitle(g) }

    if game-index > 0 { pagebreak(weak: true) }
    // Scoped to this loop iteration, so each game's pages carry that game's
    // own running header (the per-game `set page` also guarantees the game
    // starts on a fresh page).
    set page(header: if ttl == none { none } else { context [
      #set text(font: header-font, style: "italic", size: 9.5pt)
      #grid(columns: (1fr, auto), ttl, align(right)[#counter(page).display()])
      #v(-2pt)
      #line(length: 100%, stroke: 0.4pt + luma(120))
    ] })

    if ttl != none or sub != none {
      align(center)[
        #if ttl != none { text(size: 18pt, weight: "bold", ttl) }
        #if ttl != none and sub != none { v(0.2em) }
        #if sub != none { text(size: 12pt, style: "italic", sub) }
      ]
      v(1em)
    }

    let nodes = movetext(g)
    // One `_comment-info` pass, shared by diagram placement (its two filters)
    // and the render loop below; membership in `diagram-points` as a flat
    // boolean array rather than a per-node `.contains(..)` scan.
    let infos = nodes.map(_comment-info)
    let diagram-points = _diagram-points(infos, start)
    let is-diagram-point-at = {
      let flags = range(nodes.len()).map(_ => false)
      for p in diagram-points { flags.at(p) = true }
      flags
    }

    // The movetext itself -- collected into one content value so it can be
    // handed to `std.columns(..)` below, rather than flowing straight into
    // the page (which would put it under the title/subtitle at full width
    // too; it needs its own, narrower column measure).
    let movetext-body = {
      // A PGN comment BEFORE the very first move (e.g. an introductory note)
      // is carried as the first node's `comment-before` -- `notation()`
      // never renders that field (only `comment-after`), so it needs
      // printing by hand.
      let intro = if nodes.len() > 0 {
        nodes.first().at("comment-before", default: none)
      } else { _leading-comment-of-raw(g.movetext-raw) }
      if intro != none {
        [#intro.trim()]
        parbreak()
      }

      // Every run-ending comment blanked in ONE derived game, instead of a
      // fresh full-size patched game dict per commented run: a node with
      // prose/marker is by construction the LAST node of its own run, so each
      // notation slice below sees exactly its own ending comment blanked and
      // nobody else's -- same rendering, but all runs now share a single
      // source dict (one `with-comments` call, one memo key).
      let overrides = (:)
      for (i, info) in infos.enumerate() {
        if info.has-prose or info.has-marker { overrides.insert(loc-of(i), "") }
      }
      let clean-g = if overrides.len() > 0 { with-comments(g, comments: overrides) } else { g }

      let run-start = 0
      for (i, node) in nodes.enumerate() {
        let loc = loc-of(i)
        let info = infos.at(i)
        let is-last = i == nodes.len() - 1
        // Pure marker-driven placement when the game carries any; otherwise
        // automatic placement at heavily-annotated moves or fixed intervals
        // (see `_diagram-points`), always including the final position.
        let is-diagram-point = is-diagram-point-at.at(i)
        if info.has-prose or info.has-marker or is-last or is-diagram-point {
          // `comments: true` is needed so prose nested INSIDE a variation still
          // renders -- not just this run's own trailing comment. But staunton's
          // `_move-token` concatenates a MAINLINE move's own trailing comment
          // into the same string as the move before `strong()` wraps it, so
          // printing it through `comments: true` here would bold the prose (and
          // the marker) along with the move -- variations dodge this because
          // they always render through a separate `bold: false` call. Render
          // from `clean-g` (built above), where every run-ending comment is
          // blanked (nested-variation comments elsewhere in the range are
          // untouched), then print the cleaned, marker-stripped text as its
          // own ordinary-weight paragraph.
          notation(
            clean-g, from: loc-of(run-start), to: loc,
            figurine: true, nags: true, variations: true, comments: true, spaced: false,
            result: is-last,
          )
          parbreak()
          if info.has-prose {
            [#info.prose]
            parbreak()
          }
          if is-diagram-point {
            // `annotations: true` turns on staunton's own `%cal`/`%csl`
            // processing (off by default) so a move's arrows / highlighted
            // squares draw on its diagram, same as real chess software.
            align(center, with-marker(board(g, at: loc, annotations: true)))
            v(2pt)
          }
          run-start = i + 1
        }
      }
    }
    std.columns(columns, movetext-body)
  }
}
