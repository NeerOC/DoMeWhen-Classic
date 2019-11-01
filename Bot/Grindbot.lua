local DMW = DMW
DMW.Bot.Grindbot = {}
local Navigation = DMW.Bot.Navigation
local Vendor = DMW.Bot.Vendor
local Grindbot = DMW.Bot.Grindbot
local Log = DMW.Bot.Log

local Throttle = false
local VendorTask = false

local PauseFlags = {
    Nav = false,
    Interacting = false,
    Hotspotting = false,
    Information = false
}

local Modes = {
    Resting = 0,
    Dead = 1,
    Combat = 2,
    Grinding = 3,
    Vendor = 4,
    Roaming = 5,
    Looting = 6
}

Grindbot.Mode = 0

local Settings = {
    RestHP = 60,
    RestMana = 50,
    CombatDistance = 5,
    RepairPercent = 40,
    MinFreeSlots = 5,
    RoamDistance = 100,
    BuyFood = false,
    BuyWater = false,
    FoodName = '',
    WaterName = ''
}


-- < GRIND BOT FUNCTION
function ClearHotspot()
    for k in pairs (DMW.Settings.profile.Grind.HotSpots) do
        DMW.Settings.profile.Grind.HotSpots [k] = nil
    end
    Log:DebugInfo('Hotspots Cleared!')
end

local function NearHotspot(unit)
    local HotSpots = DMW.Settings.profile.Grind.HotSpots
    local ux, uy, uz = ObjectPosition(unit)
    for i = 1, #HotSpots do
        local hx, hy, hz = HotSpots[i].x, HotSpots[i].y, HotSpots[i].z
        if GetDistanceBetweenPositions(ux, uy, uz, hx, hy, hz) < Settings.RoamDistance then
            return true
        end
    end
    return false
end

function GoodUnit(unit)
    local minLvl = UnitLevel('player') - DMW.Settings.profile.Grind.minNPCLevel
    local maxLvl = UnitLevel('player') + DMW.Settings.profile.Grind.maxNPCLevel

    local Flags = {
        isLevel = UnitLevel(unit) >= minLvl and UnitLevel(unit) <= maxLvl,
        isPVP = not UnitIsPVP(unit),
        inRange = NearHotspot(unit),
        notDead = not UnitIsDeadOrGhost(unit),
        notPlayer = not ObjectIsPlayer(unit),
        canAttack = UnitCanAttack("player", unit),
        givesExp = not UnitIsTapDenied(unit),
        notPlayerPet = not ObjectIsPlayer(ObjectCreator(unit))
    }

    for k, v in pairs(Flags) do
        if not v then
            return false
        end
    end

    return true
end


local function CanLoot()
    if Grindbot:GetFreeSlots() == 0 then return false end
        local Table = {}
        for _, Unit in pairs(DMW.Units) do
            if Unit.Dead and UnitCanBeLooted(Unit.Pointer) then
                table.insert(Table, Unit)
            end
        end
    
        if #Table > 1 then
            table.sort(
                Table,
                function(x, y)
                    return x.Distance < y.Distance
                end
            )
        end
    
        for _, Unit in ipairs(Table) do
            if Unit.Distance <= 50 then
                return true, Unit.Pointer
            end
        end
    return false
end

local function DistanceToUnit(unit)
    local px, py, pz = ObjectPosition('player')
    local tx, ty, tz = ObjectPosition(unit)
    return GetDistanceBetweenPositions(px,py,pz,tx,ty,tz)
end
-- GRIND BOT FUNCTIONS />

function Grindbot:GetFreeSlots()
local totalfree=0
for bag=0, NUM_BAG_SLOTS do
    local bagfree=tonumber((GetContainerNumFreeSlots(bag)))
    totalfree=bagfree and totalfree+bagfree or totalfree
end
    return totalfree
end

function Grindbot:HasItem(itemname)
    for BagID = 0, 4 do
        for BagSlot = 1, GetContainerNumSlots(BagID) do
            CurrentItemLink = GetContainerItemLink(BagID, BagSlot)
            if CurrentItemLink then
                name, void, Rarity, void, void, itype, SubType, void, void, void, ItemPrice = GetItemInfo(CurrentItemLink)
                if name == itemname then
                    return true
                end
            end
        end
    end
    return false
end

function Grindbot:DeleteTask()
    -- Deletes quest items so we dont get stuck looting the same shit.
    for BagID = 0, 4 do
        for BagSlot = 1, GetContainerNumSlots(BagID) do
            CurrentItemLink = GetContainerItemLink(BagID, BagSlot)
            if CurrentItemLink then
                name = GetItemInfo(CurrentItemLink)
                if string.find(name, 'Distress') then
                    PickupContainerItem(bag,slot); 
                    DeleteCursorItem();
                end
            end
        end
    end
