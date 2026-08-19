EmpireLocked = EmpireLocked or {}
local EL = EmpireLocked

EL.VERSION = "0.6.2"

local function DefaultDB()
    return {
        schemaVersion = 1,
        empire = nil,
    }
end

function EL:InitDB()
    if type(EmpireLockedDB) ~= "table" then
        EmpireLockedDB = DefaultDB()
    end

    if not EmpireLockedDB.schemaVersion then
        EmpireLockedDB.schemaVersion = 1
    end
    EmpireLockedDB.chronicles = EmpireLockedDB.chronicles or {}
end

function EL:GetDB()
    return EmpireLockedDB
end

function EL:EnsureChronicle()
    local empire = self:GetEmpire()
    if not empire then return nil end
    empire.chronicle = empire.chronicle or {}
    local ch = empire.chronicle
    ch.foundedAt = ch.foundedAt or empire.createdAt or time()
    ch.highestKingLevel = ch.highestKingLevel or 0

    local king = empire.king and empire.characters and empire.characters[empire.king]
    if king and (king.level or 0) > ch.highestKingLevel then
        ch.highestKingLevel = king.level or 0
    end

    if not ch.recruitmentSeeded then
        local n=0
        for _,c in pairs(empire.characters or {}) do
            if c.role~="KING" then n=n+1 end
        end
        for _,entry in ipairs(empire.banishLog or {}) do
            if entry.name then n=n+1 end
        end
        ch.subjectsRecruited=n
        ch.recruitmentSeeded=true
    end
    return ch
end

function EL:GetEmpire()
    return EmpireLockedDB and EmpireLockedDB.empire or nil
end

function EL:HasEmpire()
    return self:GetEmpire() ~= nil
end

function EL:CreateEmpire(name)
    if not name or name == "" then
        return false, "Du måste ange ett namn."
    end

    EmpireLockedDB.empire = {
        name = name,
        runID = time(),
        createdAt = time(),
        status = "ACTIVE",
        failedAt = nil,
        failureReason = nil,
        king = nil,
        characters = {},
        violations = {},
        craftedItems = {},   -- används i senare version
    }

    return true
end

function EL:BanishSubject(name, reason)
    local empire = self:GetEmpire()
    if not empire then return false, "Inget Empire finns." end
    if not name or name == "" then return false, "Ange namnet på en subject." end

    local wanted = string.lower(name)
    local foundKey, foundCharacter

    for key, character in pairs(empire.characters or {}) do
        local charName = character.name or key:match("^([^-]+)")
        if charName and string.lower(charName) == wanted then
            foundKey = key
            foundCharacter = character
            break
        end
    end

    if not foundKey then
        return false, "Character is not a member of the Empire."
    end

    if foundKey == empire.king or foundCharacter.role == "KING" then
        return false, "The King cannot be banished."
    end

    local removedName = foundCharacter.name or name

    -- Remove current membership and character-specific caches/status.
    empire.characters[foundKey] = nil

    if empire.inventory then empire.inventory[foundKey] = nil end
    if empire.bank then empire.bank[foundKey] = nil end
    if empire.gearStatus then empire.gearStatus[foundKey] = nil end

    if empire.gearLedger then
        if empire.gearLedger.initializedCharacters then
            empire.gearLedger.initializedCharacters[foundKey] = nil
        end
        if empire.gearLedger.starterApproved then
            empire.gearLedger.starterApproved[foundKey] = nil
        end
        if empire.gearLedger.starterSlots then
            empire.gearLedger.starterSlots[foundKey] = nil
        end
        if empire.gearLedger.legacySlots then
            empire.gearLedger.legacySlots[foundKey] = nil
        end
        -- Deliberately preserve approved/crafted item history. Gear already
        -- made for the Empire remains valid after its crafter is banished.
    end

    empire.banishLog = empire.banishLog or {}
    table.insert(empire.banishLog, {
        name = removedName,
        characterKey = foundKey,
        reason = reason or "Manual removal",
        at = time(),
        by = self:GetCharacterKey(),
    })

    return true, removedName
end

function EL:DebugRestoreEmpire()
    local empire = self:GetEmpire()
    if not empire then
        return false, "Inget Empire finns."
    end

    if empire.status ~= "FAILED" then
        return false, "Empire is not failed."
    end

    empire.debugRestoreLog = empire.debugRestoreLog or {}
    table.insert(empire.debugRestoreLog, {
        previousStatus = empire.status,
        previousFailedAt = empire.failedAt,
        previousFailReason = empire.failReason,
        restoredAt = time(),
        restoredBy = self:GetCharacterKey(),
    })

    empire.status = "ACTIVE"
    empire.failedAt = nil
    empire.failReason = nil
    empire.failureReason = nil

    return true
end

function EL:LogDeath(characterKey, characterName, role, level, class)
    local empire = self:GetEmpire()
    if not empire then return end
    empire.deathLog = empire.deathLog or {}
    table.insert(empire.deathLog, {
        characterKey = characterKey,
        name = characterName,
        role = role,
        level = level,
        class = class,
        at = time(),
    })
end

