local _, FLM = ...
if not FLM or not FLM.isWarlock then
    return
end

local BACKDROP_WIN = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

local optionsFrame
local refreshCallbacks = {}
local bagButtons = {}

local function CreateSectionHeader(parent, text, x, y)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    fs:SetText(text)
    fs:SetTextColor(0.80, 0.55, 1.0)

    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 0, -2)
    line:SetSize(268, 1)
    line:SetColorTexture(0.36, 0.22, 0.56, 0.8)
    return fs
end

local function CreateCheckbox(parent, label, x, y, getter, setter)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(22, 22)
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)

    local text = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    text:SetText(label)
    cb.label = text

    cb:SetScript("OnClick", function(self)
        setter(self:GetChecked() and true or false)
        for _, fn in ipairs(refreshCallbacks) do
            fn()
        end
    end)

    table.insert(refreshCallbacks, function()
        cb:SetChecked(getter() and true or false)
    end)
    return cb
end

local function CreateCleanSlider(parent, label, x, y, minVal, maxVal, step, fmt, getter, setter, isEnabledFn)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(250, 36)
    container:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)

    local title = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    title:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)

    local slider = CreateFrame("Slider", nil, container, "BackdropTemplate")
    slider:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -16)
    slider:SetSize(250, 14)
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    slider:SetBackdropColor(0.08, 0.07, 0.12, 1)
    slider:SetBackdropBorderColor(0.32, 0.22, 0.48, 1)

    local thumb = slider:CreateTexture(nil, "OVERLAY")
    thumb:SetSize(12, 14)
    thumb:SetColorTexture(0.75, 0.48, 1.0, 1)
    slider:SetThumbTexture(thumb)

    local function UpdateTitle(val)
        title:SetText(string.format("%s: " .. fmt, label, val))
    end

    slider:SetScript("OnValueChanged", function(self, value, userInput)
        local rounded = math.floor((value / step) + 0.5) * step
        UpdateTitle(rounded)
        if userInput then
            setter(rounded)
        end
    end)

    table.insert(refreshCallbacks, function()
        local val = getter()
        slider:SetValue(val)
        UpdateTitle(val)
        local enabled = (not isEnabledFn) or isEnabledFn()
        if enabled then
            slider:Enable()
            thumb:SetColorTexture(0.75, 0.48, 1.0, 1)
            title:SetTextColor(1, 1, 1)
        else
            slider:Disable()
            thumb:SetColorTexture(0.35, 0.35, 0.40, 0.8)
            title:SetTextColor(0.5, 0.5, 0.5)
        end
    end)

    return slider
end

local function CreateActionButton(parent, text, x, y, width, onClick)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(width, 22)
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    btn:SetText(text)
    btn:SetScript("OnClick", onClick)
    return btn
end

local function RefreshBagButtons()
    if not FLM.db then
        return
    end
    local selected = FLM:GetShardBagIndex()
    for bagIndex = 0, 4 do
        local btn = bagButtons[bagIndex]
        if btn then
            local info = FLM:GetBagSummary(bagIndex)
            local tag = info.isSoulPouch and " [Soul]" or ""
            btn.text:SetText(string.format("Bag %d: %s (%d slots)%s", info.uiNumber, info.name, info.slots, tag))
            if bagIndex == selected then
                btn:SetBackdropColor(0.32, 0.16, 0.50, 0.95)
                btn:SetBackdropBorderColor(0.78, 0.50, 1.0, 1.0)
            else
                btn:SetBackdropColor(0.08, 0.07, 0.12, 0.90)
                btn:SetBackdropBorderColor(0.28, 0.20, 0.40, 1.0)
            end
        end
    end
end