end

function Grindbot:ClamTask()
    for BagID = 0, 4 do
        for BagSlot = 1, GetContainerNumSlots(BagID) do
            CurrentItemLink = GetContainerItemLink(BagID, BagSlot)
            if CurrentItemLink then
                name = GetItemInfo(CurrentItemLink)
                if (string.find(name, 'Clam') or string.find(name, 'clam') and not IsUsableItem(CurrentItemLink)) then
                    PickupContainerItem(bag,slot); 
                    DeleteCursorItem();
                end

                if (string.find(name, 'Clam') or string.find(name, "clam")) and IsUsableItem(CurrentItemLink) then
                    UseContainerItem(BagID, BagSlot)
                end
            end
        end
    end
end

function Grindbot:Hotspotter()
    if IsForeground() then
        local cx, cy, cz, ctype = GetLastClickInfo()
        local altdown, alttoggle = GetKeyState(0x12)
        local shiftdown, shifttoggle = GetKeyState(0x10)
        local leftmousedown, leftmousetoggle = GetKeyState(0x01)
        local rightmousedown, rightmousetoggle = GetKeyState(0x02)
        
        if shiftdown and altdown and leftmousedown and ctype then
            self:RemoveClickSpot(cx, cy, cz)
        end

        if shiftdown and not altdown and leftmousedown and ctype then
            self:AddClickSpot(cx, cy, cz)
        end
    end
end

function Grindbot:RemoveClickSpot(x, y, z)
    local keyremove
    for k in pairs (DMW.Settings.profile.Grind.HotSpots) do
        local hx, hy, hz = DMW.Settings.profile.Grind.HotSpots[k].x, DMW.Settings.profile.Grind.HotSpots[k].y, DMW.Settings.profile.Grind.HotSpots[k].z
        local dist = GetDistanceBetweenPositions(x, y, z, hx, hy, hz)
        if dist < 20 then
            keyremove = k
            break
        end
    end
    if keyremove then
        DMW.Settings.profile.Grind.HotSpots [keyremove] = nil
        PauseFlags.Hotspotting = true
        C_Timer.After(0.3, function()
            PauseFlags.Hotspotting = false
        end)
    end
end

function Grindbot:AddClickSpot(xx, yy, zz)
    local Spot = {x = xx, y = yy, z = zz}
    for k in pairs (DMW.Settings.profile.Grind.HotSpots) do
        local hx, hy, hz = DMW.Settings.profile.Grind.HotSpots[k].x, DMW.Settings.profile.Grind.HotSpots[k].y, DMW.Settings.profile.Grind.HotSpots[k].z
        local dist = GetDistanceBetweenPositions(xx, yy, zz, hx, hy, hz)
        if dist < DMW.Settings.profile.Grind.RoamDistance then
            return
        end
    end
    table.insert(DMW.Settings.profile.Grind.HotSpots, Spot)
    PauseFlags.Hotspotting = true
    C_Timer.After(0.3, function()
        PauseFlags.Hotspotting = false
    end)
end

function Grindbot:Pulse()
    -- < Do Stuff With Timer
    if not Throttle then
        self:LoadSettings()
        if DMW.Settings.profile.Grind.openClams then self:ClamTask() end
        self:DeleteTask()
        Throttle = DMW.Time
    end

    if Throttle and (DMW.Time - Throttle > 0.1) then
        Throttle = false
    end
    -- Do stuff with timer end />

    --local Vendor = DMW.Bot.Vendor
    if DMW.Settings.profile.HUD.DrawVisuals == 1 then Navigation:DrawVisuals() end

    if DMW.Settings.profile.HUD.Grindbot == 1 then
        if #DMW.Settings.profile.Grind.HotSpots < 2 then
            if not PauseFlags.Information then 
                Log:DebugInfo('You need atleast 2 hotspots.')
                PauseFlags.Information = true 
                C_Timer.After(1, function() PauseFlags.Information = false end) 
            end
            return
        end

        -- Call movement Update.
        --Navigation:Movement()

        -- This sets our state
        self:SwapMode()
        

        -- Do whatever our mode says.
        if Grindbot.Mode == Modes.Dead then
            Navigation:MoveToCorpse()
        end

        if Grindbot.Mode == Modes.Combat then
            self:AttackCombat()
        end

        if Grindbot.Mode == Modes.Resting then
            self:Rest()
        end

        if Grindbot.Mode == Modes.Vendor then
            Vendor:DoTask()
        end

        if Grindbot.Mode == Modes.Looting then
            self:GetLoot()
        end

        if Grindbot.Mode == Modes.Grinding then
            self:Grinding()
        end

        if Grindbot.Mode == Modes.Roaming then
            Navigation:Roam()
        end
    else
        if not PauseFlags.Hotspotting then self:Hotspotter() end
        Navigation:ResetPath()
    end
