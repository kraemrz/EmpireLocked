local GEAR_NAME_WHITELIST = {
    ["Worn Shortsword"] = true,
    ["Worn Wooden Shield"] = true,
}

EmpireLocked = EmpireLocked or {}
local EL = EmpireLocked

local function SafeCall(func, ...)
    if type(func) ~= "function" then return nil end
    local ok, a, b, c, d, e = pcall(func, ...)
    if not ok then return nil end
    return a, b, c, d, e
end

local function ItemIDFromLink(link)
    return link and tonumber(link:match("item:(%d+)")) or nil
end

local function EnsureLedger()
    local empire = EL:GetEmpire()
    if not empire then return nil end

    empire.gearLedger = empire.gearLedger or {
        approved = {},
        observed = {},
        initializedCharacters = {},
        starterApproved = {},
    }

    empire.gearLedger.approved = empire.gearLedger.approved or {}
    empire.gearLedger.observed = empire.gearLedger.observed or {}
    empire.gearLedger.initializedCharacters = empire.gearLedger.initializedCharacters or {}
    empire.gearLedger.starterApproved = empire.gearLedger.starterApproved or {}
    empire.gearLedger.starterSlots = empire.gearLedger.starterSlots or {}
    empire.gearLedger.legacySlots = empire.gearLedger.legacySlots or {}
    empire.gearStatus = empire.gearStatus or {}

    return empire.gearLedger
end

local function MakeBagLocation(bag, slot)
    if not ItemLocation or not ItemLocation.CreateFromBagAndSlot then return nil end
    return SafeCall(ItemLocation.CreateFromBagAndSlot, bag, slot)
end

local function MakeEquipLocation(slot)
    if not ItemLocation or not ItemLocation.CreateFromEquipmentSlot then return nil end
    return SafeCall(ItemLocation.CreateFromEquipmentSlot, slot)
end

local function GetGUID(location)
    if not location or not C_Item or not C_Item.GetItemGUID then return nil end
    return SafeCall(C_Item.GetItemGUID, location)
end

local function GetBagSlots(bag)
    if C_Container and C_Container.GetContainerNumSlots then
        return C_Container.GetContainerNumSlots(bag) or 0
    elseif GetContainerNumSlots then
        return GetContainerNumSlots(bag) or 0
    end
    return 0
end

local function GetBagLink(bag, slot)
    if C_Container and C_Container.GetContainerItemLink then
        return C_Container.GetContainerItemLink(bag, slot)
    elseif GetContainerItemLink then
        return GetContainerItemLink(bag, slot)
    end
end

local function SnapshotBagItems()
    local result = {}

    for bag = 0, 4 do
        for slot = 1, GetBagSlots(bag) do
            local link = GetBagLink(bag, slot)
            if link then
                local guid = GetGUID(MakeBagLocation(bag, slot))
                if guid then
                    result[guid] = {
                        guid = guid,
                        itemID = ItemIDFromLink(link),
                        itemLink = link,
                    }
                end
            end
        end
    end

    return result
end

local function GetEquippedItem(slot)
    local link = GetInventoryItemLink("player", slot)
    if not link then return nil end

    return {
        slot = slot,
        guid = GetGUID(MakeEquipLocation(slot)),
        itemID = ItemIDFromLink(link),
        itemLink = link,
        name = GetItemInfo and GetItemInfo(link) or link,
    }
end

-- Hidden tooltip used only for reading Blizzard's own item text.
local scanner = CreateFrame("GameTooltip", "EmpireLockedScannerTooltip", UIParent, "GameTooltipTemplate")
scanner:SetOwner(UIParent, "ANCHOR_NONE")
scanner:Hide()

local function CleanTooltipText(text)
    if not text then return nil end
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    text = text:gsub("^<", ""):gsub(">$", "")
    return text
end

local function ExtractCrafterFromCurrentTooltip()
    local tooltipName = scanner:GetName()
    for i = 1, scanner:NumLines() do
        local left = _G[tooltipName .. "TextLeft" .. i]
        local right = _G[tooltipName .. "TextRight" .. i]

        for _, fs in ipairs({left, right}) do
            if fs then
                local text = CleanTooltipText(fs:GetText())
                if text then
                    -- English Classic client shown in the user's screenshots.
                    -- Support with or without surrounding angle brackets.
                    local creator = text:match("^Made by%s+(.+)$")
                    if creator and creator ~= "" then
                        creator = creator:gsub("^<", ""):gsub(">$", "")
                        creator = creator:gsub("^%s+", ""):gsub("%s+$", "")
                        return creator
                    end
                end
            end
        end
    end
    return nil
