--- AceConfigCmd-3.0 handles access to an options table through the "/" command
-- @class file
-- @name AceConfigCmd-3.0
-- @release $Id: AceConfigCmd-3.0.lua 1284 2022-09-25 11:21:25Z nevcairiel $

local MAJOR, MINOR = "AceConfigCmd-3.0", 14
local AceConfigCmd = LibStub:NewLibrary(MAJOR, MINOR)

if not AceConfigCmd then return end

AceConfigCmd.commands = AceConfigCmd.commands or {}
local commands = AceConfigCmd.commands

local AceConsole = LibStub("AceConsole-3.0")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")

-- Lua APIs
local strsub, strlower, strmatch, strtrim = string.sub, string.lower, string.match, strtrim
local format, tonumber, tostring = string.format, tonumber, tostring
local tsort, tinsert = table.sort, table.insert
local select, pairs, next, type = select, pairs, next, type
local error, assert = error, assert

-- WoW APIs
local _G = _G

local function print(msg)
  AceConsole:Print(msg)
end

local function validateKey(key, errlvl)
  if not key or strmatch(key, "%s") then
    error(
      format("Attempt to register a command with an invalid key. Command keys cannot contain spaces. Key: '%s'",
        tostring(key)), errlvl or 2)
  end
end

function AceConfigCmd:CreateChatCommand(slashcmd, appName)
  if not slashcmd then
    error("Usage: AceConfigCmd:CreateChatCommand(slashcmd, appName): 'slashcmd' - string expected.", 2)
  end
  if not appName then
    error("Usage: AceConfigCmd:CreateChatCommand(slashcmd, appName): 'appName' - string expected.", 2)
  end

  validateKey(slashcmd, 3)

  if commands[slashcmd] then
    error(format("Attempt to register a command with a key that is already in use. Command: '%s'", tostring(slashcmd)), 2)
  end

  local group = AceConfigRegistry:GetOptionsTable(appName)
  if not group then
    error(format("Could not find a registered options table for addon '%s'", appName), 2)
  end

  commands[slashcmd] = appName

  local function handler(msg)
    local app = AceConfigRegistry:GetOptionsTable(appName)
    local options = app("cmd", slashcmd)
    AceConfigCmd:HandleCommand(slashcmd, appName, options, msg)
  end

  AceConsole:RegisterChatCommand(slashcmd, handler)
end

function AceConfigCmd:HandleCommand(slashcmd, appName, options, msg)
  if not slashcmd then
    error("Usage: AceConfigCmd:HandleCommand(slashcmd, appName, options, msg): 'slashcmd' - string expected.", 2)
  end
  if not appName then
    error("Usage: AceConfigCmd:HandleCommand(slashcmd, appName, options, msg): 'appName' - string expected.", 2)
  end
  if not options then
    error("Usage: AceConfigCmd:HandleCommand(slashcmd, appName, options, msg): 'options' - table expected.", 2)
  end

  local path = msg and strtrim(msg) or ""

  if path == "config" then
    if not options.config then
      print(format("The addon '%s' does not have a configuration GUI.", appName))
      return
    end
    options.config()
    return
  end

  if path == "help" or path == "?" then
    print(format("Options for '%s':", appName))
    print("  config - Open the configuration GUI")
    print("  help   - Print this help message")
    return
  end

  if path ~= "" then
    print(format("Unknown command. Use '%s help' for help.", slashcmd))
    return
  end

  if options.config then
    options.config()
  else
    print(format("The addon '%s' does not have a configuration GUI.", appName))
  end
end
