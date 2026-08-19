EmpireLocked = EmpireLocked or {}
local EL = EmpireLocked

EL.PREFIX = "|cffd6a84bEmpire Locked|r"

function EL:Print(message)
    DEFAULT_CHAT_FRAME:AddMessage(self.PREFIX .. ": " .. tostring(message))
end

function EL:PrintError(message)
    DEFAULT_CHAT_FRAME:AddMessage(self.PREFIX .. ": |cffff5555" .. tostring(message) .. "|r")
end

function EL:PrintSuccess(message)
    DEFAULT_CHAT_FRAME:AddMessage(self.PREFIX .. ": |cff55ff55" .. tostring(message) .. "|r")
end

function EL:CreateLevelLockFrame()
    if self.LevelLockFrame then
        return self.LevelLockFrame
    end

    local frame = CreateFrame("Frame", "EmpireLockedLevelLockFrame", UIParent, "BackdropTemplate")
    frame:SetSize(620, 300)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetClampedToScreen(true)

    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })

    -- Strong red overlay.
    local red = frame:CreateTexture(nil, "ARTWORK")
    red:SetPoint("TOPLEFT", 12, -12)
    red:SetPoint("BOTTOMRIGHT", -12, 12)
    red:SetColorTexture(0.55, 0.02, 0.02, 0.94)
    frame.redBackground = red

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("TOP", 0, -48)
    title:SetText("|cffffd100EMPIRE LOCKED|r")
    frame.title = title

    local message = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    message:SetPoint("TOP", title, "BOTTOM", 0, -34)
    message:SetWidth(540)
    message:SetJustifyH("CENTER")
    message:SetText("|cffffffffYou have reached the King's level.\nYou should wait for the King.|r")
    frame.message = message

    local info = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    info:SetPoint("TOP", message, "BOTTOM", 0, -18)
    info:SetWidth(520)
    info:SetJustifyH("CENTER")
    frame.info = info

    local close = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    close:SetSize(180, 42)
    close:SetPoint("BOTTOM", 0, 42)
    close:SetText("I UNDERSTAND")
    close:SetScript("OnClick", function()
        frame:Hide()
    end)
    frame.close = close

    local x = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    x:SetPoint("TOPRIGHT", -8, -8)
    frame.x = x

    frame:EnableMouse(true)
    frame:Hide()

    self.LevelLockFrame = frame
    return frame
end

function EL:ShowLevelLock(subjectLevel, kingLevel, kingName)
    local frame = self:CreateLevelLockFrame()

    frame.info:SetText(string.format(
        "|cffffbbbbYour level: %d   •   %s: %d|r",
        tonumber(subjectLevel) or 0,
        kingName or "The King",
        tonumber(kingLevel) or 0
    ))

    frame:Show()
end

function EL:HideLevelLock()
    if self.LevelLockFrame then
        self.LevelLockFrame:Hide()
    end
end

function EL:CheckLevelRule(forcedLevel)
    local empire = self:GetEmpire()
    if not empire or empire.status ~= "ACTIVE" or not empire.king then
        return
    end

    local currentKey = self:GetCharacterKey()
    local current = empire.characters[currentKey]

    if not current then
        return
    end

    -- PLAYER_LEVEL_UP can fire before UnitLevel("player") has updated.
    -- When the event gives us the new level, trust that value.
    local currentLevel = tonumber(forcedLevel) or UnitLevel("player")

    current.level = currentLevel
    current.lastSeen = time()

    if currentKey == empire.king then
        return
    end

    local king = empire.characters[empire.king]
    if not king then
        self:PrintError("King finns angiven men saknas i karaktärsregistret.")
        return
    end

    local kingLevel = tonumber(king.level) or 0

    if currentLevel > kingLevel then
        self:HideLevelLock()

        local message = string.format(
            "%s reached level %d while King %s is only level %d.",
            current.name or currentKey,
            currentLevel,
            king.name or empire.king,
            kingLevel
        )

        self:AddViolation(currentKey, "SUBJECT_ABOVE_KING", message)
        self:FailEmpire(message)

        self:PrintError("EMPIRE FAILED.")
        self:PrintError(message)
        self:PrintError("A SUBJECT may never exceed THE KING'S level.")

    elseif currentLevel == kingLevel then
        self:ShowLevelLock(
            currentLevel,
            kingLevel,
            king.name or "The King"
        )

    else
        self:HideLevelLock()
    end
end

function EL:HandlePlayerDeath()
    local empire = self:GetEmpire()
    if not empire or empire.status ~= "ACTIVE" then return end

    local key = self:GetCharacterKey()
    local character = empire.characters[key]
    if not character then return end

    character.alive = false
    character.lastSeen = time()

    local name = character.name or UnitName("player") or key
    local role = character.role or "SUBJECT"

    self:LogDeath(key, name, role, character.level or UnitLevel("player"), character.class or UnitClass("player"))

    if empire.king == key or role == "KING" then
        local reason = "The King " .. name .. " died."
        self:AddViolation(key, "KING_DEATH", reason)
        self:FailEmpire(reason)
        self:PrintError("THE KING IS DEAD.")
        self:PrintError("EMPIRE FAILED.")
        self:PrintError(reason)
        return
    end

    local ok, result = self:BanishSubject(name, "Died")
    if ok then
        self:PrintError(name .. " has died.")
        self:PrintError(name .. " has been removed from the Empire.")
        self:Print("All cached inventory, bank contents, professions and recipes for this Subject were removed.")
    else
        self:PrintError("Subject death detected, but automatic removal failed: " .. tostring(result))
    end
end

function EL:OnLogin()
    self:InitDB()

    local empire = self:GetEmpire()
    if not empire then
        self:Print("Ingen aktiv run. Skriv |cffffffff/empire create <namn>|r.")
        return
    end

    local key = self:GetCharacterKey()
    local registered = empire.characters[key]

    if registered then
        self:UpsertCurrentCharacter(registered.role)

        if UnitIsDeadOrGhost("player") and empire.king == key and empire.status == "ACTIVE" then
            self:HandlePlayerDeath()
        end
    end

    self:CheckLevelRule()

    if empire.status == "FAILED" then
        self:PrintError("Detta Empire har FAILED: " .. tostring(empire.failureReason))
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LEVEL_UP")
frame:RegisterEvent("PLAYER_DEAD")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        EL:OnLogin()

    elseif event == "PLAYER_LEVEL_UP" then
        local newLevel = ...
        local empire = EL:GetEmpire()

        if empire and empire.characters[EL:GetCharacterKey()] then
            local key = EL:GetCharacterKey()
            local character = empire.characters[key]

            -- Update the saved snapshot explicitly with the event's level.
            character.level = tonumber(newLevel) or UnitLevel("player")
            character.lastSeen = time()

            EL:CheckLevelRule(newLevel)
        end

    elseif event == "PLAYER_REGEN_DISABLED" then
        if EL.MainFrame and EL.MainFrame:IsShown() then
            EL.reopenAfterCombat = true
            EL.MainFrame:Hide()
        else
            EL.reopenAfterCombat = false
        end

    elseif event == "PLAYER_REGEN_ENABLED" then
        if EL.reopenAfterCombat then
            EL.reopenAfterCombat = false
            if EL.MainFrame then
                EL.MainFrame:Show()
                if EL.RefreshUI then EL:RefreshUI() end
            end
        end

    elseif event == "PLAYER_DEAD" then
        EL:HandlePlayerDeath()
    end
end)
