--- AceDB-3.0 provides a database for storing character-specific and realm-specific settings.
-- @class file
-- @name AceDB-3.0
-- @release $Id: AceDB-3.0.lua 1284 2022-09-25 11:21:25Z nevcairiel $

local ACEDB_MAJOR, ACEDB_MINOR = "AceDB-3.0", 27
local AceDB = LibStub:NewLibrary(ACEDB_MAJOR, ACEDB_MINOR)

if not AceDB then return end -- No upgrade needed

-- Lua APIs
local type, pairs, next, error = type, pairs, next, error
local setmetatable, rawset, rawget = setmetatable, rawset, rawget

-- WoW APIs
local _G = _G

AceDB.db_registry = AceDB.db_registry or {}
AceDB.frame = AceDB.frame or CreateFrame("Frame")

local CallbackHandler
local CallbackDummy = { Fire = function() end }

local DBObjectLib = {}

--[[-------------------------------------------------------------------------
	AceDB Utility Functions
---------------------------------------------------------------------------]]

-- Simple shallow copy for copying defaults
local function copyTable(src, dest)
  if type(dest) ~= "table" then dest = {} end
  if type(src) == "table" then
    for k, v in pairs(src) do
      if type(v) == "table" then
        -- try to index the key first so that the metatable creates the defaults, if any
        v = copyTable(v, dest[k])
      end
      dest[k] = v
    end
  end
  return dest
end

