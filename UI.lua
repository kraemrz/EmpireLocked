EmpireLocked=EmpireLocked or {}
local EL=EmpireLocked

local function StatusColor(status)
    if status=="NOW" then return "|cff55ff55","CRAFTABLE NOW"
    elseif status=="EMPIRE" then return "|cffffcc33","CRAFTABLE IN EMPIRE"
    else return "|cffff5555","MISSING MATERIALS" end
end

function EL:GetRecipeResults(query)
    local e=self:GetEmpire()
    local out={}
    if not e then return out end

    query=string.lower(query or "")

    for _,c in pairs(e.characters or {}) do
        for _,p in pairs(c.professions or {}) do
            for _,r in pairs(p.recipes or {}) do
                if query=="" or string.find(string.lower(r.name or ""),query,1,true) then
                    local rs=r.reagents or {}
                    local ownAll=#rs>0
                    local empireAll=#rs>0
                    local mats={}

                    for _,g in ipairs(rs) do
                        local need=tonumber(g.required) or 0
                        local counts=self:GetEmpireItemCounts(g.itemID,g.name)
                        local own=self:GetCachedItemCount(c,g.itemID,g.name)
                        local total=counts.total or 0

                        if own<need then ownAll=false end
                        if total<need then empireAll=false end

                        local holders={}
                        for k,where in pairs(counts.byCharacter or {}) do
                            local n=(type(where)=="table" and where.total) or tonumber(where) or 0
                            if n>0 then
                                local h=e.characters[k]
                                table.insert(holders,{
                                    name=(h and h.name) or k,
                                    count=n,
                                    bags=(type(where)=="table" and where.bags) or n,
                                    bank=(type(where)=="table" and where.bank) or 0
                                })
                            end
                        end
                        table.sort(holders,function(a,b) return a.name<b.name end)

                        local materialName=g.name
                        if (not materialName or materialName=="?") and g.itemID and GetItemInfo then
                            materialName=GetItemInfo(g.itemID)
                        end
                        if (not materialName or materialName=="?") and g.itemLink and GetItemInfo then
                            materialName=GetItemInfo(g.itemLink)
                        end
                        if materialName and materialName~="?" then
                            g.name=materialName
                        end

                        table.insert(mats,{
                            name=materialName or "?",
                            need=need,
                            own=own,
                            total=total,
                            holders=holders,
                            itemID=g.itemID,
                            itemLink=g.itemLink,
                        })
                    end

                    local status=ownAll and "NOW" or (empireAll and "EMPIRE" or "MISSING")

                    table.insert(out,{
                        name=r.name or "?",
                        crafter=c.name or "?",
                        profession=p.name or "?",
                        status=status,
                        materials=mats,
                        itemID=r.itemID,
                        itemLink=r.itemLink,
                        icon=r.icon,
                    })
                end
            end
        end
    end

    table.sort(out,function(x,y)
        if x.name==y.name then return x.crafter<y.crafter end
        return x.name<y.name
    end)

    return out
end

local function AddDivider(parent,y)
    local t=parent:CreateTexture(nil,"ARTWORK")
    t:SetPoint("TOPLEFT",8,y)
    t:SetPoint("TOPRIGHT",-8,y)
    t:SetHeight(1)
    t:SetColorTexture(1,1,1,.10)
end

