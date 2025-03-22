--- AceConfigRegistry-3.0 handles central registration of options tables in use by addons and modules.
-- @class file
-- @name AceConfigRegistry-3.0
-- @release $Id: AceConfigRegistry-3.0.lua 1284 2022-09-25 11:21:25Z nevcairiel $
local MAJOR, MINOR = "AceConfigRegistry-3.0", 20
local AceConfigRegistry = LibStub:NewLibrary(MAJOR, MINOR)

if not AceConfigRegistry then return end -- No upgrade needed

AceConfigRegistry.tables = AceConfigRegistry.tables or {}

local CallbackHandler = LibStub:GetLibrary("CallbackHandler-1.0")

if not AceConfigRegistry.callbacks then
  AceConfigRegistry.callbacks = CallbackHandler:New(AceConfigRegistry)
end

-- Lua APIs
local tinsert, tconcat = table.insert, table.concat
local format = string.format
local error, assert, type, pairs, next = error, assert, type, pairs, next

-----------------------------------------------------------------------
-- Validating options table consistency:
--
local function err(msg, ...)
  geterrorhandler()(MAJOR .. ": " .. format(msg, ...))
end

local function validateKey(k, errlvl, ...)
  if type(k) ~= "string" then
    err("['%s'] - key: expected string, got %s", type(k), ...)
  end
  if strfind(k, "[%c\127]") then
    err("['%s'] - key: control characters are not allowed", k, ...)
  end
end

local function validateVal(v, errlvl, ...)
  if type(v) ~= "table" then
    err("['%s'] - value: expected table, got %s", type(v), ...)
  end
  if type(v.name) ~= "string" then
    err("['%s'].name - expected string, got %s", type(v.name), ...)
  end
  if type(v.type) ~= "string" then
    err("['%s'].type - expected string, got %s", type(v.type), ...)
  end
  if v.type ~= "group" and v.type ~= "select" and v.type ~= "multiselect" and v.type ~= "execute" and v.type ~= "color" and v.type ~= "range" and v.type ~= "toggle" and v.type ~= "input" and v.type ~= "header" and v.type ~= "description" then
    err(
    "['%s'].type - expected group, select, multiselect, execute, color, range, toggle, input, header, or description, got %s",
      v.type, ...)
  end
end

local function validateOptions(options, errlvl, ...)
  errlvl = (errlvl or 0) + 1
  local errprefix = strrep("  ", errlvl) .. strrep(".", errlvl)

  for k, v in pairs(options) do
    if type(k) ~= "table" then
      validateKey(k, errlvl, errprefix)
      validateVal(v, errlvl, errprefix)

      if v.type == "group" then
        if type(v.args) ~= "table" and type(v.args) ~= "function" then
          err("['%s'].args - expected table or function, got %s", type(v.args), errprefix)
        end
        if type(v.args) == "table" then
          validateOptions(v.args, errlvl, errprefix)
        end
      end
    end
  end
end

--- Register a new options table with AceConfig.
-- @param appName The application name for the config table.
-- @param options The options table, see AceConfig-3.0 docs for details.
-- @param skipValidation Skip options table validation (optional).
function AceConfigRegistry:RegisterOptionsTable(appName, options, skipValidation)
  if type(appName) ~= "string" then
    error(MAJOR .. ": RegisterOptionsTable(appName, options, skipValidation): 'appName' - string expected.", 2)
  end
  if type(options) ~= "table" and type(options) ~= "function" then
    error(MAJOR .. ": RegisterOptionsTable(appName, options, skipValidation): 'options' - table or function expected.", 2)
  end

  if type(options) == "table" then
    if not skipValidation then
      validateOptions(options, 0, appName)
    end
    self.tables[appName] = options
  else
    self.tables[appName] = function()
      local t = options()
      if not skipValidation then
        validateOptions(t, 0, appName)
      end
      return t
    end
  end

  self.callbacks:Fire("ConfigTableChange", appName)
end

--- Returns an iterator of all registered options tables.
-- @return Iterator (pairs) of all registered options tables.
function AceConfigRegistry:IterateOptionsTables()
  return pairs(self.tables)
end
