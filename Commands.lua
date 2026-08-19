EmpireLocked = EmpireLocked or {}
local EL = EmpireLocked

local function Trim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function PrintHelp()
    EL:Print("Kommandon:")
    EL:Print("|cffffffff/empire create <namn>|r - skapa ett nytt Empire")
    EL:Print("|cffffffff/empire king|r - utse aktuell karaktär till King")
    EL:Print("|cffffffff/empire join|r - registrera aktuell karaktär som subject")
    EL:Print("|cffffffff/empire status|r - visa status")
    EL:Print("|cffffffff/empire chars|r - lista registrerade karaktärer")
    EL:Print("|cffffffff/empire scan|r - scanna öppen profession")
    EL:Print("|cffffffff/empire professions|r - visa sparade professions")
    EL:Print("|cffffffff/empire inventory|r - uppdatera bag-cache")
    EL:Print("|cffffffff/empire bank|r - uppdatera bank-cache (banken måste vara öppen)")
    EL:Print("|cffffffff/empire gear|r - visa gear validation-status")
    EL:Print("|cffffffff/empire kick <name>|r - kasta ut en subject ur imperiet")
    EL:Print("|cffffffff/empire testmode on|off|r - safe real-gear fail test")
    EL:Print("|cffffffff/empire debug restore|r - restore a false development failure")
    EL:Print("|cffffffff/empire deaths|r - visa Empire death history")
    EL:Print("|cffffffff/empire chronicles|r - lista arkiverade Empire-runs")
    EL:Print("|cffffffff/empire debug archive|r - skapa en säker test-post i Chronicle")
    EL:Print("|cffffffff/empire find <namn>|r - sök bland sparade recept")
    EL:Print("|cffffffff/empire debugrecipe <namn>|r - visa reagent-debug")
    EL:Print("|cffffffff/empire reset|r - radera nuvarande run")
end

