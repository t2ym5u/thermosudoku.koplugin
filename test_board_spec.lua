local DIR = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"

package.preload["gettext"] = function()
    return setmetatable({}, { __call = function(_, s) return s end })
end
package.path = DIR .. "common/?.lua;" .. DIR .. "?.lua;" .. package.path

describe("ThermoSudokuBoard", function()
    local Mod, ThermoSudokuBoard

    setup(function()
        Mod = require("board")
        ThermoSudokuBoard = Mod.ThermoSudokuBoard
    end)

    describe("new", function()
        it("creates a 9x9 board with no thermometers until generate is called", function()
            local b = ThermoSudokuBoard:new()
            assert.are.equal(9, b.n)
            assert.are.equal(0, #b.thermos)
        end)
    end)

    describe("generate", function()
        it("fills a valid 9x9 solution and places thermometers", function()
            math.randomseed(42)
            local b = ThermoSudokuBoard:new()
            b:generate("medium")
            local n = b.n
            for r = 1, n do
                local seen = {}
                for c = 1, n do seen[b.solution[r][c]] = true end
                for d = 1, n do assert.is_true(seen[d], "row " .. r .. " missing " .. d) end
            end
            assert.is_true(#b.thermos > 0)
        end)

        it("every thermometer's solution values strictly increase from bulb to tip", function()
            math.randomseed(11)
            local b = ThermoSudokuBoard:new()
            b:generate("medium")
            for _, thermo in ipairs(b.thermos) do
                local cells = thermo.cells
                for i = 2, #cells do
                    local prev = b.solution[cells[i-1].r][cells[i-1].c]
                    local cur  = b.solution[cells[i].r][cells[i].c]
                    assert.is_true(cur > prev,
                        ("thermo cell %d (%d) should exceed cell %d (%d)"):format(i, cur, i-1, prev))
                end
            end
        end)
    end)

    describe("serialize / load", function()
        it("round-trips puzzle, solution and thermometers", function()
            math.randomseed(42)
            local b = ThermoSudokuBoard:new()
            b:generate("medium")
            local data = b:serialize()

            local b2 = ThermoSudokuBoard:new()
            assert.is_true(b2:load(data))
            assert.are.equal(#b.thermos, #b2.thermos)
            for r = 1, b.n do
                for c = 1, b.n do
                    assert.are.equal(b.solution[r][c], b2.solution[r][c])
                end
            end
        end)

        it("load returns false for invalid data", function()
            local b = ThermoSudokuBoard:new()
            assert.is_false(b:load(nil))
            assert.is_false(b:load({}))
        end)
    end)
end)
