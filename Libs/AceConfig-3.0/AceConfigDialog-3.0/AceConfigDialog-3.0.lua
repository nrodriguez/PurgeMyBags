--- AceConfigDialog-3.0 creates a GUI configuration panel.
-- @class file
-- @name AceConfigDialog-3.0
-- @release $Id: AceConfigDialog-3.0.lua 1284 2022-09-25 11:21:25Z nevcairiel $

local LibStub = LibStub
local MAJOR, MINOR = "AceConfigDialog-3.0", 80
local AceConfigDialog = LibStub:NewLibrary(MAJOR, MINOR)

if not AceConfigDialog then return end

AceConfigDialog.OpenFrames = AceConfigDialog.OpenFrames or {}
AceConfigDialog.Status = AceConfigDialog.Status or {}
AceConfigDialog.frame = AceConfigDialog.frame or CreateFrame("Frame")

AceConfigDialog.frame.apps = AceConfigDialog.frame.apps or {}
AceConfigDialog.frame.closing = AceConfigDialog.frame.closing or {}
AceConfigDialog.frame.closeAllOverride = AceConfigDialog.frame.closeAllOverride or {}

-- Lua APIs
local tinsert, tsort, tremove, wipe = table.insert, table.sort, table.remove, wipe
local strmatch, format = string.match, string.format
local error = error
local pairs, next, select, type, unpack, ipairs = pairs, next, select, type, unpack, ipairs
local tostring, tonumber = tostring, tonumber
local math_min, math_max, math_floor = math.min, math.max, math.floor

local function GetButtonAnchor(frame)
  local x, y = frame:GetCenter()
  if not x or not y then return "TOP" end
  local hhalf = (x > UIParent:GetWidth() * 2 / 3) and "RIGHT" or (x < UIParent:GetWidth() / 3) and "LEFT" or ""
  local vhalf = (y > UIParent:GetHeight() / 2) and "TOP" or "BOTTOM"
  return vhalf .. hhalf
end

function AceConfigDialog:Open(appName, container, arg, ...)
  if not appName then
    error("Usage: AceConfigDialog:Open(appName, container, ...): 'appName' - string expected.", 2)
  end

  local app = AceConfigDialog:GetConfigTable(appName)
  local options = app("dialog", container or appName) or {}

  local f

  local path = appName
  local name = GetAddOnMetadata(appName, "Title") or appName
  f = AceConfigDialog:Open(name, container, options, path, arg, ...)

  return f
end

function AceConfigDialog:Close(appName)
  if not self.OpenFrames[appName] then return end
  self.OpenFrames[appName]:Hide()
end

function AceConfigDialog:CloseAll()
  for k, v in pairs(self.OpenFrames) do
    v:Hide()
  end
end

function AceConfigDialog:GetFrame(appName)
  return self.OpenFrames[appName]
end

function AceConfigDialog:SelectGroup(appName, ...)
  local f = self:GetFrame(appName)
  if not f then return end

  f:SelectGroup(...)
end

function AceConfigDialog:EnableResize(appName, state)
  local f = self:GetFrame(appName)
  if not f then return end

  f:EnableResize(state)
end

function AceConfigDialog:SetDefaultSize(appName, width, height)
  local f = self:GetFrame(appName)
  if not f then return end

  f:SetDefaultSize(width, height)
end

function AceConfigDialog:AddToBlizOptions(appName, name, parent, ...)
  local BlizOptions = Settings and Settings.RegisterCanvasLayoutCategory or InterfaceOptions_AddCategory

  local f = AceConfigDialog:Open(appName)
  f:Hide()

  local BlizPanel = CreateFrame("Frame")
  BlizPanel.name = name or appName
  BlizPanel.parent = parent
  BlizPanel:Hide()

  BlizPanel:SetScript("OnShow", function()
    local frame = AceConfigDialog:Open(appName)
    frame:ClearAllPoints()
    frame:SetParent(BlizPanel)
    frame:SetPoint("TOPLEFT", 10, -10)
    frame:SetPoint("BOTTOMRIGHT", -10, 10)
    frame:Show()
  end)

  BlizPanel:SetScript("OnHide", function()
    AceConfigDialog:Close(appName)
  end)

  if Settings then
    Settings.RegisterAddOnCategory(BlizPanel)
  else
    InterfaceOptions_AddCategory(BlizPanel)
  end

  return BlizPanel
end
