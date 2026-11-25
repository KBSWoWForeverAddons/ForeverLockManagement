local _, FLM = ...
if not FLM or not FLM.isWarlock then
    return
end

local BACKDROP_ALERT = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 2,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
}

local ICON_SIZE = 44
local ICON_GAP = 8

local CREATURE_TYPES = {
    Demon       = "DEMON",
    Elemental   = "ELEMENTAL",
    ["Démon"]   = "DEMON",
    ["Élémentaire"] = "ELEMENTAL",
    ["Dämon"]   = "DEMON",
    ["Elementar"] = "ELEMENTAL",
    ["Demonio"] = "DEMON",
    ["Демон"]   = "DEMON",
    ["Элементаль"] = "ELEMENTAL",
}

local warningsAnchor
local dragHeader
local alertFrames = {}
local testMode = false

local ALERT_DEFS = {
    {
        key = "antiFear",
        icon = "Interface\\Icons\\Spell_Shadow_Possession",
        borderColor = { 0.95, 0.22, 0.22, 1.0 },
        label = "FEAR IMMUNE",
        soundID = 8959, -- RaidWarning
    },
    {
        key = "shadowTrance",
        icon = "Interface\\Icons\\Spell_Shadow_Twilight",
        borderColor = { 0.78, 0.35, 1.00, 1.0 },
        label = "NIGHTFALL",
        soundID = 12867,
    },
    {
        key = "backlash",
        icon = "Interface\\Icons\\Spell_Fire_PlayingWithFire",
        borderColor = { 1.00, 0.55, 0.15, 1.0 },
        label = "BACKLASH",
        soundID = 12867,
    },
    {
        key = "creatureAlert",
        icon = "Interface\\Icons\\Spell_Shadow_Cripple",
        borderColor = { 0.25, 0.92, 0.45, 1.0 },
        label = "BANISHABLE",
        soundID = nil,
    },
}

local function PlayAlertSound(soundID)
    if not FLM.db or not FLM.db.warnings.sound or not soundID then
        return
    end
    if PlaySound then
        pcall(PlaySound, soundID, "Master")
    end
end

local function CreateAlertIcon(def)
    local f = CreateFrame("Frame", nil, warningsAnchor, "BackdropTemplate")
    f:SetSize(ICON_SIZE, ICON_SIZE)
    f:SetBackdrop(BACKDROP_ALERT)
    f:SetBackdropColor(0.05, 0.04, 0.07, 0.90)
    f:SetBackdropBorderColor(unpack(def.borderColor))

    local tex = f:CreateTexture(nil, "ARTWORK")
    tex:SetPoint("TOPLEFT", 2, -2)
    tex:SetPoint("BOTTOMRIGHT", -2, 2)
    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    tex:SetTexture(def.icon)
    f.icon = tex

    local label = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOP", f, "BOTTOM", 0, -2)
    label:SetText(def.label)
    label:SetTextColor(def.borderColor[1], def.borderColor[2], def.borderColor[3])
    f.label = label

    local pulse = f:CreateAnimationGroup()
    local a1 = pulse:CreateAnimation("Alpha")
    a1:SetFromAlpha(1.0)
    a1:SetToAlpha(0.45)
    a1:SetDuration(0.4)
    a1:SetOrder(1)
    local a2 = pulse:CreateAnimation("Alpha")
    a2:SetFromAlpha(0.45)
    a2:SetToAlpha(1.0)
    a2:SetDuration(0.4)
    a2:SetOrder(2)
    pulse:SetLooping("REPEAT")
    f.pulse = pulse

    f.def = def
    f.wasActive = false
    f:Hide()
    return f
end

