--- AceConfigRegistry-3.0 handles central registration of options tables in use by addons and modules.
-- Options tables can be registered as raw tables, or as function refs that return a table.
-- Such functions receive three arguments: "uiType", "uiName", "appName". This allows you to select
-- different options when some UI (such as the config dialog) requests the options table.
-- @class file
-- @name AceConfigRegistry-3.0
-- @release $Id: AceConfigRegistry-3.0.lua 1284 2022-09-25 11:21:25Z nevcairiel $

local CallbackHandler = LibStub("CallbackHandler-1.0")
local MAJOR, MINOR = "AceConfigRegistry-3.0", 20
local AceConfigRegistry = LibStub:NewLibrary(MAJOR, MINOR)

if not AceConfigRegistry then return end

AceConfigRegistry.tables = AceConfigRegistry.tables or {}

if not AceConfigRegistry.callbacks then
  AceConfigRegistry.callbacks = CallbackHandler:New(AceConfigRegistry)
end

-- Lua APIs
local tinsert, tconcat = table.insert, table.concat
local strfind, strmatch = string.find, string.match
local type, tostring, select, pairs = type, tostring, select, pairs
local error, assert = error, assert

-----------------------------------------------------------------------
-- Validating options table consistency:
--
local function validateKey(k, errlvl, ...)
  if type(k) ~= "string" then
    error(MAJOR .. ": ['keys'] in options table must be strings.", errlvl + 1)
  end
  if strfind(k, "[%c\127]") then
    error(MAJOR .. ": ['keys'] in options table must not contain control characters.", errlvl + 1)
  end
  local ok = strmatch(k, "^[%a_][%a_%d]*$")
  if not ok then
    error(MAJOR .. ": ['keys'] in options table must be valid Lua identifiers.", errlvl + 1)
  end
end

local function validateVal(v, errlvl, ...)
  if type(v) == "table" then
    for k, vv in pairs(v) do
      validateKey(k, errlvl, ...)
      validateVal(vv, errlvl, ...)
    end
  end
end

local function validateOptions(options, errlvl, ...)
  if not options.name then
    error(MAJOR .. ": ['name'] is required in options table.", errlvl + 1)
  end
  if type(options.name) ~= "string" then
    error(MAJOR .. ": ['name'] must be a string.", errlvl + 1)
  end
  if not options.type then
    options.type = "group"
  end
  if type(options.type) ~= "string" then
    error(MAJOR .. ": ['type'] must be a string.", errlvl + 1)
  end
  validateVal(options, errlvl + 1, ...)
end

-----------------------------------------------------------------------
-- Registering a table

function AceConfigRegistry:RegisterOptionsTable(appName, options, skipValidation)
  if type(appName) ~= "string" then
    error(MAJOR .. ": Argument #1 to RegisterOptionsTable must be a string.", 2)
  end
  if type(options) ~= "table" and type(options) ~= "function" then
    error(MAJOR .. ": Argument #2 to RegisterOptionsTable must be a table or function reference.", 2)
  end

  local reg = AceConfigRegistry.tables

  if reg[appName] then
    error(MAJOR .. ": Attempt to register options for '" .. appName .. "' twice.", 2)
  end

  if type(options) == "table" then
    if not skipValidation then
      validateOptions(options, 1, appName)
    end
    reg[appName] = function() return options end
  else
    reg[appName] = options
  end

  self.callbacks:Fire("ConfigTableRegistered", appName)
end

-----------------------------------------------------------------------
-- Event handling

function AceConfigRegistry:NotifyChange(appName)
  if not AceConfigRegistry.tables[appName] then return end
  AceConfigRegistry.callbacks:Fire("ConfigTableChange", appName)
end
