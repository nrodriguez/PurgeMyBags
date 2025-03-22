local addonName, addon = ...

-- Initialize Ace3 libraries
local AceAddon = LibStub("AceAddon-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
local AceDB = LibStub("AceDB-3.0")
local AceGUI = LibStub("AceGUI-3.0")

-- Create addon object (make it global)
PurgeMyBags = AceAddon:NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0")
_G[addonName] = PurgeMyBags

-- Default settings
local defaults = {
  profile = {
    whitelistedItems = {},
    whitelistedExpansions = {
      classic = true,
      tbc = true,
      wrath = true,
      cata = true,
      mop = true,
      wod = true,
      legion = true,
      bfa = true,
      sl = true,
      df = true
    },
    whitelistedItemTypes = {
      Armor = true,
      Weapon = true,
      Consumable = true,
      Container = true,
      Reagent = true,
      Recipe = true,
      Gem = true,
      Glyph = true,
      Quest = true,
      Miscellaneous = true,
      TradeGoods = true
    }
  }
}

function PurgeMyBags:OnInitialize()
  -- Initialize database
  self.db = AceDB:New("PurgeMyBagsDB", defaults)

  -- Setup options first
  self:SetupOptions()

  -- Register chat commands
  self:RegisterChatCommand("pmb", "HandleSlashCommand")
  self:RegisterChatCommand("purgemybags", "HandleSlashCommand")
end

function PurgeMyBags:OnEnable()
  -- Register events
  self:RegisterEvent("BAG_UPDATE")
end

function PurgeMyBags:HandleSlashCommand(input)
  if input:trim() == "config" then
    self:ShowConfig()
  else
    -- Default to showing the inventory browser
    self:ShowInventoryBrowser()
  end
end

function PurgeMyBags:ShowConfig()
  -- Register with both systems
  LibStub("AceConfig-3.0"):RegisterOptionsTable(addonName, self.options)

  -- Use the modern Settings API
  Settings.OpenToCategory(addonName)
end

function PurgeMyBags:CreateInventoryBrowser()
  -- Create the main frame
  local frame = AceGUI:Create("Frame")
  frame.released = false -- Add a flag to track release state

  frame:SetTitle("PurgeMyBags - Inventory Browser")
  frame:SetLayout("List")
  frame:SetCallback("OnClose", function(widget)
    if not widget.released then
      widget.released = true
      AceGUI:Release(widget)
    end
  end)
  frame:SetWidth(600)
  frame:SetHeight(700)

  -- Add settings button to the top right
  local settingsButton = CreateFrame("Button", nil, frame.frame)
  settingsButton:SetSize(32, 32)
  settingsButton:SetPoint("LEFT", frame.frame, "RIGHT", 2, 300) -- Changed vertical offset from 200 to 300

  -- Create border texture
  local border = settingsButton:CreateTexture(nil, "BACKGROUND")
  border:SetPoint("TOPLEFT", settingsButton, "TOPLEFT", -1, 1)
  border:SetPoint("BOTTOMRIGHT", settingsButton, "BOTTOMRIGHT", 1, -1)
  border:SetColorTexture(0.5, 0.5, 0.5, 1) -- Gray border color

  -- Create background texture
  local background = settingsButton:CreateTexture(nil, "BACKGROUND", nil, 1)
  background:SetAllPoints(settingsButton)
  background:SetColorTexture(0, 0, 0, 0.8) -- Dark background

  -- Create and set up the gear icon texture
  local settingsIcon = settingsButton:CreateTexture(nil, "OVERLAY")
  settingsIcon:SetTexture("Interface\\Icons\\Trade_Engineering")
  settingsIcon:SetAllPoints(settingsButton)

  -- Add hover effect
  settingsButton:SetScript("OnEnter", function(self)
    settingsIcon:SetVertexColor(1, 0.8, 0) -- Golden color on hover
    border:SetColorTexture(1, 0.8, 0, 1)   -- Golden border on hover
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Open Settings")
    GameTooltip:Show()
  end)

  settingsButton:SetScript("OnLeave", function(self)
    settingsIcon:SetVertexColor(1, 1, 1)     -- Normal color
    border:SetColorTexture(0.5, 0.5, 0.5, 1) -- Normal border color
    GameTooltip:Hide()
  end)

  -- Add click handler to open config
  settingsButton:SetScript("OnClick", function()
    PurgeMyBags:ShowConfig()
  end)

  -- Add highlight texture
  local highlightTexture = settingsButton:CreateTexture(nil, "HIGHLIGHT")
  highlightTexture:SetAllPoints(settingsButton)
  highlightTexture:SetTexture("Interface\\Buttons\\UI-OptionsButton")
  highlightTexture:SetBlendMode("ADD")
  highlightTexture:SetAlpha(0.3)

  -- Add help text container with padding
  local helpContainer = AceGUI:Create("SimpleGroup")
  helpContainer:SetFullWidth(true)
  helpContainer:SetLayout("Flow")
  helpContainer:SetHeight(100)
  frame:AddChild(helpContainer)

  -- Add padding at the top
  local topPadding = AceGUI:Create("Label")
  topPadding:SetText(" ")
  topPadding:SetFullWidth(true)
  helpContainer:AddChild(topPadding)

  -- Add help text with larger font
  local helpText = AceGUI:Create("Label")
  helpText:SetText("|cFFFFFFFF|r\n" ..
    "|cFFFFD100How to use:|r\n\n" ..
    "|cFFFFFFFFClick items to toggle whether they should be saved (whitelisted) or purged.\n\n" ..
    "• Items at full brightness will be saved\n" ..
    "• Faded items with a red tint will be purged when you click the Purge button\n" ..
    "|r")
  helpText:SetFontObject(GameFontNormalLarge)
  helpText:SetFullWidth(true)
  helpContainer:AddChild(helpText)

  -- Add padding at the bottom
  local bottomPadding = AceGUI:Create("Label")
  bottomPadding:SetText(" ")
  bottomPadding:SetFullWidth(true)
  helpContainer:AddChild(bottomPadding)

  -- Add a separator
  local separator = AceGUI:Create("Heading")
  separator:SetFullWidth(true)
  frame:AddChild(separator)

  -- Create a scrolling container for the inventory
  local scroll = AceGUI:Create("ScrollFrame")
  scroll:SetLayout("Flow")
  scroll:SetFullWidth(true)
  scroll:SetHeight(400) -- Reduced height to make room for button
  frame:AddChild(scroll)

  -- Function to create an item button
  local function CreateItemButton(bag, slot, itemLink)
    local itemButton = AceGUI:Create("Icon")
    local itemLocation = ItemLocation:CreateFromBagAndSlot(bag, slot)
    local itemID = C_Item.GetItemID(itemLocation)
    local itemName = select(1, GetItemInfo(itemLink))
    local _, _, _, _, icon = GetItemInfoInstant(itemID)

    itemButton:SetImage(icon)
    itemButton:SetImageSize(32, 32)
    itemButton:SetWidth(40)
    itemButton:SetHeight(40)

    -- Create a red overlay texture for non-whitelisted items
    local redOverlay = itemButton.frame:CreateTexture(nil, "OVERLAY")
    redOverlay:SetAllPoints(itemButton.image)
    redOverlay:SetColorTexture(0.8, 0, 0, 0.15)
    redOverlay:SetBlendMode("BLEND")

    -- Function to update item appearance
    local function UpdateItemAppearance(isWhitelisted)
      itemButton.frame:SetAlpha(isWhitelisted and 1.0 or 0.5)
      redOverlay:SetShown(not isWhitelisted)
    end

    -- Show tooltip on mouseover
    itemButton:SetCallback("OnEnter", function()
      GameTooltip:SetOwner(itemButton.frame, "ANCHOR_TOPRIGHT")
      GameTooltip:SetBagItem(bag, slot)
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine(self.db.profile.whitelistedItems[itemName] and
        "|cFF00FF00Click to remove from whitelist|r" or
        "|cFFFF0000Click to add to whitelist|r")
      GameTooltip:Show()
    end)
    itemButton:SetCallback("OnLeave", function()
      GameTooltip:Hide()
    end)

    -- Toggle whitelist on click
    itemButton:SetCallback("OnClick", function()
      local isWhitelisted = self.db.profile.whitelistedItems[itemName]
      local expansionID = select(15, GetItemInfo(itemLink))
      local expansionMap = {
        [0] = "classic",
        [1] = "tbc",
        [2] = "wrath",
        [3] = "cata",
        [4] = "mop",
        [5] = "wod",
        [6] = "legion",
        [7] = "bfa",
        [8] = "sl",
        [9] = "df"
      }
      local expName = expansionMap[expansionID]

      if isWhitelisted then
        -- Un-whitelist the item
        self.db.profile.whitelistedItems[itemName] = nil
        UpdateItemAppearance(false)

        -- If this item was whitelisted by expansion, uncheck that expansion
        if expName and self.db.profile.whitelistedExpansions[expName] then
          self.db.profile.whitelistedExpansions[expName] = false
          print("|cFFFF0000PurgeMyBags:|r Disabled whitelist for " .. expName .. " expansion items")
        end
      else
        -- Whitelist the item
        self.db.profile.whitelistedItems[itemName] = true
        UpdateItemAppearance(true)
      end

      -- Update all items in the inventory browser to reflect expansion changes
      local function UpdateAllItems()
        for _, child in pairs(scroll.children) do
          if child.children then -- This is a bag container
            for _, itemWidget in pairs(child.children) do
              if itemWidget.type == "Icon" then
                local widgetItemLink = itemWidget.itemLink
                if widgetItemLink then
                  local widgetItemName = select(1, GetItemInfo(widgetItemLink))
                  local widgetExpID = select(15, GetItemInfo(widgetItemLink))
                  local widgetExpName = expansionMap[widgetExpID]

                  local isNowWhitelisted = self.db.profile.whitelistedItems[widgetItemName] or
                      (widgetExpName and self.db.profile.whitelistedExpansions[widgetExpName]) or
                      (widgetItemName == hearthstoneName)

                  itemWidget.UpdateAppearance(isNowWhitelisted)
                end
              end
            end
          end
        end
      end

      -- Update all items to reflect the changes
      UpdateAllItems()

      -- Update the options display
      AceConfigRegistry:NotifyChange(addonName)
    end)

    -- Set initial state based on whitelist and expansion
    local expansionID = select(15, GetItemInfo(itemLink))
    local itemType = select(6, GetItemInfo(itemLink))
    local expansionMap = {
      [0] = "classic",
      [1] = "tbc",
      [2] = "wrath",
      [3] = "cata",
      [4] = "mop",
      [5] = "wod",
      [6] = "legion",
      [7] = "bfa",
      [8] = "sl",
      [9] = "df"
    }

    local expName = expansionMap[expansionID]
    local isWhitelisted = self.db.profile.whitelistedItems[itemName] or
        (expName and self.db.profile.whitelistedExpansions[expName]) or
        (itemName == hearthstoneName) or
        (itemType and self.db.profile.whitelistedItemTypes[itemType])

    -- Store references for later updates
    itemButton.itemLink = itemLink
    itemButton.itemName = itemName
    itemButton.itemType = itemType
    itemButton.expansionName = expName
    itemButton.UpdateAppearance = UpdateItemAppearance

    -- Update initial appearance
    UpdateItemAppearance(isWhitelisted)

    return itemButton
  end

  -- Populate inventory
  for bag = 0, 4 do
    local bagLabel = AceGUI:Create("Heading")
    local bagName = bag == 0 and "Backpack" or ("Bag " .. bag)
    bagLabel:SetText(bagName)
    bagLabel:SetFullWidth(true)
    scroll:AddChild(bagLabel)

    local bagContainer = AceGUI:Create("SimpleGroup")
    bagContainer:SetLayout("Flow")
    bagContainer:SetFullWidth(true)
    scroll:AddChild(bagContainer)

    for slot = 1, C_Container.GetContainerNumSlots(bag) do
      local itemLink = C_Container.GetContainerItemLink(bag, slot)
      if itemLink then
        local itemButton = CreateItemButton(bag, slot, itemLink)
        bagContainer:AddChild(itemButton)
      end
    end
  end

  -- Create a container for the purge button
  local buttonGroup = AceGUI:Create("SimpleGroup")
  buttonGroup:SetFullWidth(true)
  buttonGroup:SetLayout("Fill")
  buttonGroup:SetHeight(60) -- Reduced height
  frame:AddChild(buttonGroup)

  -- Add purge button
  local purgeButton = AceGUI:Create("Button")
  purgeButton:SetWidth(200) -- Previous width
  purgeButton:SetHeight(35) -- Keep height

  -- Set up the button
  purgeButton:SetText("Purge Non-Whitelisted Items")

  -- Set the button's font and style
  local buttonText = purgeButton.frame:GetFontString()
  buttonText:SetFont(GameFontNormalLarge:GetFont(), 13, "THICKOUTLINE")
  buttonText:SetTextColor(1, 1, 1, 1)
  buttonText:SetShadowColor(0, 0, 0, 1)
  buttonText:SetShadowOffset(2, -2)

  -- Add icon to button
  local icon = purgeButton.frame:CreateTexture(nil, "OVERLAY")
  icon:SetSize(40, 40)
  icon:SetPoint("LEFT", purgeButton.frame, "LEFT", 8, 0)
  icon:SetTexture("Interface\\Icons\\Spell_Nature_Purge")

  -- Adjust text position to account for icon
  buttonText:ClearAllPoints()
  buttonText:SetPoint("LEFT", icon, "RIGHT", 8, 0)
  buttonText:SetPoint("RIGHT", purgeButton.frame, "RIGHT", -8, 0)

  -- Add button to container and position it
  buttonGroup:AddChild(purgeButton)
  purgeButton.frame:ClearAllPoints()
  purgeButton.frame:SetPoint("CENTER", frame.content, "BOTTOM", 0, 60) -- Keep same position

  purgeButton:SetCallback("OnClick", function()
    -- Call PurgeBags directly
    PurgeMyBags:PurgeBags()
  end)

  -- Add hover effect and tooltip
  purgeButton:SetCallback("OnEnter", function()
    GameTooltip:SetOwner(purgeButton.frame, "ANCHOR_TOP")
    GameTooltip:AddLine("Purge Non-Whitelisted Items")
    GameTooltip:AddLine("Click to delete all items that aren't whitelisted", 1, 0.1, 0.1)
    GameTooltip:Show()
  end)
  purgeButton:SetCallback("OnLeave", function()
    GameTooltip:Hide()
  end)

  return frame
end

function PurgeMyBags:ShowInventoryBrowser()
  -- If we have a frame and it's shown, just hide it
  if self.inventoryFrame and self.inventoryFrame.frame and self.inventoryFrame.frame:IsShown() then
    self.inventoryFrame:Hide()
    return
  end

  -- If we have a frame but it's hidden or in an invalid state, clean it up
  if self.inventoryFrame then
    -- Only release if the frame exists and hasn't been released
    if self.inventoryFrame.frame and not self.inventoryFrame.released then
      self.inventoryFrame:Release()
    end
    self.inventoryFrame = nil
  end

  -- Create a new frame
  self.inventoryFrame = self:CreateInventoryBrowser()
end

function PurgeMyBags:SetupOptions()
  -- Initialize item types in defaults if not exists
  if not self.db.profile.whitelistedItemTypes then
    self.db.profile.whitelistedItemTypes = {
      Armor = true,
      Weapon = true,
      Consumable = true,
      Container = true,
      Reagent = true,
      Recipe = true,
      Gem = true,
      Glyph = true,
      Quest = true,
      Miscellaneous = true,
      TradeGoods = true
    }
  end

  self.options = {
    type = "group",
    name = "PurgeMyBags",
    handler = self,
    args = {
      description = {
        type = "description",
        name =
            "|cFFFFD100PurgeMyBags|r helps you clean up your bags by automatically deleting unwanted items while protecting items you want to keep.\n\n" ..
            "|cFFFFFFFFHow it works:|r\n" ..
            "• Items can be protected (whitelisted) in three ways:\n" ..
            "  1. By expansion (e.g. keep all Dragonflight items)\n" ..
            "  2. By item type (e.g. keep all Consumables)\n" ..
            "  3. Individually through the inventory browser\n\n" ..
            "• Use the inventory browser to visually manage your items\n" ..
            "• Items that aren't whitelisted will be marked for deletion\n" ..
            "• The purge button will only delete non-whitelisted items\n" ..
            "• A confirmation window will always show before deleting items\n\n",
        fontSize = "medium",
        order = 0.5
      },
      descriptionSpacer = {
        type = "description",
        name = "\n\n",
        order = 0.8
      },
      topButtonGroup = {
        type = "group",
        name = "",
        inline = true,
        order = 1,
        args = {
          leftPadding = {
            type = "description",
            name = "",
            width = 0.5,
            order = 1
          },
          openBrowser = {
            type = "execute",
            name = "Open Inventory Browser",
            desc = "Click to open the visual inventory browser",
            width = 1.3,
            func = function() self:ShowInventoryBrowser() end,
            order = 2
          },
          middlePadding = {
            type = "description",
            name = "",
            width = 0.4,
            order = 3
          },
          clearWhitelist = {
            type = "execute",
            name = "Clear All Whitelisted Items",
            desc = "Remove all items from the whitelist",
            width = 1.3,
            func = function()
              StaticPopupDialogs["PURGEMYBAGS_CLEAR_CONFIRM"] = {
                text =
                "Are you sure you want to clear all whitelisted items?\nThis will not affect expansion or item type settings.",
                button1 = "Yes",
                button2 = "No",
                OnAccept = function()
                  -- Clear the whitelist
                  wipe(self.db.profile.whitelistedItems)

                  -- Update the inventory browser if it's open
                  if self.inventoryFrame and self.inventoryFrame.frame and not self.inventoryFrame.released then
                    -- Force a refresh of the inventory browser
                    self.inventoryFrame.released = true
                    self.inventoryFrame:Release()
                    self.inventoryFrame = nil
                    C_Timer.After(0.1, function()
                      self.inventoryFrame = self:CreateInventoryBrowser()
                    end)
                  end

                  -- Notify the config registry of the change
                  AceConfigRegistry:NotifyChange(addonName)

                  print("|cFFFF0000PurgeMyBags:|r All individually whitelisted items have been cleared.")
                end,
                timeout = 0,
                whileDead = true,
                hideOnEscape = true,
                preferredIndex = 3,
              }
              StaticPopup_Show("PURGEMYBAGS_CLEAR_CONFIRM")
            end,
            order = 4
          },
          rightPadding = {
            type = "description",
            name = "",
            width = 0.5,
            order = 5
          }
        }
      },
      purgeButtonGroup = {
        type = "group",
        name = "",
        inline = true,
        order = 1.6,
        args = {
          leftPadding = {
            type = "description",
            name = "",
            width = 1,
            order = 1
          },
          purgeButton = {
            type = "execute",
            name = "Purge Non-Whitelisted Items",
            desc = "Click to delete all items that aren't whitelisted",
            width = 1.5,
            order = 2,
            func = function()
              StaticPopupDialogs["PURGEMYBAGS_CONFIRM"] = {
                text = "Are you sure you want to purge all non-whitelisted items?",
                button1 = "Yes",
                button2 = "No",
                OnAccept = function()
                  self:PurgeBags()
                end,
                timeout = 0,
                whileDead = true,
                hideOnEscape = true,
                showAlert = false,
                preferredIndex = 3,
                OnShow = function(self)
                  self.button1:SetScript("OnClick", function()
                    self.button1:SetPushedTextOffset(0, 0)
                    StaticPopupDialogs["PURGEMYBAGS_CONFIRM"].OnAccept()
                    self:Hide()
                  end)
                end
              }
              StaticPopup_Show("PURGEMYBAGS_CONFIRM")
            end
          },
          rightPadding = {
            type = "description",
            name = "",
            width = 1,
            order = 3
          }
        }
      },
      whitelistedItems = {
        type = "input",
        name = "Whitelisted Items",
        desc = "Enter item IDs or names, one per line",
        multiline = true,
        width = "full",
        get = function(info)
          local items = {}
          for item in pairs(self.db.profile.whitelistedItems) do
            table.insert(items, item)
          end
          return table.concat(items, "\n")
        end,
        set = function(info, value)
          wipe(self.db.profile.whitelistedItems)
          for line in value:gmatch("[^\r\n]+") do
            self.db.profile.whitelistedItems[line:trim()] = true
          end
        end,
        order = 2
      },
      expansions = {
        type = "group",
        name = "Whitelisted Expansions",
        inline = true,
        args = {
          checkAllExp = {
            type = "execute",
            name = "Check All Expansions",
            func = function()
              -- First, check all expansions
              for exp in pairs(self.db.profile.whitelistedExpansions) do
                self.db.profile.whitelistedExpansions[exp] = true
              end

              -- Then, scan bags and add items to individual whitelist
              for bag = 0, 4 do
                for slot = 1, C_Container.GetContainerNumSlots(bag) do
                  local itemLink = C_Container.GetContainerItemLink(bag, slot)
                  if itemLink then
                    local itemName = select(1, GetItemInfo(itemLink))
                    if itemName then
                      self.db.profile.whitelistedItems[itemName] = true
                    end
                  end
                end
              end

              -- Create new inventory browser to refresh all items
              if self.inventoryFrame then
                if self.inventoryFrame.frame and not self.inventoryFrame.released then
                  self.inventoryFrame.released = true
                  self.inventoryFrame:Release()
                end
                self.inventoryFrame = nil
                self.inventoryFrame = self:CreateInventoryBrowser()
              end

              -- Notify config of changes
              AceConfigRegistry:NotifyChange(addonName)
            end,
            order = 0.1
          },
          uncheckAllExp = {
            type = "execute",
            name = "Uncheck All Expansions",
            func = function()
              for exp in pairs(self.db.profile.whitelistedExpansions) do
                self.db.profile.whitelistedExpansions[exp] = false
              end
              -- Refresh inventory browser
              if self.inventoryFrame and self.inventoryFrame.frame and not self.inventoryFrame.released then
                self.inventoryFrame.released = true
                self.inventoryFrame:Release()
                self.inventoryFrame = nil
                C_Timer.After(0.1, function()
                  self.inventoryFrame = self:CreateInventoryBrowser()
                end)
              end
            end,
            order = 0.2,
            image = nil -- Remove icon
          },
          spacer1 = {
            type = "description",
            name = "\n",
            order = 0.3
          },
          classic = {
            type = "toggle",
            name = "Classic",
            get = function(info) return self.db.profile.whitelistedExpansions.classic end,
            set = function(info, value)
              self.db.profile.whitelistedExpansions.classic = value
              -- Refresh inventory browser
              if self.inventoryFrame and self.inventoryFrame.frame and not self.inventoryFrame.released then
                self.inventoryFrame.released = true
                self.inventoryFrame:Release()
                self.inventoryFrame = nil
                C_Timer.After(0.1, function()
                  self.inventoryFrame = self:CreateInventoryBrowser()
                end)
              end
            end,
            order = 1
          },
          tbc = {
            type = "toggle",
            name = "The Burning Crusade",
            get = function(info) return self.db.profile.whitelistedExpansions.tbc end,
            set = function(info, value) self.db.profile.whitelistedExpansions.tbc = value end,
            order = 2
          },
          wrath = {
            type = "toggle",
            name = "Wrath of the Lich King",
            get = function(info) return self.db.profile.whitelistedExpansions.wrath end,
            set = function(info, value) self.db.profile.whitelistedExpansions.wrath = value end,
            order = 3
          },
          cata = {
            type = "toggle",
            name = "Cataclysm",
            get = function(info) return self.db.profile.whitelistedExpansions.cata end,
            set = function(info, value) self.db.profile.whitelistedExpansions.cata = value end,
            order = 4
          },
          mop = {
            type = "toggle",
            name = "Mists of Pandaria",
            get = function(info) return self.db.profile.whitelistedExpansions.mop end,
            set = function(info, value) self.db.profile.whitelistedExpansions.mop = value end,
            order = 5
          },
          wod = {
            type = "toggle",
            name = "Warlords of Draenor",
            get = function(info) return self.db.profile.whitelistedExpansions.wod end,
            set = function(info, value) self.db.profile.whitelistedExpansions.wod = value end,
            order = 6
          },
          legion = {
            type = "toggle",
            name = "Legion",
            get = function(info) return self.db.profile.whitelistedExpansions.legion end,
            set = function(info, value) self.db.profile.whitelistedExpansions.legion = value end,
            order = 7
          },
          bfa = {
            type = "toggle",
            name = "Battle for Azeroth",
            get = function(info) return self.db.profile.whitelistedExpansions.bfa end,
            set = function(info, value) self.db.profile.whitelistedExpansions.bfa = value end,
            order = 8
          },
          sl = {
            type = "toggle",
            name = "Shadowlands",
            get = function(info) return self.db.profile.whitelistedExpansions.sl end,
            set = function(info, value) self.db.profile.whitelistedExpansions.sl = value end,
            order = 9
          },
          df = {
            type = "toggle",
            name = "Dragonflight",
            get = function(info) return self.db.profile.whitelistedExpansions.df end,
            set = function(info, value) self.db.profile.whitelistedExpansions.df = value end,
            order = 10
          }
        },
        order = 3
      },
      itemTypes = {
        type = "group",
        name = "Whitelisted Item Types",
        inline = true,
        args = {
          checkAllTypes = {
            type = "execute",
            name = "Check All Types",
            desc = "Check all item types and add current items to whitelist",
            width = 1.3,
            func = function()
              -- First, check all types
              for itemType in pairs(self.db.profile.whitelistedItemTypes) do
                self.db.profile.whitelistedItemTypes[itemType] = true
              end

              -- Then, scan bags and add items to individual whitelist
              for bag = 0, 4 do
                for slot = 1, C_Container.GetContainerNumSlots(bag) do
                  local itemLink = C_Container.GetContainerItemLink(bag, slot)
                  if itemLink then
                    local itemName = select(1, GetItemInfo(itemLink))
                    if itemName then
                      self.db.profile.whitelistedItems[itemName] = true
                    end
                  end
                end
              end

              -- Create new inventory browser to refresh all items
              if self.inventoryFrame then
                if self.inventoryFrame.frame and not self.inventoryFrame.released then
                  self.inventoryFrame.released = true
                  self.inventoryFrame:Release()
                end
                self.inventoryFrame = nil
                self.inventoryFrame = self:CreateInventoryBrowser()
              end

              -- Notify config of changes
              AceConfigRegistry:NotifyChange(addonName)
            end,
            order = 0.1
          },
          uncheckAllTypes = {
            type = "execute",
            name = "Uncheck All Types",
            desc = "Uncheck all item types",
            width = 1.3,
            func = function()
              for itemType in pairs(self.db.profile.whitelistedItemTypes) do
                self.db.profile.whitelistedItemTypes[itemType] = false
              end
              -- Refresh inventory browser
              if self.inventoryFrame then
                if self.inventoryFrame.frame and not self.inventoryFrame.released then
                  self.inventoryFrame.released = true
                  self.inventoryFrame:Release()
                end
                self.inventoryFrame = nil
                self.inventoryFrame = self:CreateInventoryBrowser()
              end
            end,
            order = 0.2
          },
          spacer1 = {
            type = "description",
            name = "\n",
            order = 0.3
          },
          armor = {
            type = "toggle",
            name = "Armor",
            get = function(info) return self.db.profile.whitelistedItemTypes.Armor end,
            set = function(info, value)
              self.db.profile.whitelistedItemTypes.Armor = value
              -- Refresh inventory browser
              if self.inventoryFrame and self.inventoryFrame.frame and not self.inventoryFrame.released then
                self.inventoryFrame.released = true
                self.inventoryFrame:Release()
                self.inventoryFrame = nil
                C_Timer.After(0.1, function()
                  self.inventoryFrame = self:CreateInventoryBrowser()
                end)
              end
            end,
            order = 1
          },
          weapon = {
            type = "toggle",
            name = "Weapons",
            get = function(info) return self.db.profile.whitelistedItemTypes.Weapon end,
            set = function(info, value) self.db.profile.whitelistedItemTypes.Weapon = value end,
            order = 2
          },
          consumable = {
            type = "toggle",
            name = "Consumables",
            get = function(info) return self.db.profile.whitelistedItemTypes.Consumable end,
            set = function(info, value) self.db.profile.whitelistedItemTypes.Consumable = value end,
            order = 3
          },
          container = {
            type = "toggle",
            name = "Containers",
            get = function(info) return self.db.profile.whitelistedItemTypes.Container end,
            set = function(info, value) self.db.profile.whitelistedItemTypes.Container = value end,
            order = 4
          },
          reagent = {
            type = "toggle",
            name = "Reagents",
            get = function(info) return self.db.profile.whitelistedItemTypes.Reagent end,
            set = function(info, value) self.db.profile.whitelistedItemTypes.Reagent = value end,
            order = 5
          },
          recipe = {
            type = "toggle",
            name = "Recipes",
            get = function(info) return self.db.profile.whitelistedItemTypes.Recipe end,
            set = function(info, value) self.db.profile.whitelistedItemTypes.Recipe = value end,
            order = 6
          },
          gem = {
            type = "toggle",
            name = "Gems",
            get = function(info) return self.db.profile.whitelistedItemTypes.Gem end,
            set = function(info, value) self.db.profile.whitelistedItemTypes.Gem = value end,
            order = 7
          },
          glyph = {
            type = "toggle",
            name = "Glyphs",
            get = function(info) return self.db.profile.whitelistedItemTypes.Glyph end,
            set = function(info, value) self.db.profile.whitelistedItemTypes.Glyph = value end,
            order = 8
          },
          quest = {
            type = "toggle",
            name = "Quest Items",
            get = function(info) return self.db.profile.whitelistedItemTypes.Quest end,
            set = function(info, value) self.db.profile.whitelistedItemTypes.Quest = value end,
            order = 9
          },
          tradegoods = {
            type = "toggle",
            name = "Trade Goods",
            get = function(info) return self.db.profile.whitelistedItemTypes.TradeGoods end,
            set = function(info, value) self.db.profile.whitelistedItemTypes.TradeGoods = value end,
            order = 10
          },
          misc = {
            type = "toggle",
            name = "Miscellaneous",
            get = function(info) return self.db.profile.whitelistedItemTypes.Miscellaneous end,
            set = function(info, value) self.db.profile.whitelistedItemTypes.Miscellaneous = value end,
            order = 11
          }
        },
        order = 4
      },
      spacer = {
        type = "description",
        name = "\n\n\n",
        order = 98
      }
    }
  }

  -- Register with both systems
  LibStub("AceConfig-3.0"):RegisterOptionsTable(addonName, self.options)
  LibStub("AceConfigDialog-3.0"):AddToBlizOptions(addonName, "PurgeMyBags")

  -- Create and register About section
  local aboutOptions = {
    type = "group",
    name = "About",
    args = {
      aboutText = {
        type = "description",
        name =
            "|cFFFFD100PurgeMyBags|r helps you clean up your bags by automatically deleting unwanted items while protecting items you want to keep.\n\n" ..
            "|cFFFFFFFFHow it works:|r\n" ..
            "• Items can be protected (whitelisted) in three ways:\n" ..
            "  1. By expansion (e.g. keep all Dragonflight items)\n" ..
            "  2. By item type (e.g. keep all Consumables)\n" ..
            "  3. Individually through the inventory browser\n\n" ..
            "• Use the inventory browser to visually manage your items\n" ..
            "• Items that aren't whitelisted will be marked for deletion\n" ..
            "• The purge button will only delete non-whitelisted items\n" ..
            "• A confirmation window will always show before deleting items\n\n" ..
            "|cFFFFD100Created by:|r |cFFFFFFFF@JustNeph|r\n" ..
            "|cFFFFD100Development:|r |cFFFFFFFFMade with |cFF00A5FFCursor|r |cFFFFFFFF(|cFF00A5FFhttps://cursor.sh|r)|r",
        fontSize = "medium",
        order = 1
      }
    }
  }

  LibStub("AceConfig-3.0"):RegisterOptionsTable(addonName .. "_About", aboutOptions)
  LibStub("AceConfigDialog-3.0"):AddToBlizOptions(addonName .. "_About", "About", "PurgeMyBags")
end

-- Get the Hearthstone name for whitelisting
local hearthstoneName = select(1, GetItemInfo(6948))

function PurgeMyBags:PurgeBags()
  local deletedItems = {}
  local totalDeleted = 0
  local needsRefresh = false

  -- Store the current frame reference
  local currentFrame = self.inventoryFrame
  self.inventoryFrame = nil -- Clear the reference before purging

  -- Gather items to delete first
  local itemsToDelete = {}
  for bag = 0, 4 do
    for slot = 1, C_Container.GetContainerNumSlots(bag) do
      local itemLink = C_Container.GetContainerItemLink(bag, slot)
      if itemLink then
        local itemLocation = ItemLocation:CreateFromBagAndSlot(bag, slot)
        local itemID = C_Item.GetItemID(itemLocation)
        local itemName = select(1, GetItemInfo(itemLink))
        local expansionID = select(15, GetItemInfo(itemLink))
        local itemType = select(6, GetItemInfo(itemLink))

        -- Map numeric expansion IDs to our named ones
        local expansionMap = {
          [0] = "classic",
          [1] = "tbc",
          [2] = "wrath",
          [3] = "cata",
          [4] = "mop",
          [5] = "wod",
          [6] = "legion",
          [7] = "bfa",
          [8] = "sl",
          [9] = "df"
        }

        -- Check if item should be whitelisted
        local expName = expansionMap[expansionID]
        local shouldWhitelist = self.db.profile.whitelistedItems[itemName] or
            (expName and self.db.profile.whitelistedExpansions[expName]) or
            (itemName == hearthstoneName) or
            (itemType and self.db.profile.whitelistedItemTypes[itemType])

        if not shouldWhitelist then
          table.insert(itemsToDelete, { bag = bag, slot = slot, itemLink = itemLink })
          table.insert(deletedItems, itemLink)
          totalDeleted = totalDeleted + 1
          needsRefresh = true
        end
      end
    end
  end

  -- If no items to delete, just return
  if totalDeleted == 0 then
    self.inventoryFrame = currentFrame
    print("|cFFFF0000PurgeMyBags:|r No items to delete.")
    return
  end

  -- Build confirmation message
  local itemCounts = {}
  for _, itemLink in ipairs(deletedItems) do
    itemCounts[itemLink] = (itemCounts[itemLink] or 0) + 1
  end

  local confirmMessage = "Delete the following items?\n\n"
  for itemLink, count in pairs(itemCounts) do
    if count > 1 then
      confirmMessage = confirmMessage .. itemLink .. " x" .. count .. "\n"
    else
      confirmMessage = confirmMessage .. itemLink .. "\n"
    end
  end

  -- Create and show confirmation dialog
  StaticPopupDialogs["PURGEMYBAGS_DELETE_CONFIRM"] = {
    text = confirmMessage,
    button1 = "Yes",
    button2 = "No",
    OnAccept = function()
      -- Process items one by one
      local currentIndex = 1
      local function ProcessNextItem()
        if currentIndex <= #itemsToDelete then
          local item = itemsToDelete[currentIndex]
          -- Pick up the item and immediately delete it to trigger WoW's deletion dialog
          C_Container.PickupContainerItem(item.bag, item.slot)
          if CursorHasItem() then
            DeleteCursorItem()
          end
          currentIndex = currentIndex + 1
          -- Wait longer between items to allow for the deletion dialog
          C_Timer.After(0.5, ProcessNextItem)
        else
          -- All items processed, refresh the frame
          C_Timer.After(1.0, function()
            if currentFrame and currentFrame.frame and not currentFrame.released then
              currentFrame.released = true
              currentFrame:Release()
              self.inventoryFrame = self:CreateInventoryBrowser()
            end
          end)
        end
      end
      ProcessNextItem()
    end,
    OnCancel = function()
      self.inventoryFrame = currentFrame
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
    wide = true,
    showAlert = true
  }
  StaticPopup_Show("PURGEMYBAGS_DELETE_CONFIRM")
end

function PurgeMyBags:BAG_UPDATE(event, bagID)
  if self.pendingRefresh then
    self.pendingRefresh = self.pendingRefresh - 1
    if self.pendingRefresh <= 0 then
      self.pendingRefresh = nil
      if self.inventoryFrame and self.inventoryFrame.frame and not self.inventoryFrame.released then
        self.inventoryFrame.released = true
        self.inventoryFrame:Release()
        self.inventoryFrame = nil
        C_Timer.After(0.5, function()
          self.inventoryFrame = self:CreateInventoryBrowser()
        end)
      end
    end
  end
end