end

function Grindbot:GetLoot()
    local hasLoot, LootUnit = CanLoot()
    local px, py, pz = ObjectPosition('player')
    local lx, ly, lz = ObjectPosition(LootUnit)
    if GetDistanceBetweenPositions(px, py, pz, lx, ly, lz) >= 3 then
        Navigation:MoveTo(lx, ly, lz)
    else
        if IsMounted() then Dismount() end
        if not PauseFlags.Interacting then
            ObjectInteract(LootUnit)
            PauseFlags.Interacting = true
            C_Timer.After(0.7, function() PauseFlags.Interacting = false end)
        end
        for i = GetNumLootItems(), 1, -1 do
            LootSlot(i)
        end
    end
end


function Grindbot:SearchAttackable()
    local Table = {}
    for _, Unit in pairs(DMW.Units) do
        table.insert(Table, Unit)
    end
    if #Table > 1 then
        table.sort(
            Table,
            function(x, y)
                return x.Distance < y.Distance
            end
        )
    end

    -- First get line of sight units if none exist, return the closest one. (Also make sure to priortize hostile enemies)
    for _, Unit in ipairs(Table) do
        if GoodUnit(Unit.Pointer) and Unit:LineOfSight() and UnitReaction(Unit.Pointer, 'player') < 4 then
            return true, Unit
        end
    end

    for _, Unit in ipairs(Table) do
        if GoodUnit(Unit.Pointer) and Unit:LineOfSight() then
            return true, Unit
        end
    end

    for _, Unit in ipairs(Table) do
        if GoodUnit(Unit.Pointer) then
            return true, Unit
        end
    end
    
end

function Grindbot:SearchEnemy()
    local Table = {}
    for _, Unit in pairs(DMW.Attackable) do
        table.insert(Table, Unit)
    end

    if #Table > 1 then
        table.sort(
            Table,
            function(x, y)
                return x.HP < y.HP
            end
        )
    end

    -- First check if any of the mobs have mana (indicator of a caster) otherwise kill the one with lowest hp
    for _, Unit in ipairs(Table) do
        local PowerType = UnitPowerType(Unit.Pointer)
        if Unit.Distance <= 30 and (Unit:UnitThreatSituation() > 0 or (Unit.Target == GetActivePlayer() and UnitAffectingCombat(Unit.Pointer))) and PowerType == 0 then
            return true, Unit
        end
    end

    for _, Unit in ipairs(Table) do
        local PowerType = UnitPowerType(Unit.Pointer)
        if Unit.Distance <= 30 and (Unit:UnitThreatSituation() > 0 or (Unit.Target == GetActivePlayer() and UnitAffectingCombat(Unit.Pointer))) then
            return true, Unit
        end
    end
    
end

function Grindbot:Rest()
    local Eating = AuraUtil.FindAuraByName('Food', 'player')
    local Drinking = AuraUtil.FindAuraByName('Drink', 'player')

    if Settings.FoodName ~= '' then
        if DMW.Player.HP < Settings.RestHP and not Eating then
            UseItemByName(Settings.FoodName)
        end
    end

    if Settings.WaterName ~= '' then
        if UnitPower('player', 0) / UnitPowerMax('player', 0) * 100 < Settings.RestMana and not Drinking then
            UseItemByName(Settings.WaterName)
        end
    end
end

function Grindbot:Grinding()
    if not DMW.Player.Casting and not DMW.Player.Combat then
        local hasEnemy, theEnemy = self:SearchAttackable()
        if hasEnemy then 
            self:InitiateAttack(theEnemy)
        end
    end
end

function Grindbot:AttackCombat()
    local hasEnemy, theEnemy = self:SearchEnemy()
    if hasEnemy then
        self:InitiateAttack(theEnemy)
    end
end

