--[[ $Id: CallbackHandler-1.0.lua 1186 2018-07-21 14:19:18Z nevcairiel $ ]]
local MAJOR, MINOR = "CallbackHandler-1.0", 7
local CallbackHandler = LibStub:NewLibrary(MAJOR, MINOR)

if not CallbackHandler then return end -- No upgrade needed

local meta = {
  __index = function(tbl, key)
    tbl[key] = {}
    return tbl[key]
  end
}

-- Lua APIs
local tconcat = table.concat
local assert, error, loadstring = assert, error, loadstring
local setmetatable, rawset, rawget = setmetatable, rawset, rawget
local next, select, pairs, type, tostring = next, select, pairs, type, tostring

-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: geterrorhandler

local xpcall = xpcall

local function errorhandler(err)
  return geterrorhandler()(err)
end

local function Dispatch(handlers, ...)
  local n = select("#", ...)
  -- Call each handler
  for i, func in pairs(handlers) do
    if type(func) == "function" then
      xpcall(func, errorhandler, ...)
    end
  end
end

local function CreateEventFunction(target, funcName)
  return function(...) Dispatch(target[funcName], ...) end
end

local function RegisterEvent(self, event, method, ...)
  if type(method) ~= "string" and type(method) ~= "function" then
    error("Usage: RegisterEvent(event, method [, arg1, arg2, ...]): 'method' - string or function expected.", 2)
  end

  if not self.events[event] then
    self.events[event] = setmetatable({}, meta)
    self.frame:RegisterEvent(event)
  end

  local args = { ... }
  if type(method) == "string" then
    if type(self[method]) ~= "function" then
      error(("Usage: RegisterEvent(event, method [, arg1, arg2, ...]): 'self.%s' - function expected."):format(method), 2)
    end

    if args[1] then
      local func = function(...)
        self[method](self, ...)
        for i = 1, #args do
          args[i](...)
        end
      end
      self.events[event][self] = func
    else
      self.events[event][self] = function(...) self[method](self, ...) end
    end
  else
    if args[1] then
      local func = function(...)
        method(...)
        for i = 1, #args do
          args[i](...)
        end
      end
      self.events[event][self] = func
    else
      self.events[event][self] = method
    end
  end
end

local function UnregisterEvent(self, event)
  if not self.events[event] then return end

  self.events[event][self] = nil

  if not next(self.events[event]) then
    self.events[event] = nil
    self.frame:UnregisterEvent(event)
  end
end

local function UnregisterAllEvents(self)
  for event, funcs in pairs(self.events) do
    funcs[self] = nil
    if not next(funcs) then
      self.events[event] = nil
      self.frame:UnregisterEvent(event)
    end
  end
end

local mixins = {
  "RegisterEvent",
  "UnregisterEvent",
  "UnregisterAllEvents",
}

function CallbackHandler:New(target, RegisterName, UnregisterName, UnregisterAllName)
  RegisterName = RegisterName or "RegisterEvent"
  UnregisterName = UnregisterName or "UnregisterEvent"
  UnregisterAllName = UnregisterAllName or "UnregisterAllEvents"

  -- Create the registry object
  target = target or {}
  target.events = target.events or setmetatable({}, meta)
  target.frame = target.frame or CreateFrame("Frame")

  for _, v in pairs(mixins) do
    target[v] = target[v] or _G[v]
  end

  return target
end

-- CallbackHandler can be embedded into libraries
CallbackHandler.embeds = CallbackHandler.embeds or {}

local mixins = {
  "New",
}

function CallbackHandler:Embed(target)
  for k, v in pairs(mixins) do
    target[v] = self[v]
  end
  self.embeds[target] = true
  return target
end

-- Upgrade existing libraries
for target, v in pairs(CallbackHandler.embeds) do
  CallbackHandler:Embed(target)
end