end

local function GetEquippedCrafter(slot)
    scanner:ClearLines()
    scanner:SetOwner(UIParent, "ANCHOR_NONE")
    local ok = SafeCall(scanner.SetInventoryItem, scanner, "player", slot)
    if not ok then
        scanner:Hide()
        return nil
    end
    local creator = ExtractCrafterFromCurrentTooltip()
    scanner:Hide()
    return creator
end

local function IsEmpireCharacterName(name)
    if not name then return false, nil end

    local empire = EL:GetEmpire()
    if not empire then return false, nil end

    local wanted = string.lower(name)

    for key, character in pairs(empire.characters or {}) do
        local charName = character.name or key:match("^([^-]+)")
        if charName and string.lower(charName) == wanted then
            return true, character
        end
    end

    return false, nil
end

function EL:MarkStarterGear()
    local empire = self:GetEmpire()
    local ledger = EnsureLedger()
    if not empire or not ledger then return end

    local key = self:GetCharacterKey()
    if ledger.starterApproved[key] then return end

    ledger.starterSlots[key] = ledger.starterSlots[key] or {}
    local marked = 0

    if UnitLevel("player") == 1 then
        for slot = 1, 19 do
            local item = GetEquippedItem(slot)
            if item then
                -- Slot + itemID is the fallback for Classic clients where an
                -- equipped starter item does not expose a usable GUID yet.
                ledger.starterSlots[key][slot] = {
                    itemID = item.itemID,
                    itemLink = item.itemLink,
                    capturedAt = time(),
                }

                if item.guid then
                    ledger.approved[item.guid] = ledger.approved[item.guid] or {
                        guid = item.guid,
                        itemID = item.itemID,
                        itemLink = item.itemLink,
                        crafter = "STARTER_GEAR",
                        approvedReason = "STARTER_GEAR",
                    }
                    ledger.observed[item.guid] = {
                        state = "STARTER_GEAR",
                        itemID = item.itemID,
                        itemLink = item.itemLink,
                        firstSeenBy = key,
                        firstSeenAt = time(),
                    }
                end

                marked = marked + 1
            end
        end
    end

    ledger.starterApproved[key] = time()

    if marked > 0 then
        self:PrintSuccess("Starter gear approved: " .. marked .. " equipped item(s).")
    end
end

function EL:InitializeGearObservation()
    local empire = self:GetEmpire()
    local ledger = EnsureLedger()
    if not empire or not ledger then return end

    local key = self:GetCharacterKey()

    if not ledger.initializedCharacters[key] then
        local bags = SnapshotBagItems()
        ledger.legacySlots[key] = ledger.legacySlots[key] or {}

        -- Old bag contents from before 0.4 remain unverified.
        for guid, item in pairs(bags) do
            ledger.observed[guid] = ledger.observed[guid] or {
                state = "LEGACY_UNKNOWN",
                itemID = item.itemID,
                itemLink = item.itemLink,
                firstSeenBy = key,
                firstSeenAt = time(),
            }
        end

        -- Existing equipment is legacy-unverified unless it was explicitly
        -- approved as level-1 starter gear or has a valid Made by tag.
        for slot = 1, 19 do
            local item = GetEquippedItem(slot)
            if item and item.guid and not ledger.approved[item.guid] then
                local creator = GetEquippedCrafter(slot)
                local empireMade = IsEmpireCharacterName(creator)

                if creator and empireMade then
                    ledger.approved[item.guid] = {
                        guid = item.guid,
                        itemID = item.itemID,
                        itemLink = item.itemLink,
                        crafter = creator,
                        approvedReason = "MADE_BY_TAG",
                        craftedAt = nil,
                    }
                    ledger.observed[item.guid] = {
                        state = "EMPIRE_CRAFTED",
                        itemID = item.itemID,
                        itemLink = item.itemLink,
                        firstSeenBy = key,
                        firstSeenAt = time(),
                    }
                else
                    ledger.legacySlots[key][slot] = {
                        itemID = item.itemID,
                        itemLink = item.itemLink,
                        capturedAt = time(),
                    }

                    ledger.observed[item.guid] = ledger.observed[item.guid] or {
                        state = "LEGACY_UNKNOWN",
                        itemID = item.itemID,
                        itemLink = item.itemLink,
                        firstSeenBy = key,
                        firstSeenAt = time(),
                    }
                end
            elseif item then
                -- Classic may provide no usable GUID for equipped gear.
                -- Preserve the pre-enforcement item by slot+itemID so it stays
                -- UNVERIFIED instead of becoming falsely illegal later.
                ledger.legacySlots[key][slot] = {
                    itemID = item.itemID,
                    itemLink = item.itemLink,
                    capturedAt = time(),
                }
            end
        end

        ledger.initializedCharacters[key] = time()
    end

    self._gearBagSnapshot = SnapshotBagItems()
