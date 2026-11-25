local addonName, FLM = ...
_G.ForeverLockManagement = FLM

local _, playerClass = UnitClass("player")
FLM.isWarlock = (playerClass == "WARLOCK")
if not FLM.isWarlock then
    return
end

FLM.addonName = addonName
FLM.title = "Forever Lock Management"

FLM.DEFAULTS = {
    hub = {
        locked = false,
        scale = 1.0,
        point = "CENTER",
        relPoint = "CENTER",
        x = 0,
        y = -140,
        showFirestone = true,
        showSpellstone = true,
    },
    shards = {
        bagIndex = 4, -- 0..4 in WoW container API (displayed as Bag 1..5)
        autoSort = true,
        limitToBagCapacity = true,
        maxShards = 20,
        warnExcess = true,
    },
    speech = {
        enabled = true,
        summon = true,
        soulstone = true,
        ritualOfSouls = true,
        demon = true,
        mount = false,
        whisperSoulstone = false,
        customLines = {},
    },
    warnings = {
        enabled = true,
        sound = true,
        antiFear = true,
        shadowTrance = true,
        backlash = true,
        creatureAlert = true,
        scale = 1.0,
        point = "CENTER",
        relPoint = "CENTER",
        x = 0,
        y = 110,
    },
}

local function CopyDefaults(dst, src)
    if type(dst) ~= "table" then
        dst = {}
    end
    for k, v in pairs(src) do
        if type(v) == "table" then
            dst[k] = CopyDefaults(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end

function FLM:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff9b59b6[FLM]|r " .. tostring(msg))
end

-- API Compatibility Wrappers
function FLM.GetSpellInfo(spellID)
    if not spellID then
        return nil, nil
    end
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellID)
        if info then
            return info.name, info.iconID
        end
        return nil, nil
    elseif GetSpellInfo then
        local name, _, icon = GetSpellInfo(spellID)
        return name, icon
    end
    return nil, nil
end

function FLM.GetSpellCooldown(spellID)
    if not spellID then
        return 0, 0, true
    end
    if C_Spell and C_Spell.GetSpellCooldown then
        local info = C_Spell.GetSpellCooldown(spellID)
        if info then
            return info.startTime or 0, info.duration or 0, info.isEnabled
        end
        return 0, 0, true
    elseif GetSpellCooldown then
        local start, duration, enabled = GetSpellCooldown(spellID)
        return start or 0, duration or 0, enabled
    end
    return 0, 0, true
end

function FLM.IsSpellKnown(spellID)
    if not spellID then
        return false
    end
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        if C_SpellBook.IsSpellKnown(spellID) then
            return true
        end
    end
    if IsSpellKnown and IsSpellKnown(spellID) then
        return true
    end
    if IsPlayerSpell and IsPlayerSpell(spellID) then
        return true
    end
    return false
end

function FLM.GetItemCount(itemID)
    if not itemID then
        return 0
    end
    if C_Item and C_Item.GetItemCount then
        return C_Item.GetItemCount(itemID) or 0
    elseif GetItemCount then
        return GetItemCount(itemID) or 0
    end
    return 0
end

function FLM.GetItemInfo(itemID)
    if not itemID then
        return nil
    end
    if C_Item and C_Item.GetItemInfo then
        return C_Item.GetItemInfo(itemID)
    elseif GetItemInfo then
        return GetItemInfo(itemID)
    end
    return nil
end

function FLM.GetContainerNumSlots(bag)
    if C_Container and C_Container.GetContainerNumSlots then
        return C_Container.GetContainerNumSlots(bag) or 0
    elseif GetContainerNumSlots then
        return GetContainerNumSlots(bag) or 0
    end
    return 0
end

function FLM.GetContainerItemInfo(bag, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if type(info) == "table" then
            return info
        end
        return nil
    elseif GetContainerItemInfo then
        local icon, count, locked, _, _, _, link, _, _, itemID = GetContainerItemInfo(bag, slot)
        if not icon and not itemID and not link then
            return nil
        end
        if not itemID and link then
            itemID = tonumber(string.match(link, "item:(%d+)"))
        end
        return {
            iconFileID = icon,
            stackCount = count,
            isLocked = locked,
            hyperlink = link,
            itemID = itemID,
        }
    end
    return nil
end

function FLM.GetContainerItemCooldown(bag, slot)
    if C_Container and C_Container.GetContainerItemCooldown then
        return C_Container.GetContainerItemCooldown(bag, slot)
    elseif GetContainerItemCooldown then
        return GetContainerItemCooldown(bag, slot)
    end
    return 0, 0, 0
end

function FLM.PickupContainerItem(bag, slot)
    if C_Container and C_Container.PickupContainerItem then
        return C_Container.PickupContainerItem(bag, slot)
    elseif PickupContainerItem then
        return PickupContainerItem(bag, slot)
    end
end

function FLM.GetBagName(bag)
    if C_Container and C_Container.GetBagName then
        return C_Container.GetBagName(bag)
    elseif GetBagName then
        return GetBagName(bag)
    end
    return nil
end

function FLM.IsBagSoulPouch(bag)
    if bag == 0 then
        return false
    end
    if C_Container and C_Container.GetContainerNumFreeSlots then
        local _, bagType = C_Container.GetContainerNumFreeSlots(bag)
        if bagType == 4 then -- 4 = Soul Bag family bitmask
            return true
        end
    elseif GetContainerNumFreeSlots then
        local _, bagType = GetContainerNumFreeSlots(bag)
        if bagType == 4 then
            return true
        end
    end
    return false
end

local function IsSecret(v)
    return issecretvalue and issecretvalue(v)
end

function FLM.UnitHasAura(unit, auraNameSet, auraIdSet, filter)
    if not UnitExists(unit) then
        return false, nil, nil
    end

    if unit == "player" and auraIdSet and C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        for id in pairs(auraIdSet) do
            local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, id)
            if ok and aura and not IsSecret(aura) then
                local aName = not IsSecret(aura.name) and aura.name or nil
                local aIcon = not IsSecret(aura.icon) and aura.icon or nil
                return true, aName, aIcon
            end
        end
    end

    if C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret() then
        return false, nil, nil
    end

    local idx = 1
    while true do
        local name, icon, spellId
        if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
            local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, idx, filter)
            if not ok or not aura or IsSecret(aura) then
                break
            end
            name = not IsSecret(aura.name) and aura.name or nil
            icon = not IsSecret(aura.icon) and aura.icon or nil
            spellId = not IsSecret(aura.spellId) and aura.spellId or nil
        elseif UnitAura then
            local ok, uName, uIcon, _, _, _, _, _, _, uSpellId = pcall(UnitAura, unit, idx, filter)
            if not ok or not uName or IsSecret(uName) then
                break
            end
            name = uName
            icon = not IsSecret(uIcon) and uIcon or nil
            spellId = not IsSecret(uSpellId) and uSpellId or nil
        else
            break
        end

        if (auraIdSet and spellId and auraIdSet[spellId]) or (auraNameSet and name and auraNameSet[name]) then
            return true, name, icon
        end
        idx = idx + 1
    end
    return false, nil, nil
