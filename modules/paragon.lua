-- Aethro Paragon numbers for the [paragon] tag.
-- Same limits as TipTac: hook 1 is you, hook 6 is the current target only.
-- Tag and options are registered only while AethroParagon is loaded.
local Paragon = {}
local cache = {}
local taggedFrames = {}
local requestedSelf
local requestedTargetGUID
local hookedSelf, hookedTarget
local tagRegistered

ShadowUF.Paragon = Paragon

local function IsAethroParagonLoaded()
	return IsAddOnLoaded("AethroParagon")
end

local function IsPlayerUnit(unit)
	return unit and UnitExists(unit) and UnitIsPlayer(unit)
end

local function CacheLevel(unit, level)
	level = tonumber(level)
	if( not level or level <= 0 or not unit ) then
		return
	end

	local guid = UnitGUID(unit)
	local name = UnitName(unit)
	if( guid ) then
		cache[guid] = level
	end
	if( name ) then
		cache[name] = level
	end

	return level
end

local function ReadPortrait(unit)
	if( UnitIsUnit(unit, "player") ) then
		if( ParagonCharacterLevel and ParagonCharacterLevel.Text ) then
			return CacheLevel("player", ParagonCharacterLevel.Text:GetText())
		end
	elseif( UnitIsUnit(unit, "target") and IsPlayerUnit("target") and ParagonTargetLevel and ParagonTargetLevel.Text ) then
		if( ParagonTargetLevel.lastTargetGUID == UnitGUID(unit) and ParagonTargetLevel:GetAlpha() > 0 ) then
			return CacheLevel("target", ParagonTargetLevel.Text:GetText())
		end
	end
end

function Paragon:GetLevel(unit)
	if( not IsAethroParagonLoaded() or not IsPlayerUnit(unit) ) then
		return
	end

	return cache[UnitGUID(unit) or ""] or cache[UnitName(unit) or ""] or ReadPortrait(unit)
end

function Paragon:GetLevelText(unit, wrap)
	local level = self:GetLevel(unit)
	if( not level ) then
		return
	end
	if( wrap ) then
		return "(" .. tostring(level) .. ")"
	end
	return tostring(level)
end

function Paragon:RequestIfNeeded(unit)
	if( not IsAethroParagonLoaded() or not IsPlayerUnit(unit) or not SendClientRequest ) then
		return
	end
	if( self:GetLevel(unit) ) then
		return
	end

	if( UnitIsUnit(unit, "player") ) then
		if( not requestedSelf ) then
			requestedSelf = true
			SendClientRequest("ParagonAnniversary", 1)
		end
	elseif( UnitIsUnit(unit, "target") ) then
		local guid = UnitGUID(unit)
		if( guid and requestedTargetGUID ~= guid ) then
			requestedTargetGUID = guid
			SendClientRequest("ParagonAnniversary", 6)
		end
	end
end

function Paragon:UpdateTaggedFrames()
	if( not tagRegistered ) then
		return
	end

	for frame in pairs(taggedFrames) do
		if( frame.fontStrings ) then
			for _, fontString in pairs(frame.fontStrings) do
				if( fontString.PARAGON and fontString.UpdateTags ) then
					fontString:UpdateTags()
				end
			end
		end
	end
end

function Paragon:EnableTag(frame)
	if( not self:RegisterTag() ) then
		return
	end

	taggedFrames[frame] = true
	frame.hasParagonTag = true
	self:EnsureHooks()
	self:RequestIfNeeded(frame.unitOwner or frame.unit)
end

function Paragon:DisableTag(frame)
	if( frame.fontStrings ) then
		for _, fontString in pairs(frame.fontStrings) do
			if( fontString.PARAGON ) then
				return
			end
		end
	end

	frame.hasParagonTag = nil
	taggedFrames[frame] = nil
end

function Paragon:EnsureHooks()
	if( not IsAethroParagonLoaded() ) then
		return
	end

	if( not hookedSelf and UIParagon_OnClientReceiveLevel ) then
		hooksecurefunc("UIParagon_OnClientReceiveLevel", function(_, arg_table)
			CacheLevel("player", arg_table and arg_table[1])
			Paragon:UpdateTaggedFrames()
		end)
		hookedSelf = true
	end

	if( not hookedTarget and UIParagon_OnReceiveTargetLevel ) then
		hooksecurefunc("UIParagon_OnReceiveTargetLevel", function(_, arg_table)
			if( IsPlayerUnit("target") ) then
				CacheLevel("target", arg_table and arg_table[1])
			end
			Paragon:UpdateTaggedFrames()
		end)
		hookedTarget = true
	end
end

function Paragon:RegisterTag()
	if( tagRegistered ) then
		return true
	end
	if( not IsAethroParagonLoaded() ) then
		return
	end

	local Tags = ShadowUF.Tags
	local L = ShadowUF.L
	Tags.customEvents["PARAGON"] = Paragon
	Tags.defaultTags["paragon"] = [[function(unit, unitOwner)
		local Paragon = ShadowUF.Paragon
		if( not Paragon ) then return nil end
		Paragon:RequestIfNeeded(unitOwner)
		return Paragon:GetLevelText(unitOwner)
	end]]
	Tags.defaultTags["paragon()"] = [[function(unit, unitOwner)
		local Paragon = ShadowUF.Paragon
		if( not Paragon ) then return nil end
		Paragon:RequestIfNeeded(unitOwner)
		return Paragon:GetLevelText(unitOwner, true)
	end]]
	Tags.defaultEvents["paragon"] = "PARAGON PLAYER_TARGET_CHANGED"
	Tags.defaultEvents["paragon()"] = "PARAGON PLAYER_TARGET_CHANGED"
	Tags.defaultCategories["paragon"] = "classification"
	Tags.defaultCategories["paragon()"] = "classification"
	Tags.defaultHelp["paragon"] = L["Shows the units Aethro Paragon level if it is known. Only shown for players, not NPCs or mobs. Yourself and the current target are requested from the server. Other players only show a number if you have targeted them before."]
	Tags.defaultHelp["paragon()"] = L["Same as [paragon], but wraps the number in parentheses, for example (12). Only shown for players."]
	Tags.defaultNames["paragon"] = L["Paragon"]
	Tags.defaultNames["paragon()"] = L["Paragon (parentheses)"]

	if( ShadowUF.tagFunc ) then
		ShadowUF.tagFunc["paragon"] = nil
		ShadowUF.tagFunc["paragon()"] = nil
	end

	tagRegistered = true
	self:EnsureHooks()
	return true
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, event, addon)
	if( event == "ADDON_LOADED" and addon ~= "AethroParagon" ) then
		return
	end

	if( Paragon:RegisterTag() and event == "ADDON_LOADED" and ShadowUF.Tags.Reload ) then
		ShadowUF.Tags:Reload()
	end

	if( event == "PLAYER_LOGIN" ) then
		self:UnregisterEvent("PLAYER_LOGIN")
	elseif( event == "ADDON_LOADED" ) then
		self:UnregisterEvent("ADDON_LOADED")
	end
end)

Paragon:RegisterTag()
