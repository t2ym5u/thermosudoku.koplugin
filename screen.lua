local _dir = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
local function lrequire(name)
    local key = _dir .. name
    if not package.loaded[key] then
        package.loaded[key] = assert(loadfile(_dir .. name .. ".lua"))()
    end
    return package.loaded[key]
end
local function lrequire_common(name)
    local key = _dir .. "common/" .. name
    if not package.loaded[key] then
        package.loaded[key] = assert(loadfile(_dir .. "common/" .. name .. ".lua"))()
    end
    return package.loaded[key]
end

local ButtonTable     = require("ui/widget/buttontable")
local Device          = require("device")
local FrameContainer  = require("ui/widget/container/framecontainer")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan  = require("ui/widget/horizontalspan")
local Menu            = require("ui/widget/menu")
local Size            = require("ui/size")
local UIManager       = require("ui/uimanager")
local VerticalGroup   = require("ui/widget/verticalgroup")
local VerticalSpan    = require("ui/widget/verticalspan")
local _               = require("i18n")
local T               = require("ffi/util").template

local board_module            = lrequire("board")
local ThermoSudokuBoardWidget = lrequire("board_widget")

local common            = lrequire_common("base_screen")
local BaseScreen        = common.BaseScreen
local DIFFICULTY_ORDER  = common.DIFFICULTY_ORDER
local DIFFICULTY_LABELS = common.DIFFICULTY_LABELS

local DeviceScreen = Device.screen

local function digitToChar(d)
    return d <= 9 and tostring(d) or string.char(55 + d)
end

local GAME_RULES_EN = _([[
Thermo Sudoku — Rules

Standard Sudoku rules apply:
• Fill the 9×9 grid with 1–9; each row, column, and 3×3 box must contain each digit exactly once.

Thermometer constraint:
• Thermometers are drawn on the grid, each starting from a bulb.
• Digits along a thermometer must strictly increase from the bulb to the tip.]])

local GAME_RULES_FR = [[
Thermo Sudoku — Règles

Les règles du Sudoku classique s'appliquent :
• Remplissez la grille 9×9 avec les chiffres 1 à 9 ; chaque ligne, colonne et carré 3×3 doit contenir chaque chiffre exactement une fois.

Contrainte des thermomètres :
• Des thermomètres sont dessinés sur la grille, chacun commençant par un bulbe.
• Les chiffres le long d'un thermomètre doivent être strictement croissants du bulbe vers l'extrémité.
]]

local ThermoSudokuScreen = BaseScreen:extend{}