end

function EL:BeginTrackedCraft(recipeID, outputItemID, outputLink)
    local ledger = EnsureLedger()
    if not ledger then return end

    self._pendingGearCraft = {
        recipeID = recipeID,
        outputItemID = outputItemID,
        outputLink = outputLink,
        crafter = self:GetCharacterKey(),
        startedAt = GetTime(),
        before = SnapshotBagItems(),
    }
end

function EL:ResolveTrackedCraft()
    local pending = self._pendingGearCraft
    if not pending then return end

    if GetTime() - (pending.startedAt or 0) > 8 then
        self._pendingGearCraft = nil
        return
    end

    local ledger = EnsureLedger()
    if not ledger then return end

    local after = SnapshotBagItems()
    local approvedCount = 0

    for guid, item in pairs(after) do
        if not pending.before[guid]
            and (not pending.outputItemID or item.itemID == pending.outputItemID) then

            ledger.approved[guid] = {
                guid = guid,
                itemID = item.itemID,
                itemLink = item.itemLink,
                crafter = pending.crafter,
                recipeID = pending.recipeID,
                craftedAt = time(),
                approvedReason = "CRAFT_LEDGER",
            }

            ledger.observed[guid] = {
                state = "EMPIRE_CRAFTED",
                itemID = item.itemID,
                itemLink = item.itemLink,
                firstSeenBy = pending.crafter,
                firstSeenAt = time(),
            }

            approvedCount = approvedCount + 1
        end
    end

    if approvedCount > 0 then
        self:PrintSuccess("Recorded " .. approvedCount .. " Empire-crafted item.")
        self._pendingGearCraft = nil
    end
end

function EL:ObserveNewBagItems()
    local ledger = EnsureLedger()
    if not ledger then return end

    local now = SnapshotBagItems()
    local before = self._gearBagSnapshot or {}

    self:ResolveTrackedCraft()

    for guid, item in pairs(now) do
        if not before[guid] and not ledger.observed[guid] then
            if ledger.approved[guid] then
                ledger.observed[guid] = {
                    state = "EMPIRE_CRAFTED",
                    itemID = item.itemID,
                    itemLink = item.itemLink,
                    firstSeenBy = self:GetCharacterKey(),
                    firstSeenAt = time(),
                }
            else
                ledger.observed[guid] = {
                    state = "EXTERNAL",
                    itemID = item.itemID,
                    itemLink = item.itemLink,
                    firstSeenBy = self:GetCharacterKey(),
                    firstSeenAt = time(),
                }
            end
        end
    end

    self._gearBagSnapshot = now
end

