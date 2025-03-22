--- AceGUI-3.0 provides a framework for creating GUI widgets.
-- @class file
-- @name AceGUI-3.0
-- @release $Id: AceGUI-3.0.lua 1284 2022-09-25 11:21:25Z nevcairiel $
local ACEGUI_MAJOR, ACEGUI_MINOR = "AceGUI-3.0", 41
local AceGUI = LibStub:NewLibrary(ACEGUI_MAJOR, ACEGUI_MINOR)

if not AceGUI then return end -- No upgrade needed

-- Lua APIs
local pairs, next, type = pairs, next, type
local error = error
local floor, min, max = math.floor, math.min, math.max
local select, wipe = select, table.wipe

-- WoW APIs
local CreateFrame, UIParent = CreateFrame, UIParent

-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: GameTooltip, NORMAL_FONT_COLOR, HIGHLIGHT_FONT_COLOR

AceGUI.WidgetRegistry = AceGUI.WidgetRegistry or {}
AceGUI.LayoutRegistry = AceGUI.LayoutRegistry or {}
AceGUI.WidgetBase = AceGUI.WidgetBase or {}
AceGUI.WidgetContainerBase = AceGUI.WidgetContainerBase or {}
AceGUI.WidgetVersions = AceGUI.WidgetVersions or {}
AceGUI.tooltip = AceGUI.tooltip or CreateFrame("GameTooltip", "AceGUITooltip", UIParent, "GameTooltipTemplate")

-- local upvalues
local WidgetRegistry = AceGUI.WidgetRegistry
local LayoutRegistry = AceGUI.LayoutRegistry
local WidgetVersions = AceGUI.WidgetVersions

local function fixlevels(parent, ...)
  local i = 1
  local child = select(i, ...)
  while child do
    child:SetFrameLevel(parent:GetFrameLevel() + 1)
    fixlevels(child, child:GetChildren())
    i = i + 1
    child = select(i, ...)
  end
end

local function fixstrata(strata, parent, ...)
  local i = 1
  local child = select(i, ...)
  while child do
    child:SetFrameStrata(strata)
    fixstrata(strata, child, child:GetChildren())
    i = i + 1
    child = select(i, ...)
  end
end

-- Check the widget version
local function CheckVersion(widgetType, version)
  if not version then return end
  if not WidgetVersions[widgetType] then
    WidgetVersions[widgetType] = version
  end
  if version > WidgetVersions[widgetType] then
    WidgetVersions[widgetType] = version
  end
end

--- Create a new widget.
-- @param widgetType The type of the widget.
-- @param name The name of the widget (defaults to AceGUI30 + widget type).
-- @return The newly created widget.
function AceGUI:Create(widgetType, name)
  if not WidgetRegistry[widgetType] then
    error(("Widget type %s does not exist in AceGUI-3.0"):format(widgetType), 2)
  end

  local widget = WidgetRegistry[widgetType]()
  widget:SetName(name or ("AceGUI30" .. widgetType .. AceGUI:GetNextWidgetNum(widgetType)))

  return widget
end

--- Register a widget type.
-- @param widgetType The type of the widget being registered.
-- @param widgetData The data of the widget being registered.
function AceGUI:RegisterWidgetType(widgetType, widgetData, version)
  if not widgetType then
    error("Attempt to register a widget with a nil type", 2)
  end
  if not widgetData then
    error("Attempt to register a widget with no data", 2)
  end
  if not widgetData.OnAcquire then
    error("Attempt to register a widget with no OnAcquire method", 2)
  end

  CheckVersion(widgetType, version)

  WidgetRegistry[widgetType] = function()
    local widget = CreateFrame("Frame")
    for k, v in pairs(widgetData) do
      widget[k] = v
    end
    return widget
  end

  return true
end

--- Register a layout.
-- @param layoutType The type of the layout being registered.
-- @param layoutFunc The layout function.
function AceGUI:RegisterLayout(layoutType, layoutFunc)
  if not layoutType then
    error("Attempt to register a layout with a nil type", 2)
  end
  if not layoutFunc then
    error("Attempt to register a layout with no function", 2)
  end

  LayoutRegistry[layoutType] = layoutFunc
end

--- Get the next widget number for a type.
-- @param widgetType The type of the widget.
-- @return The next number to be used for widgets of this type.
function AceGUI:GetNextWidgetNum(widgetType)
  if not widgetType then
    error("Attempt to get next widget number with a nil type", 2)
  end

  if not self.widgetNum then
    self.widgetNum = {}
  end

  local num = self.widgetNum[widgetType] or 0
  self.widgetNum[widgetType] = num + 1
  return num + 1
end

--- Embed AceGUI into a target object.
-- @param target target object to embed AceGUI in
function AceGUI:Embed(target)
  for k, v in pairs(self) do
    if k ~= "GetLibraryVersion" then
      target[k] = v
    end
  end
end

-- Initialize the library
local function Initialize()
  local frame = CreateFrame("Frame")
  frame:SetScript("OnEvent", function(this, event, ...)
    if event == "PLAYER_LOGIN" then
      this:UnregisterEvent("PLAYER_LOGIN")
      this:SetScript("OnEvent", nil)
      this:SetParent(nil)
      Initialize = nil
      frame = nil
    end
  end)
  frame:RegisterEvent("PLAYER_LOGIN")
end

Initialize()
