# Changelog

All notable changes to this project will be documented in this file.

## [1.4.0] - 2026-10-01

### Added
- Play sessions are now recorded in the shared `game_stats.lua`, so the game
  finally appears in Dashboard's statistics. Every variant tracked its own
  saved grid but none of them ever reported a session, which is why they were
  all missing from the "most played" list however long you had played.
- `stopPlugin()` and `deletePluginSettings()`, the hooks KOReader 2026.07
  calls when a plugin is deleted from the device (PR #15240): the first closes
  an open game screen, the second drops this game's statistics row.

## [1.3.2] - 2026-09-30

### Fixed
- A digit conflicting with another was meant to stand out, but was painted
  with `Blitbuffer.COLOR_RED` -- a constant KOReader does not define. Its
  palette is greyscale only, so the colour came out `nil` and `renderUtf8Text`
  fell back to black: exactly the colour of a given digit. The conflict was
  invisible. It is now signalled by shape rather than colour -- the digit turns
  bold and gets a bar underneath it.

## [1.3.0] - 2026-09-30

### Added
- Generated puzzles are now guaranteed solvable by **pure deduction** — no
  guessing, ever. Previously only the uniqueness of the solution was checked,
  which is weaker: measured before the change, 35% of 9x9 "expert" grids and
  5% of "hard" ones could only be cracked by trying a digit and backtracking.
- Each difficulty is now a promise about technique, not just clue count:
  Easy never needs more than naked/hidden singles, Medium adds locked
  candidates and naked pairs, Hard adds hidden pairs and triples/quads,
  Expert adds X-Wing, Swordfish and XY-Wing.
- **Hint** button. Three taps: which row/column/box is about to give, then the
  technique and digit, then the value itself (undoable like any other move).
  Hints refuse to run while an entered value contradicts the solution, so they
  can never reason from a false premise.

### Changed
- Large grids generate considerably faster, since a dead end is now rejected by
  constraint propagation instead of a full backtracking search: 12x12 Expert
  3.5s -> 0.13s, 16x16 Expert over 60s -> 1.1s per grid.

### Fixed
- The shared game UI now speaks French (and Spanish/German) again. Its strings
  were going straight to KOReader's gettext, which knows none of them, so
  messages like "Hide result to keep playing." stayed English whatever the
  device language.

## [1.2.10] - 2026-07-28

### Fixed
- Thermometers could only extend right, down, or diagonally-down, so a
  corner cell could never host part of a thermometer — thermometers
  clustered heavily toward the grid's center (the center 3×3 box was
  touched roughly 1.9× more often than a corner box). Thermometers now
  use all 8 directions and are each assigned to a different one of the
  grid's 9 boxes, spreading them across the whole grid.
