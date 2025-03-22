--- AceConfig-3.0 handles the creation and management of configuration UIs.
-- @class file
-- @name AceConfig-3.0
-- @release $Id: AceConfig-3.0.lua 1284 2022-09-25 11:21:25Z nevcairiel $

local MAJOR, MINOR = "AceConfig-3.0", 3
local AceConfig = LibStub:NewLibrary(MAJOR, MINOR)

if not AceConfig then return end -- No upgrade needed

local cfgreg = LibStub("AceConfigRegistry-3.0")
local cfgcmd = LibStub("AceConfigCmd-3.0")
local cfgdlg = LibStub("AceConfigDialog-3.0")

-- Lua APIs
local pcall, error, type, pairs = pcall, error, type, pairs
local format = string.format

-- WoW APIs
local GetAddOnMetadata = GetAddOnMetadata

local function ValidateType(options)
  if type(options) ~= "table" then
    error(format("Usage: %s(options): 'options' - table expected, got %s", MAJOR, type(options)), 2)
  end
end

--- Register a new options table with the config registry.
-- @param appName The application name for the config table.
-- @param options The options table, see AceConfig-3.0 docs for details.
-- @param skipValidation Skip option structure validation (optional).
function AceConfig:RegisterOptionsTable(appName, options, skipValidation)
  if type(appName) ~= "string" then
    error(
    format("Usage: %s:RegisterOptionsTable(appName, options, skipValidation): 'appName' - string expected, got %s", MAJOR,
      type(appName)), 2)
  end
  if not skipValidation then
    ValidateType(options)
  end
  cfgreg:RegisterOptionsTable(appName, options)
end

--- Add slash commands to open the config window.
-- @param appName The application name as given to `:RegisterOptionsTable()`.
-- @param slashcmd A slash command to use, with or without the slash (optional).
-- @param ... Additional slash commands (optional).
function AceConfig:RegisterChatCommand(appName, slashcmd, ...)
  cfgcmd:CreateChatCommand(slashcmd, appName)
  for i = 1, select("#", ...) do
    cfgcmd:CreateChatCommand((select(i, ...)), appName)
  end
end

--- Display a GUI config window for the given application.
-- @param appName The application name as given to `:RegisterOptionsTable()`.
-- @param container A container frame to place the config window in, or nil for a standalone window.
function AceConfig:OpenConfigDialog(appName, container)
  cfgdlg:Open(appName, container)
end
