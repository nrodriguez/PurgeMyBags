--- AceAddon-3.0 provides a template for creating addon objects.
-- It'll create a stub addon object that you can use to initialize your
-- addon once the required libraries are loaded.
-- @class file
-- @name AceAddon-3.0
-- @release $Id: AceAddon-3.0.lua 1284 2022-09-25 11:21:25Z nevcairiel $

local MAJOR, MINOR = "AceAddon-3.0", 13
local AceAddon, oldminor = LibStub:NewLibrary(MAJOR, MINOR)

if not AceAddon then return end -- No upgrade needed

AceAddon.frame = AceAddon.frame or CreateFrame("Frame")
AceAddon.addons = AceAddon.addons or {}                   -- addon objects
AceAddon.statuses = AceAddon.statuses or {}               -- statuses of addon objects
AceAddon.initializequeue = AceAddon.initializequeue or {} -- addons that are new and not initialized
AceAddon.enablequeue = AceAddon.enablequeue or {}         -- addons that are initialized and waiting to be enabled
AceAddon.embeds = AceAddon.embeds or setmetatable({}, { __index = function(tbl, key)
  tbl[key] = {}
  return tbl[key]
end })

-- Lua APIs
local tinsert, tconcat, tremove = table.insert, table.concat, table.remove
local fmt, tostring = string.format, tostring
local select, pairs, next, type, unpack = select, pairs, next, type, unpack
local loadstring, assert, error = loadstring, assert, error
local setmetatable, getmetatable, rawset, rawget = setmetatable, getmetatable, rawset, rawget

-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: LibStub, IsLoggedIn, GetTime

local function safecall(func, ...)
  local success, err = pcall(func, ...)
  if not success then geterrorhandler()(err) end
end

--[[
	 xpcall safecall implementation
]]
local xpcall = xpcall

local function errorhandler(err)
  return geterrorhandler()(err)
end

local function CreateDispatcher(argCount)
  local code = [[
		local xpcall, eh = ...
		local method, ARGS
		local function call() return method(ARGS) end
	
		local function dispatch(func, ...)
			method = func
			if not method then return end
			ARGS = ...
			return xpcall(call, eh)
		end
	
		return dispatch
	]]

  local ARGS = {}
  for i = 1, argCount do ARGS[i] = "arg" .. i end
  code = code:gsub("ARGS", tconcat(ARGS, ", "))
  return assert(loadstring(code, "safecall Dispatcher[" .. argCount .. "]"))(xpcall, errorhandler)
end

local Dispatchers = setmetatable({}, {
  __index = function(self, argCount)
    local dispatcher = CreateDispatcher(argCount)
    rawset(self, argCount, dispatcher)
    return dispatcher
  end
})
Dispatchers[0] = function(func) return xpcall(func, errorhandler) end

local function safecall(func, ...)
  return Dispatchers[select("#", ...)](func, ...)
end

-- local functions that will be implemented further down
local Enable, Disable, EnableModule, DisableModule, Embed, NewModule, GetModule, GetName, SetDefaultModuleState, SetDefaultModuleLibraries, SetEnabledState, SetDefaultModulePrototype

-- used in :Enable() and :Disable()
local function SetState(self, state)
  state = state or (self.state ~= true)
  self.state = state

  if state then
    safecall(self.OnEnable, self)
  else
    safecall(self.OnDisable, self)
  end

  return state
end

local ModuleBase = {}

function ModuleBase.Enable(self)
  if not self.isEnabled then
    self.isEnabled = true
    return SetState(self, true)
  end
end

function ModuleBase.Disable(self)
  if self.isEnabled then
    self.isEnabled = false
    return SetState(self, false)
  end
end

function ModuleBase.IsEnabled(self)
  return self.isEnabled
end

function ModuleBase.SetEnabledState(self, state)
  self.enabledState = state
  if state then
    self:Enable()
  else
    self:Disable()
  end
end

function ModuleBase.SetDefaultModuleLibraries(self, ...)
  if not self.modules then return end
  for k, v in pairs(self.modules) do
    v:SetDefaultModuleLibraries(...)
  end
end

function ModuleBase.SetDefaultModuleState(self, state)
  if not self.modules then return end
  for k, v in pairs(self.modules) do
    v:SetDefaultModuleState(state)
  end
end

function ModuleBase.SetDefaultModulePrototype(self, prototype)
  if not self.modules then return end
  for k, v in pairs(self.modules) do
    v:SetDefaultModulePrototype(prototype)
  end
end

function ModuleBase.NewModule(self, name, ...)
  if not self.modules then
    self.modules = {}
  end
  local module = NewModule(self, name, ...)
  module.moduleName = name
  return module
end

function ModuleBase.GetModule(self, name)
  if not self.modules then return end
  return self.modules[name]
end