-- Called to remove all defaults in the default table from the database
local function removeDefaults(db, defaults, path)
  -- remove all metatables from the db, so we don't have to deal with them
  setmetatable(db, nil)

  -- loop through the defaults and remove them from the db
  for k, v in pairs(defaults) do
    if type(v) == "table" then
      path[#path + 1] = k
      removeDefaults(db[k], v, path)
      path[#path] = nil

      if next(db[k]) == nil then
        db[k] = nil
      end
    else
      db[k] = nil
    end
  end
end

-- Called to copy all defaults in the default table to the database
local function copyDefaults(db, defaults, path)
  -- remove all metatables from the db, so we don't have to deal with them
  setmetatable(db, nil)

  -- loop through the defaults and add them to the db
  for k, v in pairs(defaults) do
    if type(v) == "table" then
      path[#path + 1] = k
      if not db[k] then
        db[k] = {}
      end
      copyDefaults(db[k], v, path)
      path[#path] = nil
    else
      if db[k] == nil then
        db[k] = v
      end
    end
  end
end

-- Called to remove all defaults in the default table from the database
local function cleanDefaults(db, defaults, path)
  -- remove all metatables from the db, so we don't have to deal with them
  setmetatable(db, nil)

  -- loop through the defaults and remove them from the db
  for k, v in pairs(defaults) do
    if type(v) == "table" and db[k] then
      path[#path + 1] = k
      cleanDefaults(db[k], v, path)
      path[#path] = nil

      if next(db[k]) == nil then
        db[k] = nil
      end
    else
      if db[k] == defaults[k] then
        db[k] = nil
      end
    end
  end
end

-- This metatable is used for database defaults
local function ismember(table, key)
  return rawget(table, key) ~= nil
end

local dbmt = {
  __index = function(t, key)
    local defaults = rawget(t, "defaults")
    if defaults then
      return defaults[key]
    end
  end,
  __newindex = function(t, key, value)
    local defaults = rawget(t, "defaults")
    if defaults and not ismember(t, key) and defaults[key] == value then
      return
    end
    rawset(t, key, value)
  end,
}

--[[-------------------------------------------------------------------------
	AceDB Object Method Definitions
---------------------------------------------------------------------------]]

local methods = {
  RegisterCallback = function(self, eventname, method, ...)
    if not self.callbacks then
      self.callbacks = CallbackHandler:New(self)
    end
    self.callbacks:RegisterCallback(eventname, method, ...)
  end,

  UnregisterCallback = function(self, eventname, method)
    if self.callbacks then
      self.callbacks:UnregisterCallback(eventname, method)
    end
  end,

  UnregisterAllCallbacks = function(self)
    if self.callbacks then
      self.callbacks:UnregisterAllCallbacks()
    end
  end,

  RegisterDefaults = function(self, defaults)
    if not defaults then return end
    if not self.defaults then self.defaults = {} end
    copyDefaults(self.defaults, defaults, {})
    copyDefaults(self, defaults, {})
  end,

  ResetProfile = function(self)
    if not self.keys.profile then return end
    if self.keys.profile == self.defaultProfile then
      self.profile = nil
    else
      self.profile = copyTable(self.defaults.profile, self.profile)
    end
    self.callbacks:Fire("OnProfileReset", self.keys.profile)
  end,

  ResetDB = function(self, defaultProfile)
    if defaultProfile and self.keys.profile ~= self.defaultProfile then
      -- cleanup the old profile
      self.profile = nil
      self.keys.profile = self.defaultProfile
    end

    -- cleanup custom profiles
    for k, v in pairs(self.profiles) do
      if not self.keys[k] then
        self.profiles[k] = nil
      end
    end

    -- cleanup character profiles
    for k, v in pairs(self.char) do
      if k ~= self.keys.char then
        self.char[k] = nil
      end
    end

    self.callbacks:Fire("OnDatabaseReset", self.keys.profile)
  end,

  SetProfile = function(self, name)
    if not self.profiles or not self.keys.profile then return end
    self.keys.profile = name
    self.profile = self.profiles[name]
    if not self.profile then
      self.profile = copyTable(self.defaults.profile, {})
      self.profiles[name] = self.profile
    end
    self.callbacks:Fire("OnProfileChanged", name)
  end,

  GetProfiles = function(self)
    if not self.profiles then return {} end
    local t = {}
    local currentProfile = self.keys.profile
    for k in pairs(self.profiles) do
      if k == currentProfile then
        t[1] = k
      else
        t[#t + 1] = k
      end
    end
    return t
  end,

  GetCurrentProfile = function(self)
    return self.keys.profile
  end,

  DeleteProfile = function(self, name)
    if not self.profiles or not name then return end
    if self.keys.profile == name then
      self:SetProfile(self.defaultProfile)
    end
    self.profiles[name] = nil
    self.callbacks:Fire("OnProfileDeleted", name)
  end,

  CopyProfile = function(self, name)
    if not self.profiles or not name then return end
    if name == self.keys.profile then return end
    local profile = self.profiles[name]
    if profile then
      self.profile = copyTable(profile, nil)
      self.profiles[self.keys.profile] = self.profile
      self.callbacks:Fire("OnProfileCopied", name, self.keys.profile)
    end
  end,
}

--[[-------------------------------------------------------------------------
	AceDB Public API
---------------------------------------------------------------------------]]

function AceDB:New(tbl, defaults)
  if not tbl then
    error("Usage: AceDB:New(tbl[, defaults]): 'tbl' - table expected, got " .. tostring(tbl), 2)
  end

  if not defaults then defaults = {} end

  local db = setmetatable(tbl, dbmt)
  db.callbacks = CallbackDummy
  db.keys = {
    char = UnitName("player") .. " - " .. GetRealmName(),
    realm = GetRealmName(),
    class = select(2, UnitClass("player")),
    race = select(2, UnitRace("player")),
    faction = UnitFactionGroup("player"),
    factionrealm = UnitFactionGroup("player") .. " - " .. GetRealmName(),
    profile = "Default",
  }
  db.profiles = db.profiles or {}
  db.profile = db.profiles[db.keys.profile]
  if not db.profile then
    db.profile = copyTable(defaults.profile, {})
    db.profiles[db.keys.profile] = db.profile
  end

  db.char = db.char or {}
  if not db.char[db.keys.char] then
    db.char[db.keys.char] = copyTable(defaults.char, {})
  end

  for k, v in pairs(methods) do
    db[k] = v
  end

  db.defaultProfile = "Default"
  db.defaults = defaults

  return db
end
