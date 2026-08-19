EmpireLocked = EmpireLocked or {}
local EL = EmpireLocked

local function SafeCall(func, ...)
    if type(func) ~= "function" then return nil end
    local ok, a,b,c,d,e,f,g,h = pcall(func, ...)
    if not ok then return nil end
    return a,b,c,d,e,f,g,h
end

local function GetItemIDFromLink(link)
    if not link then return nil end
    return tonumber(string.match(link, "item:(%d+)"))
end

local function EnsureProfessionTable(character, key)
    character.professions = character.professions or {}
    character.professions[key] = character.professions[key] or {
        name = key,
        skillLineID = nil,
        skill = 0,
        maxSkill = 0,
        lastScanned = 0,
        recipeCount = 0,
        recipes = {},
    }
    return character.professions[key]
end

function EL:GetCurrentTradeSkillInfo()
    if C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillLine then
        local skillLineID, displayName, rank, maxRank = SafeCall(C_TradeSkillUI.GetTradeSkillLine)
        if displayName and displayName ~= "" then
            return {name=displayName, skillLineID=skillLineID, skill=rank or 0, maxSkill=maxRank or 0, api="modern"}
        end
    end

    if GetTradeSkillLine then
        local name, rank, maxRank = SafeCall(GetTradeSkillLine)
        if name and name ~= "" and name ~= "UNKNOWN" then
            return {name=name, skillLineID=nil, skill=rank or 0, maxSkill=maxRank or 0, api="legacy"}
        end
    end
    return nil
end

function EL:ScanCurrentProfession()
    local empire = self:GetEmpire()
    if not empire then return false, "Inget Empire finns." end

    local key = self:GetCharacterKey()
    local character = empire.characters[key]
    if not character then
        return false, "Karaktären är inte registrerad. Kör /empire join först."
    end

    local trade = self:GetCurrentTradeSkillInfo()
    if not trade then
        return false, "Ingen profession verkar vara öppen."
    end

    local prof = EnsureProfessionTable(character, trade.name)
    prof.name = trade.name
    prof.skillLineID = trade.skillLineID
    prof.skill = trade.skill or 0
    prof.maxSkill = trade.maxSkill or 0
    prof.lastScanned = time()
    prof.recipes = {}

    local recipeCount = 0

    if trade.api == "modern" and C_TradeSkillUI and C_TradeSkillUI.GetAllRecipeIDs and C_TradeSkillUI.GetRecipeInfo then
        local recipeIDs = SafeCall(C_TradeSkillUI.GetAllRecipeIDs) or {}

        for _, recipeID in ipairs(recipeIDs) do
            local info = SafeCall(C_TradeSkillUI.GetRecipeInfo, recipeID)
            if type(info) == "table" and info.learned then
                local recipe = {
                    recipeID = recipeID,
                    name = info.name or ("Recipe " .. tostring(recipeID)),
                    icon = info.icon,
                    learned = true,
                    reagents = {},
                }

                if C_TradeSkillUI.GetRecipeItemLink then
                    local itemLink = SafeCall(C_TradeSkillUI.GetRecipeItemLink, recipeID)
                    recipe.itemLink = itemLink
                    recipe.itemID = GetItemIDFromLink(itemLink)
                end

                if C_TradeSkillUI.GetRecipeNumReagents and C_TradeSkillUI.GetRecipeReagentInfo then
                    local numReagents = SafeCall(C_TradeSkillUI.GetRecipeNumReagents, recipeID) or 0
                    for reagentIndex = 1, numReagents do
                        local r1,r2,r3,r4 = SafeCall(C_TradeSkillUI.GetRecipeReagentInfo, recipeID, reagentIndex)
                        local reagent = {}
                        if type(r1) == "table" then
                            reagent.name = r1.name
                            reagent.icon = r1.icon
                            reagent.required = r1.requiredQuantity or r1.numRequired or r1.quantity or 0
                            reagent.have = r1.haveQuantity or r1.numHave or 0
                            reagent.itemID = r1.itemID
                            reagent.itemLink = r1.itemLink
                        else
                            reagent.name = r1
                            reagent.icon = r2
                            reagent.required = r3 or 0
                            reagent.have = r4 or 0
                        end

                        if C_TradeSkillUI.GetRecipeReagentItemLink then
                            local reagentLink = SafeCall(C_TradeSkillUI.GetRecipeReagentItemLink, recipeID, reagentIndex)
                            if reagentLink then
                                reagent.itemLink = reagentLink
                                reagent.itemID = GetItemIDFromLink(reagentLink)
                            end
                        end
                        table.insert(recipe.reagents, reagent)
                    end
                end

                prof.recipes[tostring(recipeID)] = recipe
                recipeCount = recipeCount + 1
            end
        end

    elseif GetNumTradeSkills and GetTradeSkillInfo then
        local count = SafeCall(GetNumTradeSkills) or 0
        for index = 1, count do
            local name, skillType = SafeCall(GetTradeSkillInfo, index)
            if name and skillType ~= "header" then
                local recipe = {recipeID=index, name=name, learned=true, reagents={}}

                if GetTradeSkillItemLink then
                    local itemLink = SafeCall(GetTradeSkillItemLink, index)
                    recipe.itemLink = itemLink
                    recipe.itemID = GetItemIDFromLink(itemLink)
                end

                local numReagents = 0
                if GetTradeSkillNumReagents then
                    numReagents = SafeCall(GetTradeSkillNumReagents, index) or 0
                end

                for reagentIndex = 1, numReagents do
                    local reagentName, reagentTexture, required, have = SafeCall(GetTradeSkillReagentInfo, index, reagentIndex)
                    local reagent = {name=reagentName, icon=reagentTexture, required=required or 0, have=have or 0}

                    if GetTradeSkillReagentItemLink then
                        local reagentLink = SafeCall(GetTradeSkillReagentItemLink, index, reagentIndex)
                        reagent.itemLink = reagentLink
                        reagent.itemID = GetItemIDFromLink(reagentLink)
                    end
                    table.insert(recipe.reagents, reagent)
                end

                prof.recipes[tostring(index)] = recipe
                recipeCount = recipeCount + 1
            end
        end
    else
        return false, "TradeSkill-API kunde inte hittas på klienten."
    end

    prof.recipeCount = recipeCount
    character.lastSeen = time()
    return true, prof