function ThermoSudokuScreen:buildLayout()
    local is_landscape = DeviceScreen:getWidth() > DeviceScreen:getHeight()
    local sw = DeviceScreen:getWidth()
    local sh = DeviceScreen:getHeight()

    local max_board_size
    if not is_landscape then
        local btn_row_h   = Size.item.height_default + 2 * Size.padding.buttontable
        local frame_h     = (Size.padding.large + Size.margin.default) * 2
        local span        = Size.span.vertical_large
        local keypad_rows = self.board.box_rows + 1
        local status_h    = 2 * Size.item.height_default
        local non_board_h = 5 * span + btn_row_h + status_h + keypad_rows * btn_row_h + frame_h
        max_board_size = sh - non_board_h
    end

    self.board_widget = ThermoSudokuBoardWidget:new{
        board              = self.board,
        max_size           = max_board_size,
        onSelectionChanged = function() self:updateStatus() end,
    }

    local board_frame = FrameContainer:new{
        padding = Size.padding.large,
        margin  = Size.margin.default,
        self.board_widget,
    }

    local board_frame_size  = self.board_widget.size + (Size.padding.large + Size.margin.default) * 2
    local right_panel_width = sw - board_frame_size - Size.span.horizontal_default
    local button_width = is_landscape
        and math.max(right_panel_width - Size.span.horizontal_default, 100)
        or  math.floor(sw * 0.9)
    local keypad_width = is_landscape and button_width or math.floor(sw * 0.75)

    local title_bar = self:buildTitleBar(_("Thermo Sudoku"), function()
        return {
            { text = _("New game"),                  callback = function() self:onNewGame() end },
            { text = self:getDifficultyButtonText(), callback = function() self:openDifficultyMenu() end },
            { text = self.board:isShowingSolution() and _("Hide result") or _("Show result"),
              callback = function() self:toggleSolution() end },
            self:makeRulesButtonConfig(GAME_RULES_EN, GAME_RULES_FR),
        }
    end)

    local n        = self.board.n
    local box_rows = self.board.box_rows
    local box_cols = self.board.box_cols
    local keypad_rows = {}
    local digit = 1
    for _ = 1, box_rows do
        local row = {}
        for _ = 1, box_cols do
            local d = digit
            row[#row + 1] = {
                id = "digit_" .. d, text = digitToChar(d),
                callback = function() self:onDigit(d) end,
            }
            digit = digit + 1
        end
        keypad_rows[#keypad_rows + 1] = row
    end
    keypad_rows[#keypad_rows + 1] = {
        { id = "note_button", text = self:getNoteButtonText(),
          callback = function() self:toggleNoteMode() end },
        { text = _("Erase"),  callback = function() self:onErase() end },
        { text = _("Check"),  callback = function() self:checkProgress() end },
        { id = "undo_button", text = _("Undo"),
          callback = function() self:onUndo() end },
    }
    local keypad = ButtonTable:new{
        width = keypad_width, shrink_unneeded_width = true, buttons = keypad_rows,
    }
    self.note_button  = keypad:getButtonById("note_button")
    self.undo_button  = keypad:getButtonById("undo_button")
    self.digit_buttons = {}
    for d = 1, n do
        self.digit_buttons[d] = keypad:getButtonById("digit_" .. d)
    end

    if is_landscape then
        local right_panel = VerticalGroup:new{
            align = "center",
            self.status_text,
            VerticalSpan:new{ width = Size.span.vertical_large },
            keypad,
        }
        local content = HorizontalGroup:new{
            align = "center",
            board_frame,
            HorizontalSpan:new{ width = Size.span.horizontal_default },
            right_panel,
        }
        self:buildLandscapeLayout(title_bar, content)
    else
        local content = VerticalGroup:new{
            align = "center",
            board_frame,
            VerticalSpan:new{ width = Size.span.vertical_large },
            self.status_text,
        }
        self:buildPortraitLayout(title_bar, content, keypad)
    end
    self:ensureShowButtonState()
    self:updateNoteButton()
    self:updateUndoButton()
    self:updateDigitButtons()
    self:updateDifficultyButton()
    self:updateStatus()
end

function ThermoSudokuScreen:getDifficultyButtonText()
    local label = DIFFICULTY_LABELS[self.board.difficulty] or self.board.difficulty
    return T(_("Diff: %1"), label)
end

function ThermoSudokuScreen:openDifficultyMenu()
    local menu
    local function selectDifficulty(level)
        if level ~= self.board.difficulty then
            self.board:generate(level)
            self.plugin:saveState()
            self.board_widget:refresh()
            self:ensureShowButtonState()
            self:updateDigitButtons()
            self:updateStatus(T(_("Started a %1 game."), DIFFICULTY_LABELS[level] or level))
        else
            self:updateStatus()
        end
        self:updateDifficultyButton()
        if menu then UIManager:close(menu) end
        return true
    end
    local items = {}
    for _, level in ipairs(DIFFICULTY_ORDER) do
        items[#items + 1] = {
            text    = DIFFICULTY_LABELS[level] or level,
            checked = (level == self.board.difficulty),
            callback = function() return selectDifficulty(level) end,
        }
    end
    menu = Menu:new{
        title      = _("Select difficulty"),
        item_table = items,
        width      = math.floor(DeviceScreen:getWidth() * 0.7),
        height     = math.floor(DeviceScreen:getHeight() * 0.9),
        disable_footer_padding = true,
        show_parent = self,
    }
    UIManager:show(menu)
end

function ThermoSudokuScreen:updateStatus(message)
    local status
    if message then
        status = message
    else
        local remaining = self.board:getRemainingCells()
        local row, col  = self.board:getSelection()
        status = T(_("Selected: %1,%2  \xC2\xB7  Empty cells: %3"), row, col, remaining)
        if self.board:isShowingSolution() then
            status = status .. "\n" .. _("Result is being shown; editing is disabled.")
        elseif self.board:isSolved() then
            status = _("Congratulations! Puzzle solved.")
        elseif self.note_mode then
            status = status .. "\n" .. _("Note mode is ON.")
        end
    end
    self.status_text:setText(status)
    UIManager:setDirty(self, function() return "ui", self.dimen end)
end

return ThermoSudokuScreen
