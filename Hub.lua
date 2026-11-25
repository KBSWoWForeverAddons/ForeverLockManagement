local _, FLM = ...
if not FLM or not FLM.isWarlock then
    return
end

local BACKDROP_SOLID = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

local COLORS = {
    bg          = { 0.06, 0.05, 0.09, 0.92 },
    border      = { 0.36, 0.22, 0.56, 1.00 },
    borderHover = { 0.72, 0.45, 0.98, 1.00 },
    borderWarn  = { 0.95, 0.32, 0.15, 1.00 },
    borderSort  = { 0.25, 0.72, 0.95, 1.00 },
    drawerBg    = { 0.04, 0.03, 0.07, 0.95 },
    fillNormal  = { 0.45, 0.20, 0.68, 0.45 },
    fillFull    = { 0.18, 0.68, 0.32, 0.45 },
    fillExcess  = { 0.90, 0.24, 0.14, 0.55 },
}

local BUTTON_SIZE = 30
local HUB_WIDTH = 72
local HUB_HEIGHT = 98
local GAP = 4

local hubFrame
local secureHeader
local shardFillTex, shardCountText, shardSubText, shardBagTag
local buttons = {}
local drawers = {}
local drawerButtons = {}
local pendingSecureUpdate = false

local function ApplySquareBackdrop(frame, bgColor, borderColor)
    if not frame.SetBackdrop then
        Mixin(frame, BackdropTemplateMixin)
    end
    frame:SetBackdrop(BACKDROP_SOLID)
    frame:SetBackdropColor(unpack(bgColor or COLORS.bg))
    frame:SetBackdropBorderColor(unpack(borderColor or COLORS.border))
end

local function StyleSquareButton(btn, iconPath, arrowText)
    btn:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    ApplySquareBackdrop(btn, COLORS.bg, COLORS.border)

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", -2, 2)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetTexture(iconPath or "Interface\\Icons\\INV_Misc_QuestionMark")
    btn.icon = icon

    local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(icon)
    highlight:SetColorTexture(1, 1, 1, 0.18)

    local count = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    count:SetPoint("BOTTOMRIGHT", -2, 2)
    count:SetJustifyH("RIGHT")
    btn.countText = count

    local cd = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    cd:SetAllPoints(icon)
    btn.cooldown = cd

    if arrowText then
        local arrow = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        arrow:SetPoint("TOPRIGHT", -2, -1)
        arrow:SetText(arrowText)
        arrow:SetTextColor(0.85, 0.68, 1.0)
        btn.arrowText = arrow
    end

    btn:HookScript("OnEnter", function(self)
        if not self.warnBorderActive then
            self:SetBackdropBorderColor(unpack(COLORS.borderHover))
        end
        if self.ShowCustomTooltip then
            self:ShowCustomTooltip()
        end
    end)
    btn:HookScript("OnLeave", function(self)
        if self.warnBorderActive then
            self:SetBackdropBorderColor(unpack(self.warnBorderColor or COLORS.borderWarn))
        else
            self:SetBackdropBorderColor(unpack(COLORS.border))
        end
        GameTooltip:Hide()
    end)
end

local function CreateSecureHubButton(name, parent, x, y, iconPath)
    local btn = CreateFrame("Button", name, parent, "SecureActionButtonTemplate,BackdropTemplate")
    btn:SetPoint("CENTER", parent, "CENTER", x, y)
    btn:RegisterForClicks("AnyUp", "AnyDown")
    StyleSquareButton(btn, iconPath)
    return btn
end

local function CreateMenuToggleButton(name, parent, x, y, iconPath, arrowText)
    local btn = CreateFrame("Button", name, parent, "SecureActionButtonTemplate,BackdropTemplate")
    btn:SetPoint("CENTER", parent, "CENTER", x, y)
    btn:RegisterForClicks("LeftButtonUp")
    StyleSquareButton(btn, iconPath, arrowText)
    return btn
end

local function CreateDrawerFrame(name, anchorBtn, anchorPoint, relPoint, offX, offY)
    local drawer = CreateFrame("Frame", name, anchorBtn, "SecureHandlerStateTemplate,BackdropTemplate")
    drawer:SetPoint(anchorPoint, anchorBtn, relPoint, offX, offY)
    drawer:SetFrameStrata("DIALOG")
    ApplySquareBackdrop(drawer, COLORS.drawerBg, COLORS.borderHover)
    drawer:Hide()
    return drawer
end

local DRAWER_CHILD_PRECLICK = [[
    local wantDown = control:GetAttribute("useKeyDown")
    if control:GetAttribute("autoCloseDrawers") and ((wantDown and down) or (not wantDown and not down)) then
        return nil, "close"
    end
]]

local DRAWER_CHILD_POSTCLICK = [[
    if message == "close" then
        local count = control:GetAttribute("drawerCount") or 0
        for i = 1, count do
            local d = control:GetFrameRef("drawer" .. i)
            if d and d:IsShown() then
                d:Hide()
            end
        end
    end
]]