end

function EL:PrintProfessions()
    local empire = self:GetEmpire()
    if not empire then self:Print("Inget Empire finns."); return end

    local found = false
    for _, character in pairs(empire.characters) do
        local headerPrinted = false
        for _, prof in pairs(character.professions or {}) do
            if not headerPrinted then
                self:Print("|cffffffff" .. (character.name or "?") .. "|r:")
                headerPrinted = true
                found = true
            end
            self:Print(string.format("  %s %d/%d - %d sparade recept", prof.name or "?", prof.skill or 0, prof.maxSkill or 0, prof.recipeCount or 0))
        end
    end

    if not found then
        self:Print("Inga professions har scannats ännu.")
        self:Print("Öppna en profession och kör |cffffffff/empire scan|r.")
    end
end

local function GetBagItemCount(itemID, itemLink, itemName)
    -- Classic 1.15.x doesn't always populate reagent.itemID.
    -- GetItemCount accepts item ID, item link, or item name, so try all.
    local candidates = { itemID, itemLink, itemName }

    for _, itemInfo in ipairs(candidates) do
        if itemInfo then
            if C_Item and C_Item.GetItemCount then
                local count = SafeCall(C_Item.GetItemCount, itemInfo, false, false, false)
                if count ~= nil then
                    return tonumber(count) or 0
                end
            end

            if GetItemCount then
                local count = SafeCall(GetItemCount, itemInfo, false, false)
                if count ~= nil then
                    return tonumber(count) or 0
                end
            end
        end
    end

    return nil
end