function EL:CreateMainUI()
    if self.MainFrame then return self.MainFrame end

    local f=CreateFrame("Frame","EmpireLockedMainFrame",UIParent,"BackdropTemplate")
    f:SetSize(820,520)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart",f.StartMoving)
    f:SetScript("OnDragStop",f.StopMovingOrSizing)
    f:SetBackdrop({
        bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",
        tile=true,tileSize=32,edgeSize=32,
        insets={left=11,right=12,top=12,bottom=11}
    })

    local shade=f:CreateTexture(nil,"BACKGROUND")
    shade:SetPoint("TOPLEFT",12,-12)
    shade:SetPoint("BOTTOMRIGHT",-12,12)
    shade:SetColorTexture(0,0,0,.58)

    local title=f:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
    title:SetPoint("TOP",0,-17)
    title:SetText("EMPIRE LOCKED")

    local close=CreateFrame("Button",nil,f,"UIPanelCloseButton")
    close:SetPoint("TOPRIGHT",-7,-7)

    local empireBtn=CreateFrame("Button",nil,f,"UIPanelButtonTemplate")
    empireBtn:SetSize(120,26)
    empireBtn:SetPoint("TOPLEFT",24,-48)
    empireBtn:SetText("Empire")

    local craftBtn=CreateFrame("Button",nil,f,"UIPanelButtonTemplate")
    craftBtn:SetSize(120,26)
    craftBtn:SetPoint("LEFT",empireBtn,"RIGHT",6,0)
    craftBtn:SetText("Crafting")

    local chronicleBtn=CreateFrame("Button",nil,f,"UIPanelButtonTemplate")
    chronicleBtn:SetSize(120,26)
    chronicleBtn:SetPoint("LEFT",craftBtn,"RIGHT",6,0)
    chronicleBtn:SetText("Chronicle")

    -- Empire dashboard
    local empirePage=CreateFrame("Frame",nil,f)
    empirePage:SetPoint("TOPLEFT",24,-84)
    empirePage:SetPoint("BOTTOMRIGHT",-24,24)

    local empireScroll=CreateFrame("ScrollFrame",nil,empirePage,"UIPanelScrollFrameTemplate")
    empireScroll:SetPoint("TOPLEFT",4,-4)
    empireScroll:SetPoint("BOTTOMRIGHT",-28,4)

    local empireContent=CreateFrame("Frame",nil,empireScroll)
    empireContent:SetSize(730,1)
    empireScroll:SetScrollChild(empireContent)

    empirePage.content=empireContent
    empirePage.dynamic={}

    -- Chronicle page
    local chroniclePage=CreateFrame("Frame",nil,f)
    chroniclePage:SetPoint("TOPLEFT",24,-84)
    chroniclePage:SetPoint("BOTTOMRIGHT",-24,24)
    chroniclePage:Hide()

    local chronicleScroll=CreateFrame("ScrollFrame",nil,chroniclePage,"UIPanelScrollFrameTemplate")
    chronicleScroll:SetPoint("TOPLEFT",4,-4)
    chronicleScroll:SetPoint("BOTTOMRIGHT",-28,4)

    local chronicleContent=CreateFrame("Frame",nil,chronicleScroll)
    chronicleContent:SetSize(730,1)
    chronicleScroll:SetScrollChild(chronicleContent)
    chroniclePage.dynamic={}
    chroniclePage.collapsedArchives={}

    -- Craft page
    local craftPage=CreateFrame("Frame",nil,f)
    craftPage:SetPoint("TOPLEFT",24,-84)
    craftPage:SetPoint("BOTTOMRIGHT",-24,24)

    local searchLabel=craftPage:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    searchLabel:SetPoint("TOPLEFT",8,-4)
    searchLabel:SetText("Search")

    local search=CreateFrame("EditBox",nil,craftPage,"InputBoxTemplate")
    search:SetSize(300,28)
    search:SetPoint("TOPLEFT",8,-21)
    search:SetAutoFocus(false)
    search:SetTextInsets(8,8,0,0)

    local countText=craftPage:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
    countText:SetPoint("LEFT",search,"RIGHT",12,0)
    countText:SetText("")

    -- Left recipe list
    local listFrame=CreateFrame("Frame",nil,craftPage,"BackdropTemplate")
    listFrame:SetPoint("TOPLEFT",8,-58)
    listFrame:SetSize(360,340)
    listFrame:SetBackdrop({
        bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
        tile=true,tileSize=16,edgeSize=12,
        insets={left=3,right=3,top=3,bottom=3}
    })

    local scroll=CreateFrame("ScrollFrame",nil,listFrame,"UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",8,-8)
    scroll:SetPoint("BOTTOMRIGHT",-28,8)

    local content=CreateFrame("Frame",nil,scroll)
    content:SetSize(320,1)
    scroll:SetScrollChild(content)

    -- Right detail panel
    local detail=CreateFrame("Frame",nil,craftPage,"BackdropTemplate")
    detail:SetPoint("TOPLEFT",listFrame,"TOPRIGHT",14,0)
    detail:SetPoint("BOTTOMRIGHT",-8,8)
    detail:SetBackdrop({
        bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
        tile=true,tileSize=16,edgeSize=12,
        insets={left=3,right=3,top=3,bottom=3}
    })

    local icon=detail:CreateTexture(nil,"ARTWORK")
    icon:SetSize(42,42)
    icon:SetPoint("TOPLEFT",12,-12)
    icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")

    local dname=detail:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
    dname:SetPoint("TOPLEFT",icon,"TOPRIGHT",10,-2)
    dname:SetWidth(330)
    dname:SetJustifyH("LEFT")
    dname:SetText("Select a recipe")

    local dcrafter=detail:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    dcrafter:SetPoint("TOPLEFT",dname,"BOTTOMLEFT",0,-6)
    dcrafter:SetWidth(330)
    dcrafter:SetJustifyH("LEFT")

    local dstatus=detail:CreateFontString(nil,"OVERLAY","GameFontNormal")
    dstatus:SetPoint("TOPLEFT",12,-72)
    dstatus:SetWidth(390)
    dstatus:SetJustifyH("LEFT")

    AddDivider(detail,-98)

    local matTitle=detail:CreateFontString(nil,"OVERLAY","GameFontNormal")
    matTitle:SetPoint("TOPLEFT",12,-112)
    matTitle:SetText("Materials")

    local matText=detail:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    matText:SetPoint("TOPLEFT",12,-134)
    matText:SetWidth(385)
    matText:SetJustifyH("LEFT")
    matText:SetJustifyV("TOP")

    local holderTitle=detail:CreateFontString(nil,"OVERLAY","GameFontNormal")
    holderTitle:SetPoint("TOPLEFT",12,-258)
    holderTitle:SetText("Empire storage")

    local holderText=detail:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    holderText:SetPoint("TOPLEFT",12,-280)
    holderText:SetWidth(385)
    holderText:SetJustifyH("LEFT")
    holderText:SetJustifyV("TOP")

    local selected=nil

    local function showDetails(r)
        selected=r
        if not r then
            icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            dname:SetText("Select a recipe")
            dcrafter:SetText("")
            dstatus:SetText("")
            matText:SetText("")
            holderText:SetText("")
            return
        end

        local texture=r.icon
        if not texture and r.itemID and GetItemIcon then texture=GetItemIcon(r.itemID) end
        if not texture and r.itemID and C_Item and C_Item.GetItemIconByID then texture=C_Item.GetItemIconByID(r.itemID) end
        icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")

        dname:SetText(r.name)
        dcrafter:SetText(r.crafter.." - "..r.profession)

        local col,label=StatusColor(r.status)
        dstatus:SetText(col..label.."|r")

        local ml={}
        local holders={}
        local seen={}

        if #r.materials==0 then
            table.insert(ml,"|cffffcc33No material data stored.|r")
        end

        for _,m in ipairs(r.materials) do
            local mc=(m.own>=m.need and "|cff55ff55") or (m.total>=m.need and "|cffffcc33") or "|cffff5555"
            table.insert(ml,string.format(
                "%s%dx %s|r  |cffaaaaaa[crafter %d / empire %d]|r",
                mc,m.need,m.name,m.own,m.total
            ))

            for _,h in ipairs(m.holders or {}) do
                local key=m.name.."@"..h.name
                if not seen[key] then
                    local location=""
                    if (h.bags or 0)>0 and (h.bank or 0)>0 then
                        location=string.format("  |cff888888[Bags %d / Bank %d]|r",h.bags,h.bank)
                    elseif (h.bank or 0)>0 then
                        location=string.format("  |cff888888[Bank %d]|r",h.bank)
                    else
                        location=string.format("  |cff888888[Bags %d]|r",h.bags or h.count)
                    end
                    table.insert(holders,string.format("%s: %d x %s%s",h.name,h.count,m.name,location))
                    seen[key]=true
                end
            end
        end

        if #holders==0 then table.insert(holders,"|cff777777No cached holders.|r") end
        matText:SetText(table.concat(ml,"\n"))
        holderText:SetText(table.concat(holders,"\n"))
    end

    local function ClearEmpireDashboard()
        for _,obj in ipairs(empirePage.dynamic or {}) do
            if obj.Hide then obj:Hide() end
            if obj.SetParent then obj:SetParent(nil) end
        end
        empirePage.dynamic={}
    end

    local function AddDashboardText(text,x,y,width,font)
        local fs=empirePage.content:CreateFontString(nil,"OVERLAY",font or "GameFontHighlight")
        fs:SetPoint("TOPLEFT",x,y)
        fs:SetWidth(width or 680)
        fs:SetJustifyH("LEFT")
        fs:SetJustifyV("TOP")
        fs:SetText(text or "")
        table.insert(empirePage.dynamic,fs)
        return fs
    end

    local function AddDashboardDivider(y,width)
        local t=empirePage.content:CreateTexture(nil,"ARTWORK")
        t:SetPoint("TOPLEFT",8,y)
        t:SetSize(width or 360,1)
        t:SetColorTexture(1,1,1,.25)
        table.insert(empirePage.dynamic,t)
        return t
    end

    local function AddCharacterRow(y,name,role,level,class)
        AddDashboardText(name,8,y,135,"GameFontHighlight")
        AddDashboardText(role,153,y,140,"GameFontHighlight")
        AddDashboardText(tostring(level),308,y,60,"GameFontHighlight")
        AddDashboardText(class,393,y,170,"GameFontHighlight")
    end

    local function AddStatusRow(y,label,value,color)
        AddDashboardText(label,8,y,215,"GameFontHighlight")
        AddDashboardText((color or "")..tostring(value).."|r",230,y,250,"GameFontHighlight")
    end

    local function CountAHViolations(empire)
        local count=0
        for _,violation in ipairs(empire.violations or {}) do
            local vtype=string.upper(tostring(violation.type or ""))
            -- Only genuine Auction House violations belong in this counter.
            -- Level, gear, death, etc. must never be counted here.
            if vtype=="AUCTION_HOUSE"
                or vtype=="AH"
                or string.find(vtype,"AUCTION_HOUSE",1,true)
                or string.find(vtype,"AH_",1,true)==1 then
                count=count+1
            end
        end
        return count
    end

    local function showEmpire()
        craftPage:Hide()
        chroniclePage:Hide()
        empirePage:Show()
        ClearEmpireDashboard()

        local e=EL:GetEmpire()
        if not e then
            AddDashboardText("No Empire exists.",8,-8,680,"GameFontHighlight")
            empirePage.content:SetHeight(440)
            return
        end

        local king=e.king and e.characters[e.king]
        local statusActive=e.status=="ACTIVE"
        local y=-8

        -- Summary
        AddDashboardText("|cffffd100"..(e.name or "Empire").."|r",8,y,680,"GameFontNormal"); y=y-18
        AddDashboardText("Status: "..(statusActive and "|cff55ff55ACTIVE|r" or "|cffff5555FAILED|r"),8,y,680); y=y-30

        if king then
            AddDashboardText(string.format(
                "King: |cffffd100%s|r   Level %d %s",
                king.name or "?",king.level or 0,king.class or ""
            ),8,y,680)
        else
            AddDashboardText("King: |cffff5555NOT SET|r",8,y,680)
        end
        y=y-32

        -- Characters table
        AddDashboardText("|cffffd100CHARACTERS|r",8,y,680,"GameFontNormal"); y=y-22
        AddDashboardText("Name",8,y,135,"GameFontNormal")
        AddDashboardText("Role",153,y,140,"GameFontNormal")
        AddDashboardText("Level",308,y,60,"GameFontNormal")
        AddDashboardText("Class",393,y,170,"GameFontNormal")
        y=y-22

        local chars={}
        for _,c in pairs(e.characters or {}) do table.insert(chars,c) end
        table.sort(chars,function(a,b)
            if a.role~=b.role then return a.role=="KING" end
            return (a.name or "")<(b.name or "")
        end)

        for _,c in ipairs(chars) do
            local role=(c.role=="KING") and "[ KING ]" or "[ SUBJECT ]"
            AddCharacterRow(y,c.name or "?",role,c.level or 0,c.class or "?")
            y=y-20
        end

        y=y-8

        -- Death is technically implemented through banishment, but the
        -- dashboard should not display the same event twice. "Last banished"
        -- therefore shows only non-death removals.
        local lastManualBanish=nil
        if e.banishLog then
            for i=#e.banishLog,1,-1 do
                local entry=e.banishLog[i]
                if string.upper(tostring(entry.reason or ""))~="DIED" then
                    lastManualBanish=entry
                    break
                end
            end
        end

        if lastManualBanish then
            AddDashboardText(string.format(
                "|cffaaaaaaLast banished: %s (%s)|r",
                lastManualBanish.name or "?",
                lastManualBanish.reason or "Manual removal"
            ),8,y,680)
            y=y-20
        end

        if e.deathLog and #e.deathLog>0 then
            local death=e.deathLog[#e.deathLog]
            local details=""
            if death.level and death.class then
                details=string.format("Level %d %s",death.level,death.class)
            elseif death.class then
                details=death.class
            elseif death.level then
                details="Level "..tostring(death.level)
            else
                -- Older death records (such as Empireoffer from 0.5.x)
                -- did not store level/class yet.
                details=death.role or "SUBJECT"
            end

            AddDashboardText(string.format(
                "|cffaaaaaaLast fallen: %s (%s)|r",
                death.name or "?",
                details
            ),8,y,680)
            y=y-20
        end

        y=y-4
        AddDashboardDivider(y,360); y=y-18

        -- Rules
        AddDashboardText("|cffffd100EMPIRE RULES|r",8,y,680,"GameFontNormal"); y=y-28

        AddDashboardText("|cffffd100THE KING|r",8,y,680,"GameFontNormal"); y=y-18
        AddDashboardText("If the King dies, the Empire falls and the challenge must restart.",8,y,680); y=y-30

        AddDashboardText("|cffffd100SUBJECTS|r",8,y,680,"GameFontNormal"); y=y-18
        AddDashboardText("Subjects may never exceed the King's level.",8,y,680); y=y-18
        AddDashboardText("When a subject reaches the King's level, wait for the King.",8,y,680); y=y-30

        AddDashboardText("|cffffd100EMPIRE CRAFTED|r",8,y,680,"GameFontNormal"); y=y-18
        AddDashboardText("Only equipment crafted by members of the Empire may be equipped.",8,y,680); y=y-30

        AddDashboardText("|cffffd100NO AUCTION HOUSE|r",8,y,680,"GameFontNormal"); y=y-18
        AddDashboardText("Buying or selling through the Auction House is forbidden.",8,y,680); y=y-24

        AddDashboardDivider(y,360); y=y-20

        -- Status: starts immediately after heading, no artificial 200px gap.
        AddDashboardText("|cffffd100EMPIRE STATUS|r",8,y,680,"GameFontNormal"); y=y-30

        local levelOK=true
        if king then
            for _,c in ipairs(chars) do
                if c.role~="KING" and (c.level or 0)>(king.level or 0) then
                    levelOK=false
                    break
                end
            end
        end

        local gearIllegal,gearUnknown=0,0
        for _,gs in pairs(e.gearStatus or {}) do
            gearIllegal=gearIllegal+(gs.illegal or 0)
            gearUnknown=gearUnknown+(gs.unknown or 0)
        end

        local subjectDeaths,kingDeaths=0,0
        for _,death in ipairs(e.deathLog or {}) do
            if death.role=="KING" then kingDeaths=kingDeaths+1 else subjectDeaths=subjectDeaths+1 end
        end

        local ahViolations=CountAHViolations(e)

        AddStatusRow(y,"King registered",king and "OK" or "MISSING",king and "|cff55ff55" or "|cffff5555"); y=y-18
        AddStatusRow(y,"Level rule",levelOK and "OK" or "VIOLATION",levelOK and "|cff55ff55" or "|cffff5555"); y=y-18
        AddStatusRow(y,"Auction House violations",ahViolations,"|cffaaaaaa"); y=y-18

        if gearIllegal>0 then
            AddStatusRow(y,"Illegal equipment",gearIllegal,"|cffff5555")
        elseif gearUnknown>0 then
            AddStatusRow(y,"Gear verification",gearUnknown.." UNVERIFIED","|cffffcc33")
        else
            AddStatusRow(y,"Gear verification","OK","|cff55ff55")
        end
        y=y-26

        AddDashboardDivider(y,265); y=y-20

        AddStatusRow(y,"Subject deaths",subjectDeaths,"|cffaaaaaa"); y=y-18
        AddStatusRow(y,"King deaths",kingDeaths,kingDeaths>0 and "|cffff5555" or "|cff55ff55"); y=y-26

        AddDashboardDivider(y,265); y=y-22
        AddDashboardText(statusActive and "|cff55ff55EMPIRE ACTIVE|r" or "|cffff5555EMPIRE FAILED|r",8,y,680,"GameFontNormal")
        y=y-24

        if e.testMode then
            AddDashboardText("|cffffaa00TEST MODE ACTIVE - REAL FAILURES DISABLED|r",8,y,680,"GameFontNormal")
            y=y-22
        end

        if e.failureReason then
            AddDashboardText("|cffff5555Failure: "..e.failureReason.."|r",8,y,680,"GameFontNormal")
            y=y-26
        end

        empirePage.content:SetHeight(math.max(440,-y+20))
    end

    local function clearChronicle()
        for _,obj in ipairs(chroniclePage.dynamic or {}) do
            if obj.Hide then obj:Hide() end
            if obj.SetParent then obj:SetParent(nil) end
        end
        chroniclePage.dynamic={}
    end

    local function chronText(text,x,y,width,font)
        local fs=chronicleContent:CreateFontString(nil,"OVERLAY",font or "GameFontHighlight")
        fs:SetPoint("TOPLEFT",x,y)
        fs:SetWidth(width or 680)
        fs:SetJustifyH("LEFT")
        fs:SetText(text or "")
        table.insert(chroniclePage.dynamic,fs)
    end

    local function chronLine(y,width)
        local t=chronicleContent:CreateTexture(nil,"ARTWORK")
        t:SetPoint("TOPLEFT",8,y)
        t:SetSize(width or 430,1)
        t:SetColorTexture(1,1,1,.25)
        table.insert(chroniclePage.dynamic,t)
    end

    local function chronDuration(seconds)
        seconds=math.max(0,seconds or 0)
        local days=math.floor(seconds/86400)
        local hours=math.floor((seconds % 86400)/3600)
        local mins=math.floor((seconds % 3600)/60)
        if days>0 then return string.format("%dd %dh %dm",days,hours,mins) end
        if hours>0 then return string.format("%dh %dm",hours,mins) end
        return string.format("%dm",mins)
    end

    local function showChronicle()
        empirePage:Hide()
        craftPage:Hide()
        chroniclePage:Show()
        clearChronicle()

        local e=EL:GetEmpire()
        if not e then
            chronText("No Empire exists.",8,-8,680)
            chronicleContent:SetHeight(440)
            return
        end
        local ch=EL:EnsureChronicle()
        local king=e.king and e.characters and e.characters[e.king]
        local y=-8

        chronText("|cffffd100EMPIRE CHRONICLE|r",8,y,680,"GameFontNormalLarge"); y=y-34
        chronText("|cffffd100CURRENT REIGN|r",8,y,680,"GameFontNormal"); y=y-26
        chronText("|cffffd100"..(e.name or "Empire").."|r",8,y,680,"GameFontNormal"); y=y-22
        chronText(e.status=="ACTIVE" and "|cff55ff55ACTIVE REIGN|r" or "|cffff5555FALLEN EMPIRE|r",8,y,680,"GameFontNormal"); y=y-28
        chronLine(y); y=y-24

        chronText("|cffffd100THE REIGN|r",8,y,680,"GameFontNormal"); y=y-24
        chronText("King",8,y,180); chronText(king and king.name or "Unknown",210,y,300); y=y-19
        chronText("King level",8,y,180); chronText(king and tostring(king.level or 0) or "?",210,y,300); y=y-19
        chronText("Highest King level",8,y,180); chronText(tostring(ch.highestKingLevel or 0),210,y,300); y=y-19
        chronText("Founded",8,y,180); chronText(date("%d %b %Y",ch.foundedAt),210,y,300); y=y-19
        chronText("Current reign",8,y,180); chronText(chronDuration(time()-ch.foundedAt),210,y,300); y=y-30

        local current=0
        for _,c in pairs(e.characters or {}) do if c.role~="KING" then current=current+1 end end
        chronText("|cffffd100THE EMPIRE|r",8,y,680,"GameFontNormal"); y=y-24
        chronText("Current subjects",8,y,180); chronText(tostring(current),210,y,300); y=y-19
        chronText("Subjects recruited",8,y,180); chronText(tostring(ch.subjectsRecruited or current),210,y,300); y=y-19
        chronText("Subjects lost",8,y,180); chronText(tostring(#(e.deathLog or {})),210,y,300); y=y-30

        chronText("|cffffd100THE FALLEN|r",8,y,680,"GameFontNormal"); y=y-24
        if #(e.deathLog or {})==0 then
            chronText("|cffaaaaaaNone. The Empire endures.|r",8,y,600); y=y-22
        else
            for i=#e.deathLog,1,-1 do
                local death=e.deathLog[i]
                chronText("|cffff5555X|r  "..(death.name or "Unknown"),8,y,220,"GameFontNormal")
                local detail={}
                if death.level then table.insert(detail,"Level "..tostring(death.level)) end
                if death.class then table.insert(detail,death.class) end
                if #detail==0 then table.insert(detail,death.role or "SUBJECT") end
                chronText(table.concat(detail," "),230,y,360)
                y=y-19
            end
        end
        y=y-12

        local ah=0
        for _,v in ipairs(e.violations or {}) do
            local vt=string.upper(tostring(v.type or ""))
            if vt=="AUCTION_HOUSE" or vt=="AH" or string.find(vt,"AUCTION_HOUSE",1,true) or string.find(vt,"AH_",1,true)==1 then ah=ah+1 end
        end
        chronText("|cffffd100THE LAW|r",8,y,680,"GameFontNormal"); y=y-24
        chronText("Auction violations",8,y,180); chronText(tostring(ah),210,y,300); y=y-19
        chronText("Recorded deaths",8,y,180); chronText(tostring(#(e.deathLog or {})),210,y,300); y=y-28

        chronLine(y); y=y-26
        chronText(e.status=="ACTIVE" and "|cff55ff55THE EMPIRE ENDURES.|r" or "|cffff5555THE EMPIRE HAS FALLEN.|r",8,y,680,"GameFontNormalLarge")
        y=y-36

        chronLine(y,600); y=y-28
        chronText("|cffffd100PAST EMPIRES|r",8,y,680,"GameFontNormalLarge"); y=y-30

        local archives=EL:GetChronicleArchive()
        if not archives or #archives==0 then
            chronText("|cffaaaaaaNo archived Empires yet.|r",8,y,680); y=y-24
        else
            for i=#archives,1,-1 do
                local run=archives[i]
                local collapsed=chroniclePage.collapsedArchives[i]
                local fateText=run.finalStatus=="FAILED" and "FALLEN" or "ENDED"
                local fateColor=run.finalStatus=="FAILED" and "|cffff5555" or "|cffffcc33"
                local arrow=collapsed and ">" or "v"

                local header=CreateFrame("Button",nil,chronicleContent)
                header:SetSize(610,24)
                header:SetPoint("TOPLEFT",8,y)
                table.insert(chroniclePage.dynamic,header)

                local hi=header:CreateTexture(nil,"HIGHLIGHT")
                hi:SetAllPoints()
                hi:SetColorTexture(1,1,1,.06)

                local htext=header:CreateFontString(nil,"OVERLAY","GameFontNormal")
                htext:SetPoint("LEFT",6,0)
                htext:SetWidth(430)
                htext:SetJustifyH("LEFT")
                htext:SetText(string.format(
                    "|cffffd100%s  #%d  %s|r",
                    arrow,i,run.name or "Empire"
                ))

                local hstatus=header:CreateFontString(nil,"OVERLAY","GameFontNormal")
                hstatus:SetPoint("RIGHT",-8,0)
                hstatus:SetText(fateColor..fateText.."|r")

                header:SetScript("OnClick",function()
                    chroniclePage.collapsedArchives[i]=not chroniclePage.collapsedArchives[i]
                    showChronicle()
                end)

                y=y-28

                if not collapsed then
                    chronText("King",28,y,120)
                    chronText(string.format("%s - Level %d %s",
                        run.kingName or "?",
                        run.kingLevel or 0,
                        run.kingClass or ""
                    ),165,y,430)
                    y=y-18

                    chronText("Highest level",28,y,120)
                    chronText(tostring(run.highestKingLevel or run.kingLevel or 0),165,y,200)
                    y=y-18

                    chronText("Subjects recruited",28,y,120)
                    chronText(tostring(run.subjectsRecruited or 0),165,y,200)
                    y=y-18

                    chronText("Subjects lost",28,y,120)
                    chronText(tostring(#(run.deathLog or {})),165,y,200)
                    y=y-18

                    if run.foundedAt and run.endedAt then
                        chronText("Reign",28,y,120)
                        chronText(chronDuration(run.endedAt-run.foundedAt),165,y,220)
                        y=y-18
                    end

                    if run.failureReason then
                        chronText("Fate",28,y,120)
                        chronText("|cffff7777"..run.failureReason.."|r",165,y,470)
                        y=y-24
                    else
                        chronText("Fate",28,y,120)
                        chronText(run.endReason or "Ended",165,y,470)
                        y=y-24
                    end

                    if run.deathLog and #run.deathLog>0 then
                        chronText("|cffffd100The Fallen|r",28,y,220,"GameFontNormal")
                        y=y-20
                        for _,death in ipairs(run.deathLog) do
                            local detail={}
                            if death.level then table.insert(detail,"Level "..tostring(death.level)) end
                            if death.class then table.insert(detail,death.class) end
                            chronText("|cffff5555X|r "..(death.name or "?"),48,y,210)
                            chronText(#detail>0 and table.concat(detail," ") or (death.role or "SUBJECT"),265,y,320)
                            y=y-18
                        end
                    end
                end

                chronLine(y,560)
                y=y-20
            end
        end

        chronicleContent:SetHeight(math.max(440,-y+20))
    end

    local function clearRows()
        local children={content:GetChildren()}
        for _,child in ipairs(children) do
            child:Hide()
            child:SetParent(nil)
        end
    end

    local collapsedProfessions={}

    local function refreshCraft()
        clearRows()

        local results=EL:GetRecipeResults(search:GetText())
        countText:SetText(#results.." recipes")

        local groups={}
        for _,r in ipairs(results) do
            local profession=r.profession or "Other"
            groups[profession]=groups[profession] or {}
            table.insert(groups[profession],r)
        end

        local professionNames={}
        for profession in pairs(groups) do
            table.insert(professionNames,profession)
        end
        table.sort(professionNames)

        local y=-2

        for _,profession in ipairs(professionNames) do
            local recipes=groups[profession]

            local header=CreateFrame("Button",nil,content)
            header:SetSize(310,28)
            header:SetPoint("TOPLEFT",0,y)

            local hbg=header:CreateTexture(nil,"BACKGROUND")
            hbg:SetAllPoints()
            hbg:SetColorTexture(.12,.09,.02,.72)

            local htext=header:CreateFontString(nil,"OVERLAY","GameFontNormal")
            htext:SetPoint("LEFT",8,0)
            htext:SetJustifyH("LEFT")

            local function updateHeader()
                local arrow=collapsedProfessions[profession] and ">" or "v"
                htext:SetText(string.format("|cffffd100%s %s|r  |cff888888(%d)|r",
                    arrow,string.upper(profession),#recipes))
            end
            updateHeader()

            header:SetScript("OnClick",function()
                collapsedProfessions[profession]=not collapsedProfessions[profession]
                refreshCraft()
            end)

            y=y-30

            if not collapsedProfessions[profession] then
                for _,r in ipairs(recipes) do
                    local row=CreateFrame("Button",nil,content)
                    row:SetSize(310,42)
                    row:SetPoint("TOPLEFT",0,y)

                    local hi=row:CreateTexture(nil,"HIGHLIGHT")
                    hi:SetAllPoints()
                    hi:SetColorTexture(1,1,1,.08)

                    local ric=row:CreateTexture(nil,"ARTWORK")
                    ric:SetSize(30,30)
                    ric:SetPoint("LEFT",10,0)

                    local texture=r.icon
                    if not texture and r.itemID and GetItemIcon then texture=GetItemIcon(r.itemID) end
                    if not texture and r.itemID and C_Item and C_Item.GetItemIconByID then texture=C_Item.GetItemIconByID(r.itemID) end
                    ric:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")

                    local rn=row:CreateFontString(nil,"OVERLAY","GameFontNormal")
                    rn:SetPoint("TOPLEFT",ric,"TOPRIGHT",8,-2)
                    rn:SetWidth(188)
                    rn:SetJustifyH("LEFT")
                    rn:SetText(r.name)

                    local rw=row:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
                    rw:SetPoint("TOPLEFT",rn,"BOTTOMLEFT",0,-2)
                    rw:SetWidth(188)
                    rw:SetJustifyH("LEFT")
                    rw:SetText(r.crafter)

                    local status=row:CreateFontString(nil,"OVERLAY","GameFontNormal")
                    status:SetPoint("RIGHT",-8,0)
                    if r.status=="NOW" then
                        status:SetText("|cff55ff55OK|r")
                    elseif r.status=="EMPIRE" then
                        status:SetText("|cffffcc33EMPIRE|r")
                    else
                        status:SetText("|cffff5555X|r")
                    end

                    row:SetScript("OnClick",function() showDetails(r) end)

                    -- Recipe tooltip where WoW has an item link/ID.
                    row:SetScript("OnEnter",function(self)
                        local link=r.itemLink
                        if not link and r.itemID then
                            link=select(2,GetItemInfo(r.itemID))
                        end
                        if link then
                            GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
                            GameTooltip:SetHyperlink(link)
                            GameTooltip:Show()
                        end
                    end)
                    row:SetScript("OnLeave",function() GameTooltip:Hide() end)

                    y=y-44
                end
            end
        end

        content:SetHeight(math.max(1,-y+5))

        if selected then
            local found=false
            for _,r in ipairs(results) do
                if r.name==selected.name and r.crafter==selected.crafter then
                    showDetails(r)
                    found=true
                    break
                end
            end
            if not found then showDetails(nil) end
        elseif #results>0 then
            showDetails(results[1])
        else
            showDetails(nil)
        end
    end

    empireBtn:SetScript("OnClick",showEmpire)
    craftBtn:SetScript("OnClick",function()
        empirePage:Hide()
        chroniclePage:Hide()
        craftPage:Show()
        refreshCraft()
    end)
    chronicleBtn:SetScript("OnClick",showChronicle)

    search:SetScript("OnTextChanged",function() refreshCraft() end)
    search:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
    search:SetScript("OnEnterPressed",function(self) self:ClearFocus() end)

    f:SetScript("OnShow",showEmpire)
    f.RefreshCrafting=refreshCraft

    craftPage:Hide()
    f:Hide()
    self.MainFrame=f
    return f
end

function EL:ToggleMainUI()
    local f=self:CreateMainUI()
    if f:IsShown() then f:Hide() else f:Show() end
end
