local _dir = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
local function lrequire_common(name)
    local key = _dir .. "common/" .. name
    if not package.loaded[key] then
        package.loaded[key] = assert(loadfile(_dir .. "common/" .. name .. ".lua"))()
    end
    return package.loaded[key]
end

local grid_utils       = lrequire_common("sudoku_grid_utils")
local puzzle_generator = lrequire_common("puzzle_generator")
local BaseBoard        = lrequire_common("base_board")

local emptyGrid        = grid_utils.emptyGrid
local emptyNotes       = grid_utils.emptyNotes
local emptyMarkerGrid  = grid_utils.emptyMarkerGrid
local copyGrid         = grid_utils.copyGrid
local copyNotes        = grid_utils.copyNotes

local generateSolvedBoard = puzzle_generator.generateSolvedBoard
local createPuzzle        = puzzle_generator.createPuzzle

-- ---------------------------------------------------------------------------
-- Grid config (9x9 only)
-- ---------------------------------------------------------------------------

local GRID_CONFIGS = {
    { id = "9x9", n = 9, box_rows = 3, box_cols = 3, label = "9×9" },
}

local function getGridConfig(id)
    return GRID_CONFIGS[1]
end

local DEFAULT_DIFFICULTY = "medium"

-- ---------------------------------------------------------------------------
-- Thermometer placement helpers
-- ---------------------------------------------------------------------------

