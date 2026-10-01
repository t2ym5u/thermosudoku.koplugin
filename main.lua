local _dir = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
package.path = _dir .. "?.lua;" .. _dir .. "common/?.lua;" .. package.path

local function lrequire(name)
    local key = _dir .. name
    if not package.loaded[key] then
        package.loaded[key] = assert(loadfile(_dir .. name .. ".lua"))()
    end
    return package.loaded[key]
end

local DataStorage     = require("datastorage")
local LuaSettings     = require("luasettings")
local UIManager       = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _               = require("i18n")

-- Play-session stats, shared with every other game through
-- game_stats.lua (Dashboard reads it). pcall'd: an install whose
-- common/ predates sudoku-common 1.4.0 has no stats_exporter.lua,
-- and a bare require would take the whole plugin down with it.
local ok_stats, StatsExporter = pcall(require, "stats_exporter")

require("i18n").extend(lrequire("i18n_fr"))

local board_module       = lrequire("board")
local ThermoSudokuBoard  = board_module.ThermoSudokuBoard
local DEFAULT_DIFFICULTY = board_module.DEFAULT_DIFFICULTY
local generateWithProgress = lrequire("common/base_screen").generateWithProgress

local ThermoSudokuScreen = lrequire("screen")

-- Spelled out rather than read off self.name: ReaderUI/FileManager
-- rewrite an instance's name to "reader<id>"/"filemanager<id>" right
-- after it is built, so self.name is not the plugin id after :init().
local PLUGIN_ID = "thermosudoku"

local ThermoSudoku = WidgetContainer:extend{
    name        = "thermosudoku",
    is_doc_only = false,
}

function ThermoSudoku:ensureSettings()
    if not self.settings_file then
        self.settings_file = DataStorage:getSettingsDir() .. "/thermosudoku.lua"
    end
    if not self.settings then
        self.settings = LuaSettings:open(self.settings_file)
    end
end

function ThermoSudoku:init()
    self:ensureSettings()
    self.ui.menu:registerToMainMenu(self)
end

function ThermoSudoku:addToMainMenu(menu_items)
    menu_items.thermosudoku = {
        text         = _("Thermo Sudoku"),
        sorting_hint = "tools",
        callback     = function() self:showGame() end,
    }
end

function ThermoSudoku:getBoard()
    if not self.board then
        self:ensureSettings()
        self.board = ThermoSudokuBoard:new()
        local state = self.settings:readSetting("state")
        if not self.board:load(state) then
            generateWithProgress(self.board, DEFAULT_DIFFICULTY)
        end
    end
    return self.board
end

function ThermoSudoku:saveState()
    if not self.board then return end
    self:ensureSettings()
    self.settings:saveSetting("state", self.board:serialize())
    self.settings:flush()
end

function ThermoSudoku:showGame()
    if self.screen then return end
    self._session_start = os.time()
    self.screen = ThermoSudokuScreen:new{
        board  = self:getBoard(),
        plugin = self,
    }
    UIManager:show(self.screen)
end

function ThermoSudoku:onScreenClosed()
    local elapsed = self._session_start and (os.time() - self._session_start) or 0
    self._session_start = nil
    if ok_stats then
        local cur = StatsExporter:get(PLUGIN_ID) or {}
        StatsExporter:record(PLUGIN_ID, {
            sessions    = (cur.sessions or 0) + 1,
            last_played = os.time(),
            time_played = (cur.time_played or 0) + elapsed,
        })
    end
    self.screen = nil
end

-- KOReader >= 2026.07 plugin management (PluginLoader, PR #15240).
-- PluginLoader removes self.settings_file itself; what is left is the
-- open game screen and this game's row in the shared game_stats.lua.
function ThermoSudoku:stopPlugin()
    if self.screen then
        UIManager:close(self.screen)
        self.screen = nil
    end
end

function ThermoSudoku:deletePluginSettings()
    if ok_stats then StatsExporter:remove(PLUGIN_ID) end
end

return ThermoSudoku