function EL:GetGearState(item)
    local itemName = item and item.itemLink and item.itemLink:match("%[(.-)%]")
    if itemName and GEAR_NAME_WHITELIST[itemName] then
        return "APPROVED", "Empire whitelist"
    end

    local ledger = EnsureLedger()
    if not ledger or not item then return "UNKNOWN", nil end

    -- Strong evidence #1: Blizzard's Made by tag on the equipped item.
    if item.slot then
        local creator = GetEquippedCrafter(item.slot)
        if creator then
            local empireMade = IsEmpireCharacterName(creator)
            if empireMade then
                if item.guid then
                    ledger.approved[item.guid] = ledger.approved[item.guid] or {
                        guid = item.guid,
                        itemID = item.itemID,
                        itemLink = item.itemLink,
                        crafter = creator,
                        approvedReason = "MADE_BY_TAG",
                    }
                end
                return "APPROVED", "Made by " .. creator
            else
                return "ILLEGAL", "Made by " .. creator
            end
        end
    end

    -- Strong evidence #2: level-1 starter snapshot.
    -- This fallback is intentionally slot-specific: replacing the starter
    -- item later does not approve some unrelated item elsewhere.
    local key = EL:GetCharacterKey()
    local starter = ledger.starterSlots
        and ledger.starterSlots[key]
        and item.slot
        and ledger.starterSlots[key][item.slot]

    if starter and starter.itemID and starter.itemID == item.itemID then
        return "APPROVED", "Starter gear"
    end

    -- Pre-0.4 equipped gear is grandfathered only as UNVERIFIED in the
    -- exact slot/itemID combination captured when enforcement was introduced.
    local legacy = ledger.legacySlots
        and ledger.legacySlots[key]
        and item.slot
        and ledger.legacySlots[key][item.slot]

    if legacy and legacy.itemID and legacy.itemID == item.itemID then
        return "UNKNOWN", "Origin predates verification"
    end

    -- Strong evidence #3: our physical-instance craft ledger.
    if item.guid and ledger.approved[item.guid] then
        local entry = ledger.approved[item.guid]
        if entry.approvedReason == "STARTER_GEAR" then
            return "APPROVED", "Starter gear"
        end
        return "APPROVED", "Empire craft ledger"
    end

    if item.guid and ledger.observed[item.guid] then
        local state = ledger.observed[item.guid].state
        if state == "EMPIRE_CRAFTED" or state == "STARTER_GEAR" then
            return "APPROVED", state == "STARTER_GEAR" and "Starter gear" or "Empire craft ledger"
        elseif state == "EXTERNAL" then
            return "ILLEGAL", "Observed entering from outside the Empire"
        else
            return "UNKNOWN", "Origin predates verification"
        end
    end

    -- At this point the item is not starter gear, not the old legacy item
    -- captured for this slot, has no Empire Made-by proof, and is absent from
    -- the Empire craft ledger. A newly equipped item therefore violates the
    -- challenge rule.
    return "ILLEGAL", "New equipment is not verified as Empire-crafted"
end

local function BuildGearStatus()
    local status = {
        approved = 0,
        illegal = 0,
        unknown = 0,
        items = {},
        checkedAt = time(),
    }

    for slot = 1, 19 do
        local item = GetEquippedItem(slot)
        if item then
            local state, reason = EL:GetGearState(item)

            if state == "APPROVED" then status.approved = status.approved + 1
            elseif state == "ILLEGAL" then status.illegal = status.illegal + 1
            else status.unknown = status.unknown + 1 end

            table.insert(status.items, {
                slot = slot,
                state = state,
                reason = reason,
                itemID = item.itemID,
                itemLink = item.itemLink,
                guid = item.guid,
                name = item.name,
            })
        end
    end

    return status
end

function EL:CheckEquippedGearNoFail()
    local empire = self:GetEmpire()
    if not empire then return end
    empire.gearStatus = empire.gearStatus or {}
    empire.gearStatus[self:GetCharacterKey()] = BuildGearStatus()
end

