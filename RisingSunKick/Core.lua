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
local bar, barFrame
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


local function getBar(category)
	local cooldownIDs = C_CooldownViewer.GetCooldownViewerCategorySet(category, false)
	for i, cooldownID in ipairs(cooldownIDs) do
		local cooldownInfo = C_CooldownViewer.GetCooldownViewerCooldownInfo(cooldownID)
		if cooldownInfo.spellID == spellID then
			return cooldownID
		end
	end
end


local function findAndHookViewer(viewer, cdID)
	if not viewer or not viewer.itemFramePool then return end

	for f in viewer.itemFramePool:EnumerateActive() do
		if f._RisingSunKick then
			f.SetAlpha = nil
			f._RisingSunKick = nil
			f:SetAlpha(1)
		end
		if f.cooldownID == cdID then
			barFrame = f
		end
	end
end


local function refreshHooks()
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

	barFrame = nil
	local cdID = getBar(Enum.CooldownViewerCategory.Essential)
		or getBar(Enum.CooldownViewerCategory.Utility)
		or getBar(Enum.CooldownViewerCategory.TrackedBuff)
		or getBar(Enum.CooldownViewerCategory.TrackedBar)

	findAndHookViewer(EssentialCooldownViewer, cdID)
	findAndHookViewer(UtilityCooldownViewer, cdID)
	findAndHookViewer(BuffIconCooldownViewer, cdID)
	findAndHookViewer(BuffBarCooldownViewer, cdID)

	local show = C_SpecializationInfo.GetSpecialization() == 2
	bar:SetShown(show)
	if not show then
		if eventFrame then eventFrame:UnregisterAllEvents() end
		return
	end

	if eventFrame then
		eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
		eventFrame:RegisterEvent("SPELL_UPDATE_CHARGES")
		eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
	end

	if barFrame then
		local alpha = anchorFrame.db.hideDefault and 0 or 1
		barFrame._RisingSunKick = true
		barFrame:SetAlpha(alpha)

		local setAlpha = getmetatable(barFrame).__index.SetAlpha
		hooksecurefunc(barFrame, "SetAlpha", function(self)
			setAlpha(self, alpha)
		end)
	end

	updateFromCooldown()
end

RSK.refresh = refreshHooks


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
	if db.hideDefault == nil then db.hideDefault = true end
	db.size = db.size or 30
	db.iconSize = db.iconSize or 32
	db.xOffset = db.xOffset or 0
	db.yOffset = db.yOffset or 48
end


C_Timer.After(0, function()
	init(anchorFrame)

	eventFrame = CreateFrame("Frame")
	eventFrame:SetScript("OnEvent", function(self, event, a1, a2, a3)
		-- Cast may report the base ability (107428) rather than 178341.
		if event == "UNIT_SPELLCAST_SUCCEEDED" and a3 ~= spellID and a3 ~= 107428 then return end
		updateFromCooldown()
	end)

	local function hookViewer(viewer)
		if viewer then
			hooksecurefunc(viewer, "RefreshLayout", refreshHooks)
		end
	end
	hookViewer(EssentialCooldownViewer)
	hookViewer(UtilityCooldownViewer)
	hookViewer(BuffIconCooldownViewer)
	hookViewer(BuffBarCooldownViewer)
	refreshHooks()

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
		refreshHooks()
	end)
end)
