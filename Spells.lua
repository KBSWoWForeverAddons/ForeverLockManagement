local _, FLM = ...
if not FLM or not FLM.isWarlock then
    return
end

FLM.SOUL_SHARD_ID = 6265

-- Ordered from highest rank/tier to lowest for automatic bag lookup
FLM.ITEM_LISTS = {
    healthstone = {
        22105, 22104, 22103, -- Master Healthstone (2/2, 1/2, 0/2)
        19013, 19012, 9421,  -- Major Healthstone
        19011, 19010, 5510,  -- Greater Healthstone
        19009, 19008, 5509,  -- Healthstone
        19007, 19006, 5511,  -- Lesser Healthstone
        19005, 19004, 5512,  -- Minor Healthstone
    },
    soulstone = {
        22116, -- Master Soulstone
        16896, -- Major Soulstone
        16895, -- Greater Soulstone
        16893, -- Soulstone
        16892, -- Lesser Soulstone
        5232,  -- Minor Soulstone
    },
    firestone = {
        22128, -- Master Firestone
        13701, -- Major Firestone
        13700, -- Greater Firestone
        13699, -- Firestone
        1254,  -- Lesser Firestone
    },
    spellstone = {
        22646, -- Master Spellstone
        13603, -- Major Spellstone
        13602, -- Greater Spellstone
        5522,  -- Spellstone
    },
}

