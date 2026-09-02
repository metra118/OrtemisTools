local addonName, ns = ...

if select(2, UnitClass("player")) ~= "MONK" then return end

local RSK = {}
ns.RisingSunKick = RSK

local anchorFrame = CreateFrame("FRAME", nil, ns.ballsAnchor)
anchorFrame:SetClampedToScreen(true)

local spellID = 178341
local bgAtlas = "uf-chi-bg"
local iconTexture = "Interface\\AddOns\\OrtemisTools\\RisingSunKick\\RSK_texture"
local iconX = 0
local iconY = 5

local dSize = 50
local iconSize = 32
local bar
local isEditing = false
local eventFrame

bar = CreateFrame("StatusBar", nil, anchorFrame)
bar:SetSize(dSize, dSize)
-- Fill when at least one charge is available (SetValue accepts secret currentCharges).
bar:SetMinMaxValues(0.5, 1, Enum.StatusBarInterpolation.Immediate)
bar:SetStatusBarTexture("")
local barTex = bar:GetStatusBarTexture()
barTex:SetAtlas(bgAtlas)
bar.icon = CreateFrame("StatusBar", nil, bar)
bar.icon:SetSize(iconSize, iconSize)
bar.icon:SetPoint("CENTER", iconX, iconY)
bar.icon:SetMinMaxValues(0.5, 1, Enum.StatusBarInterpolation.Immediate)
bar.icon:SetStatusBarTexture("")
local iconTex = bar.icon:GetStatusBarTexture()
iconTex:SetTexture(iconTexture)


local function updateBars(readyValue)
	bar:SetValue(readyValue)
	bar.icon:SetValue(readyValue)
end


-- Show the orb when Rising Sun Kick is usable (not on its own cooldown).
-- Prefer charges: isActive is NeverSecret and means a charge is regenerating;
-- currentCharges may be secret, so it is only passed into SetValue.
-- Fall back to GetSpellCooldown.isActive when the spell has no charge data.
local function updateFromCooldown()
	if isEditing then return end

	local chargeInfo = C_Spell.GetSpellCharges(spellID)
	if chargeInfo then
		updateBars(chargeInfo.currentCharges)
		return
	end

	local cd = C_Spell.GetSpellCooldown(spellID)
	if not cd then
		updateBars(0)
		return
	end

	-- isActive / isOnGCD are NeverSecret. Treat GCD-only as ready so the orb
	-- stays up between casts of other abilities while RSK itself is available.
	local ready = not cd.isActive or cd.isOnGCD
	updateBars(ready and 1 or 0)
end


local function refresh()
	if OrtemisToolsDB.risingSunKick.enabled == false then
		bar:Hide()
		if eventFrame then eventFrame:UnregisterAllEvents() end
		return
	end

	if isEditing then
		bar:Show()
		updateBars(1)
		return
	end

	local show = C_SpecializationInfo.GetSpecialization() == 2
	if not show then
		bar:Hide()
		if eventFrame then eventFrame:UnregisterAllEvents() end
		return
	end

	if eventFrame then
		eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
		eventFrame:RegisterEvent("SPELL_UPDATE_CHARGES")
		eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
		eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
		eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
	end

	local inCombat = UnitAffectingCombat("player")
	bar:SetShown(inCombat)
	if inCombat then
		updateFromCooldown()
	end
end

RSK.refresh = refresh


local function updateLayout(self)
	local size = self.db.size
	local scale = size / dSize

	bar:SetScale(scale)
	bar.icon:SetSize(self.db.iconSize, self.db.iconSize)
	bar:ClearAllPoints()
	bar:SetPoint("BOTTOM", 0, 15)

	self:SetSize(size + 10, size + 30)
	self:ClearAllPoints()
	self:SetPoint("CENTER", self.db.xOffset, self.db.yOffset)
end

RSK.updateLayout = function() updateLayout(anchorFrame) end


local function init(self)
	OrtemisToolsDB.risingSunKick = OrtemisToolsDB.risingSunKick or {}
	self.db = OrtemisToolsDB.risingSunKick
	local db = self.db
	db.size = db.size or 30
	db.iconSize = db.iconSize or 32
	db.xOffset = db.xOffset or 0
	db.yOffset = db.yOffset or 48
end


C_Timer.After(0, function()
	init(anchorFrame)
	updateLayout(anchorFrame)

	eventFrame = CreateFrame("Frame")
	eventFrame:SetScript("OnEvent", function(self, event, a1, a2, a3)
		if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
			refresh()
			return
		end
		-- Cast may report the base ability (107428) rather than 178341.
		if event == "UNIT_SPELLCAST_SUCCEEDED" and a3 ~= spellID and a3 ~= 107428 then return end
		updateFromCooldown()
	end)

	refresh()

	local lem = LibStub("LibEditMode")
	lem:RegisterCallback("layout", function()
		updateLayout(anchorFrame)
	end)

	lem:RegisterCallback("enter", function()
		isEditing = true
		bar:Show()
		updateBars(1)
	end)

	lem:RegisterCallback("exit", function()
		isEditing = false
		refresh()
	end)
end)