local function SyncDrawerAttributes()
    if not secureHeader or not FLM.db then
        return
    end
    if InCombatLockdown() then
        pendingSecureUpdate = true
        return
    end
    secureHeader:SetAttribute("autoCloseDrawers", FLM.db.hub.autoCloseDrawers and true or false)
    secureHeader:SetAttribute("useKeyDown", (GetCVarBool and GetCVarBool("ActionButtonUseKeyDown")) and true or false)
end

local function WireDrawerToggle(toggleBtn, drawerIndex)
    toggleBtn:SetAttribute("drawerIndex", drawerIndex)
    secureHeader:WrapScript(toggleBtn, "OnClick", [[
        local idx = self:GetAttribute("drawerIndex")
        local owned = idx and control:GetFrameRef("drawer" .. idx)
        if not owned then return false end
        local shouldShow = not owned:IsShown()
        local count = control:GetAttribute("drawerCount") or 0
        for i = 1, count do
            local other = control:GetFrameRef("drawer" .. i)
            if other and other:IsShown() then
                other:Hide()
            end
        end
        if shouldShow then
            owned:Show()
        else
            owned:Hide()
        end
        return false
    ]])
end

local SPELL_KEY_TO_SPEECH = {
    summon_imp          = "imp",
    summon_voidwalker   = "voidwalker",
    summon_succubus     = "succubus",
    summon_felhunter    = "felhunter",
    summon_felguard     = "felguard",
    inferno             = "inferno",
    ritual_of_doom      = "doomguard",
    ritual_of_summoning = "summon",
}

local function ApplyDrawerButtonAction(btn, spellName, speechKey)
    local macroStr = speechKey and FLM.BuildSpeechMacro and FLM:BuildSpeechMacro(spellName, speechKey)
    if macroStr then
        btn:SetAttribute("type", "macro")
        btn:SetAttribute("macrotext", macroStr)
        btn:SetAttribute("spell", nil)
    else
        btn:SetAttribute("type", "spell")
        btn:SetAttribute("spell", spellName)
        btn:SetAttribute("macrotext", nil)
    end
end