function EL:DebugRecipe(searchText)
    local empire = self:GetEmpire()
    if not empire then
        self:Print("Inget Empire finns.")
        return
    end

    searchText = string.lower(searchText or "")
    if searchText == "" then
        self:Print("Använd: |cffffffff/empire debugrecipe <namn>|r")
        return
    end

    for _, character in pairs(empire.characters) do
        for _, profession in pairs(character.professions or {}) do
            for _, recipe in pairs(profession.recipes or {}) do
                if string.find(string.lower(recipe.name or ""), searchText, 1, true) then
                    self:Print("DEBUG " .. (recipe.name or "?"))
                    for i, reagent in ipairs(recipe.reagents or {}) do
                        local have = GetBagItemCount(reagent.itemID, reagent.itemLink, reagent.name)
                        self:Print(string.format(
                            "  R%d name=%s itemID=%s link=%s count=%s",
                            i,
                            tostring(reagent.name),
                            tostring(reagent.itemID),
                            tostring(reagent.itemLink),
                            tostring(have)
                        ))
                    end
                    return
                end
            end
        end
    end

    self:Print("DEBUG: inget matchande recept hittades.")
end

function EL:FindRecipe(searchText)
 local e=self:GetEmpire(); if not e then self:Print("Inget Empire finns."); return end
 searchText=string.lower(searchText or ""); if searchText=="" then self:Print("Använd: /empire find <item/recept>"); return end
 local hits=0
 for _,c in pairs(e.characters or {}) do for _,p in pairs(c.professions or {}) do for _,r in pairs(p.recipes or {}) do
  if string.find(string.lower(r.name or ""),searchText,1,true) then hits=hits+1
   self:Print(string.format("|cff55ff55%s|r kan göra |cffffffff%s|r (%s)",c.name or "?",r.name or "?",p.name or "?"))
   local rs=r.reagents or {}; local empireAll=#rs>0; local crafterAll=#rs>0
   for _,g in ipairs(rs) do
    local need=tonumber(g.required) or 0; local cs=self:GetEmpireItemCounts(g.itemID,g.name); local own=self:GetCachedItemCount(c,g.itemID,g.name); local total=cs.total or 0
    if own<need then crafterAll=false end; if total<need then empireAll=false end
    local col=(own>=need and "|cff55ff55") or (total>=need and "|cffffaa00") or "|cffff5555"
    self:Print(string.format("    %s%dx %s|r |cffaaaaaa(crafter %d, empire %d)|r",col,need,g.name or "?",own,total))
    if total>=need and own<need then for k,n in pairs(cs.byCharacter) do if n>0 and k~=c.key then local h=e.characters[k]; self:Print(string.format("       |cffffaa00%s: %d|r",(h and h.name) or k,n)) end end end
   end
   if #rs==0 then self:Print("    |cffffaa00Materialdata saknas.|r") elseif crafterAll then self:Print("    |cff55ff55CRAFTABLE NOW|r") elseif empireAll then self:Print("    |cffffaa00CRAFTABLE IN EMPIRE|r") else self:Print("    |cffff5555MISSING MATERIALS|r") end
  end
 end end end
 self:Print("Träffar: "..hits)
end


function EL:RepairProfessionMaterialNames()
    local empire=self:GetEmpire()
    if not empire then return end

    for _,character in pairs(empire.characters or {}) do
        for _,profession in pairs(character.professions or {}) do
            for _,recipe in pairs(profession.recipes or {}) do
                for _,reagent in ipairs(recipe.reagents or {}) do
                    if not reagent.name or reagent.name=="?" then
                        local name
                        if reagent.itemID and GetItemInfo then
                            name=GetItemInfo(reagent.itemID)
                        end
                        if (not name) and reagent.itemLink and GetItemInfo then
                            name=GetItemInfo(reagent.itemLink)
                        end
                        if name then reagent.name=name end
                    end
                end
            end
        end
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("TRADE_SKILL_SHOW")
frame:RegisterEvent("TRADE_SKILL_LIST_UPDATE")
frame:RegisterEvent("TRADE_SKILL_DATA_SOURCE_CHANGED")

frame:SetScript("OnEvent", function(_, event)
    local empire = EL:GetEmpire()
    if not empire or not empire.characters[EL:GetCharacterKey()] then return end

    if event == "TRADE_SKILL_SHOW" then
        C_Timer.After(0.4, function()
            local ok, prof = EL:ScanCurrentProfession()
            if ok and prof then
                EL:PrintSuccess(string.format("%s scannad: %d/%d, %d recept.", prof.name or "Profession", prof.skill or 0, prof.maxSkill or 0, prof.recipeCount or 0))
            end
        end)
    else
        C_Timer.After(0.2, function() EL:ScanCurrentProfession() end)
    end
end)