function EL:ArchiveCurrentEmpire(reason)
    local empire = self:GetEmpire()
    if not empire then return false end

    EmpireLockedDB.chronicles = EmpireLockedDB.chronicles or {}
    local ch = self:EnsureChronicle() or {}

    -- Freeze a compact historical snapshot. Do not retain inventory/bank
    -- caches: Chronicle is history, not active crafting storage.
    local archive = {
        name = empire.name or "Empire",
        runID = empire.runID,
        foundedAt = ch.foundedAt or empire.createdAt,
        endedAt = time(),
        finalStatus = empire.status or "ACTIVE",
        endReason = reason or empire.failureReason or "Manual reset",
        failureReason = empire.failureReason,
        kingName = nil,
        kingClass = nil,
        kingLevel = 0,
        highestKingLevel = ch.highestKingLevel or 0,
        subjectsRecruited = ch.subjectsRecruited or 0,
        subjectsRemaining = 0,
        deathLog = {},
        banishLog = {},
        violations = {},
    }

    local king = empire.king and empire.characters and empire.characters[empire.king]
    if king then
        archive.kingName = king.name
        archive.kingClass = king.class
        archive.kingLevel = king.level or 0
    end

    for _,c in pairs(empire.characters or {}) do
        if c.role ~= "KING" then archive.subjectsRemaining=archive.subjectsRemaining+1 end
    end
    for _,v in ipairs(empire.deathLog or {}) do
        table.insert(archive.deathLog, {
            name=v.name, role=v.role, level=v.level, class=v.class, at=v.at
        })
    end
    for _,v in ipairs(empire.banishLog or {}) do
        table.insert(archive.banishLog, {
            name=v.name, reason=v.reason, at=v.at
        })
    end
    for _,v in ipairs(empire.violations or {}) do
        table.insert(archive.violations, {
            type=v.type, message=v.message, timestamp=v.timestamp
        })
    end

    table.insert(EmpireLockedDB.chronicles, archive)
    return true
end

function EL:AddDebugChronicleArchive()
    EmpireLockedDB.chronicles = EmpireLockedDB.chronicles or {}

    local now=time()
    local archive={
        name="Test Empire",
        runID=now-86400,
        foundedAt=now-(3*86400+4*3600+27*60),
        endedAt=now-3600,
        finalStatus="FAILED",
        endReason="Development test archive",
        failureReason="The King Testking died.",
        kingName="Testking",
        kingClass="PALADIN",
        kingLevel=17,
        highestKingLevel=17,
        subjectsRecruited=4,
        subjectsRemaining=1,
        deathLog={
            {name="Testsubject",role="SUBJECT",level=9,class="MAGE",at=now-7200},
            {name="Testrogue",role="SUBJECT",level=12,class="ROGUE",at=now-5400},
        },
        banishLog={
            {name="Badsubject",reason="Manual removal",at=now-10000},
        },
        violations={
            {type="KING_DEATH",message="The King Testking died.",timestamp=now-3600},
        },
        debug=true,
    }

    table.insert(EmpireLockedDB.chronicles,archive)
    return #EmpireLockedDB.chronicles
end

function EL:GetChronicleArchive()
    EmpireLockedDB.chronicles = EmpireLockedDB.chronicles or {}
    return EmpireLockedDB.chronicles
end

function EL:ResetEmpire()
    if self:GetEmpire() then
        self:ArchiveCurrentEmpire("Manual reset")
    end
    EmpireLockedDB.empire = nil
end

function EL:GetCharacterKey()
    local name = UnitName("player")
    local realm = GetNormalizedRealmName and GetNormalizedRealmName() or GetRealmName()

    realm = realm or "UnknownRealm"
    realm = realm:gsub("%s+", "")

    return name .. "-" .. realm
end

function EL:GetCharacterSnapshot(role)
    local name = UnitName("player")
    local _, class = UnitClass("player")

    return {
        key = self:GetCharacterKey(),
        name = name,
        realm = GetRealmName(),
        class = class,
        level = UnitLevel("player"),
        role = role or "SUBJECT",
        alive = not UnitIsDeadOrGhost("player"),
        lastSeen = time(),

        professions = {}, -- fylls av professionsdelen senare
    }
end

function EL:UpsertCurrentCharacter(role)
    local empire = self:GetEmpire()
    if not empire then
        return nil
    end

    local key = self:GetCharacterKey()
    local old = empire.characters[key]
    local snapshot = self:GetCharacterSnapshot(role or (old and old.role) or "SUBJECT")

    if old and old.professions then
        snapshot.professions = old.professions
    end
    if old and old.inventory then
        snapshot.inventory = old.inventory
    end

    empire.characters[key] = snapshot
    return snapshot
end

function EL:SetKing()
    local empire = self:GetEmpire()
    if not empire then
        return false, "Inget Empire finns."
    end

    if empire.status ~= "ACTIVE" then
        return false, "Detta Empire är inte längre aktivt."
    end

    local key = self:GetCharacterKey()

    if empire.king and empire.king ~= key then
        return false, "Det finns redan en King: " .. empire.king
    end

    local character = self:UpsertCurrentCharacter("KING")
    empire.king = key
    character.role = "KING"

    return true
end

function EL:JoinCurrentCharacter()
    local empire = self:GetEmpire()
    if not empire then
        return false, "Inget Empire finns."
    end

    if empire.status ~= "ACTIVE" then
        return false, "Detta Empire är inte längre aktivt."
    end

    local key = self:GetCharacterKey()

    if empire.king == key then
        self:UpsertCurrentCharacter("KING")
        return false, "Den här karaktären är redan King."
    end

    self:UpsertCurrentCharacter("SUBJECT")
    return true
end

function EL:AddViolation(characterKey, violationType, message)
    local empire = self:GetEmpire()
    if not empire then return end

    table.insert(empire.violations, {
        character = characterKey,
        type = violationType,
        message = message,
        timestamp = time(),
    })
end

function EL:FailEmpire(reason)
    local empire = self:GetEmpire()
    if not empire or empire.status == "FAILED" then
        return
    end

    empire.status = "FAILED"
    empire.failedAt = time()
    empire.failureReason = reason
end
