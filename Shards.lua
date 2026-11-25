local _, FLM = ...
if not FLM or not FLM.isWarlock then
    return
end

local SOUL_SHARD_ID = FLM.SOUL_SHARD_ID
local sortPendingAfterCombat = false

function FLM:GetShardBagIndex()
    local idx = self.db and self.db.shards and self.db.shards.bagIndex or 4
    if idx < 0 then
        idx = 0
    elseif idx > NUM_BAG_SLOTS then
        idx = NUM_BAG_SLOTS
    end
    return idx
end

function FLM:GetBagCapacity(bagIndex)
    return self.GetContainerNumSlots(bagIndex)
end

function FLM:GetBagSummary(bagIndex)
    local slots = self.GetContainerNumSlots(bagIndex)
    local name = self.GetBagName(bagIndex)
    if bagIndex == 0 and (not name or name == "") then
        name = "Backpack"
    elseif not name or name == "" then
        name = (slots == 0) and "Empty Slot" or ("Bag " .. (bagIndex + 1))
    end
    return {
        index = bagIndex,
        uiNumber = bagIndex + 1,
        name = name,
        slots = slots,
        isSoulPouch = self.IsBagSoulPouch(bagIndex),
    }
end

function FLM:GetEffectiveShardCap()
    local shardsDB = self.db.shards
    local targetBag = self:GetShardBagIndex()
    local bagCap = self:GetBagCapacity(targetBag)
    if shardsDB.limitToBagCapacity and bagCap > 0 then
        return bagCap
    end
    return shardsDB.maxShards or 20
end

function FLM:CountShards()
    local targetBag = self:GetShardBagIndex()
    local total = 0
    local inAssigned = 0
    local outside = 0

    for bag = 0, NUM_BAG_SLOTS do
        local slots = self.GetContainerNumSlots(bag)
        for slot = 1, slots do
            local info = self.GetContainerItemInfo(bag, slot)
            if info and info.itemID == SOUL_SHARD_ID then
                local count = info.stackCount or 1
                total = total + count
                if bag == targetBag then
                    inAssigned = inAssigned + count
                else
                    outside = outside + count
                end
            end
        end
    end

    return total, inAssigned, outside
end

function FLM:HasExcessShards()
    local total, _, outside = self:CountShards()
    local cap = self:GetEffectiveShardCap()
    local excess = math.max(0, total - cap)
    return excess > 0, excess, total, cap, outside
end

function FLM:SortShards()
    if InCombatLockdown() then
        sortPendingAfterCombat = true
        return 0
    end
    if CursorHasItem() then
        return 0
    end

    local targetBag = self:GetShardBagIndex()
    local targetSlots = self.GetContainerNumSlots(targetBag)
    if targetSlots == 0 then
        return 0
    end

    -- Pass 1: find empty slots in the assigned shard bag
    local emptySlots = {}
    for slot = 1, targetSlots do
        local info = self.GetContainerItemInfo(targetBag, slot)
        if not info then
            table.insert(emptySlots, slot)
        end
    end

    if #emptySlots == 0 then
        return 0
    end

    -- Pass 2: find unlocked Soul Shards in all other bags
    local shardsToMove = {}
    for bag = 0, NUM_BAG_SLOTS do
        if bag ~= targetBag then
            local slots = self.GetContainerNumSlots(bag)
            for slot = 1, slots do
                local info = self.GetContainerItemInfo(bag, slot)
                if info and info.itemID == SOUL_SHARD_ID and not info.isLocked then
                    table.insert(shardsToMove, { bag = bag, slot = slot })
                end
            end
        end
    end

    local moves = math.min(#shardsToMove, #emptySlots)
    local moved = 0
    for i = 1, moves do
        local src = shardsToMove[i]
        local dstSlot = emptySlots[i]
        self.PickupContainerItem(src.bag, src.slot)
        if CursorHasItem() then
            self.PickupContainerItem(targetBag, dstSlot)
            if CursorHasItem() then
                ClearCursor()
                break
            end
            moved = moved + 1
        end
    end

    return moved
end

function FLM:DestroyExcessShards()
    if InCombatLockdown() then
        return 0, "Cannot destroy shards during combat."
    end
    if CursorHasItem() then
        return 0, "Clear your cursor before destroying shards."
    end

    local total, _, _ = self:CountShards()
    local cap = self:GetEffectiveShardCap()
    local excess = total - cap
    if excess <= 0 then
        return 0, "No excess Soul Shards to destroy."
    end

    local targetBag = self:GetShardBagIndex()
    local candidates = {}

    -- Priority 1: shards outside the assigned shard bag (reverse order)
    for bag = NUM_BAG_SLOTS, 0, -1 do
        if bag ~= targetBag then
            local slots = self.GetContainerNumSlots(bag)
            for slot = slots, 1, -1 do
                local info = self.GetContainerItemInfo(bag, slot)
                if info and info.itemID == SOUL_SHARD_ID and not info.isLocked then
                    table.insert(candidates, { bag = bag, slot = slot })
                end
            end
        end
    end

    -- Priority 2: shards inside the assigned bag only if custom cap is lower than bag capacity
    if #candidates < excess then
        local slots = self.GetContainerNumSlots(targetBag)
        for slot = slots, 1, -1 do
            local info = self.GetContainerItemInfo(targetBag, slot)
            if info and info.itemID == SOUL_SHARD_ID and not info.isLocked then
                table.insert(candidates, { bag = targetBag, slot = slot })
            end
        end
    end

    local toDelete = math.min(excess, #candidates)
    local deleted = 0
    for i = 1, toDelete do
        local c = candidates[i]
        self.PickupContainerItem(c.bag, c.slot)
        local infoType, itemID = GetCursorInfo()
        if CursorHasItem() and infoType == "item" and tonumber(itemID) == SOUL_SHARD_ID then
            DeleteCursorItem()
            if CursorHasItem() then
                -- Client blocked further deletions or item stayed on cursor
                ClearCursor()
                break
            end
            deleted = deleted + 1
        else
            if CursorHasItem() then
                ClearCursor()
            end
            break
        end
    end

    if self.UpdateShardDisplay then
        self:UpdateShardDisplay()
    end
    if self.UpdateHub then
        self:UpdateHub()
    end

    return deleted, nil
end

local function OnBagsChanged()
    if not FLM.db then
        return
    end
    if FLM.db.shards.autoSort then
        if InCombatLockdown() then
            sortPendingAfterCombat = true
        else
            FLM:SortShards()
        end
    end
    if FLM.UpdateShardDisplay then
        FLM:UpdateShardDisplay()
    end
    if FLM.UpdateHub then
        FLM:UpdateHub()
    end
end

function FLM:InitShards()
    self:RegisterEvent("BAG_UPDATE_DELAYED", OnBagsChanged)
    self:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        if sortPendingAfterCombat and FLM.db and FLM.db.shards.autoSort then
            sortPendingAfterCombat = false
            FLM:SortShards()
        end
        if FLM.UpdateShardDisplay then
            FLM:UpdateShardDisplay()
        end
    end)
end