-- Spells grouped by function; ranks ordered highest-to-lowest where multiple IDs exist
FLM.SPELL_DEFS = {
    -- Stone Creation & Soulwell
    create_healthstone = {
        ids = { 27230, 11730, 11729, 5723, 5720, 6202, 6201 },
        fallbackIcon = "Interface\\Icons\\INV_Stone_04",
        label = "Create Healthstone",
    },
    ritual_of_souls = {
        ids = { 29893 },
        fallbackIcon = "Interface\\Icons\\Spell_Shadow_Shadesofdarkness",
        label = "Ritual of Souls",
    },
    create_soulstone = {
        ids = { 27238, 20757, 20756, 20755, 20752, 693 },
        fallbackIcon = "Interface\\Icons\\INV_Misc_Orb_04",
        label = "Create Soulstone",
    },
    create_firestone = {
        ids = { 27250, 17953, 17952, 17951, 6366 },
        fallbackIcon = "Interface\\Icons\\INV_Ammo_FireTar",
        label = "Create Firestone",
    },
    create_spellstone = {
        ids = { 28172, 17728, 17727, 2362 },
        fallbackIcon = "Interface\\Icons\\INV_Misc_Gem_Sapphire_01",
        label = "Create Spellstone",
    },

    -- Mounts
    mount_dreadsteed = {
        ids = { 23161 },
        fallbackIcon = "Interface\\Icons\\Ability_Mount_Dreadsteed",
        label = "Summon Dreadsteed",
    },
    mount_felsteed = {
        ids = { 5784 },
        fallbackIcon = "Interface\\Icons\\Spell_Nature_Swiftness",
        label = "Summon Felsteed",
    },

    -- Demons
    fel_domination = {
        ids = { 18708 },
        fallbackIcon = "Interface\\Icons\\Spell_Nature_RemoveCurse",
        label = "Fel Domination",
    },
    summon_imp = {
        ids = { 688 },
        fallbackIcon = "Interface\\Icons\\Spell_Shadow_SummonImp",
        label = "Summon Imp",
    },
    summon_voidwalker = {
        ids = { 697 },
        fallbackIcon = "Interface\\Icons\\Spell_Shadow_SummonVoidWalker",
        label = "Summon Voidwalker",
    },
    summon_succubus = {
        ids = { 712 },
        fallbackIcon = "Interface\\Icons\\Spell_Shadow_SummonSuccubus",
        label = "Summon Succubus",
    },
    summon_felhunter = {
        ids = { 691 },
        fallbackIcon = "Interface\\Icons\\Spell_Shadow_SummonFelHunter",
        label = "Summon Felhunter",
    },
    summon_felguard = {
        ids = { 30146 },
        fallbackIcon = "Interface\\Icons\\Spell_Shadow_SummonFelGuard",
        label = "Summon Felguard",
    },
    inferno = {
        ids = { 1122 },
        fallbackIcon = "Interface\\Icons\\Spell_Shadow_SummonInfernal",
        label = "Inferno",
    },
    ritual_of_doom = {
        ids = { 18540 },
        fallbackIcon = "Interface\\Icons\\Spell_Shadow_AntiMagicShell",
        label = "Ritual of Doom",
    },
    enslave_demon = {
        ids = { 1098, 11725, 11726 },
        fallbackIcon = "Interface\\Icons\\Spell_Shadow_EnslaveDemon",
        label = "Enslave Demon",
    },
    demonic_sacrifice = {
        ids = { 18788 },
        fallbackIcon = "Interface\\Icons\\Spell_Shadow_PsychicScream",
        label = "Demonic Sacrifice",
    },

    -- Buffs & Utility
    fel_armor = {
        ids = { 28189, 28176 },
        fallbackIcon = "Interface\\Icons\\Spell_Shadow_FelArmour",
        label = "Fel Armor",
    },
    demon_armor = {
        ids = { 27260, 11735, 11734, 11733, 706, 696, 687 },
        fallbackIcon = "Interface\\Icons\\Spell_Shadow_RagingScream",
        label = "Demon Armor",
    },
    soul_link = {
        ids = { 19028 },
        fallbackIcon = "Interface\\Icons\\Spell_Shadow_GatherShadows",
        label = "Soul Link",
    },
    shadow_ward = {
        ids = { 28610, 11739, 11738, 6229 },
        fallbackIcon = "Interface\\Icons\\Spell_Shadow_AntiShadow",
        label = "Shadow Ward",
    },
    unending_breath = {
        ids = { 5697 },
        fallbackIcon = "Interface\\Icons\\Spell_Shadow_DemonBreath",
        label = "Unending Breath",
    },
    detect_invisibility = {
        ids = { 2970, 11743, 132 },
        fallbackIcon = "Interface\\Icons\\Spell_Shadow_DetectInvisibility",
        label = "Detect Invisibility",
    },
    eye_of_kilrogg = {
        ids = { 126 },
        fallbackIcon = "Interface\\Icons\\Spell_Shadow_EvilEye",
        label = "Eye of Kilrogg",
    },
    ritual_of_summoning = {
        ids = { 698 },
        fallbackIcon = "Interface\\Icons\\Spell_Shadow_Twilight",
        label = "Ritual of Summoning",
    },
    banish = {
        ids = { 18647, 710 },
        fallbackIcon = "Interface\\Icons\\Spell_Shadow_Cripple",
        label = "Banish",
    },

    -- Curses
    curse_agony = {
        ids = { 27218, 11713, 11712, 11711, 1014, 6217, 980 },
        fallbackIcon = "Interface\\Icons\\Spell_Shadow_CurseOfSargeras",
        label = "Curse of Agony",
    },
    curse_doom = {
        ids = { 30910, 603 },
        fallbackIcon = "Interface\\Icons\\Spell_Shadow_AuraOfDarkness",
        label = "Curse of Doom",
    },
    curse_elements = {
        ids = { 27228, 11722, 11721, 1490 },
        fallbackIcon = "Interface\\Icons\\Spell_Shadow_ChillTouch",
        label = "Curse of the Elements",
    },
    curse_shadow = {
        ids = { 27229, 17937, 17862 },
        fallbackIcon = "Interface\\Icons\\Spell_Shadow_CurseOfAchimonde",
        label = "Curse of Shadow",
    },
    curse_weakness = {
        ids = { 27224, 11708, 11707, 7646, 6205, 1108, 702 },
        fallbackIcon = "Interface\\Icons\\Spell_Shadow_CurseOfMannoroth",
        label = "Curse of Weakness",
    },
    curse_recklessness = {
        ids = { 27226, 11717, 7658, 704 },
        fallbackIcon = "Interface\\Icons\\Spell_Shadow_UnholyStrength",
        label = "Curse of Recklessness",
    },
    curse_tongues = {
        ids = { 11719, 1714 },
        fallbackIcon = "Interface\\Icons\\Spell_Shadow_CurseOfTounges",
        label = "Curse of Tongues",
    },
    curse_exhaustion = {
        ids = { 18223 },
        fallbackIcon = "Interface\\Icons\\Spell_Shadow_GrimWard",
        label = "Curse of Exhaustion",
    },
}

FLM.MENUS = {
    demons = {
        "fel_domination",
        "summon_imp",
        "summon_voidwalker",
        "summon_succubus",
        "summon_felhunter",
        "summon_felguard",
        "inferno",
        "ritual_of_doom",
        "enslave_demon",
        "demonic_sacrifice",
    },
    buffs = {
        "fel_armor",
        "demon_armor",
        "soul_link",
        "shadow_ward",
        "unending_breath",
        "detect_invisibility",
        "eye_of_kilrogg",
        "ritual_of_summoning",
        "banish",
    },
    curses = {
        "curse_agony",
        "curse_doom",
        "curse_elements",
        "curse_shadow",
        "curse_weakness",
        "curse_recklessness",
        "curse_tongues",
        "curse_exhaustion",
    },
}