local function BuildSpellDrawerButtons(drawerKey, spellKeys, cols, growDirX, growDirY)
    local drawer = drawers[drawerKey]
    if not drawer or InCombatLockdown() then
        return
    end

    drawerButtons[drawerKey] = drawerButtons[drawerKey] or {}
    local pool = drawerButtons[drawerKey]

    local visible = {}
    for _, spellKey in ipairs(spellKeys) do
        local info = FLM.knownSpells[spellKey]
        if info then
            table.insert(visible, { key = spellKey, info = info })
        end
    end

    for _, btn in ipairs(pool) do
        btn:Hide()
    end

    if #visible == 0 then
        drawer:SetSize(BUTTON_SIZE + 8, BUTTON_SIZE + 8)
        return
    end

    local pad = 4
    local cellGap = 3
    local numCols = math.min(cols, #visible)
    local numRows = math.ceil(#visible / numCols)
    local totalW = pad * 2 + numCols * BUTTON_SIZE + (numCols - 1) * cellGap
    local totalH = pad * 2 + numRows * BUTTON_SIZE + (numRows - 1) * cellGap
    drawer:SetSize(totalW, totalH)

    for i, entry in ipairs(visible) do
        local btn = pool[i]
        if not btn then
            btn = CreateFrame("Button", nil, drawer, "SecureActionButtonTemplate,BackdropTemplate")
            btn:RegisterForClicks("AnyUp", "AnyDown")
            StyleSquareButton(btn, entry.info.icon)
            if secureHeader then
                secureHeader:WrapScript(btn, "OnClick", DRAWER_CHILD_PRECLICK, DRAWER_CHILD_POSTCLICK)
            end
            btn:HookScript("PreClick", function(self)
                if self.speechCategory and FLM.MarkHubSpeechSent then
                    FLM:MarkHubSpeechSent(self.speechCategory)
                end
            end)
            btn:HookScript("PostClick", function(self)
                if self.speechKey and self.spellName and not InCombatLockdown() then
                    ApplyDrawerButtonAction(self, self.spellName, self.speechKey)
                end
            end)
            btn.ShowCustomTooltip = function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                if self.spellID then
                    GameTooltip:SetSpellByID(self.spellID)
                elseif self.spellName then
                    GameTooltip:SetText(self.spellName, 1, 1, 1)
                end
                GameTooltip:Show()
            end
            pool[i] = btn
        end

        local idx0 = i - 1
        local col = idx0 % numCols
        local row = math.floor(idx0 / numCols)

        local x = pad + col * (BUTTON_SIZE + cellGap)
        local y = pad + row * (BUTTON_SIZE + cellGap)

        btn:ClearAllPoints()
        if growDirX < 0 then
            btn:SetPoint("TOPRIGHT", drawer, "TOPRIGHT", -x, -y)
        else
            btn:SetPoint("TOPLEFT", drawer, "TOPLEFT", x, -y)
        end

        local speechKey = SPELL_KEY_TO_SPEECH[entry.key]
        btn.spellID = entry.info.id
        btn.spellName = entry.info.name
        btn.speechKey = speechKey
        btn.speechCategory = speechKey and FLM.GetSpeechCategoryForKey and FLM:GetSpeechCategoryForKey(speechKey) or nil
        btn.icon:SetTexture(entry.info.icon)
        ApplyDrawerButtonAction(btn, entry.info.name, speechKey)
        btn:Show()
    end
end

local function UpdateStoneButtons()
    if InCombatLockdown() then
        pendingSecureUpdate = true
        return
    end

    -- Healthstone Button
    local hsBtn = buttons.healthstone
    if hsBtn then
        local hsItem = FLM:FindBestBagItem(FLM.ITEM_LISTS.healthstone)
        local createHS = FLM.knownSpells.create_healthstone
        local soulwell = FLM.knownSpells.ritual_of_souls

        hsBtn:SetAttribute("type1", nil)
        hsBtn:SetAttribute("item1", nil)
        hsBtn:SetAttribute("type2", nil)
        hsBtn:SetAttribute("spell2", nil)
        hsBtn:SetAttribute("shift-type1", nil)
        hsBtn:SetAttribute("shift-spell1", nil)
        hsBtn:SetAttribute("shift-macrotext1", nil)

        if hsItem then
            hsBtn:SetAttribute("type1", "item")
            hsBtn:SetAttribute("item1", hsItem.name or ("item:" .. hsItem.itemID))
            hsBtn.icon:SetTexture(hsItem.icon or "Interface\\Icons\\INV_Stone_04")
            hsBtn.icon:SetDesaturated(false)
            hsBtn.countText:SetText(hsItem.count > 1 and hsItem.count or "1")
        else
            hsBtn.icon:SetTexture(createHS and createHS.icon or "Interface\\Icons\\INV_Stone_04")
            hsBtn.icon:SetDesaturated(true)
            hsBtn.countText:SetText("")
        end

        if createHS then
            hsBtn:SetAttribute("type2", "spell")
            hsBtn:SetAttribute("spell2", createHS.name)
        end
        if soulwell then
            local soulwellMacro = FLM.BuildSpeechMacro and FLM:BuildSpeechMacro(soulwell.name, "ritualOfSouls")
            if soulwellMacro then
                hsBtn:SetAttribute("shift-type1", "macro")
                hsBtn:SetAttribute("shift-macrotext1", soulwellMacro)
            else
                hsBtn:SetAttribute("shift-type1", "spell")
                hsBtn:SetAttribute("shift-spell1", soulwell.name)
            end
        end
        hsBtn.cachedItem = hsItem
        hsBtn.createSpell = createHS
        hsBtn.soulwellSpell = soulwell
    end

    -- Soulstone Button
    local ssBtn = buttons.soulstone
    if ssBtn then
        local ssItem = FLM:FindBestBagItem(FLM.ITEM_LISTS.soulstone)
        local createSS = FLM.knownSpells.create_soulstone

        ssBtn:SetAttribute("type1", nil)
        ssBtn:SetAttribute("item1", nil)
        ssBtn:SetAttribute("macrotext1", nil)
        ssBtn:SetAttribute("type2", nil)
        ssBtn:SetAttribute("spell2", nil)

        if ssItem then
            local itemAction = ssItem.name or ("item:" .. ssItem.itemID)
            local ssMacro = FLM.BuildSpeechMacro and FLM:BuildSpeechMacro(itemAction, "soulstone", true)
            if ssMacro then
                ssBtn:SetAttribute("type1", "macro")
                ssBtn:SetAttribute("macrotext1", ssMacro)
            else
                ssBtn:SetAttribute("type1", "item")
                ssBtn:SetAttribute("item1", itemAction)
            end
            ssBtn.icon:SetTexture(ssItem.icon or "Interface\\Icons\\INV_Misc_Orb_04")
            ssBtn.icon:SetDesaturated(false)
            ssBtn.countText:SetText("1")
        else
            ssBtn.icon:SetTexture(createSS and createSS.icon or "Interface\\Icons\\INV_Misc_Orb_04")
            ssBtn.icon:SetDesaturated(true)
            ssBtn.countText:SetText("")
        end

        if createSS then
            ssBtn:SetAttribute("type2", "spell")
            ssBtn:SetAttribute("spell2", createSS.name)
        end
        ssBtn.cachedItem = ssItem
        ssBtn.createSpell = createSS
    end

    -- Mount Button
    local mountBtn = buttons.mount
    if mountBtn then
        local mountSpell = FLM:GetBestMountSpell()
        if mountSpell then
            local mountMacro = FLM.BuildSpeechMacro and FLM:BuildSpeechMacro(mountSpell.name, "mount")
            if mountMacro then
                mountBtn:SetAttribute("type", "macro")
                mountBtn:SetAttribute("macrotext", mountMacro)
                mountBtn:SetAttribute("spell", nil)
            else
                mountBtn:SetAttribute("type", "spell")
                mountBtn:SetAttribute("spell", mountSpell.name)
                mountBtn:SetAttribute("macrotext", nil)
            end
            mountBtn.icon:SetTexture(mountSpell.icon)
            mountBtn.icon:SetDesaturated(false)
            mountBtn.spellName = mountSpell.name
            mountBtn.spellID = mountSpell.id
        else
            mountBtn:SetAttribute("type", nil)
            mountBtn:SetAttribute("spell", nil)
            mountBtn:SetAttribute("macrotext", nil)
            mountBtn.icon:SetTexture("Interface\\Icons\\Ability_Mount_Dreadsteed")
            mountBtn.icon:SetDesaturated(true)
            mountBtn.spellName = nil
            mountBtn.spellID = nil
        end
    end

    -- Weapon Stones Drawer (Spellstone & Firestone)
    local stonesDrawer = drawers.stones
    if stonesDrawer then
        local stoneDefs = {}
        if FLM.db.hub.showSpellstone and (FLM.knownSpells.create_spellstone or FLM:FindBestBagItem(FLM.ITEM_LISTS.spellstone)) then
            table.insert(stoneDefs, {
                itemList = FLM.ITEM_LISTS.spellstone,
                createSpell = FLM.knownSpells.create_spellstone,
                fallbackIcon = "Interface\\Icons\\INV_Misc_Gem_Sapphire_01",
                label = "Spellstone",
            })
        end
        if FLM.db.hub.showFirestone and (FLM.knownSpells.create_firestone or FLM:FindBestBagItem(FLM.ITEM_LISTS.firestone)) then
            table.insert(stoneDefs, {
                itemList = FLM.ITEM_LISTS.firestone,
                createSpell = FLM.knownSpells.create_firestone,
                fallbackIcon = "Interface\\Icons\\INV_Ammo_FireTar",
                label = "Firestone",
            })
        end

        drawerButtons.stones = drawerButtons.stones or {}
        for _, b in ipairs(drawerButtons.stones) do
            b:Hide()
        end

        local count = math.max(1, #stoneDefs)
        local pad = 4
        local cellGap = 3
        stonesDrawer:SetSize(pad * 2 + count * BUTTON_SIZE + (count - 1) * cellGap, pad * 2 + BUTTON_SIZE)

        for i, sdef in ipairs(stoneDefs) do
            local btn = drawerButtons.stones[i]
            if not btn then
                btn = CreateFrame("Button", nil, stonesDrawer, "SecureActionButtonTemplate,BackdropTemplate")
                btn:RegisterForClicks("AnyUp", "AnyDown")
                StyleSquareButton(btn, sdef.fallbackIcon)
                if secureHeader then
                    secureHeader:WrapScript(btn, "OnClick", DRAWER_CHILD_PRECLICK, DRAWER_CHILD_POSTCLICK)
                end
                btn.ShowCustomTooltip = function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
                    GameTooltip:SetText(self.stoneLabel or "Weapon Stone", 1, 1, 1)
                    if self.cachedItem then
                        GameTooltip:AddLine("Left-Click: Use " .. (self.cachedItem.name or self.stoneLabel), 0.2, 1, 0.2)
                    else
                        GameTooltip:AddLine("Left-Click: None in bags", 0.6, 0.6, 0.6)
                    end
                    if self.createSpell then
                        GameTooltip:AddLine("Right-Click: " .. self.createSpell.name, 0.6, 0.8, 1)
                    end
                    GameTooltip:Show()
                end
                drawerButtons.stones[i] = btn
            end

            btn:ClearAllPoints()
            local x = pad + (i - 1) * (BUTTON_SIZE + cellGap)
            btn:SetPoint("TOPRIGHT", stonesDrawer, "TOPRIGHT", -x, -pad)

            local held = FLM:FindBestBagItem(sdef.itemList)
            btn:SetAttribute("type1", nil)
            btn:SetAttribute("item1", nil)
            btn:SetAttribute("type2", nil)
            btn:SetAttribute("spell2", nil)

            if held then
                btn:SetAttribute("type1", "item")
                btn:SetAttribute("item1", held.name or ("item:" .. held.itemID))
                btn.icon:SetTexture(held.icon or sdef.fallbackIcon)
                btn.icon:SetDesaturated(false)
                btn.countText:SetText("1")
            else
                btn.icon:SetTexture(sdef.createSpell and sdef.createSpell.icon or sdef.fallbackIcon)
                btn.icon:SetDesaturated(true)
                btn.countText:SetText("")
            end

            if sdef.createSpell then
                btn:SetAttribute("type2", "spell")
                btn:SetAttribute("spell2", sdef.createSpell.name)
            end

            btn.cachedItem = held
            btn.createSpell = sdef.createSpell
            btn.stoneLabel = sdef.label
            btn:Show()
        end

        if #stoneDefs == 0 and buttons.stones then
            buttons.stones.icon:SetDesaturated(true)
        elseif buttons.stones then
            buttons.stones.icon:SetDesaturated(false)
        end
    end

    -- Category Drawers
    BuildSpellDrawerButtons("demons", FLM.MENUS.demons, 5, 1, -1)
    BuildSpellDrawerButtons("curses", FLM.MENUS.curses, 4, 1, -1)
    BuildSpellDrawerButtons("buffs",  FLM.MENUS.buffs,  5, 1, -1)

    -- Update Buffs menu icon dynamically (Fel Armor if known, else Demon Armor)
    if buttons.buffs then
        local armorSpell = FLM.knownSpells.fel_armor or FLM.knownSpells.demon_armor
        if armorSpell then
            buttons.buffs.icon:SetTexture(armorSpell.icon)
        end
    end
end

local function UpdateCooldowns()
    local hsBtn = buttons.healthstone
    if hsBtn and hsBtn.cachedItem then
        local start, dur, enable = FLM.GetContainerItemCooldown(hsBtn.cachedItem.bag, hsBtn.cachedItem.slot)
        CooldownFrame_Set(hsBtn.cooldown, start, dur, enable)
    elseif hsBtn then
        hsBtn.cooldown:Hide()
    end

    local ssBtn = buttons.soulstone
    if ssBtn and ssBtn.cachedItem then
        local start, dur, enable = FLM.GetContainerItemCooldown(ssBtn.cachedItem.bag, ssBtn.cachedItem.slot)
        CooldownFrame_Set(ssBtn.cooldown, start, dur, enable)
    elseif ssBtn then
        ssBtn.cooldown:Hide()
    end
end

function FLM:UpdateShardDisplay()
    if not hubFrame or not self.db then
        return
    end

    local hasExcess, excess, total, cap, outside = self:HasExcessShards()
    local bagIndex = self:GetShardBagIndex()

    shardCountText:SetText(tostring(total))
    shardSubText:SetText(string.format("%d / %d", total, cap))
    shardBagTag:SetText("Bag " .. (bagIndex + 1))

    local ratio = (cap > 0) and math.min(1, total / cap) or 0
    local fillHeight = math.max(1, math.floor((HUB_HEIGHT - 4) * ratio))
    shardFillTex:SetHeight(fillHeight)

    if hasExcess then
        shardFillTex:SetColorTexture(unpack(COLORS.fillExcess))
        shardCountText:SetTextColor(1.0, 0.35, 0.25)
        hubFrame:SetBackdropBorderColor(unpack(COLORS.borderWarn))
    elseif total >= cap and cap > 0 then
        shardFillTex:SetColorTexture(unpack(COLORS.fillFull))
        shardCountText:SetTextColor(0.45, 1.0, 0.55)
        hubFrame:SetBackdropBorderColor(unpack(COLORS.border))
    else
        shardFillTex:SetColorTexture(unpack(COLORS.fillNormal))
        shardCountText:SetTextColor(0.92, 0.85, 1.0)
        hubFrame:SetBackdropBorderColor(unpack(COLORS.border))
    end

    local shardBtn = buttons.shards
    if shardBtn then
        shardBtn.countText:SetText(outside > 0 and ("+" .. outside) or "")
        if hasExcess and self.db.shards.warnExcess then
            shardBtn.warnBorderActive = true
            shardBtn.warnBorderColor = COLORS.borderWarn
            shardBtn:SetBackdropBorderColor(unpack(COLORS.borderWarn))
            if shardBtn.pulseAnim and not shardBtn.pulseAnim:IsPlaying() then
                shardBtn.pulseAnim:Play()
            end
        elseif outside > 0 then
            shardBtn.warnBorderActive = true
            shardBtn.warnBorderColor = COLORS.borderSort
            shardBtn:SetBackdropBorderColor(unpack(COLORS.borderSort))
            if shardBtn.pulseAnim and shardBtn.pulseAnim:IsPlaying() then
                shardBtn.pulseAnim:Stop()
                shardBtn.icon:SetAlpha(1)
            end
        else
            shardBtn.warnBorderActive = false
            shardBtn:SetBackdropBorderColor(unpack(COLORS.border))
            if shardBtn.pulseAnim and shardBtn.pulseAnim:IsPlaying() then
                shardBtn.pulseAnim:Stop()
                shardBtn.icon:SetAlpha(1)
            end
        end
    end
end

function FLM:SyncDrawerSettings()
    SyncDrawerAttributes()
end

function FLM:UpdateHub()
    if not hubFrame or not self.db then
        return
    end
    SyncDrawerAttributes()
    UpdateStoneButtons()
    UpdateCooldowns()
    self:UpdateShardDisplay()
end

function FLM:ApplyHubPosition()
    if not hubFrame or not self.db or InCombatLockdown() then
        return
    end
    local h = self.db.hub
    hubFrame:ClearAllPoints()
    hubFrame:SetPoint(h.point or "CENTER", UIParent, h.relPoint or "CENTER", h.x or 0, h.y or -140)
    hubFrame:SetScale(h.scale or 1.0)
end

function FLM:InitHub()
    hubFrame = CreateFrame("Frame", "FLM_Hub", UIParent, "BackdropTemplate")
    hubFrame:SetSize(HUB_WIDTH, HUB_HEIGHT)
    hubFrame:SetFrameStrata("MEDIUM")
    hubFrame:SetClampedToScreen(true)
    hubFrame:EnableMouse(true)
    hubFrame:SetMovable(true)
    hubFrame:RegisterForDrag("LeftButton")
    ApplySquareBackdrop(hubFrame, COLORS.bg, COLORS.border)

    -- Bottom-up shard capacity fill meter inside center square
    shardFillTex = hubFrame:CreateTexture(nil, "BACKGROUND", nil, 2)
    shardFillTex:SetPoint("BOTTOMLEFT", hubFrame, "BOTTOMLEFT", 2, 2)
    shardFillTex:SetPoint("BOTTOMRIGHT", hubFrame, "BOTTOMRIGHT", -2, 2)
    shardFillTex:SetHeight(1)
    shardFillTex:SetColorTexture(unpack(COLORS.fillNormal))

    shardBagTag = hubFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    shardBagTag:SetPoint("TOP", hubFrame, "TOP", 0, -5)
    shardBagTag:SetTextColor(0.75, 0.65, 0.90)

    shardCountText = hubFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    shardCountText:SetPoint("CENTER", hubFrame, "CENTER", 0, 1)

    shardSubText = hubFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    shardSubText:SetPoint("BOTTOM", hubFrame, "BOTTOM", 0, 5)
    shardSubText:SetTextColor(0.82, 0.82, 0.85)

    hubFrame:SetScript("OnDragStart", function(self)
        if InCombatLockdown() then
            return
        end
        if not FLM.db.hub.locked or IsShiftKeyDown() then
            self:StartMoving()
            self.isMoving = true
        end
    end)

    hubFrame:SetScript("OnDragStop", function(self)
        if not self.isMoving then
            return
        end
        self:StopMovingOrSizing()
        self.isMoving = false
        local point, _, relPoint, x, y = self:GetPoint()
        FLM.db.hub.point = point
        FLM.db.hub.relPoint = relPoint
        FLM.db.hub.x = math.floor(x + 0.5)
        FLM.db.hub.y = math.floor(y + 0.5)
    end)

    hubFrame:SetScript("OnMouseUp", function(self, btn)
        if btn == "RightButton" and not self.isMoving then
            if FLM.ToggleOptions then
                FLM:ToggleOptions()
            end
        end
    end)

    hubFrame:SetScript("OnEnter", function(self)
        local total, inBag, outside = FLM:CountShards()
        local cap = FLM:GetEffectiveShardCap()
        local bagInfo = FLM:GetBagSummary(FLM:GetShardBagIndex())

        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Forever Lock Management", 0.78, 0.52, 1.0)
        GameTooltip:AddLine(string.format("Soul Shards: %d / %d", total, cap), 1, 1, 1)
        GameTooltip:AddLine(string.format("Assigned Bag (Bag %d - %s): %d / %d", bagInfo.uiNumber, bagInfo.name, inBag, bagInfo.slots), 0.75, 0.90, 1.0)
        if outside > 0 then
            GameTooltip:AddLine(string.format("Outside Assigned Bag: %d", outside), 1.0, 0.75, 0.25)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(FLM.db.hub.locked and "Shift+Drag: Move Hub" or "Left-Drag: Move Hub", 0.65, 0.65, 0.65)
        GameTooltip:AddLine("Right-Click: Open Options (/flm)", 0.65, 0.65, 0.65)
        GameTooltip:Show()
    end)
    hubFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Geometry offsets around 72x98 vertical rectangle hub (no bottom buttons)
    local topY = (HUB_HEIGHT / 2) + GAP + (BUTTON_SIZE / 2)  -- +68
    local sideX = (HUB_WIDTH / 2) + GAP + (BUTTON_SIZE / 2)  -- +/-55
    local pairOff = (BUTTON_SIZE / 2) + (GAP / 2)            -- 17
    local sideStep = BUTTON_SIZE + GAP                       -- 34

    -- Top Row (2 buttons): Healthstone (-17, +68) & Soulstone (+17, +68)
    buttons.healthstone = CreateSecureHubButton("FLM_HealthstoneBtn", hubFrame, -pairOff, topY, "Interface\\Icons\\INV_Stone_04")
    buttons.healthstone:HookScript("PreClick", function(_, mouseBtn)
        if mouseBtn == "LeftButton" and IsShiftKeyDown() and FLM.MarkHubSpeechSent then
            FLM:MarkHubSpeechSent("ritualOfSouls")
        end
    end)
    buttons.healthstone.ShowCustomTooltip = function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Healthstone", 0.2, 1.0, 0.2)
        if self.cachedItem then
            GameTooltip:AddLine("Left-Click: Use " .. (self.cachedItem.name or "Healthstone"), 1, 1, 1)
        else
            GameTooltip:AddLine("Left-Click: None in bags", 0.6, 0.6, 0.6)
        end
        if self.createSpell then
            GameTooltip:AddLine("Right-Click: " .. self.createSpell.name, 0.6, 0.85, 1.0)
        end
        if self.soulwellSpell then
            GameTooltip:AddLine("Shift+Left-Click: " .. self.soulwellSpell.name, 0.8, 0.6, 1.0)
        end
        GameTooltip:Show()
    end

    buttons.soulstone = CreateSecureHubButton("FLM_SoulstoneBtn", hubFrame, pairOff, topY, "Interface\\Icons\\INV_Misc_Orb_04")
    buttons.soulstone:HookScript("PreClick", function(_, mouseBtn)
        if mouseBtn == "LeftButton" and not IsShiftKeyDown() and not IsControlKeyDown() and not IsAltKeyDown() and FLM.MarkHubSpeechSent then
            FLM:MarkHubSpeechSent("soulstone")
        end
    end)
    buttons.soulstone.ShowCustomTooltip = function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Soulstone", 0.78, 0.52, 1.0)
        if self.cachedItem then
            GameTooltip:AddLine("Left-Click: Use " .. (self.cachedItem.name or "Soulstone"), 1, 1, 1)
        else
            GameTooltip:AddLine("Left-Click: None in bags", 0.6, 0.6, 0.6)
        end
        if self.createSpell then
            GameTooltip:AddLine("Right-Click: " .. self.createSpell.name, 0.6, 0.85, 1.0)
        end
        GameTooltip:Show()
    end

    -- Right Column (3 buttons): Demons (+55, +34), Curses (+55, 0), Buffs (+55, -34)
    buttons.demons = CreateMenuToggleButton("FLM_DemonsMenuBtn", hubFrame, sideX, sideStep, "Interface\\Icons\\Spell_Shadow_SummonVoidWalker", ">")
    buttons.demons.ShowCustomTooltip = function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Demons", 0.78, 0.52, 1.0)
        GameTooltip:AddLine("Click: Toggle Demon Summon Drawer", 1, 1, 1)
        GameTooltip:Show()
    end

    buttons.curses = CreateMenuToggleButton("FLM_CursesMenuBtn", hubFrame, sideX, 0, "Interface\\Icons\\Spell_Shadow_CurseOfSargeras", ">")
    buttons.curses.ShowCustomTooltip = function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Curses", 0.78, 0.52, 1.0)
        GameTooltip:AddLine("Click: Toggle Curses Drawer", 1, 1, 1)
        GameTooltip:Show()
    end

    buttons.buffs = CreateMenuToggleButton("FLM_BuffsMenuBtn", hubFrame, sideX, -sideStep, "Interface\\Icons\\Spell_Shadow_FelArmour", ">")
    buttons.buffs.ShowCustomTooltip = function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Buffs & Utility", 0.78, 0.52, 1.0)
        GameTooltip:AddLine("Click: Toggle Buffs & Utility Drawer", 1, 1, 1)
        GameTooltip:Show()
    end

    -- Left Column (3 buttons): Weapon Stones (-55, +34), Mount (-55, 0), Shard Manager (-55, -34)
    buttons.stones = CreateMenuToggleButton("FLM_StonesMenuBtn", hubFrame, -sideX, sideStep, "Interface\\Icons\\INV_Misc_Gem_Sapphire_01", "<")
    buttons.stones.ShowCustomTooltip = function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Firestone & Spellstone", 0.78, 0.52, 1.0)
        GameTooltip:AddLine("Click: Toggle Weapon Stones Drawer", 1, 1, 1)
        GameTooltip:Show()
    end

    buttons.mount = CreateSecureHubButton("FLM_MountBtn", hubFrame, -sideX, 0, "Interface\\Icons\\Ability_Mount_Dreadsteed")
    buttons.mount:HookScript("PreClick", function(_, mouseBtn)
        if mouseBtn == "LeftButton" and FLM.MarkHubSpeechSent then
            FLM:MarkHubSpeechSent("mount")
        end
    end)
    buttons.mount.ShowCustomTooltip = function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        if self.spellName then
            GameTooltip:SetText(self.spellName, 1, 1, 1)
            GameTooltip:AddLine("Left-Click: Summon Mount", 0.6, 0.85, 1.0)
        else
            GameTooltip:SetText("Warlock Mount", 0.6, 0.6, 0.6)
            GameTooltip:AddLine("Not learned yet", 0.8, 0.4, 0.4)
        end
        GameTooltip:Show()
    end

    buttons.shards = CreateFrame("Button", "FLM_ShardActionBtn", hubFrame, "BackdropTemplate")
    buttons.shards:SetPoint("CENTER", hubFrame, "CENTER", -sideX, -sideStep)
    buttons.shards:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    buttons.shards:EnableMouseWheel(true)
    StyleSquareButton(buttons.shards, "Interface\\Icons\\INV_Misc_Gem_Amethyst_02")

    local pulse = buttons.shards.icon:CreateAnimationGroup()
    local fadeOut = pulse:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(1.0)
    fadeOut:SetToAlpha(0.35)
    fadeOut:SetDuration(0.45)
    fadeOut:SetOrder(1)
    local fadeIn = pulse:CreateAnimation("Alpha")
    fadeIn:SetFromAlpha(0.35)
    fadeIn:SetToAlpha(1.0)
    fadeIn:SetDuration(0.45)
    fadeIn:SetOrder(2)
    pulse:SetLooping("REPEAT")
    buttons.shards.pulseAnim = pulse

    buttons.shards:SetScript("OnClick", function(self, mouseBtn)
        if mouseBtn == "LeftButton" then
            local moved = FLM:SortShards()
            local bagInfo = FLM:GetBagSummary(FLM:GetShardBagIndex())
            if moved > 0 then
                FLM:Print(string.format("Moved %d Soul Shard(s) into Bag %d (%s).", moved, bagInfo.uiNumber, bagInfo.name))
            else
                local _, _, outside = FLM:CountShards()
                if outside > 0 then
                    FLM:Print(string.format("Bag %d (%s) is full (%d shard(s) outside).", bagInfo.uiNumber, bagInfo.name, outside))
                end
            end
            FLM:UpdateShardDisplay()
        elseif mouseBtn == "RightButton" then
            local destroyed, reason = FLM:DestroyExcessShards()
            if reason then
                FLM:Print(reason)
            elseif destroyed > 0 then
                FLM:Print(string.format("Destroyed %d excess Soul Shard(s).", destroyed))
            end
            if self.ShowCustomTooltip then
                self:ShowCustomTooltip()
            end
        end
    end)

    buttons.shards:SetScript("OnMouseWheel", function(self, delta)
        if FLM.db.shards.limitToBagCapacity then
            return
        end
        local cur = FLM.db.shards.maxShards or 20
        local nextVal = math.max(1, math.min(32, cur + (delta > 0 and 1 or -1)))
        if nextVal ~= cur then
            FLM.db.shards.maxShards = nextVal
            FLM:UpdateShardDisplay()
            if self.ShowCustomTooltip then
                self:ShowCustomTooltip()
            end
        end
    end)

    buttons.shards.ShowCustomTooltip = function(self)
        local hasExcess, excess, total, cap, outside = FLM:HasExcessShards()
        local bagInfo = FLM:GetBagSummary(FLM:GetShardBagIndex())

        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Soul Shard Manager", 0.78, 0.52, 1.0)
        GameTooltip:AddLine(string.format("Total: %d   |   Limit: %d (%s)", total, cap, FLM.db.shards.limitToBagCapacity and ("Bag " .. bagInfo.uiNumber) or "Custom"), 1, 1, 1)
        if outside > 0 then
            GameTooltip:AddLine(string.format("Outside Assigned Bag: %d", outside), 0.35, 0.80, 1.0)
        end
        if hasExcess then
            GameTooltip:AddLine(string.format("Excess Shards: %d (Right-Click to Destroy)", excess), 1.0, 0.35, 0.25)
        else
            GameTooltip:AddLine("No excess shards.", 0.3, 0.95, 0.4)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Left-Click: Sort shards into Bag " .. bagInfo.uiNumber, 0.75, 0.75, 0.75)
        GameTooltip:AddLine("Right-Click: Destroy excess shards", 0.75, 0.75, 0.75)
        if not FLM.db.shards.limitToBagCapacity then
            GameTooltip:AddLine("Mouse Wheel: Adjust shard cap", 0.75, 0.75, 0.75)
        end
        GameTooltip:Show()
    end

    -- Pull-out Drawers
    secureHeader = CreateFrame("Frame", "FLM_SecureHeader", UIParent, "SecureHandlerStateTemplate")

    drawers.demons = CreateDrawerFrame("FLM_DemonsDrawer", buttons.demons, "TOPLEFT", "TOPRIGHT", 6, 4)
    drawers.curses = CreateDrawerFrame("FLM_CursesDrawer", buttons.curses, "TOPLEFT", "TOPRIGHT", 6, 4)
    drawers.buffs  = CreateDrawerFrame("FLM_BuffsDrawer",  buttons.buffs,  "TOPLEFT", "TOPRIGHT", 6, 4)
    drawers.stones = CreateDrawerFrame("FLM_StonesDrawer", buttons.stones, "TOPRIGHT", "TOPLEFT", -6, 4)

    local allDrawers = { drawers.demons, drawers.curses, drawers.buffs, drawers.stones }
    secureHeader:SetAttribute("drawerCount", #allDrawers)
    for i, d in ipairs(allDrawers) do
        secureHeader:SetFrameRef("drawer" .. i, d)
    end

    WireDrawerToggle(buttons.demons, 1)
    WireDrawerToggle(buttons.curses, 2)
    WireDrawerToggle(buttons.buffs,  3)
    WireDrawerToggle(buttons.stones, 4)

    self:ApplyHubPosition()
    SyncDrawerAttributes()
    self:UpdateHub()

    self:RegisterEvent("BAG_UPDATE_COOLDOWN", UpdateCooldowns)
    self:RegisterEvent("SPELL_UPDATE_COOLDOWN", UpdateCooldowns)
    self:RegisterEvent("GROUP_ROSTER_UPDATE", function()
        FLM:UpdateHub()
    end)
    self:RegisterEvent("CVAR_UPDATE", function(_, cvar)
        if cvar == "ActionButtonUseKeyDown" then
            SyncDrawerAttributes()
        end
    end)
    self:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        if pendingSecureUpdate then
            pendingSecureUpdate = false
            FLM:UpdateHub()
        end
    end)
end
