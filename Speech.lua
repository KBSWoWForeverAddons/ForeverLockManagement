local _, FLM = ...
if not FLM or not FLM.isWarlock then
    return
end

local lastPicked = {}
local pendingTargets = {}

local SPEECH_LINES = {
    summon = {
        "Channeling the Nether to pull <target> across the void — click the portal!",
        "Opening a summoning rift for <target>. Please assist with the portal!",
        "Ripping open space-time for <target> — two clicks on the portal, please.",
    },
    soulstone = {
        "Anchoring <target>'s soul with a Soulstone. Death is merely an inconvenience.",
        "Soulstone placed on <target> — rise again if the shadows claim you.",
        "Binding <target>'s essence to a Soulstone. Keep swinging!",
    },
    ritualOfSouls = {
        "Summoning a Soulwell — grab a fresh Healthstone before we pull!",
        "Soulwell going up! Click the table for your emergency Healthstone.",
        "Opening a Ritual of Souls — help yourselves to green candy.",
    },
    demon = {
        imp        = { "Calling forth my Imp from the Twisting Nether." },
        voidwalker = { "Summoning a Voidwalker to soak the hits." },
        succubus   = { "Beckoning a Succubus out of the shadows." },
        felhunter  = { "Unleashing a Felhunter — mind your spellcasts." },
        felguard   = { "Summoning a Felguard to cleave the front line!" },
        inferno    = { "Calling an Infernal down from the skies!" },
        doomguard  = { "Initiating Ritual of Doom — someone is about to have a bad day!" },
    },
    mount = {
        "Calling forth a demonic steed from the abyss.",
        "Saddling up in fel-fire.",
    },
}

local SUMMON_SPELL_IDS = { [698] = true }
local SOULWELL_SPELL_IDS = { [29893] = true }
local SOULSTONE_SPELL_IDS = {
    [20707] = true,
    [20762] = true,
    [20763] = true,
    [20764] = true,
    [20765] = true,
    [27239] = true,
}
local DEMON_SPELL_MAP = {
    [688]   = "imp",
    [697]   = "voidwalker",
    [712]   = "succubus",
    [691]   = "felhunter",
    [30146] = "felguard",
    [1122]  = "inferno",
    [18540] = "doomguard",
}
local MOUNT_SPELL_IDS = {
    [23161] = true,
    [5784]  = true,
}

-- Also resolve localized spell names for cross-rank matching
local SUMMON_SPELL_NAMES = {}
local SOULWELL_SPELL_NAMES = {}
local SOULSTONE_SPELL_NAMES = {}
do
    local n = FLM.GetSpellInfo(698)
    if n then SUMMON_SPELL_NAMES[n] = true end
    n = FLM.GetSpellInfo(29893)
    if n then SOULWELL_SPELL_NAMES[n] = true end
    for id in pairs(SOULSTONE_SPELL_IDS) do
        local ssName = FLM.GetSpellInfo(id)
        if ssName then SOULSTONE_SPELL_NAMES[ssName] = true end
    end
end