-- Fear-immunity auras checked on hostile target
FLM.ANTI_FEAR_AURA_IDS = {
    [6346]  = true, -- Fear Ward
    [18499] = true, -- Berserker Rage
    [12292] = true, -- Death Wish
    [7744]  = true, -- Will of the Forsaken
    [45438] = true, -- Ice Block
    [642]   = true, -- Divine Shield
    [1020]  = true, -- Divine Shield (Rank 2)
    [19574] = true, -- Bestial Wrath
    [34471] = true, -- The Beast Within
    [31224] = true, -- Cloak of Shadows
    [8178]  = true, -- Grounding Totem Effect
    [49039] = true, -- Lichborne
    [16689] = true, -- Nature's Grasp (placeholder avoided) -> keep strict fear immunities
}
FLM.ANTI_FEAR_AURA_IDS[16689] = nil

FLM.ANTI_FEAR_AURA_NAMES = {}
for id in pairs(FLM.ANTI_FEAR_AURA_IDS) do
    local name = FLM.GetSpellInfo(id)
    if name then
        FLM.ANTI_FEAR_AURA_NAMES[name] = true
    end
end
-- English fallbacks in case GetSpellInfo didn't resolve at load time
local antiFearFallbacks = {
    "Fear Ward",
    "Berserker Rage",
    "Death Wish",
    "Will of the Forsaken",
    "Ice Block",
    "Divine Shield",
    "Bestial Wrath",
    "The Beast Within",
    "Cloak of Shadows",
    "Grounding Totem Effect",
    "Lichborne",
}
for _, fallbackName in ipairs(antiFearFallbacks) do
    FLM.ANTI_FEAR_AURA_NAMES[fallbackName] = true
end

FLM.SHADOW_TRANCE_IDS = { [17941] = true }
FLM.SHADOW_TRANCE_NAMES = { ["Shadow Trance"] = true }
do
    local name = FLM.GetSpellInfo(17941)
    if name then
        FLM.SHADOW_TRANCE_NAMES[name] = true
    end
end

FLM.BACKLASH_IDS = { [34936] = true }
FLM.BACKLASH_NAMES = { ["Backlash"] = true }
do
    local name = FLM.GetSpellInfo(34936)
    if name then
        FLM.BACKLASH_NAMES[name] = true
    end
end

-- Resolved highest known spells cache: FLM.knownSpells[key] = { id = ..., name = ..., icon = ... }
FLM.knownSpells = {}

function FLM:RefreshKnownSpells()
    wipe(self.knownSpells)
    for key, def in pairs(self.SPELL_DEFS) do
        local bestID, bestName, bestIcon
        for _, spellID in ipairs(def.ids) do
            if self.IsSpellKnown(spellID) then
                local name, icon = self.GetSpellInfo(spellID)
                bestID = spellID
                bestName = name or def.label
                bestIcon = icon or def.fallbackIcon
                break
            end
        end
        if bestID then
            self.knownSpells[key] = {
                id = bestID,
                name = bestName,
                icon = bestIcon,
                label = def.label,
            }
        end
    end
end

function FLM:GetBestMountSpell()
    if self.knownSpells.mount_dreadsteed then
        return self.knownSpells.mount_dreadsteed
    end
    if self.knownSpells.mount_felsteed then
        return self.knownSpells.mount_felsteed
    end
    return nil
end

function FLM:FindBestBagItem(idList)
    if not idList then
        return nil
    end
    local lookup = {}
    for priority, itemID in ipairs(idList) do
        lookup[itemID] = priority
    end

    local bestPriority = math.huge
    local bestBag, bestSlot, bestItemID, bestIcon, bestCount
    for bag = 0, NUM_BAG_SLOTS do
        local slots = self.GetContainerNumSlots(bag)
        for slot = 1, slots do
            local info = self.GetContainerItemInfo(bag, slot)
            if info and info.itemID and lookup[info.itemID] then
                local prio = lookup[info.itemID]
                if prio < bestPriority then
                    bestPriority = prio
                    bestBag = bag
                    bestSlot = slot
                    bestItemID = info.itemID
                    bestIcon = info.iconFileID
                    bestCount = info.stackCount or 1
                end
            end
        end
    end

    if not bestItemID then
        return nil
    end
    local itemName = self.GetItemInfo(bestItemID)
    return {
        bag = bestBag,
        slot = bestSlot,
        itemID = bestItemID,
        name = itemName,
        icon = bestIcon,
        count = bestCount,
    }
end

function FLM:InitSpells()
    self:RefreshKnownSpells()
    self:RegisterEvent("SPELLS_CHANGED", function()
        FLM:RefreshKnownSpells()
        if FLM.UpdateHub then
            FLM:UpdateHub()
        end
    end)
end