end

function FLM.SendChatMessage(msg, chatType, language, target)
    if C_ChatInfo and C_ChatInfo.SendChatMessage then
        C_ChatInfo.SendChatMessage(msg, chatType, language, target)
    elseif SendChatMessage then
        SendChatMessage(msg, chatType, language, target)
    end
end

-- Event Bus
local eventHandlers = {}
local eventFrame = CreateFrame("Frame", "FLM_EventFrame")

function FLM:RegisterEvent(event, callback)
    if not eventHandlers[event] then
        eventHandlers[event] = {}
        pcall(eventFrame.RegisterEvent, eventFrame, event)
    end
    table.insert(eventHandlers[event], callback)
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    local handlers = eventHandlers[event]
    if not handlers then
        return
    end
    for i = 1, #handlers do
        handlers[i](event, ...)
    end
end)

function FLM:ResetPositions()
    self.db.hub.point = self.DEFAULTS.hub.point
    self.db.hub.relPoint = self.DEFAULTS.hub.relPoint
    self.db.hub.x = self.DEFAULTS.hub.x
    self.db.hub.y = self.DEFAULTS.hub.y
    self.db.warnings.point = self.DEFAULTS.warnings.point
    self.db.warnings.relPoint = self.DEFAULTS.warnings.relPoint
    self.db.warnings.x = self.DEFAULTS.warnings.x
    self.db.warnings.y = self.DEFAULTS.warnings.y
    if self.ApplyHubPosition and not InCombatLockdown() then
        self:ApplyHubPosition()
    end
    if self.ApplyWarningsPosition then
        self:ApplyWarningsPosition()
    end
    self:Print("Positions reset to defaults.")
end

local function InitDatabase()
    ForeverLockManagementDB = CopyDefaults(ForeverLockManagementDB, FLM.DEFAULTS)
    FLM.db = ForeverLockManagementDB
end

FLM:RegisterEvent("PLAYER_LOGIN", function()
    InitDatabase()
    if FLM.InitSpells then
        FLM:InitSpells()
    end
    if FLM.InitShards then
        FLM:InitShards()
    end
    if FLM.InitHub then
        FLM:InitHub()
    end
    if FLM.InitSpeech then
        FLM:InitSpeech()
    end
    if FLM.InitWarnings then
        FLM:InitWarnings()
    end
    if FLM.InitOptions then
        FLM:InitOptions()
    end
    FLM:Print("Loaded. Type /flm or /lock for options.")
end)

SLASH_FOREVERLOCKMANAGEMENT1 = "/flm"
SLASH_FOREVERLOCKMANAGEMENT2 = "/lock"
SlashCmdList["FOREVERLOCKMANAGEMENT"] = function(msg)
    local cmd = string.lower(string.trim(msg or ""))
    if cmd == "sort" then
        if FLM.SortShards then
            local moved = FLM:SortShards()
            FLM:Print("Sorted " .. tostring(moved or 0) .. " Soul Shard(s).")
        end
    elseif cmd == "destroy" then
        if FLM.DestroyExcessShards then
            local destroyed, reason = FLM:DestroyExcessShards()
            if reason then
                FLM:Print(reason)
            else
                FLM:Print("Destroyed " .. tostring(destroyed or 0) .. " excess Soul Shard(s).")
            end
        end
    elseif cmd == "test" then
        if FLM.ToggleTestWarnings then
            FLM:ToggleTestWarnings()
        end
    elseif cmd == "speech" or cmd == "testspeech" then
        if FLM.PreviewSpeech then
            FLM:PreviewSpeech()
        end
    elseif cmd == "customspeech" or cmd == "editspeech" then
        if FLM.ToggleSpeechDialog then
            FLM:ToggleSpeechDialog()
        end
    elseif cmd == "reset" then
        FLM:ResetPositions()
    else
        if FLM.ToggleOptions then
            FLM:ToggleOptions()
        end
    end
end
