EmpireLocked=EmpireLocked or {}
local EL=EmpireLocked

local function Slots(b)
    if C_Container and C_Container.GetContainerNumSlots then return C_Container.GetContainerNumSlots(b) or 0 end
    if GetContainerNumSlots then return GetContainerNumSlots(b) or 0 end
    return 0
end
local function Link(b,s)
    if C_Container and C_Container.GetContainerItemLink then return C_Container.GetContainerItemLink(b,s) end
    if GetContainerItemLink then return GetContainerItemLink(b,s) end
end
local function Count(b,s)
    if C_Container and C_Container.GetContainerItemInfo then
        local i=C_Container.GetContainerItemInfo(b,s)
        return i and i.stackCount or 0
    elseif GetContainerItemInfo then
        local _,n=GetContainerItemInfo(b,s)
        return n or 0
    end
    return 0
end
local function AddItem(items,link,count)
    local id=link and tonumber(link:match("item:(%d+)"))
    if not id then return end
    if not items[id] then
        items[id]={itemID=id,name=GetItemInfo and GetItemInfo(id) or nil,itemLink=link,count=0}
    end
    items[id].count=items[id].count+(count or 0)
end
local function ScanBags()
    local items={}
    for b=0,4 do
        for s=1,Slots(b) do
            local l=Link(b,s)
            if l then AddItem(items,l,Count(b,s)) end
        end
    end
    return items
end
local function ScanBank()
    local items={}
    -- Main bank container
    local bankBag=BANK_CONTAINER or -1
    for s=1,Slots(bankBag) do
        local l=Link(bankBag,s)
        if l then AddItem(items,l,Count(bankBag,s)) end
    end
    -- Classic bank bags are container IDs 5-11.
    for b=5,11 do
        for s=1,Slots(b) do
            local l=Link(b,s)
            if l then AddItem(items,l,Count(b,s)) end
        end
    end
    return items
end

function EL:ScanInventory(silent)
    local e=self:GetEmpire(); if not e then return false end
    local c=e.characters[self:GetCharacterKey()]; if not c then return false end
    c.inventory=c.inventory or {}
    c.inventory.items=ScanBags()
    c.inventory.lastScanned=time()
    c.inventory.bankItems=c.inventory.bankItems or {}
    c.inventory.bankLastScanned=c.inventory.bankLastScanned or 0
    if not silent then self:PrintSuccess((c.name or "?").." bags cached.") end
    return true
end

function EL:ScanBank(silent)
    local e=self:GetEmpire(); if not e then return false end
    local c=e.characters[self:GetCharacterKey()]; if not c then return false end
    c.inventory=c.inventory or {}
    c.inventory.items=c.inventory.items or {}
    c.inventory.bankItems=ScanBank()
    c.inventory.bankLastScanned=time()
    if not silent then self:PrintSuccess((c.name or "?").." bank cached.") end
    return true
end

local function CachedCount(items,id,name)
    if not items then return 0 end
    if id and items[id] then return tonumber(items[id].count) or 0 end
    if name then
        local wanted=string.lower(name)
        for _,i in pairs(items) do
            if i.name and string.lower(i.name)==wanted then return tonumber(i.count) or 0 end
        end
    end
    return 0
end

function EL:GetCachedItemBreakdown(c,id,name)
    local inv=c and c.inventory
    local bags=CachedCount(inv and inv.items,id,name)
    local bank=CachedCount(inv and inv.bankItems,id,name)
    return bags,bank,bags+bank
end

function EL:GetCachedItemCount(c,id,name)
    local _,_,total=self:GetCachedItemBreakdown(c,id,name)
    return total
end

function EL:GetEmpireItemCounts(id,name)
    local r={total=0,bagTotal=0,bankTotal=0,byCharacter={}}
    local e=self:GetEmpire(); if not e then return r end
    for k,c in pairs(e.characters or {}) do
        local bags,bank,total=self:GetCachedItemBreakdown(c,id,name)
        r.byCharacter[k]={bags=bags,bank=bank,total=total}
        r.bagTotal=r.bagTotal+bags
        r.bankTotal=r.bankTotal+bank
        r.total=r.total+total
    end
    return r
end

local f=CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("BAG_UPDATE_DELAYED")
f:RegisterEvent("BANKFRAME_OPENED")
f:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
local pending=false
local bankPending=false
f:SetScript("OnEvent",function(_,ev)
    if ev=="PLAYER_LOGIN" then
        C_Timer.After(1,function() EL:ScanInventory(true) end)
    elseif ev=="BAG_UPDATE_DELAYED" then
        if not pending then
            pending=true
            C_Timer.After(.25,function() pending=false; EL:ScanInventory(true) end)
        end
    elseif ev=="BANKFRAME_OPENED" then
        C_Timer.After(.25,function() EL:ScanBank(true) end)
    elseif ev=="PLAYERBANKSLOTS_CHANGED" then
        if not bankPending then
            bankPending=true
            C_Timer.After(.25,function() bankPending=false; EL:ScanBank(true) end)
        end
    end
end)