function ModuleBase.EnableModule(self, name)
  local mod = self:GetModule(name)
  if mod and not mod.isEnabled then
    mod:Enable()
  end
end

function ModuleBase.DisableModule(self, name)
  local mod = self:GetModule(name)
  if mod and mod.isEnabled then
    mod:Disable()
  end
end

local defaultPrototype = {
  Enable = ModuleBase.Enable,
  Disable = ModuleBase.Disable,
  IsEnabled = ModuleBase.IsEnabled,
  SetEnabledState = ModuleBase.SetEnabledState,
  SetDefaultModuleLibraries = ModuleBase.SetDefaultModuleLibraries,
  SetDefaultModuleState = ModuleBase.SetDefaultModuleState,
  SetDefaultModulePrototype = ModuleBase.SetDefaultModulePrototype,
  NewModule = ModuleBase.NewModule,
  GetModule = ModuleBase.GetModule,
  EnableModule = ModuleBase.EnableModule,
  DisableModule = ModuleBase.DisableModule,
}

local function NewModule(self, name, ...)
  if type(self) ~= "table" then error(
    ("Usage: NewModule(object, name, [lib, lib, lib, ...]): 'self' - table expected got '%s'."):format(type(self)), 2) end
  if type(name) ~= "string" then error(
    ("Usage: NewModule(object, name, [lib, lib, lib, ...]): 'name' - string expected got '%s'."):format(type(name)), 2) end
  if self.modules and self.modules[name] then error(
    ("Usage: NewModule(object, name, [lib, lib, lib, ...]): 'name' - Module '%s' already exists."):format(name), 2) end

  local module = {}
  module.moduleName = name
  module.enabledState = self.defaultModuleState
  module.prototype = self.defaultModulePrototype or defaultPrototype

  local mt = {
    __index = function(t, k)
      local p = t.prototype[k]
      if type(p) == "function" then
        return function(self, ...)
          return p(self, ...)
        end
      else
        return p
      end
    end
  }

  setmetatable(module, mt)

  for i = 1, select("#", ...) do
    local lib = select(i, ...)
    lib:Embed(module)
  end

  self.modules[name] = module

  return module
end

function GetModule(self, name, silent)
  if not self.modules or not self.modules[name] then
    if silent then
      return nil
    else
      error(("Usage: GetModule(object, name[, silent]): 'name' - Cannot find module '%s'."):format(tostring(name)), 2)
    end
  end
  return self.modules[name]
end

local function IsEnabled(self)
  return self.enabledState
end

local function SetEnabledState(self, state)
  self.enabledState = state
  return state
end

local mixins = {
  NewModule = NewModule,
  GetModule = GetModule,
  Enable = Enable,
  Disable = Disable,
  EnableModule = EnableModule,
  DisableModule = DisableModule,
  IsEnabled = IsEnabled,
  SetEnabledState = SetEnabledState,
  SetDefaultModuleLibraries = SetDefaultModuleLibraries,
  SetDefaultModuleState = SetDefaultModuleState,
  SetDefaultModulePrototype = SetDefaultModulePrototype,
}

function NewAddon(name, ...)
  local addon = {}
  addon.name = name
  addon.modules = {}
  addon.orderedModules = {}
  addon.defaultModuleState = true

  local mt = {
    __index = function(t, k)
      if k == "GetModule" then
        return GetModule
      elseif k == "Enable" then
        return Enable
      elseif k == "Disable" then
        return Disable
      elseif k == "EnableModule" then
        return EnableModule
      elseif k == "DisableModule" then
        return DisableModule
      elseif k == "IsEnabled" then
        return IsEnabled
      elseif k == "SetEnabledState" then
        return SetEnabledState
      elseif k == "SetDefaultModuleLibraries" then
        return SetDefaultModuleLibraries
      elseif k == "SetDefaultModuleState" then
        return SetDefaultModuleState
      elseif k == "SetDefaultModulePrototype" then
        return SetDefaultModulePrototype
      else
        return nil
      end
    end
  }

  setmetatable(addon, mt)

  for i = 1, select("#", ...) do
    local lib = select(i, ...)
    if type(lib) ~= "string" then
      lib:Embed(addon)
    end
  end

  AceAddon.addons[name] = addon
  return addon
end

function GetAddon(name, silent)
  if not silent and not AceAddon.addons[name] then
    error(("Usage: GetAddon(name): 'name' - Cannot find addon '%s'."):format(tostring(name)), 2)
  end
  return AceAddon.addons[name]
end

-- embed & upgrade our Addon prototype
function Embed(target)
  for k, v in pairs(mixins) do
    target[k] = v
  end
end

AceAddon:Embed(AceAddon)

-- upgrade existing addons
for name, addon in pairs(AceAddon.addons) do
  Embed(addon)
end