local function BuildOptionsWindow()
    optionsFrame = CreateFrame("Frame", "FLM_OptionsFrame", UIParent, "BackdropTemplate")
    optionsFrame:SetSize(610, 560)
    optionsFrame:SetPoint("CENTER")
    optionsFrame:SetFrameStrata("DIALOG")
    optionsFrame:SetClampedToScreen(true)
    optionsFrame:EnableMouse(true)
    optionsFrame:SetMovable(true)
    optionsFrame:RegisterForDrag("LeftButton")
    optionsFrame:SetScript("OnDragStart", optionsFrame.StartMoving)
    optionsFrame:SetScript("OnDragStop", optionsFrame.StopMovingOrSizing)
    optionsFrame:SetBackdrop(BACKDROP_WIN)
    optionsFrame:SetBackdropColor(0.05, 0.04, 0.08, 0.96)
    optionsFrame:SetBackdropBorderColor(0.50, 0.30, 0.78, 1.0)
    tinsert(UISpecialFrames, "FLM_OptionsFrame")

    local title = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 16, -14)
    title:SetText("Forever Lock Management")
    title:SetTextColor(0.84, 0.60, 1.0)

    local subtitle = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
    subtitle:SetText("Square Hub, Soul Shard Bag Manager, Speech & Combat Warnings")
    subtitle:SetTextColor(0.70, 0.70, 0.75)

    local closeBtn = CreateFrame("Button", nil, optionsFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", optionsFrame, "TOPRIGHT", -4, -4)

    -- ================= LEFT COLUMN =================
    local lx = 18
    CreateSectionHeader(optionsFrame, "Hub Layout", lx, -56)

    CreateCheckbox(optionsFrame, "Lock Hub Position (Shift+Drag to move)", lx, -78,
        function() return FLM.db.hub.locked end,
        function(v) FLM.db.hub.locked = v end)

    CreateCheckbox(optionsFrame, "Auto-close drawers after selection", lx, -102,
        function() return FLM.db.hub.autoCloseDrawers end,
        function(v)
            FLM.db.hub.autoCloseDrawers = v
            if FLM.SyncDrawerSettings then
                FLM:SyncDrawerSettings()
            end
        end)

    CreateCheckbox(optionsFrame, "Show Spellstone in Weapon Stones Drawer", lx, -126,
        function() return FLM.db.hub.showSpellstone end,
        function(v) FLM.db.hub.showSpellstone = v; FLM:UpdateHub() end)

    CreateCheckbox(optionsFrame, "Show Firestone in Weapon Stones Drawer", lx, -150,
        function() return FLM.db.hub.showFirestone end,
        function(v) FLM.db.hub.showFirestone = v; FLM:UpdateHub() end)

    CreateCleanSlider(optionsFrame, "Hub Scale", lx, -180, 0.70, 1.50, 0.05, "%.2f",
        function() return FLM.db.hub.scale end,
        function(v)
            FLM.db.hub.scale = v
            if not InCombatLockdown() then
                FLM:ApplyHubPosition()
            end
        end)

    CreateActionButton(optionsFrame, "Reset Hub & Warning Positions", lx, -222, 220, function()
        FLM:ResetPositions()
    end)

    -- Soul Shard Bag & Excess Management
    CreateSectionHeader(optionsFrame, "Soul Shard Bag & Excess Control", lx, -260)

    local bagPrompt = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bagPrompt:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", lx, -282)
    bagPrompt:SetText("Assigned Soul Shard Bag (Bags 1-5):")

    for bagIndex = 0, 4 do
        local rowBtn = CreateFrame("Button", nil, optionsFrame, "BackdropTemplate")
        rowBtn:SetSize(266, 20)
        rowBtn:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", lx, -300 - (bagIndex * 22))
        rowBtn:SetBackdrop(BACKDROP_WIN)

        local txt = rowBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        txt:SetPoint("LEFT", rowBtn, "LEFT", 6, 0)
        txt:SetPoint("RIGHT", rowBtn, "RIGHT", -6, 0)
        txt:SetJustifyH("LEFT")
        rowBtn.text = txt

        rowBtn:SetScript("OnClick", function()
            FLM.db.shards.bagIndex = bagIndex
            RefreshBagButtons()
            if FLM.db.shards.autoSort and not InCombatLockdown() then
                local moved = FLM:SortShards()
                if moved > 0 then
                    FLM:Print("Moved " .. moved .. " Soul Shard(s) to Bag " .. (bagIndex + 1) .. ".")
                end
            end
            FLM:UpdateShardDisplay()
        end)

        bagButtons[bagIndex] = rowBtn
    end
    table.insert(refreshCallbacks, RefreshBagButtons)

    CreateCheckbox(optionsFrame, "Auto-sort shards into assigned bag (out of combat)", lx, -416,
        function() return FLM.db.shards.autoSort end,
        function(v)
            FLM.db.shards.autoSort = v
            if v and not InCombatLockdown() then
                FLM:SortShards()
            end
            FLM:UpdateShardDisplay()
        end)

    CreateCheckbox(optionsFrame, "Cap shards to assigned bag capacity", lx, -440,
        function() return FLM.db.shards.limitToBagCapacity end,
        function(v)
            FLM.db.shards.limitToBagCapacity = v
            FLM:UpdateShardDisplay()
        end)

    CreateCleanSlider(optionsFrame, "Custom Max Shards", lx, -468, 1, 32, 1, "%d",
        function() return FLM.db.shards.maxShards end,
        function(v)
            FLM.db.shards.maxShards = v
            FLM:UpdateShardDisplay()
        end,
        function() return not FLM.db.shards.limitToBagCapacity end)

    CreateCheckbox(optionsFrame, "Highlight Shard button when excess shards exist", lx, -506,
        function() return FLM.db.shards.warnExcess end,
        function(v)
            FLM.db.shards.warnExcess = v
            FLM:UpdateShardDisplay()
        end)

    -- ================= RIGHT COLUMN =================
    local rx = 316
    CreateSectionHeader(optionsFrame, "Chat & Speech Announcements", rx, -56)

    CreateCheckbox(optionsFrame, "Enable Speech Announcements", rx, -78,
        function() return FLM.db.speech.enabled end,
        function(v) FLM.db.speech.enabled = v end)

    CreateCheckbox(optionsFrame, "Ritual of Summoning (<target>)", rx + 14, -102,
        function() return FLM.db.speech.summon end,
        function(v) FLM.db.speech.summon = v end)

    CreateCheckbox(optionsFrame, "Soulstone (<target>)", rx + 14, -126,
        function() return FLM.db.speech.soulstone end,
        function(v) FLM.db.speech.soulstone = v end)

    CreateCheckbox(optionsFrame, "Whisper Soulstone Target", rx + 14, -150,
        function() return FLM.db.speech.whisperSoulstone end,
        function(v) FLM.db.speech.whisperSoulstone = v end)

    CreateCheckbox(optionsFrame, "Ritual of Souls (Soulwell)", rx + 14, -174,
        function() return FLM.db.speech.ritualOfSouls end,
        function(v) FLM.db.speech.ritualOfSouls = v end)

    CreateCheckbox(optionsFrame, "Demon Summoning", rx + 14, -198,
        function() return FLM.db.speech.demon end,
        function(v) FLM.db.speech.demon = v end)

    CreateCheckbox(optionsFrame, "Mount Summoning", rx + 14, -222,
        function() return FLM.db.speech.mount end,
        function(v) FLM.db.speech.mount = v end)

    CreateActionButton(optionsFrame, "Customize Speech...", rx, -250, 125, function()
        FLM:ToggleSpeechDialog()
    end)

    CreateActionButton(optionsFrame, "Preview Speech", rx + 135, -250, 115, function()
        FLM:PreviewSpeech()
    end)

    -- Center Warning Icons
    CreateSectionHeader(optionsFrame, "Center Warning Icons", rx, -282)

    CreateCheckbox(optionsFrame, "Enable Center Warning Icons", rx, -304,
        function() return FLM.db.warnings.enabled end,
        function(v) FLM.db.warnings.enabled = v; FLM:EvaluateWarnings() end)

    CreateCheckbox(optionsFrame, "Play Warning Sound", rx + 14, -328,
        function() return FLM.db.warnings.sound end,
        function(v) FLM.db.warnings.sound = v end)

    CreateCheckbox(optionsFrame, "Anti-Fear (Target Fear Immunity)", rx + 14, -352,
        function() return FLM.db.warnings.antiFear end,
        function(v) FLM.db.warnings.antiFear = v; FLM:EvaluateWarnings() end)

    CreateCheckbox(optionsFrame, "Shadow Trance (Nightfall Proc)", rx + 14, -376,
        function() return FLM.db.warnings.shadowTrance end,
        function(v) FLM.db.warnings.shadowTrance = v; FLM:EvaluateWarnings() end)

    CreateCheckbox(optionsFrame, "Backlash Proc", rx + 14, -400,
        function() return FLM.db.warnings.backlash end,
        function(v) FLM.db.warnings.backlash = v; FLM:EvaluateWarnings() end)

    CreateCheckbox(optionsFrame, "Demon / Elemental Target Alert", rx + 14, -424,
        function() return FLM.db.warnings.creatureAlert end,
        function(v) FLM.db.warnings.creatureAlert = v; FLM:EvaluateWarnings() end)

    CreateCleanSlider(optionsFrame, "Warnings Scale", rx, -452, 0.70, 1.60, 0.05, "%.2f",
        function() return FLM.db.warnings.scale end,
        function(v)
            FLM.db.warnings.scale = v
            FLM:ApplyWarningsPosition()
        end)

    CreateActionButton(optionsFrame, "Test / Move Warnings (/flm test)", rx, -494, 220, function()
        FLM:ToggleTestWarnings()
    end)

    local note = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    note:SetPoint("BOTTOMRIGHT", optionsFrame, "BOTTOMRIGHT", -18, 12)
    note:SetText("Tip: Right-click Shard button to destroy excess shards.")

    optionsFrame:SetScript("OnShow", function()
        for _, fn in ipairs(refreshCallbacks) do
            fn()
        end
    end)

    optionsFrame:Hide()
end

local function RegisterSettingsPanel()
    local panel = CreateFrame("Frame", "FLM_SettingsStub")
    panel.name = FLM.title

    local hdr = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    hdr:SetPoint("TOPLEFT", 16, -16)
    hdr:SetText(FLM.title)

    local desc = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", hdr, "BOTTOMLEFT", 0, -8)
    desc:SetText("Use /flm or /lock (or right-click the center hub square) to configure Forever Lock Management.")

    local openBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    openBtn:SetSize(200, 26)
    openBtn:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -16)
    openBtn:SetText("Open Options Window")
    openBtn:SetScript("OnClick", function()
        FLM:ToggleOptions()
    end)

    local speechBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    speechBtn:SetSize(200, 26)
    speechBtn:SetPoint("LEFT", openBtn, "RIGHT", 12, 0)
    speechBtn:SetText("Customize Speech...")
    speechBtn:SetScript("OnClick", function()
        FLM:ToggleSpeechDialog()
    end)

    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, FLM.title)
        Settings.RegisterAddOnCategory(category)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end

function FLM:ToggleOptions()
    if not optionsFrame then
        BuildOptionsWindow()
    end
    if optionsFrame:IsShown() then
        optionsFrame:Hide()
    else
        if _G.FLM_SpeechDialog and _G.FLM_SpeechDialog:IsShown() then
            _G.FLM_SpeechDialog:Hide()
        end
        optionsFrame:Show()
        optionsFrame:Raise()
    end
end

function FLM:InitOptions()
    BuildOptionsWindow()
    RegisterSettingsPanel()
end
