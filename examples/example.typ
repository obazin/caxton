// Minimal usage: point `caxton` at a PGN and it does the rest -- title and
// subtitle come from the PGN's own tags, diagrams appear exactly where the
// PGN itself marks them ([#] / a comment starting with #), and the layout
// defaults to a two-column A5 page in the old chess-book style.
#import "@local/caxton:0.1.0": caxton

#caxton(read("fischer_spassky_1972_g6.pgn"))
