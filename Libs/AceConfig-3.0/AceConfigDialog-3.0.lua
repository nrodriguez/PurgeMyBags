--- AceConfigDialog-3.0 creates a GUI configuration panel.
-- @class file
-- @name AceConfigDialog-3.0
-- @release $Id: AceConfigDialog-3.0.lua 1284 2022-09-25 11:21:25Z nevcairiel $

local LibStub = LibStub
local MAJOR, MINOR = "AceConfigDialog-3.0", 3
local AceConfigDialog = LibStub:NewLibrary(MAJOR, MINOR)

if not AceConfigDialog then return end -- No upgrade needed

AceConfigDialog.OpenFrames = AceConfigDialog.OpenFrames or {}
AceConfigDialog.Status = AceConfigDialog.Status or {}
AceConfigDialog.frame = AceConfigDialog.frame or CreateFrame("Frame")

AceConfigDialog.frame.apps = AceConfigDialog.frame.apps or {}
AceConfigDialog.frame.closing = AceConfigDialog.frame.closing or {}
AceConfigDialog.frame.closeAllOverride = AceConfigDialog.frame.closeAllOverride or {}

-- Lua APIs
local tinsert, tremove, tconcat = table.insert, table.remove, table.concat
local strmatch, format = string.match, string.format
local assert, error, loadstring = assert, error, loadstring
local pairs, next, select, type = pairs, next, select, type
local tostring, tonumber = tostring, tonumber
local math = math

-- WoW APIs
local GetTime, CreateFrame, UIParent = GetTime, CreateFrame, UIParent
local CloseDropDownMenus = CloseDropDownMenus

local registry = LibStub("AceConfigRegistry-3.0")

-- Create a new GUI config panel.
function AceConfigDialog:Open(appName, container)
  if not registry.tables[appName] then return end

  if not container then
    container = UIParent
  end

  if not self.OpenFrames[appName] then
    local frame = self:Create(appName)
    self.OpenFrames[appName] = frame
  end

  local frame = self.OpenFrames[appName]
  frame:SetParent(container)
  frame:ClearAllPoints()
  frame:SetPoint("CENTER", container, "CENTER")
  frame:Show()

  self:Open(appName)
end

function AceConfigDialog:Close(appName)
  if self.OpenFrames[appName] then
    self.OpenFrames[appName]:Hide()
  end
end

function AceConfigDialog:CloseAll()
  for k, v in pairs(self.OpenFrames) do
    v:Hide()
  end
end

function AceConfigDialog:SelectGroup(appName, ...)
  local frame = self.OpenFrames[appName]
  if frame then
    frame:SelectGroup(...)
  end
end

function AceConfigDialog:EnableResize(appName, state)
  local frame = self.OpenFrames[appName]
  if frame then
    frame.resizing = state
  end
end

function AceConfigDialog:SetDefaultSize(appName, width, height)
  local frame = self.OpenFrames[appName]
  if frame then
    frame.defaultWidth = width or 700
    frame.defaultHeight = height or 500
  end
end

function AceConfigDialog:Create(appName)
  local frame = CreateFrame("Frame", nil, UIParent)
  frame:Hide()

  frame:SetWidth(700)
  frame:SetHeight(500)
  frame:SetPoint("CENTER", UIParent, "CENTER")

  frame.titletext = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  frame.titletext:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -10)

  local title = frame:CreateTexture(nil, "OVERLAY")
  title:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
  title:SetWidth(300)
  title:SetHeight(68)
  title:SetPoint("TOP", frame, "TOP", 0, 12)

  local titlebg = frame:CreateTexture(nil, "OVERLAY")
  titlebg:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
  titlebg:SetWidth(300)
  titlebg:SetHeight(68)
  titlebg:SetPoint("TOP", frame, "TOP", 0, 12)

  frame.sizer_se = CreateFrame("Frame", nil, frame)
  frame.sizer_se:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
  frame.sizer_se:SetWidth(25)
  frame.sizer_se:SetHeight(25)
  frame.sizer_se:EnableMouse()
  frame.sizer_se:SetScript("OnMouseDown", function() frame:StartSizing("BOTTOMRIGHT") end)
  frame.sizer_se:SetScript("OnMouseUp", function() frame:StopMovingOrSizing() end)

  local line1 = frame.sizer_se:CreateTexture(nil, "BACKGROUND")
  line1:SetWidth(14)
  line1:SetHeight(14)
  line1:SetPoint("BOTTOMRIGHT", -8, 8)
  line1:SetTexture("Interface\\Tooltips\\UI-Tooltip-Border")
  local x = 0.1 * 14 / 17
  line1:SetTexCoord(0.05 - x, 0.5, 0.05, 0.5 + x, 0.05, 0.5 - x, 0.5 + x, 0.5)

  local line2 = frame.sizer_se:CreateTexture(nil, "BACKGROUND")
  line2:SetWidth(8)
  line2:SetHeight(8)
  line2:SetPoint("BOTTOMRIGHT", -8, 8)
  line2:SetTexture("Interface\\Tooltips\\UI-Tooltip-Border")
  local x = 0.1 * 8 / 17
  line2:SetTexCoord(0.05 - x, 0.5, 0.05, 0.5 + x, 0.05, 0.5 - x, 0.5 + x, 0.5)

  frame:SetResizable(true)
  frame:SetMinResize(400, 200)
  frame:SetScript("OnSizeChanged", function() frame:OnSizeChanged() end)

  frame:SetScript("OnShow", function()
    frame:Refresh()
  end)

  frame:SetScript("OnHide", function()
    frame:OnClose()
  end)

  return frame
end

function AceConfigDialog:AddToBlizOptions(appName, name)
  local frame = self:Create(appName)
  frame:Hide()

  if not name then
    name = appName
  end

  if not InterfaceOptions_AddCategory then return end

  InterfaceOptions_AddCategory(frame, name)
end
