Vendored code: provenance and license status
==============================================

Everything under `vendor/staunton/` is a snapshot of a locally modified fork
of the `staunton` Typst package (chess boards, FEN/PGN diagrams, notation),
folded directly into caxton so caxton has no external Typst package
dependency at all.

Sources
-------

- Upstream: `staunton` v2.0.0, https://github.com/ndg6/staunton
  (MIT AND GPL-2.0-or-later -- see `LICENSE` and `LICENSE-PIECES` in this
  directory, copied unchanged from upstream).
- Fork: `staunton-fork` (local, sibling project to caxton), commit
  `a3a27ce` (branch `shakmaty-engine`). Three changes from upstream:
  1. `src/game.typ`'s `_mainline-positions` (standard-chess games only)
     resolves a game's mainline through a bundled WASM plugin instead of a
     pure-Typst move generator (fork commit `3d641227` -- see its message
     for the rationale and correctness work: matching the original engine's
     en-passant semantics and error wording exactly; verified against the
     fork's own 218-test suite and a byte-for-byte identical real-document
     benchmark before and after).
  2. The interpreted hot paths left downstream of that plugin cut (fork
     commit `f7ce8816`): the plugin's per-ply resolved-move fields replace
     the per-diagram pure-Typst `legal-moves()` walk, mainline positions
     parse lazily (one `parse-fen` per addressed ply, not all N+1), and the
     hottest helpers drop per-call regex construction / eager assert
     messages (fen.typ, coords.typ, pieces.typ, annotations.typ, i18n.typ,
     pgn.typ). Verified against the same 218-test suite and pixel-identical
     rendering of the fork's real-document benchmark and showcase.
  3. Bundled `shakmaty.wasm` updated (fork commits `352b3bb`, `a3a27ce`) to
     accept PGN's null-move convention (`"--"` / `"Z0"`) -- editorial game
     collections (e.g. annotated books) use it to attach a comment to a ply
     without an actual move being played; the plugin previously rejected it
     outright, which failed EVERY later diagram in that game (it resolves a
     game's whole mainline in one call). `game.typ`'s `_resolved-move` fast
     path also needed `.at(.., default: none)` instead of bare field access
     for from/to/piece/color/kind, since a null-move ply's ply entry omits
     them exactly like the starting-position entry already does -- caught by
     a diagram requested AT the null move's own locator. No behavior change
     for any game without a null move. Verified against the fork's
     220-test suite (2 new regression tests added for this).
- Plugin: `typst-shakmaty-engine`,
  https://github.com/obazin/typst-shakmaty-engine --
  the Rust source `src/assets/engine/shakmaty.wasm` is built from, wrapping
  the `shakmaty` crate (GPL-3.0-or-later) as a Typst WASM plugin. See that
  project's own README for its protocol and build instructions. The bundled
  binary is that project's commit `e252318`,
  https://github.com/obazin/typst-shakmaty-engine/tree/e252318f301829bf2368cbe97865309e4575b561
  (accepts PGN null moves via
  `Position::swap_turn`; built at `opt-level = 3` -- Typst executes plugins
  under the wasmi interpreter, where size-optimized builds run several
  times slower).

License status: UNRESOLVED, flagged deliberately
-------------------------------------------------

Caxton's own `typst.toml` still declares plain `MIT` -- **this has not been
reconciled with what's now bundled here**, and should be before caxton is
ever published or distributed:

- The vendored staunton code itself is MIT (`LICENSE`); its bundled piece-set
  SVGs are GPL-2.0-or-later (`LICENSE-PIECES`) -- upstream's own existing
  multi-license split, justified there as mere aggregation (displaying image
  data, not linking against it).
- `shakmaty.wasm` is a different case: Typst's `plugin()` mechanism *calls
  into* the GPL-3.0-or-later `shakmaty` code to compute a result, which is
  arguably closer to "combining" than "aggregating" under GPL -- a real,
  non-obvious distinction, not a formality. What that implies for caxton's
  own license (add an "AND GPL-3.0-or-later" clause? relicense the whole
  package? something narrower?) has not been decided and needs a real
  answer -- ideally with actual legal input -- before this goes anywhere
  public. Nothing here has been published; this note exists so that
  question doesn't get silently lost.