local function PickLine(key, list)
    if not list or #list == 0 then
        return nil
    end
    if #list == 1 then
        return list[1]
    end
    local prev = lastPicked[key]
    local idx = math.random(1, #list)
    if idx == prev then
        idx = (idx % #list) + 1
    end
    lastPicked[key] = idx
    return list[idx]
end

local function GetCustomLine(customKey)
    local custom = FLM.db and FLM.db.speech and FLM.db.speech.customLines
    local val = custom and custom[customKey]
    if type(val) == "string" then
        val = string.trim(val)
        if val ~= "" then
            return val
        end
    end
    return nil
end

local function GetSpeechLine(customKey, defaultKey, defaultList)
    local custom = GetCustomLine(customKey)
    if custom then
        return custom
    end
    return PickLine(defaultKey, defaultList)
end

local function GetGroupChannel()
    if LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return "INSTANCE_CHAT"
    elseif IsInRaid() then
        return "RAID"
    elseif IsInGroup() then
        return "PARTY"
    end
    return "SAY"
end

local function CanSendChat(channel)
    if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() then
        return false
    end
    if channel == "SAY" then
        local inInstance, instanceType = IsInInstance()
        return (inInstance and instanceType ~= "none") and true or false
    end
    if channel == "WHISPER" then
        return IsInGroup() or IsInRaid()
    end
    return true
end

local function SayLine(text)
    if not text or text == "" then
        return
    end
    local channel = GetGroupChannel()
    if CanSendChat(channel) then
        pcall(FLM.SendChatMessage, text, channel)
    else
        FLM:Print(text)
    end
end

local function ResolveTargetName(castGUID, explicitTarget)
    local target = explicitTarget
    if (not target or target == "") and castGUID and pendingTargets[castGUID] then
        target = pendingTargets[castGUID]
    end
    if not target or target == "" then
        target = UnitName("target")
    end
    if not target or target == "" then
        target = "a party member"
    end
    return target
end

function FLM:InitSpeech()
    self:RegisterEvent("UNIT_SPELLCAST_SENT", function(_, unit, target, castGUID, spellID)
        if unit ~= "player" or not FLM.db or not FLM.db.speech.enabled then
            return
        end

        if target and target ~= "" and castGUID then
            pendingTargets[castGUID] = target
        end

        local spellName = FLM.GetSpellInfo(spellID)

        if FLM.db.speech.summon and (SUMMON_SPELL_IDS[spellID] or (spellName and SUMMON_SPELL_NAMES[spellName])) then
            local line = GetSpeechLine("summon", "summon", SPEECH_LINES.summon)
            local who = ResolveTargetName(castGUID, target)
            if line then
                SayLine((line:gsub("<target>", who)))
            end
        elseif FLM.db.speech.ritualOfSouls and (SOULWELL_SPELL_IDS[spellID] or (spellName and SOULWELL_SPELL_NAMES[spellName])) then
            local line = GetSpeechLine("ritualOfSouls", "ritualOfSouls", SPEECH_LINES.ritualOfSouls)
            if line then
                SayLine(line)
            end
        elseif FLM.db.speech.demon and DEMON_SPELL_MAP[spellID] then
            local demonKey = DEMON_SPELL_MAP[spellID]
            local line = GetSpeechLine(demonKey, "demon_" .. demonKey, SPEECH_LINES.demon[demonKey])
            if line then
                SayLine(line)
            end
        elseif FLM.db.speech.mount and MOUNT_SPELL_IDS[spellID] then
            local line = GetSpeechLine("mount", "mount", SPEECH_LINES.mount)
            if line then
                SayLine(line)
            end
        elseif FLM.db.speech.soulstone and (SOULSTONE_SPELL_IDS[spellID] or (spellName and SOULSTONE_SPELL_NAMES[spellName])) then
            local who = ResolveTargetName(castGUID, target)
            local line = GetSpeechLine("soulstone", "soulstone", SPEECH_LINES.soulstone)
            if line then
                SayLine((line:gsub("<target>", who)))
            end
            if FLM.db.speech.whisperSoulstone and who ~= "a party member" and who ~= UnitName("player") and CanSendChat("WHISPER") then
                local whisperMsg = GetCustomLine("soulstoneWhisper") or "Soulstone placed on you!"
                pcall(FLM.SendChatMessage, whisperMsg, "WHISPER", nil, who)
            end
        end
    end)

    self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED", function(_, unit, castGUID)
        if unit == "player" and castGUID then
            pendingTargets[castGUID] = nil
        end
    end)

    self:RegisterEvent("UNIT_SPELLCAST_FAILED", function(_, unit, castGUID)
        if unit == "player" and castGUID then
            pendingTargets[castGUID] = nil
        end
    end)
end

function FLM:PreviewSpeech()
    local targetName = UnitName("target") or UnitName("player") or "TargetName"
    local s = self.db and self.db.speech or {}

    local function StatusTag(flag)
        return flag and "|cff33ff66[ON]|r" or "|cffff5555[OFF]|r"
    end

    local function ShowGroup(header, enabled, customKey, defaultLines, useTarget)
        DEFAULT_CHAT_FRAME:AddMessage("|cffb983ff" .. header .. "|r " .. StatusTag(enabled) .. ":")
        local custom = GetCustomLine(customKey)
        if custom then
            local out = useTarget and (custom:gsub("<target>", targetName)) or custom
            DEFAULT_CHAT_FRAME:AddMessage("  |cff33ff66[CUSTOM]|r " .. out)
        else
            for _, line in ipairs(defaultLines) do
                local out = useTarget and (line:gsub("<target>", targetName)) or line
                DEFAULT_CHAT_FRAME:AddMessage("  - " .. out)
            end
        end
    end

    self:Print("--- Speech Preview (Local Only - Not Sent to Chat) ---")
    self:Print("Master Speech: " .. StatusTag(s.enabled))

    ShowGroup("Ritual of Summoning", s.summon, "summon", SPEECH_LINES.summon, true)
    ShowGroup("Soulstone", s.soulstone, "soulstone", SPEECH_LINES.soulstone, true)
    local customWhisper = GetCustomLine("soulstoneWhisper")
    DEFAULT_CHAT_FRAME:AddMessage("|cffb983ffSoulstone Whisper|r " .. StatusTag(s.whisperSoulstone) .. ": " .. (customWhisper and ("|cff33ff66[CUSTOM]|r " .. customWhisper) or "Soulstone placed on you!"))
    ShowGroup("Ritual of Souls", s.ritualOfSouls, "ritualOfSouls", SPEECH_LINES.ritualOfSouls, false)

    DEFAULT_CHAT_FRAME:AddMessage("|cffb983ffDemon Summons|r " .. StatusTag(s.demon) .. ":")
    local demonOrder = { "imp", "voidwalker", "succubus", "felhunter", "felguard", "inferno", "doomguard" }
    for _, key in ipairs(demonOrder) do
        local customDemon = GetCustomLine(key)
        if customDemon then
            DEFAULT_CHAT_FRAME:AddMessage("  [" .. key .. "] |cff33ff66[CUSTOM]|r " .. customDemon)
        else
            local lines = SPEECH_LINES.demon[key]
            if lines and lines[1] then
                DEFAULT_CHAT_FRAME:AddMessage("  [" .. key .. "] " .. lines[1])
            end
        end
    end

    ShowGroup("Mount Summon", s.mount, "mount", SPEECH_LINES.mount, false)
end

local speechDialog
local speechInputs = {}

local DIALOG_ROWS = {
    { key = "summon",           label = "Ritual of Summoning",  useTarget = true,  defaults = SPEECH_LINES.summon },
    { key = "soulstone",        label = "Soulstone Cast",       useTarget = true,  defaults = SPEECH_LINES.soulstone },
    { key = "soulstoneWhisper", label = "Soulstone Whisper",    useTarget = false, defaults = { "Soulstone placed on you!" } },
    { key = "ritualOfSouls",    label = "Ritual of Souls",      useTarget = false, defaults = SPEECH_LINES.ritualOfSouls },
    { key = "imp",              label = "Summon Imp",           useTarget = false, defaults = SPEECH_LINES.demon.imp },
    { key = "voidwalker",       label = "Summon Voidwalker",    useTarget = false, defaults = SPEECH_LINES.demon.voidwalker },
    { key = "succubus",         label = "Summon Succubus",      useTarget = false, defaults = SPEECH_LINES.demon.succubus },
    { key = "felhunter",        label = "Summon Felhunter",     useTarget = false, defaults = SPEECH_LINES.demon.felhunter },
    { key = "felguard",         label = "Summon Felguard",      useTarget = false, defaults = SPEECH_LINES.demon.felguard },
    { key = "inferno",          label = "Summon Infernal",      useTarget = false, defaults = SPEECH_LINES.demon.inferno },
    { key = "doomguard",        label = "Ritual of Doom",       useTarget = false, defaults = SPEECH_LINES.demon.doomguard },
    { key = "mount",            label = "Mount Summon",         useTarget = false, defaults = SPEECH_LINES.mount },
}

local function RefreshSpeechInputs()
    local custom = (FLM.db and FLM.db.speech and FLM.db.speech.customLines) or {}
    for _, row in ipairs(DIALOG_ROWS) do
        local eb = speechInputs[row.key]
        if eb then
            local defaultLine = (row.defaults and row.defaults[1]) or ""
            eb:SetText(custom[row.key] or defaultLine)
            eb:SetCursorPosition(0)
        end
    end
end

local function SaveSpeechInputs()
    if not FLM.db then
        return
    end
    FLM.db.speech.customLines = FLM.db.speech.customLines or {}
    local savedCount = 0
    for _, row in ipairs(DIALOG_ROWS) do
        local eb = speechInputs[row.key]
        if eb then
            local text = string.trim(eb:GetText() or "")
            local defaultLine = (row.defaults and row.defaults[1]) or ""
            if text ~= "" and text ~= defaultLine then
                FLM.db.speech.customLines[row.key] = text
                savedCount = savedCount + 1
            else
                FLM.db.speech.customLines[row.key] = nil
            end
        end
    end
    RefreshSpeechInputs()
    FLM:Print(string.format("Saved custom speech settings (%d custom line(s) active).", savedCount))
end

local function BuildSpeechDialog()
    speechDialog = CreateFrame("Frame", "FLM_SpeechDialog", UIParent, "BackdropTemplate")
    speechDialog:SetSize(580, 510)
    speechDialog:SetPoint("CENTER")
    speechDialog:SetFrameStrata("DIALOG")
    speechDialog:SetClampedToScreen(true)
    speechDialog:EnableMouse(true)
    speechDialog:SetMovable(true)
    speechDialog:RegisterForDrag("LeftButton")
    speechDialog:SetScript("OnDragStart", speechDialog.StartMoving)
    speechDialog:SetScript("OnDragStop", speechDialog.StopMovingOrSizing)
    speechDialog:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    speechDialog:SetBackdropColor(0.05, 0.04, 0.08, 0.96)
    speechDialog:SetBackdropBorderColor(0.50, 0.30, 0.78, 1.0)
    tinsert(UISpecialFrames, "FLM_SpeechDialog")

    local title = speechDialog:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -14)
    title:SetText("Custom Speech Messages")
    title:SetTextColor(0.84, 0.60, 1.0)

    local sub = speechDialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    sub:SetText("Edit any line to personalize it (use <target> for target name). Clear or Reset Defaults to restore built-in lines.")
    sub:SetTextColor(0.75, 0.75, 0.80)

    local closeBtn = CreateFrame("Button", nil, speechDialog, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -4, -4)

    for i, row in ipairs(DIALOG_ROWS) do
        local y = -66 - ((i - 1) * 32)

        local lbl = speechDialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        lbl:SetPoint("TOPLEFT", speechDialog, "TOPLEFT", 16, y - 4)
        lbl:SetWidth(134)
        lbl:SetJustifyH("LEFT")
        lbl:SetText(row.label)

        local eb = CreateFrame("EditBox", nil, speechDialog, "BackdropTemplate")
        eb:SetPoint("TOPLEFT", speechDialog, "TOPLEFT", 154, y)
        eb:SetSize(348, 22)
        eb:SetAutoFocus(false)
        eb:SetFontObject(GameFontHighlightSmall)
        eb:SetTextInsets(6, 6, 0, 0)
        eb:SetMaxLetters(240)
        eb:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        eb:SetBackdropColor(0.09, 0.07, 0.13, 1.0)
        eb:SetBackdropBorderColor(0.34, 0.22, 0.52, 1.0)
        eb:SetScript("OnEditFocusGained", function(self)
            self:SetBackdropBorderColor(0.76, 0.48, 1.0, 1.0)
        end)
        eb:SetScript("OnEditFocusLost", function(self)
            self:SetBackdropBorderColor(0.34, 0.22, 0.52, 1.0)
        end)
        eb:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
        end)
        eb:SetScript("OnEnterPressed", function(self)
            self:ClearFocus()
        end)
        speechInputs[row.key] = eb

        local testBtn = CreateFrame("Button", nil, speechDialog, "UIPanelButtonTemplate")
        testBtn:SetSize(52, 22)
        testBtn:SetPoint("LEFT", eb, "RIGHT", 6, 0)
        testBtn:SetText("Test")
        testBtn:SetScript("OnClick", function()
            local typed = string.trim(eb:GetText() or "")
            local defaultLine = (row.defaults and row.defaults[1]) or ""
            local isCustom = (typed ~= "" and typed ~= defaultLine)
            local sample = (typed ~= "" and typed) or defaultLine
            local targetName = UnitName("target") or UnitName("player") or "TargetName"
            if row.useTarget then
                sample = sample:gsub("<target>", targetName)
            end
            local tag = isCustom and "|cff33ff66[CUSTOM]|r " or "|cffaaaaaa[DEFAULT]|r "
            FLM:Print(row.label .. ": " .. tag .. sample)
        end)
    end

    local saveBtn = CreateFrame("Button", nil, speechDialog, "UIPanelButtonTemplate")
    saveBtn:SetSize(130, 24)
    saveBtn:SetPoint("BOTTOMLEFT", speechDialog, "BOTTOMLEFT", 16, 16)
    saveBtn:SetText("Save")
    saveBtn:SetScript("OnClick", function()
        SaveSpeechInputs()
    end)

    local previewBtn = CreateFrame("Button", nil, speechDialog, "UIPanelButtonTemplate")
    previewBtn:SetSize(130, 24)
    previewBtn:SetPoint("LEFT", saveBtn, "RIGHT", 10, 0)
    previewBtn:SetText("Preview All")
    previewBtn:SetScript("OnClick", function()
        SaveSpeechInputs()
        FLM:PreviewSpeech()
    end)

    local resetBtn = CreateFrame("Button", nil, speechDialog, "UIPanelButtonTemplate")
    resetBtn:SetSize(130, 24)
    resetBtn:SetPoint("BOTTOMRIGHT", speechDialog, "BOTTOMRIGHT", -16, 16)
    resetBtn:SetText("Reset Defaults")
    resetBtn:SetScript("OnClick", function()
        if FLM.db and FLM.db.speech then
            FLM.db.speech.customLines = {}
        end
        RefreshSpeechInputs()
        FLM:Print("Reset all speech lines to built-in defaults.")
    end)

    speechDialog:SetScript("OnShow", RefreshSpeechInputs)
    speechDialog:Hide()
end

function FLM:ToggleSpeechDialog()
    if not speechDialog then
        BuildSpeechDialog()
    end
    if speechDialog:IsShown() then
        speechDialog:Hide()
    else
        if _G.FLM_OptionsFrame and _G.FLM_OptionsFrame:IsShown() then
            _G.FLM_OptionsFrame:Hide()
        end
        if _G.SettingsPanel and _G.SettingsPanel:IsShown() then
            if HideUIPanel then
                HideUIPanel(_G.SettingsPanel)
            else
                _G.SettingsPanel:Hide()
            end
        end
        if _G.InterfaceOptionsFrame and _G.InterfaceOptionsFrame:IsShown() then
            if HideUIPanel then
                HideUIPanel(_G.InterfaceOptionsFrame)
            else
                _G.InterfaceOptionsFrame:Hide()
            end
        end
        speechDialog:Show()
        speechDialog:Raise()
    end
end
