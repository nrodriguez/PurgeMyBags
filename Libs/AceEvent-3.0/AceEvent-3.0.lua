--- AceEvent-3.0 provides event registration and secure event dispatching.
-- All dispatching is done using **CallbackHandler-1.0**. AceEvent is a simple wrapper around
-- CallbackHandler, and dispatches all game events or addon message to the registrees.
-- @class file
-- @name AceEvent-3.0
-- @release $Id: AceEvent-3.0.lua 1202 2019-05-15 23:11:22Z nevcairiel $
local MAJOR, MINOR = "AceEvent-3.0", 4
local AceEvent = LibStub:NewLibrary(MAJOR, MINOR)

if not AceEvent then return end -- No upgrade needed

-- Lua APIs
local pairs = pairs

local CallbackHandler = LibStub:GetLibrary("CallbackHandler-1.0")

AceEvent.frame = AceEvent.frame or CreateFrame("Frame", "AceEvent30Frame") -- our event frame
AceEvent.embeds = AceEvent.embeds or {}                                    -- what objects embed this lib

-- APIs and registry for blizzard events, using CallbackHandler lib
if not AceEvent.events then
  AceEvent.events = CallbackHandler:New(AceEvent,
    "RegisterEvent", "UnregisterEvent",
    "RegisterMessage", "UnregisterMessage",
    "UnregisterAllEvents")
end

function AceEvent:OnEmbedDisable(target)
  target:UnregisterAllEvents()
  target:UnregisterAllMessages()
end

function AceEvent:PLAYER_ENTERING_WORLD()
  self.frame:UnregisterEvent("PLAYER_ENTERING_WORLD")
  self.frame:RegisterEvent("PLAYER_LEAVING_WORLD")
  self.playerLoginFired = true

  -- fire a custom event that tells the addons that use AceEvent-3.0 that they should recheck their event registrations
  -- this event will only fire once (unless the addon explicitly registers it)
  self.events:Fire("PLAYER_LOGIN")
end

function AceEvent:PLAYER_LEAVING_WORLD()
  self.frame:UnregisterEvent("PLAYER_LEAVING_WORLD")
  self.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
  self.playerLoginFired = false
end

--- Register for a Blizzard Event.
-- The callback will be called with the optional argument as the first argument (if supplied), and the event arguments after that
-- @param event The event to register for
-- @param callback The callback function to call when the event is triggered (funcref or method, defaults to a method with the event name)
-- @param arg An optional argument to pass to the callback function
function AceEvent:RegisterEvent(event, callback, arg)
  return self.events:RegisterEvent(event, callback, arg)
end

--- Unregister an event.
-- @param event The event to unregister from
function AceEvent:UnregisterEvent(event)
  return self.events:UnregisterEvent(event)
end

--- Register a Message.
-- @name AceEvent:RegisterMessage
-- @class function
-- @paramsig message[, callback [, arg]]
-- @param message The message to register for
-- @param callback The callback function to call when the message is triggered (funcref or method, defaults to a method with the event name)
-- @param arg An optional argument to pass to the callback function
function AceEvent:RegisterMessage(message, callback, arg)
  return self.events:RegisterMessage(message, callback, arg)
end

--- Unregister a Message
-- @name AceEvent:UnregisterMessage
-- @class function
-- @paramsig message
-- @param message The message to unregister
function AceEvent:UnregisterMessage(message)
  return self.events:UnregisterMessage(message)
end

--- Unregister all events.
function AceEvent:UnregisterAllEvents()
  return self.events:UnregisterAllEvents()
end

--- Unregister all messages.
-- @name AceEvent:UnregisterAllMessages
-- @class function
function AceEvent:UnregisterAllMessages()
  return self.events:UnregisterAllMessages()
end

--- Send a message over the AceEvent-3.0 event system to other addons registered for this message.
-- @name AceEvent:SendMessage
-- @class function
-- @paramsig message[, ...]
-- @param message The message to send
-- @param ... Any arguments to the message
function AceEvent:SendMessage(message, ...)
  return self.events:Fire(message, ...)
end

-- Embed AceEvent into the target object making the functions from the mixins list available on target:..
-- @param target target object to embed AceEvent in
function AceEvent:Embed(target)
  for k, v in pairs(self.embeds) do
    target[k] = v
  end
  self.embeds[target] = true
  return target
end

-- AceEvent can be embedded into your addon, either explicitly by calling AceEvent:Embed(target) or by
-- specifying it as an embeddable lib in your AceAddon. All functions will be available on target:..
-- @class table
-- @name AceEvent:Embed
-- @field RegisterEvent
-- @field UnregisterEvent
-- @field UnregisterAllEvents
AceEvent:Embed(AceEvent) -- Embed AceEvent in itself, making it possible to just :RegisterEvent directly

-- Register the frame for receiving events
AceEvent.frame:SetScript("OnEvent", function(self, event, ...)
  AceEvent.events:Fire(event, ...)
end)

-- Register our name in the global scope
_G.AceEvent = AceEvent
