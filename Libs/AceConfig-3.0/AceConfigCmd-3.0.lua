--- AceConfigCmd-3.0 handles access to an options table through the "/" command.
-- @class file
-- @name AceConfigCmd-3.0
-- @release $Id: AceConfigCmd-3.0.lua 1284 2022-09-25 11:21:25Z nevcairiel $
local MAJOR, MINOR = "AceConfigCmd-3.0", 14
local AceConfigCmd = LibStub:NewLibrary(MAJOR, MINOR)

if not AceConfigCmd then return end -- No upgrade needed

AceConfigCmd.commands = AceConfigCmd.commands or {}
local commands = AceConfigCmd.commands

local AceConsole = LibStub("AceConsole-3.0")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")

-- Lua APIs
local strsub, strlower, strmatch, gsub = string.sub, string.lower, string.match, string.gsub
local format, tonumber, tostring = string.format, tonumber, tostring
local error, pairs, ipairs, type = error, pairs, ipairs, type
local loadstring = loadstring

-- WoW APIs
local _G = _G

local function err(msg, ...)
  geterrorhandler()(MAJOR .. ": " .. format(msg, ...))
end

local function parseWords(line)
  local words = {}
  for word in line:gmatch("%S+") do
    tinsert(words, word)
  end
  return words
end

local function getSubCmd(cmd, path)
  local subcmd = commands[cmd]
  if subcmd and path then
    for i = 1, #path do
      subcmd = subcmd.args[path[i]]
      if not subcmd then
        return nil
      end
    end
  end
  return subcmd
end

local function validateCmd(cmd)
  if not cmd then
    return nil
  end
  if cmd.type == "execute" then
    if type(cmd.func) ~= "function" then
      err("'func' - function expected, got %s", type(cmd.func))
      return nil
    end
  elseif cmd.type == "input" then
    if type(cmd.set) ~= "function" then
      err("'set' - function expected, got %s", type(cmd.set))
      return nil
    end
    if cmd.get and type(cmd.get) ~= "function" then
      err("'get' - function expected, got %s", type(cmd.get))
      return nil
    end
  elseif cmd.type == "toggle" then
    if type(cmd.set) ~= "function" then
      err("'set' - function expected, got %s", type(cmd.set))
      return nil
    end
    if cmd.get and type(cmd.get) ~= "function" then
      err("'get' - function expected, got %s", type(cmd.get))
      return nil
    end
  elseif cmd.type == "range" then
    if type(cmd.set) ~= "function" then
      err("'set' - function expected, got %s", type(cmd.set))
      return nil
    end
    if cmd.get and type(cmd.get) ~= "function" then
      err("'get' - function expected, got %s", type(cmd.get))
      return nil
    end
    if type(cmd.min) ~= "number" then
      err("'min' - number expected, got %s", type(cmd.min))
      return nil
    end
    if type(cmd.max) ~= "number" then
      err("'max' - number expected, got %s", type(cmd.max))
      return nil
    end
    if cmd.step and type(cmd.step) ~= "number" then
      err("'step' - number expected, got %s", type(cmd.step))
      return nil
    end
  elseif cmd.type == "select" then
    if type(cmd.values) ~= "table" and type(cmd.values) ~= "function" then
      err("'values' - table or function expected, got %s", type(cmd.values))
      return nil
    end
    if type(cmd.set) ~= "function" then
      err("'set' - function expected, got %s", type(cmd.set))
      return nil
    end
    if cmd.get and type(cmd.get) ~= "function" then
      err("'get' - function expected, got %s", type(cmd.get))
      return nil
    end
  elseif cmd.type == "multiselect" then
    if type(cmd.values) ~= "table" and type(cmd.values) ~= "function" then
      err("'values' - table or function expected, got %s", type(cmd.values))
      return nil
    end
    if type(cmd.set) ~= "function" then
      err("'set' - function expected, got %s", type(cmd.set))
      return nil
    end
    if cmd.get and type(cmd.get) ~= "function" then
      err("'get' - function expected, got %s", type(cmd.get))
      return nil
    end
  elseif cmd.type == "color" then
    if type(cmd.set) ~= "function" then
      err("'set' - function expected, got %s", type(cmd.set))
      return nil
    end
    if cmd.get and type(cmd.get) ~= "function" then
      err("'get' - function expected, got %s", type(cmd.get))
      return nil
    end
  elseif cmd.type == "group" then
    if type(cmd.args) ~= "table" and type(cmd.args) ~= "function" then
      err("'args' - table or function expected, got %s", type(cmd.args))
      return nil
    end
  elseif cmd.type == "header" then
    -- no validation needed
  elseif cmd.type == "description" then
    -- no validation needed
  else
    err(
    "'type' - expected execute, input, toggle, range, select, multiselect, color, group, header, or description, got %s",
      cmd.type)
    return nil
  end

  return true
end

function AceConfigCmd:CreateChatCommand(slashcmd, appName)
  if type(slashcmd) ~= "string" then
    error(MAJOR .. ": CreateChatCommand(slashcmd, appName): 'slashcmd' - string expected.", 2)
  end

  if type(appName) ~= "string" then
    error(MAJOR .. ": CreateChatCommand(slashcmd, appName): 'appName' - string expected.", 2)
  end

  if not AceConfigRegistry.tables[appName] then
    error(MAJOR .. ": CreateChatCommand(slashcmd, appName): 'appName' - no options table registered.", 2)
  end

  if slashcmd:find("[%s%.]") then
    error(MAJOR .. ": CreateChatCommand(slashcmd, appName): 'slashcmd' - command can not contain spaces or dots.", 2)
  end

  if commands[slashcmd] then
    error(MAJOR .. ": CreateChatCommand(slashcmd, appName): 'slashcmd' - command already registered.", 2)
  end

  commands[slashcmd] = {
    appName = appName,
    slashcmd = slashcmd,
  }

  AceConsole:RegisterChatCommand(slashcmd, function(input)
    local words = parseWords(input)
    local path = {}
    local options = AceConfigRegistry.tables[appName]

    if type(options) == "function" then
      options = options()
    end

    if not options then
      return
    end

    for i = 1, #words do
      if options.args and options.args[words[i]] then
        options = options.args[words[i]]
        tinsert(path, words[i])
      else
        break
      end
    end

    if options.type == "execute" then
      options.func()
    elseif options.type == "input" then
      local value = strsub(input, #path[#path] + 1)
      value = strtrim(value)
      options.set(nil, value)
    elseif options.type == "toggle" then
      options.set(nil, not options.get())
    elseif options.type == "range" then
      local value = tonumber(words[#path + 1])
      if value then
        options.set(nil, value)
      end
    elseif options.type == "select" then
      local value = words[#path + 1]
      if value then
        options.set(nil, value)
      end
    elseif options.type == "multiselect" then
      local value = words[#path + 1]
      if value then
        options.set(nil, value, not options.get(nil, value))
      end
    elseif options.type == "color" then
      local r, g, b, a = tonumber(words[#path + 1]), tonumber(words[#path + 2]), tonumber(words[#path + 3]),
          tonumber(words[#path + 4])
      if r and g and b then
        if a then
          options.set(nil, r, g, b, a)
        else
          options.set(nil, r, g, b)
        end
      end
    end
  end)
end