local function LayoutActiveAlerts()
    local shown = {}
    for _, def in ipairs(ALERT_DEFS) do
        local f = alertFrames[def.key]
        if f and f:IsShown() then
            table.insert(shown, f)
        end
    end

    if #shown == 0 then
        return
    end

    local totalW = (#shown * ICON_SIZE) + ((#shown - 1) * ICON_GAP)
    local startX = -totalW / 2 + (ICON_SIZE / 2)
    for i, f in ipairs(shown) do
        f:ClearAllPoints()
        f:SetPoint("CENTER", warningsAnchor, "CENTER", startX + (i - 1) * (ICON_SIZE + ICON_GAP), 0)
    end
end

function FLM:EvaluateWarnings()
    if not warningsAnchor or not self.db then
        return
    end

    local wdb = self.db.warnings
    if not wdb.enabled and not testMode then
        for _, f in pairs(alertFrames) do
            f.wasActive = false
            f.pulse:Stop()
            f:Hide()
        end
        return
    end

    local hostileTarget = UnitExists("target") and UnitCanAttack("player", "target") and not UnitIsDead("target")

    local states = {
        antiFear = false,
        shadowTrance = false,
        backlash = false,
        creatureAlert = false,
    }
    local creatureLabel = "BANISHABLE"

    if testMode then
        states.antiFear = true
        states.shadowTrance = true
        states.backlash = true
        states.creatureAlert = true
        creatureLabel = "DEMON"
    else
        if wdb.antiFear and hostileTarget then
            states.antiFear = self.UnitHasAura("target", self.ANTI_FEAR_AURA_NAMES, self.ANTI_FEAR_AURA_IDS)
        end
        if wdb.shadowTrance then
            states.shadowTrance = self.UnitHasAura("player", self.SHADOW_TRANCE_NAMES, self.SHADOW_TRANCE_IDS, "HELPFUL")
        end
        if wdb.backlash then
            states.backlash = self.UnitHasAura("player", self.BACKLASH_NAMES, self.BACKLASH_IDS, "HELPFUL")
        end
        if wdb.creatureAlert and hostileTarget then
            local cType = UnitCreatureType("target")
            local mapped = cType and CREATURE_TYPES[cType]
            if mapped then
                states.creatureAlert = true
                creatureLabel = mapped
            end
        end
    end

    for _, def in ipairs(ALERT_DEFS) do
        local f = alertFrames[def.key]
        local active = states[def.key]
        if active then
            if def.key == "creatureAlert" then
                f.label:SetText(creatureLabel)
            end
            if not f.wasActive and not testMode then
                PlayAlertSound(def.soundID)
            end
            f.wasActive = true
            f:Show()
            if not f.pulse:IsPlaying() then
                f.pulse:Play()
            end
        else
            f.wasActive = false
            if f.pulse:IsPlaying() then
                f.pulse:Stop()
            end
            f:SetAlpha(1.0)
            f:Hide()
        end
    end

    LayoutActiveAlerts()
end

function FLM:ApplyWarningsPosition()
    if not warningsAnchor or not self.db then
        return
    end
    local w = self.db.warnings
    warningsAnchor:ClearAllPoints()
    warningsAnchor:SetPoint(w.point or "CENTER", UIParent, w.relPoint or "CENTER", w.x or 0, w.y or 110)
    warningsAnchor:SetScale(w.scale or 1.0)
end

function FLM:ToggleTestWarnings()
    testMode = not testMode
    if testMode then
        warningsAnchor:EnableMouse(true)
        dragHeader:Show()
        self:Print("Warning test mode ON — drag the warning bar to reposition. Type /flm test to lock.")
    else
        warningsAnchor:EnableMouse(false)
        dragHeader:Hide()
        self:Print("Warning test mode OFF.")
    end
    self:EvaluateWarnings()
end

function FLM:InitWarnings()
    warningsAnchor = CreateFrame("Frame", "FLM_WarningsAnchor", UIParent)
    warningsAnchor:SetSize(210, 62)
    warningsAnchor:SetFrameStrata("HIGH")
    warningsAnchor:SetClampedToScreen(true)
    warningsAnchor:SetMovable(true)
    warningsAnchor:RegisterForDrag("LeftButton")
    warningsAnchor:EnableMouse(false)

    dragHeader = CreateFrame("Frame", nil, warningsAnchor, "BackdropTemplate")
    dragHeader:SetPoint("BOTTOM", warningsAnchor, "TOP", 0, 4)
    dragHeader:SetSize(180, 20)
    dragHeader:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    dragHeader:SetBackdropColor(0.10, 0.06, 0.16, 0.92)
    dragHeader:SetBackdropBorderColor(0.72, 0.45, 0.98, 1.0)
    local title = dragHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("CENTER")
    title:SetText("FLM Warnings (Drag to Move)")
    dragHeader:Hide()

    warningsAnchor:SetScript("OnDragStart", function(self)
        if testMode then
            self:StartMoving()
        end
    end)
    warningsAnchor:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        FLM.db.warnings.point = point
        FLM.db.warnings.relPoint = relPoint
        FLM.db.warnings.x = math.floor(x + 0.5)
        FLM.db.warnings.y = math.floor(y + 0.5)
    end)

    for _, def in ipairs(ALERT_DEFS) do
        alertFrames[def.key] = CreateAlertIcon(def)
    end

    self:ApplyWarningsPosition()
    self:EvaluateWarnings()

    self:RegisterEvent("UNIT_AURA", function(_, unit)
        if unit == "player" or unit == "target" then
            FLM:EvaluateWarnings()
        end
    end)
    self:RegisterEvent("PLAYER_TARGET_CHANGED", function()
        FLM:EvaluateWarnings()
    end)
end