-- Try to place thermos on the solution grid.
-- Returns array of { cells = {{r,c},...} } with 3-5 cells each.
local function placeThermos(solution)
    local n = 9
    -- All 8 compass directions -- using only the 4 "forward" ones (right/
    -- down/both down-diagonals) left corner cells unreachable as a path
    -- cell (arriving at a corner would require a source with a negative
    -- row/col), so thermometers clustered heavily toward the grid's
    -- center and almost never touched the corner boxes. All 8 directions
    -- make every cell reachable from some source, spreading thermometers
    -- across the whole grid. (The reversed-direction retry below already
    -- handles which end becomes the bulb; this is about which cells the
    -- path occupies at all.)
    local directions = {
        { dr = 0,  dc = 1  },  -- right
        { dr = 0,  dc = -1 },  -- left
        { dr = 1,  dc = 0  },  -- down
        { dr = -1, dc = 0  },  -- up
        { dr = 1,  dc = 1  },  -- diag down-right
        { dr = 1,  dc = -1 },  -- diag down-left
        { dr = -1, dc = 1  },  -- diag up-right
        { dr = -1, dc = -1 },  -- diag up-left
    }

    local thermos = {}
    local cell_used = {}  -- track which cells are already in a thermo

    local function cellKey(r, c) return r * 100 + c end

    -- Even with all 8 directions available, uniformly-random start-cell
    -- placement still favors the grid's center: any bounded-length path
    -- dropped at a random position/orientation in a bounded grid is more
    -- likely to fit (not go out of bounds) the closer its start is to the
    -- center -- a general geometric effect, not specific to this game.
    -- Since the target count (5) never exceeds the 9 boxes, assign each
    -- thermometer to its own shuffled box up front and require its start
    -- cell to land there -- this guarantees real spread rather than
    -- merely nudging the odds (a soft inverse-touch-count bias was tried
    -- and found too weak: a start cell biased toward a corner box still
    -- mostly extends its path *into* the center anyway).
    local box_order = {}
    for br = 1, 3 do for bc = 1, 3 do box_order[#box_order + 1] = { br = br, bc = bc } end end
    for i = #box_order, 2, -1 do
        local j = math.random(i)
        box_order[i], box_order[j] = box_order[j], box_order[i]
    end

    local function randomCellInBox(box)
        local row_in_box = math.random(0, 2)
        local col_in_box = math.random(0, 2)
        return (box.br - 1) * 3 + row_in_box + 1, (box.bc - 1) * 3 + col_in_box + 1
    end

    -- Try to place one thermometer with its start cell restricted to
    -- `box` (nil = anywhere). Returns true and appends to `thermos` on
    -- success.
    local function tryPlaceOne(box)
        local r, c
        if box then
            r, c = randomCellInBox(box)
        else
            r, c = math.random(1, n), math.random(1, n)
        end
        if cell_used[cellKey(r, c)] then return false end

        local dir    = directions[math.random(#directions)]
        local length = math.random(3, 5)

        local cells = { {r = r, c = c} }
        for i = 1, length - 1 do
            local nr = r + dir.dr * i
            local nc = c + dir.dc * i
            if nr < 1 or nr > n or nc < 1 or nc > n then return false end
            if cell_used[cellKey(nr, nc)] then return false end
            cells[#cells + 1] = {r = nr, c = nc}
        end
        if #cells < 3 then return false end

        -- Check strictly increasing along the path
        local increasing = true
        for i = 2, #cells do
            local v_prev = solution[cells[i-1].r][cells[i-1].c]
            local v_curr = solution[cells[i].r][cells[i].c]
            if v_curr <= v_prev then
                increasing = false
                break
            end
        end

        -- Try reversed direction if not increasing
        if not increasing then
            local rev = {}
            for i = #cells, 1, -1 do
                rev[#rev + 1] = cells[i]
            end
            local rev_ok = true
            for i = 2, #rev do
                local v_prev = solution[rev[i-1].r][rev[i-1].c]
                local v_curr = solution[rev[i].r][rev[i].c]
                if v_curr <= v_prev then
                    rev_ok = false
                    break
                end
            end
            if rev_ok then
                cells = rev
                increasing = true
            end
        end

        if not increasing then return false end

        for _, cell in ipairs(cells) do
            cell_used[cellKey(cell.r, cell.c)] = true
        end
        thermos[#thermos + 1] = { cells = cells }
        return true
    end

    local target_count = 5
    local box_sub_attempts = 200

    for i = 1, target_count do
        local box = box_order[i]
        local placed = false
        for _ = 1, box_sub_attempts do
            if tryPlaceOne(box) then placed = true; break end
        end
        if not placed then
            -- This box couldn't fit one (rare -- e.g. heavily used by
            -- earlier thermometers); fall back to a free placement
            -- anywhere so the target count is still reached.
            for _ = 1, box_sub_attempts * 2 do
                if tryPlaceOne(nil) then break end
            end
        end
    end

    return thermos
end

-- ---------------------------------------------------------------------------
-- ThermoSudokuBoard
-- ---------------------------------------------------------------------------

local ThermoSudokuBoard = setmetatable({}, { __index = BaseBoard })
ThermoSudokuBoard.__index = ThermoSudokuBoard

function ThermoSudokuBoard:new(config)
    local n        = 9
    local box_rows = 3
    local box_cols = 3
    local board = {
        n               = n,
        box_rows        = box_rows,
        box_cols        = box_cols,
        grid_id         = "9x9",
        puzzle          = emptyGrid(n),
        solution        = emptyGrid(n),
        user            = emptyGrid(n),
        conflicts       = emptyGrid(n),
        notes           = emptyNotes(n),
        wrong_marks     = emptyMarkerGrid(n),
        selected        = { row = 1, col = 1 },
        difficulty      = DEFAULT_DIFFICULTY,
        reveal_solution = false,
        undo_stack      = {},
        thermos         = {},
        thermo_violations = {},  -- set of cell keys that violate
    }
    setmetatable(board, self)
    board:recalcConflicts()
    return board
end

function ThermoSudokuBoard:serialize()
    local n = self.n
    -- Serialize thermos
    local thermos_data = {}
    for i, thermo in ipairs(self.thermos) do
        local cells_data = {}
        for j, cell in ipairs(thermo.cells) do
            cells_data[j] = { r = cell.r, c = cell.c }
        end
        thermos_data[i] = { cells = cells_data }
    end
    return {
        n               = n,
        box_rows        = self.box_rows,
        box_cols        = self.box_cols,
        grid_id         = self.grid_id,
        puzzle          = copyGrid(self.puzzle, n),
        solution        = copyGrid(self.solution, n),
        user            = copyGrid(self.user, n),
        notes           = copyNotes(self.notes, n),
        wrong_marks     = copyGrid(self.wrong_marks, n),
        selected        = { row = self.selected.row, col = self.selected.col },
        difficulty      = self.difficulty,
        reveal_solution = self.reveal_solution,
        thermos         = thermos_data,
    }
end

function ThermoSudokuBoard:load(state)
    if not state or not state.puzzle or not state.solution or not state.user then
        return false
    end
    self.n        = state.n        or 9
    self.box_rows = state.box_rows or 3
    self.box_cols = state.box_cols or 3
    self.grid_id  = state.grid_id  or "9x9"
    local n = self.n
    self.puzzle      = copyGrid(state.puzzle, n)
    self.solution    = copyGrid(state.solution, n)
    self.user        = copyGrid(state.user, n)
    self.notes       = copyNotes(state.notes, n)
    self.wrong_marks = state.wrong_marks and copyGrid(state.wrong_marks, n) or emptyMarkerGrid(n)
    self.conflicts   = emptyGrid(n)
    self.difficulty  = state.difficulty or DEFAULT_DIFFICULTY
    self.undo_stack  = {}
    if state.selected then
        self.selected = {
            row = math.max(1, math.min(n, state.selected.row or 1)),
            col = math.max(1, math.min(n, state.selected.col or 1)),
        }
    else
        self.selected = { row = 1, col = 1 }
    end
    self.reveal_solution = state.reveal_solution or false
    -- Load thermos
    self.thermos = {}
    if state.thermos then
        for i, td in ipairs(state.thermos) do
            local cells = {}
            for j, cell in ipairs(td.cells) do
                cells[j] = { r = cell.r, c = cell.c }
            end
            self.thermos[i] = { cells = cells }
        end
    end
    self.thermo_violations = {}
    self:recalcConflicts()
    return true
end

function ThermoSudokuBoard:generate(difficulty, on_progress)
    self.difficulty = difficulty or self.difficulty or DEFAULT_DIFFICULTY
    local n, box_rows, box_cols = self.n, self.box_rows, self.box_cols
    local solution = generateSolvedBoard(n, box_rows, box_cols)
    local puzzle   = createPuzzle(solution, self.difficulty, n, box_rows, box_cols, nil, on_progress)
    self.puzzle          = puzzle
    self.solution        = solution
    self.user            = emptyGrid(n)
    self.notes           = emptyNotes(n)
    self.wrong_marks     = emptyMarkerGrid(n)
    self.selected        = { row = 1, col = 1 }
    self.reveal_solution = false
    self.undo_stack      = {}
    self.thermos         = placeThermos(solution)
    self.thermo_violations = {}
    self:recalcConflicts()
end

function ThermoSudokuBoard:isGiven(row, col)
    return self.puzzle[row][col] ~= 0
end

function ThermoSudokuBoard:getWorkingValue(row, col)
    local given = self.puzzle[row][col]
    if given ~= 0 then return given end
    return self.user[row][col]
end

function ThermoSudokuBoard:getDisplayValue(row, col)
    if self.reveal_solution then
        return self.solution[row][col], self:isGiven(row, col)
    end
    if self:isGiven(row, col) then
        return self.puzzle[row][col], true
    end
    local value = self.user[row][col]
    if value == 0 then return nil end
    return value, false
end

-- Returns true if the cell at (row,col) is in a violated thermo
function ThermoSudokuBoard:isThermoViolation(row, col)
    local key = row * 100 + col
    return self.thermo_violations[key] or false
end

-- Validate a single thermo against working values; returns true if valid (or not fully filled).
-- An empty cell (v == 0) does NOT reset the comparison — subsequent filled cells must still
-- be greater than the last filled cell seen before the gap.
function ThermoSudokuBoard:validateThermo(thermo)
    local cells = thermo.cells
    local prev = 0  -- last non-zero value seen; 0 means no filled cell yet
    for _, cell in ipairs(cells) do
        local v = self:getWorkingValue(cell.r, cell.c)
        if v ~= 0 then
            if prev ~= 0 and v <= prev then
                return false
            end
            prev = v
        end
        -- Empty cells are skipped; prev retains the last filled value
    end
    return true
end

function ThermoSudokuBoard:recalcConflicts()
    -- Call parent for row/col/box conflicts
    BaseBoard.recalcConflicts(self)
    -- Check thermo violations
    self.thermo_violations = {}
    for _, thermo in ipairs(self.thermos) do
        -- Check each consecutive pair
        local cells = thermo.cells
        local violated_cells = {}
        local has_violation = false
        for i = 2, #cells do
            local v_prev = self:getWorkingValue(cells[i-1].r, cells[i-1].c)
            local v_curr = self:getWorkingValue(cells[i].r, cells[i].c)
            if v_prev ~= 0 and v_curr ~= 0 and v_curr <= v_prev then
                has_violation = true
                violated_cells[i-1] = true
                violated_cells[i]   = true
            end
        end
        if has_violation then
            for idx, _ in pairs(violated_cells) do
                local cell = cells[idx]
                local key  = cell.r * 100 + cell.c
                self.thermo_violations[key] = true
                self.conflicts[cell.r][cell.c] = true
            end
        end
    end
end

function ThermoSudokuBoard:isConflict(row, col)
    return self.conflicts[row][col]
end

function ThermoSudokuBoard:clearUndoHistory()
    self.undo_stack = {}
end

return {
    ThermoSudokuBoard  = ThermoSudokuBoard,
    DEFAULT_DIFFICULTY = DEFAULT_DIFFICULTY,
    GRID_CONFIGS       = GRID_CONFIGS,
    getGridConfig      = getGridConfig,
}
