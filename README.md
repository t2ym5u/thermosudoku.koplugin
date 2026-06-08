# Thermo Sudoku

> **Status: stub — not yet implemented**

## Description

Standard Sudoku where thermometer-shaped lines are drawn on the grid. Numbers must strictly increase from the bulb end.

## Files to create

- `board.lua` — game logic, puzzle generator, serialize/load
- `board_widget.lua` — grid rendering and tap gestures
- `screen.lua` — full-screen layout (buttons + board)
- `main.lua` — PluginBase entry point

## Notes

Shares rules with sudoku.koplugin; extend SudokuBoard base or copy and add variant constraints.
