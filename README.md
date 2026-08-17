# caxton

Typeset an annotated PGN chess game as a print-ready, book-style page — built on [`staunton`](https://github.com/ndg6/staunton). Point it at a PGN and it renders figurine move notation with bold mainline moves, nested variations, NAGs and comments, diagrams placed exactly where the PGN marks them, and a title/subtitle read straight from the PGN's own tags. Named after William Caxton, who introduced printing to England.

![Example page](examples/preview.png)

## Quick start

```typ
#import "@local/caxton:0.1.0": caxton

#caxton(read("game.pgn"))
```

That's it for the common case — no configuration needed. See [Installing](#installing) for how to get the package onto your machine (it isn't on Typst Universe, only on GitHub, so `@preview/caxton` won't resolve).

## Diagram placement

Diagrams are placed exactly where the PGN itself marks them, using the two markers real chess software actually writes into PGN comments — not a fixed "every N moves" rule, and not staunton's own built-in marker set (which turns out to only partially match real-world practice — see [Why not staunton's own markers](#why-not-stauntons-own-markers)).

A diagram is inserted after a move whose comment contains either:

- **`[#]`** anywhere in the comment — the ChessBase / RPB Chessboard convention.
- **a comment that starts with `#`** — Scid's own documented rule.

The marker is stripped before the surrounding text is printed as prose, so it never shows up in the book. Either form can carry ordinary commentary alongside it — `{Some prose. [#]}` and `{# Some prose}` both work: the diagram is drawn, and "Some prose." is printed as a normal paragraph.

**If a game has no markers anywhere**, one diagram is drawn at the final position instead, so output is never diagram-less. Once a game has *any* real marker, placement becomes purely marker-driven — no automatic diagram is added anywhere else.

### Why not staunton's own markers?

`staunton`'s built-in `notation(diagrams: true)` recognises a bare `#`, an `#[caption]` form, `[d]`/`[D]`, and `\diagram`/`%%diagram`. Checked against ChessBase's, Scid's and RPB Chessboard's own documentation directly: only the bare `#` overlaps with a real convention (Scid's "comment starts with `#`"), and only by coincidence — Scid's actual rule is about the comment's leading character, not a marker anywhere inside it. `#[caption]`, a literal `[d]`/`[D]` bracket form, and `\diagram`/`%%diagram` could not be confirmed against any real tool's documentation or output. ChessBase's real marker — confirmed via RPB Chessboard's PGN syntax docs, which explicitly adopt "the same convention as ChessBase" — is `[#]` (bracket-hash-bracket), which staunton's own regex does not match correctly (it would strip the bare `#` but leave stray `[`/`]` behind).

There's also a correctness reason to reimplement this rather than call `notation(diagrams: true)` directly: staunton concatenates a move's own trailing comment into the *same string* as the move before bolding it, so a marker (and any prose beside it) on a mainline move would get bolded along with the move itself. `caxton` blanks that one comment before rendering and prints the cleaned prose separately, at normal weight — see the comments in `lib.typ` for the full explanation.

## API

```typ
#caxton(
  pgn,                    // required: PGN text (string, or a ```raw block```)
  title: auto,             // auto: "White -- Black" from the PGN tags; content; none
  subtitle: auto,           // auto: "Event, Year" from the PGN tags; content; none
  paper: "a5",
  columns: 2,
  margin: auto,             // auto: proportioned for the default A5/2-column layout
  board-size: 46mm,         // tuned for the default layout; widen if you change paper/columns
  board-color-theme: color-theme(light: white, dark: white, pattern: "stripes"),
  board-labels: false,
  board-border: 1pt + black,
  font: ("Avenir Next", "Arial Unicode MS"),
  text-size: 8.3pt,
  leading: 0.68em,
  header-font: "Baskerville",
  to-move-marker: true,      // small triangle outside each diagram's corner
  marker-gap: auto,          // auto: board-size / 8 / 1.5
)
```

Every field is overridable. The defaults reproduce the two-column A5, diagonally-hatched "old chess book" look this package started as; nothing about the layout is hardcoded beyond those defaults. `board-color-theme` takes any `staunton` `color-theme(..)` value — e.g. a normal green/cream board:

```typ
#import "@preview/staunton:2.0.0": color-theme
#caxton(read("game.pgn"), board-color-theme: color-theme("wikipedia"), board-labels: true)
```

`font` needs a fallback covering the Unicode chess-figurine block (U+2654–U+265F) for pieces to render instead of tofu boxes — `"Arial Unicode MS"` and `"Apple Symbols"` both work on macOS; the former is noticeably better-weighted and baseline-aligned against most body fonts.

`to-move-marker` is purely decorative (an echo of the small side-to-move triangle printed in some older chess books) — it does not indicate which side is actually to move.

## Installing

Not on Typst Universe — clone this repo into Typst's local package directory:

```sh
git clone https://github.com/obazin/caxton.git \
  "$(typst --version >/dev/null 2>&1 && echo "$HOME/Library/Application Support/typst/packages/local/caxton/0.1.0")"
```

(On Linux, the local package directory is `$HOME/.local/share/typst/packages/local/`; on Windows, `%APPDATA%\typst\packages\local\`.) Then `#import "@local/caxton:0.1.0": caxton` as above.

Alternatively, vendor `lib.typ` directly into your project and `#import "lib.typ": caxton` by relative path — the only dependency it pulls in is `@preview/staunton:2.0.0`, resolved automatically by Typst at compile time.

## License

MIT — see [LICENSE](LICENSE). The bundled example PGN (`examples/fischer_spassky_1972_g6.pgn`) is a bare game score with two short annotations written for this package; it carries no third-party commentary.