function EL:CheckEquippedGear()
    local empire = self:GetEmpire()
    if not empire then return end

    local key = self:GetCharacterKey()
    empire.gearStatus = empire.gearStatus or {}
    empire.gearStatus[key] = BuildGearStatus()

    local first = empire.gearStatus[key]
    if not first or first.illegal == 0 or empire.status ~= "ACTIVE" then return end

    -- Triple-check before fail: initial event + two delayed independent scans.
    C_Timer.After(0.5, function()
        local e = EL:GetEmpire()
        if not e or e.status ~= "ACTIVE" then return end
        EL:CheckEquippedGearNoFail()
        local second = e.gearStatus[key]
        if not second or second.illegal == 0 then return end

        C_Timer.After(0.75, function()
            local current = EL:GetEmpire()
            if not current or current.status ~= "ACTIVE" then return end
            EL:CheckEquippedGearNoFail()
            local third = current.gearStatus[key]
            if not third or third.illegal == 0 then return end

            local names = {}
            for _, entry in ipairs(third.items or {}) do
                if entry.state == "ILLEGAL" then
                    table.insert(names, entry.itemLink or entry.name or "?")
                end
            end

            local reason = string.format(
                "%s equipped %d item(s) not crafted by the Empire.",
                UnitName("player"),
                third.illegal
            )

            if current.testMode then
                EL:PrintError("TEST MODE: EMPIRE WOULD HAVE FAILED.")
                EL:PrintError(reason)

                for _, name in ipairs(names) do
                    EL:PrintError("Illegal gear: " .. name)
                end

                EL:Print("|cff55ff55REAL EMPIRE STATUS REMAINS ACTIVE.|r")
            else
                EL:AddViolation(key, "ILLEGAL_EQUIPMENT", reason)
                EL:FailEmpire(reason)
                EL:PrintError("EMPIRE FAILED: " .. reason)

                for _, name in ipairs(names) do
                    EL:PrintError("Illegal gear: " .. name)
                end
            end
        end)
    end)
end

function EL:PrintGearStatus()
    local empire = self:GetEmpire()
    if not empire then
        self:Print("Inget Empire finns.")
        return
    end

    self:CheckEquippedGearNoFail()
    local status = empire.gearStatus[self:GetCharacterKey()]
    if not status then return end

    self:Print(string.format(
        "Gear: |cff55ff55%d approved|r, |cffff5555%d illegal|r, |cffffcc33%d unverified|r.",
        status.approved or 0,
        status.illegal or 0,
        status.unknown or 0
    ))

    for _, item in ipairs(status.items or {}) do
        local color = item.state=="APPROVED" and "|cff55ff55"
            or item.state=="ILLEGAL" and "|cffff5555"
            or "|cffffcc33"

        self:Print(string.format(
            "  Slot %d: %s%s|r - %s |cffaaaaaa(%s)|r",
            item.slot,
            color,
            item.itemLink or item.name or "?",
            item.state,
            item.reason or "no reason"
        ))
    end
end

local function InstallCraftHooks()
    if EL._gearHooksInstalled then return end
    EL._gearHooksInstalled = true

    if hooksecurefunc and C_TradeSkillUI and type(C_TradeSkillUI.CraftRecipe)=="function" then
        hooksecurefunc(C_TradeSkillUI, "CraftRecipe", function(recipeID)
            local outputLink
            local outputID

            if C_TradeSkillUI.GetRecipeItemLink then
                outputLink = SafeCall(C_TradeSkillUI.GetRecipeItemLink, recipeID)
                outputID = ItemIDFromLink(outputLink)
            end

            EL:BeginTrackedCraft(recipeID, outputID, outputLink)
        end)
    end

    if hooksecurefunc and type(DoTradeSkill)=="function" then
        hooksecurefunc("DoTradeSkill", function(index)
            local outputLink = GetTradeSkillItemLink and SafeCall(GetTradeSkillItemLink, index)
            EL:BeginTrackedCraft(index, ItemIDFromLink(outputLink), outputLink)
        end)
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("BAG_UPDATE_DELAYED")
frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
frame:RegisterEvent("TRADE_SKILL_SHOW")

frame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        C_Timer.After(1.5, function()
            local empire = EL:GetEmpire()
            if empire and empire.characters[EL:GetCharacterKey()] then
                EnsureLedger()
                EL:MarkStarterGear()
                EL:InitializeGearObservation()
                InstallCraftHooks()
                EL:CheckEquippedGearNoFail()
            end
        end)

    elseif event == "TRADE_SKILL_SHOW" then
        InstallCraftHooks()

    elseif event == "BAG_UPDATE_DELAYED" then
        local empire = EL:GetEmpire()
        if empire and empire.characters[EL:GetCharacterKey()] then
            C_Timer.After(0.15, function()
                EL:ObserveNewBagItems()
            end)
        end

    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        local empire = EL:GetEmpire()
        if empire and empire.characters[EL:GetCharacterKey()] then
            C_Timer.After(0.2, function()
                EL:CheckEquippedGear()
            end)
        end
    end
end)