local function PrintStatus()
    local empire = EL:GetEmpire()
    if not empire then EL:Print("Inget Empire har skapats."); return end

    EL:Print("Empire: |cffffffff" .. empire.name .. "|r")
    EL:Print("Status: " .. (empire.status == "ACTIVE" and "|cff55ff55ACTIVE|r" or "|cffff5555FAILED|r"))

    if empire.king then
        local king = empire.characters[empire.king]
        if king then
            EL:Print(string.format("King: |cffffffff%s|r - Level %d %s", king.name, king.level or 0, king.class or ""))
        else
            EL:Print("King: " .. empire.king)
        end
    else
        EL:Print("King: |cffffaa00Inte utsedd|r")
    end

    local count = 0
    for _ in pairs(empire.characters) do count = count + 1 end
    EL:Print("Registrerade karaktärer: " .. count)
    EL:Print("Regelbrott loggade: " .. #empire.violations)
end

local function PrintCharacters()
    local empire = EL:GetEmpire()
    if not empire then EL:Print("Inget Empire har skapats."); return end

    EL:Print("Karaktärer i " .. empire.name .. ":")
    for key, character in pairs(empire.characters) do
        local role = character.role == "KING" and "|cffd6a84bKING|r" or "SUBJECT"
        local alive = character.alive == false and "|cffff5555DEAD|r" or "|cff55ff55ALIVE|r"
        EL:Print(string.format("%s - %s - Level %d %s - %s", character.name or key, role, character.level or 0, character.class or "", alive))
    end
end

SLASH_EMPIRELOCKED1 = "/empire"
SlashCmdList["EMPIRELOCKED"] = function(msg)
    msg = Trim(msg or "")
    local command, rest = msg:match("^(%S+)%s*(.-)$")
    command = command and command:lower() or ""
    rest = Trim(rest or "")

    if command == "" then
        EL:ToggleMainUI()

    elseif command == "help" then
        PrintHelp()
    elseif command == "create" then
        if EL:HasEmpire() then EL:PrintError("Ett Empire finns redan. Använd /empire reset först."); return end
        local ok, err = EL:CreateEmpire(rest)
        if not ok then EL:PrintError(err); return end
        EL:PrintSuccess("Empire '" .. rest .. "' skapades.")
        EL:Print("Logga in på den blivande kungen och skriv |cffffffff/empire king|r.")
    elseif command == "king" then
        local ok, err = EL:SetKing()
        if ok then
            EL:PrintSuccess(UnitName("player") .. " är nu THE KING.")
            EL:MarkStarterGear()
            EL:InitializeGearObservation()
            EL:CheckEquippedGearNoFail()
        else
            EL:PrintError(err)
        end
    elseif command == "join" then
        local ok, err = EL:JoinCurrentCharacter()
        if ok then
            EL:PrintSuccess(UnitName("player") .. " har anslutit som subject.")
            EL:MarkStarterGear()
            EL:InitializeGearObservation()
            EL:CheckEquippedGearNoFail()
            EL:CheckLevelRule()
        else
            EL:PrintError(err)
        end
    elseif command == "status" then
        PrintStatus()
    elseif command == "chars" then
        PrintCharacters()
    elseif command == "scan" then
        local ok, result = EL:ScanCurrentProfession()
        if ok then
            EL:PrintSuccess(string.format("%s sparad: %d/%d, %d recept.", result.name or "Profession", result.skill or 0, result.maxSkill or 0, result.recipeCount or 0))
        else
            EL:PrintError(result)
        end
    elseif command == "professions" or command == "profs" then
        EL:PrintProfessions()
    elseif command == "find" then
        EL:FindRecipe(rest)
    elseif command == "inventory" or command == "inv" then
        if not EL:ScanInventory(false) then EL:PrintError("Kunde inte scanna inventory.") end

    elseif command == "bank" then
        if not EL:ScanBank(false) then EL:PrintError("Kunde inte scanna banken.") end

    elseif command == "gear" then
        EL:PrintGearStatus()

    elseif command == "kick" or command == "banish" then
        local target = rest and rest:match("^%s*(.-)%s*$") or ""
        local ok, result = EL:BanishSubject(target, "Manual removal")
        if ok then
            EL:PrintSuccess(result .. " has been banished from the Empire.")
        else
            EL:PrintError(result)
        end

    elseif command == "testmode" then
        local empire = EL:GetEmpire()
        local mode = string.lower(rest or "")

        if not empire then
            EL:PrintError("Inget Empire finns.")
        elseif mode == "on" then
            empire.testMode = true
            EL:PrintError("TEST MODE ENABLED.")
            EL:Print("Real illegal gear will be detected, but the Empire will not be failed.")
        elseif mode == "off" then
            empire.testMode = false
            EL:PrintSuccess("TEST MODE DISABLED. Gear enforcement is LIVE.")
        else
            EL:Print("Test mode: " .. (empire.testMode and "|cffffaa00ON|r" or "|cff55ff55OFF|r"))
        end

    elseif command == "debug" then
        local action = string.lower(rest or "")
        if action == "restore" then
            local ok, err = EL:DebugRestoreEmpire()
            if ok then
                EL:PrintSuccess("DEVELOPMENT RESTORE: Empire status restored to ACTIVE.")
                EL:Print("Characters, crafting data, inventory and gear history were preserved.")
            else
                EL:PrintError(err)
            end
        elseif action == "archive" then
            local index=EL:AddDebugChronicleArchive()
            EL:PrintSuccess("Debug Chronicle archive created as entry #"..index..".")
            EL:Print("The active Empire was NOT changed.")
        else
            EL:Print("Use /empire debug restore or /empire debug archive")
        end

    elseif command == "deaths" then
        local empire = EL:GetEmpire()
        if not empire then
            EL:PrintError("Inget Empire finns.")
        elseif not empire.deathLog or #empire.deathLog == 0 then
            EL:Print("No deaths recorded.")
        else
            EL:Print("Empire death history:")
            for _, death in ipairs(empire.deathLog) do
                EL:Print(string.format("  %s - %s",death.name or "?",death.role or "?"))
            end
        end

    elseif command == "chronicles" then
        local archive=EL:GetChronicleArchive()
        if #archive==0 then
            EL:Print("No archived Empires yet.")
        else
            EL:Print("Empire Chronicles:")
            for i,run in ipairs(archive) do
                local fate=run.finalStatus=="FAILED" and "FALLEN" or "ENDED"
                EL:Print(string.format(
                    "  #%d %s - %s - King %s Level %d",
                    i,run.name or "Empire",fate,run.kingName or "?",run.kingLevel or 0
                ))
            end
        end

    elseif command == "reset" then
        EL:ResetEmpire(); EL:PrintSuccess("Empire archived in Chronicle. Du kan nu börja en ny run.")
    else
        EL:PrintError("Okänt kommando: " .. command); PrintHelp()
    end
end