function Grindbot:InitiateAttack(Unit)
    if (DistanceToUnit(Unit.Pointer) >= Settings.CombatDistance or not Unit:LineOfSight()) then
        Navigation:MoveTo(Unit.PosX, Unit.PosY, Unit.PosZ)
    else
        if DMW.Player.Moving then
            Navigation:StopMoving()
        end
    end

    if not UnitIsUnit(Unit.Pointer, "target") then ClearTarget() SpellStopCasting() TargetUnit(Unit.Pointer) end

    if Unit.Distance < 9 and IsMounted() then
        Dismount()
    end

    if not UnitIsFacing('player', Unit.Pointer, 60) and DistanceToUnit(Unit.Pointer) < Settings.CombatDistance and Unit:LineOfSight() then
        FaceDirection(Unit.Pointer, true)
    end
end

function Grindbot:SwapMode()
    if UnitIsDeadOrGhost('player') then
        Grindbot.Mode = Modes.Dead
        return
    end

    if not DMW.Player:Standing() and (DMW.Player.HP < 95 or  UnitPower('player', 0) > 0 and (UnitPower('player', 0) / UnitPowerMax('player', 0) * 100) < 95) then
        Grindbot.Mode = Modes.Resting
        return
    else
        if not DMW.Player:Standing() then DoEmote('STAND') end
    end

    if not DMW.Settings.profile.Grind.SkipCombatWhileMounted and self:SearchEnemy() then
        Grindbot.Mode = Modes.Combat
        return
    end

    if CanLoot() and not DMW.Player.Combat then
        Grindbot.Mode = Modes.Looting
        return
    end

    if VendorTask and Vendor:TaskDone() then
        VendorTask = false
        return
    end

    if VendorTask then
        Grindbot.Mode = Modes.Vendor
        return
    end

    if (Vendor:GetDurability() <= Settings.RepairPercent or self:GetFreeSlots() < Settings.MinFreeSlots) then
        Grindbot.Mode = Modes.Vendor
        if not VendorTask then VendorTask = true end
        return
    end

    if (Settings.BuyFood and not self:HasItem(Settings.FoodName)) or (Settings.BuyWater and not self:HasItem(Settings.WaterName)) then
        Grindbot.Mode = Modes.Vendor
        if not VendorTask then VendorTask = true end
        return
    end

    if not NearHotspot(GetActivePlayer()) then
        Grindbot.Mode = Modes.Roaming
        return
    end

    if self:SearchEnemy()  then
        Grindbot.Mode = Modes.Combat
        return
    end


    if DMW.Player.HP < Settings.RestHP or UnitPower('player', 0) > 0 and (UnitPower('player', 0) / UnitPowerMax('player', 0) * 100) < Settings.RestMana then
        Grindbot.Mode = Modes.Resting
        return
    end

    if not DMW.Player.Combat and not DMW.Player.Casting and self:SearchAttackable() then
        Grindbot.Mode = Modes.Grinding
        return
    end

    if not DMW.Player.Combat and not self:SearchAttackable() then
        Grindbot.Mode = Modes.Roaming
    end
end

function Grindbot:LoadSettings()
    if Settings.BuyWater ~= DMW.Settings.profile.Grind.BuyWater then
        Settings.BuyWater = DMW.Settings.profile.Grind.BuyWater
    end

    if Settings.BuyFood ~= DMW.Settings.profile.Grind.BuyFood then
        Settings.BuyFood = DMW.Settings.profile.Grind.BuyFood
    end

    if Settings.RoamDistance ~= DMW.Settings.profile.Grind.RoamDistance then
        Settings.RoamDistance = DMW.Settings.profile.Grind.RoamDistance 
    end

    if Settings.RepairPercent ~= DMW.Settings.profile.Grind.RepairPercent then
        Settings.RepairPercent = DMW.Settings.profile.Grind.RepairPercent
    end

    if Settings.MinFreeSlots ~= DMW.Settings.profile.Grind.MinFreeSlots then
        Settings.MinFreeSlots = DMW.Settings.profile.Grind.MinFreeSlots
    end

    if Settings.RestHP ~= DMW.Settings.profile.Grind.RestHP then
        Settings.RestHP = DMW.Settings.profile.Grind.RestHP
    end

    if Settings.RestMana ~= DMW.Settings.profile.Grind.RestMana then
        Settings.RestMana = DMW.Settings.profile.Grind.RestMana
    end

    if Settings.CombatDistance ~= DMW.Settings.profile.Grind.CombatDistance then
        Settings.CombatDistance = DMW.Settings.profile.Grind.CombatDistance
    end

    if Settings.FoodName ~= DMW.Settings.profile.Grind.FoodName then
        Settings.FoodName = DMW.Settings.profile.Grind.FoodName
    end

    if Settings.WaterName ~= DMW.Settings.profile.Grind.WaterName then
        Settings.WaterName = DMW.Settings.profile.Grind.WaterName
    end
end