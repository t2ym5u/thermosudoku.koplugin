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

local Device          = require("device")
local Menu            = require("ui/widget/menu")
local UIManager       = require("ui/uimanager")
local _               = require("i18n")
local T               = require("ffi/util").template

local ThermoSudokuBoardWidget = lrequire("board_widget")

local common            = lrequire_common("base_screen")
local BaseScreen        = common.BaseScreen
local DIFFICULTY_ORDER  = common.DIFFICULTY_ORDER
local DIFFICULTY_LABELS = common.DIFFICULTY_LABELS
local generateWithProgress = common.generateWithProgress

local DeviceScreen = Device.screen

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
    local title_bar = self:buildTitleBar(_("Thermo Sudoku"), function()
        return {
            { text = _("New game"),                  callback = function() self:onNewGame() end },
            { text = self:getDifficultyButtonText(), callback = function() self:openDifficultyMenu() end },
            { text = self.board:isShowingSolution() and _("Hide solution") or _("Show solution"),
              callback = function() self:toggleSolution() end },
            self:makeRulesButtonConfig(GAME_RULES_EN, GAME_RULES_FR),
        }
    end)
    local controls = self:buildKeypadControls()
    self.board_widget = ThermoSudokuBoardWidget:new{
        board              = self.board,
        max_size           = self:getBoardMaxSize(title_bar, controls),
        onSelectionChanged = function() self:updateStatus() end,
    }
    self:placeBoard(title_bar, self.board_widget, controls)
    self:ensureShowButtonState()
    self:updateNoteButton()
    self:updateUndoButton()
    self:updateDigitButtons()
    self:updateDifficultyButton()
    self:updateStatus()
end

function ThermoSudokuScreen:getDifficultyButtonText()
    local label = DIFFICULTY_LABELS[self.board.difficulty] or self.board.difficulty
    return T(_("Difficulty: %1"), label)
end

function ThermoSudokuScreen:openDifficultyMenu()
    local menu
    local function selectDifficulty(level)
        if level ~= self.board.difficulty then
            generateWithProgress(self.board, level)
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

return ThermoSudokuScreen
