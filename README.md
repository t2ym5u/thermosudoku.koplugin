# thermosudoku.koplugin

A Thermo Sudoku plugin for [KOReader](https://github.com/koreader/koreader).

## Screenshot

*(Screenshot to be added.)*

## Rules

Standard 9×9 Sudoku rules plus **thermometer constraints**: digits along each thermometer must strictly increase from the bulb toward the tip.

## Features

- **Three difficulty levels** — Easy, Medium, Hard
- **Thermometer display** — bulbs and tubes clearly shown on the grid
- **Note mode** — pencil in candidate digits
- **Check** — highlights cells violating thermometer constraints
- **Reveal solution** — shows the full solution
- **Undo** — step back through your moves
- **Auto-save** — game state saved and restored on next launch

## Installation

1. Download `thermosudoku.koplugin.zip` from the [latest release](../../releases/latest).
2. Extract into the `plugins/` folder of your KOReader data directory.
3. Restart KOReader.
4. Open the menu → **Tools** → **Thermo Sudoku**.

## Controls

| Action | How |
|--------|-----|
| Select a cell | Tap it |
| Enter a digit | Tap the digit button |
| Erase a cell | Tap **Erase** |
| Toggle note mode | Tap **Note: Off / On** |
| Undo last move | Tap **Undo** |
| Check progress | Tap **Check** |
| New game | Tap **New game** |
| Change difficulty | Tap **Diff** |
| Show rules | Tap **Rules** |

## License

GPL-3.0 — see [LICENSE](LICENSE).
