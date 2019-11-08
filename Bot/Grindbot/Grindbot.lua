local DMW = DMW
DMW.Bot.Grindbot = {}
local Navigation = DMW.Bot.Navigation
local Vendor = DMW.Bot.Vendor
local Combat = DMW.Bot.Combat
local Grindbot = DMW.Bot.Grindbot
local Log = DMW.Bot.Log

local Throttle = false
local VendorTask = false
local InformationOutput = false

local PauseFlags = {
    Interacting = false,
    Hotspotting = false,
    Information = false,
    CantEat = false,
    CantDrink = false
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
    RepairPercent = 40,
    MinFreeSlots = 5,
    BuyFood = false,
    BuyWater = false,
    FoodName = '',
    WaterName = ''
}

-- Just to show our mode
local ModeFrame = CreateFrame("Frame",nil,UIParent)
ModeFrame:SetWidth(1) 
ModeFrame:SetHeight(1) 
ModeFrame:SetAlpha(.90);
ModeFrame:SetPoint("CENTER",0,-200)
ModeFrame.text = ModeFrame:CreateFontString(nil,"ARTWORK") 
ModeFrame.text:SetFont("Fonts\\ARIALN.ttf", 13, "OUTLINE")
ModeFrame.text:SetPoint("CENTER",0,0)


-- < Global functions
function ClearHotspot()
    for k in pairs (DMW.Settings.profile.Grind.HotSpots) do
        DMW.Settings.profile.Grind.HotSpots [k] = nil
    end
    Log:DebugInfo('Hotspots Cleared!')
end
-- Global functions />

function Grindbot:CanLoot()
    if Grindbot:GetFreeSlots() == 0 then return false end
    if DMW.Player.Casting then return false end

        local Table = {}
        for _, Unit in pairs(DMW.Units) do
            if Unit.Dead and (UnitCanBeLooted(Unit.Pointer) or DMW.Settings.profile.Grind.doSkin and UnitCanBeSkinned(Unit.Pointer)) then
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
            if Unit.Distance <= 30 then
                return true, Unit
            end
        end
    return false
end

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
                    PickupContainerItem(BagID, BagSlot); 
                    DeleteCursorItem();
                end
            end
        end
    end
end

function Grindbot:ClamTask()
    -- instantly opens clams and deletes meat
    for BagID = 0, 4 do
        for BagSlot = 1, GetContainerNumSlots(BagID) do
            CurrentItemLink = GetContainerItemLink(BagID, BagSlot)
            if CurrentItemLink then
                name = GetItemInfo(CurrentItemLink)
                if string.find(name, 'Clam') or string.find(name, 'clam') then
                    if not IsUsableItem(CurrentItemLink) then
                        PickupContainerItem(BagID,BagSlot); 
                        DeleteCursorItem();
                    else
                        UseContainerItem(BagID, BagSlot)
                    end
                end
            end
        end
    end

    self:LootSlots()
end

function Grindbot:Hotspotter()
    if IsForeground() then
        local cx, cy, cz, ctype = GetLastClickInfo()
        local altdown, alttoggle = GetKeyState(0x12)
        local shiftdown, shifttoggle = GetKeyState(0x10)
        local leftmousedown, leftmousetoggle = GetKeyState(0x01)
        local rightmousedown, rightmousetoggle = GetKeyState(0x02)
        
        if shiftdown and altdown and leftmousedown and ctype then
            if self:RemoveClickSpot(cx, cy, cz) then
                Log:DebugInfo('Removed Grind Hotspot [X: ' .. Round(cx) .. '] [Y: ' .. Round(cy) .. '] [Z: ' .. Round(cz) .. '] [Distance: ' .. Round(GetDistanceBetweenPositions(DMW.Player.PosX, DMW.Player.PosY, DMW.Player.PosZ, cx, cy, cz)) .. ']')
            end
        end

        if altdown and not shiftdown and leftmousedown and ctype then
            if self:AddClickSpot(cx, cy, cz) then
                Log:DebugInfo('Added Grind Hotspot [X: ' .. Round(cx) .. '] [Y: ' .. Round(cy) .. '] [Z: ' .. Round(cz) .. '] [Distance: ' .. Round(GetDistanceBetweenPositions(DMW.Player.PosX, DMW.Player.PosY, DMW.Player.PosZ, cx, cy, cz)) .. ']')
            end
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
        return true
    end
    return false
end

function Grindbot:AddClickSpot(xx, yy, zz)
    local Spot = {x = xx, y = yy, z = zz}
    for k in pairs (DMW.Settings.profile.Grind.HotSpots) do
        local hx, hy, hz = DMW.Settings.profile.Grind.HotSpots[k].x, DMW.Settings.profile.Grind.HotSpots[k].y, DMW.Settings.profile.Grind.HotSpots[k].z
        local dist = GetDistanceBetweenPositions(xx, yy, zz, hx, hy, hz)
        if dist < DMW.Settings.profile.Grind.RoamDistance then
            return false
        end
    end
    table.insert(DMW.Settings.profile.Grind.HotSpots, Spot)
    PauseFlags.Hotspotting = true
    C_Timer.After(0.3, function()
        PauseFlags.Hotspotting = false
    end)
    return true
end

function Grindbot:RotationToggle()
    if DMW.Settings.profile.Grind.SkipCombatOnTransport then
        -- if we have skip aggro enabled then if we are near hotspot(150 yards) enable rotation otherwise disable it.
        if Navigation:NearHotspot(DMW.Settings.profile.Grind.RoamDistance * 1.5) then
            RunMacroText('/LILIUM HUD Rotation 1')
        else
            RunMacroText('/LILIUM HUD Rotation 2')
        end
    else
        -- If we dont have skip aggro then Enable rotation if its disabled
            RunMacroText('/LILIUM HUD Rotation 1')
    end
end

function Grindbot:Pulse()
    -- < Do Stuff With Timer
    if not Throttle then
        self:LoadSettings()
        if DMW.Settings.profile.Grind.openClams then self:ClamTask() end
        self:DeleteTask()
        Throttle = true
        C_Timer.After(0.1, function() Throttle = false end)
    end
    -- Do stuff with timer end />

    if #DMW.Settings.profile.Grind.HotSpots < 2 then
        if not PauseFlags.Information then 
            Log:DebugInfo('You need atleast 2 hotspots.')
            PauseFlags.Information = true
            RunMacroText('/LILIUM HUD Grindbot 2')
            C_Timer.After(1, function() PauseFlags.Information = false end) 
        end
        return
    end

    -- Call the enable and disable function of rotation when going to and from vendor.
    self:RotationToggle()
    -- Call movement
    Navigation:Movement()
    if not Combat:EnemyBehind() then MoveForwardStop() end -- Just extra to make sure we dont walk like a moron

    if not InformationOutput then
        Log:NormalInfo('Food Vendor [' .. DMW.Settings.profile.Grind.FoodVendorName .. '] Distance [' .. math.floor(GetDistanceBetweenPositions(DMW.Player.PosX, DMW.Player.PosY, DMW.Player.PosZ, DMW.Settings.profile.Grind.FoodVendorX, DMW.Settings.profile.Grind.FoodVendorY, DMW.Settings.profile.Grind.FoodVendorZ)) .. ' Yrds]') 
        Log:NormalInfo('Repair Vendor [' .. DMW.Settings.profile.Grind.RepairVendorName .. '] Distance [' .. math.floor(GetDistanceBetweenPositions(DMW.Player.PosX, DMW.Player.PosY, DMW.Player.PosZ, DMW.Settings.profile.Grind.RepairVendorX, DMW.Settings.profile.Grind.RepairVendorY, DMW.Settings.profile.Grind.RepairVendorZ)) .. ' Yrds]')
        Log:NormalInfo('Number of hotspots: ' .. #DMW.Settings.profile.Grind.HotSpots)
        InformationOutput = true
    end

    -- This sets our state
    self:SwapMode()

    -- Do whatever our mode says.
    if Grindbot.Mode == Modes.Dead then
        Navigation:MoveToCorpse()
        ModeFrame.text:SetText('Corpse Run')
    end

    if Grindbot.Mode == Modes.Combat then
        Combat:AttackCombat()
        ModeFrame.text:SetText('Combat Attack')
    end

    if Grindbot.Mode == Modes.Resting then
        self:Rest()
        ModeFrame.text:SetText('Resting')
    end

    if Grindbot.Mode == Modes.Vendor then
        Vendor:DoTask()
        ModeFrame.text:SetText('Vendor run')
    end

    if Grindbot.Mode == Modes.Looting then
        self:GetLoot()
        ModeFrame.text:SetText('Looting')
    end

    if Grindbot.Mode == Modes.Grinding then
        Combat:Grinding()
        ModeFrame.text:SetText('Grinding')
    end

    if Grindbot.Mode == Modes.Roaming then
        Navigation:Roam()
        ModeFrame.text:SetText('Roaming')
    end
end

function Grindbot:DisabledFunctions()
    if not PauseFlags.Hotspotting then self:Hotspotter() end
    Navigation:ResetPath()
    Navigation:SortHotspots()
    if InformationOutput then InformationOutput = false end
    ModeFrame.text:SetText('Disabled')
end

function Grindbot:GetLoot()
    local hasLoot, LootUnit = self:CanLoot()
    local px, py, pz = ObjectPosition('player')
    local lx, ly, lz = ObjectPosition(LootUnit)

    if LootUnit then
        if LootUnit.Distance >= 5 then
            Navigation:MoveTo(LootUnit.PosX, LootUnit.PosY, LootUnit.PosZ)
        else
            if IsMounted() then Dismount() end
            if not PauseFlags.Interacting and not DMW.Player.Casting then
                for _, Unit in pairs(DMW.Units) do
                    if Unit.Dead and Unit.Distance < 5 and (UnitCanBeLooted(Unit.Pointer) or DMW.Settings.profile.Grind.doSkin and UnitCanBeSkinned(Unit.Pointer)) then
                        InteractUnit(Unit.Pointer)
                    end
                end
                PauseFlags.Interacting = true
                C_Timer.After(0.8, function() PauseFlags.Interacting = false end)
            end
        end
    end

    self:LootSlots()
end

function Grindbot:LootSlots()
    for i = GetNumLootItems(), 1, -1 do
        LootSlot(i)
        ConfirmLootSlot(i)
    end
    CloseLoot()
end

function Grindbot:Rest()
    local Eating = AuraUtil.FindAuraByName('Food', 'player')
    local Drinking = AuraUtil.FindAuraByName('Drink', 'player')

    if DMW.Player.Moving then Navigation:StopMoving() return end

    if Settings.FoodName ~= '' then
        if DMW.Player.HP < Settings.RestHP and not Eating and not PauseFlags.CantEat then
            UseItemByName(Settings.FoodName)
            PauseFlags.CantEat = true
            C_Timer.After(1, function() PauseFlags.CantEat = false end)
        end
    end

    if Settings.WaterName ~= '' then
        if UnitPower('player', 0) / UnitPowerMax('player', 0) * 100 < Settings.RestMana and not Drinking and not PauseFlags.CantDrink then
            UseItemByName(Settings.WaterName)
            PauseFlags.CantDrink = true
            C_Timer.After(1, function() PauseFlags.CantDrink = false end)
        end
    end
end

function Grindbot:SwapMode()
    if UnitIsDeadOrGhost('player') then
        Grindbot.Mode = Modes.Dead
        return
    end

    local Eating = AuraUtil.FindAuraByName('Food', 'player')
    local Drinking = AuraUtil.FindAuraByName('Drink', 'player')
    local hasEnemy, theEnemy = Combat:SearchEnemy()
    local hasAttackable, theAttackable = Combat:SearchAttackable()

    -- If we arent in combat and we arent standing (if our health is less than 95 percent and we currently have the eating buff or we are a caster and our mana iss less than 95 and we have the drinking buff) then set mode to rest.
    if not DMW.Player.Combat and not DMW.Player:Standing() and (DMW.Player.HP < 95 and Eating or UnitPower('player', 0) > 0 and (UnitPower('player', 0) / UnitPowerMax('player', 0) * 100) < 95 and Drinking) then
        Grindbot.Mode = Modes.Resting
        return
    else
        -- If the above is not true and we arent standing, we stand.
        if not DMW.Player:Standing() then DoEmote('STAND') end
    end

    -- if we dont have skip aggro enabled in pathing and we arent mounted and we are in combat, fight back.
    if not DMW.Settings.profile.Grind.SkipCombatOnTransport and not IsMounted() and hasEnemy then
        Grindbot.Mode = Modes.Combat
        return
    end

    -- If we are not in combat and not mounted and our health is less than we decided or if we use mana and its less than decided do the rest function.
    if not DMW.Player.Combat and not IsMounted() and (DMW.Player.HP < Settings.RestHP or UnitPower('player', 0) > 0 and (UnitPower('player', 0) / UnitPowerMax('player', 0) * 100) < Settings.RestMana) then
        Grindbot.Mode = Modes.Resting
        return
    end

    -- Loot out of combat?
    if self:CanLoot() and not hasEnemy then
        Grindbot.Mode = Modes.Looting
        return
    end

    -- If we got dismounted and we are near hotspot and we have an enemy and its closer than 10 yrds, attack it.
    if not IsMounted() and hasEnemy and Combat:UnitNearHotspot(theEnemy.Pointer) then
        Grindbot.Mode = Modes.Combat
        return
    end

    -- If we are on vendor task and the Vendor.lua has determined the task to be done then we set the vendor task to false.
    if VendorTask and Vendor:TaskDone() then
        VendorTask = false
        return
    end

    -- Force vendor while vendor task is true, this is set in Vendor.lua file to make sure we complete it all.
    if VendorTask then
        Grindbot.Mode = Modes.Vendor
        return
    end

    -- If our durability is less than we decided or our bag slots is less than decided, vendor task :)
    if (Vendor:GetDurability() <= Settings.RepairPercent or self:GetFreeSlots() < Settings.MinFreeSlots) then
        Grindbot.Mode = Modes.Vendor
        if not VendorTask then VendorTask = true end
        return
    end

    -- if we chose to buy food and we dont have any food, if we chose to buy water and we dont have any water, Vendor task.
    if (Settings.BuyFood and not self:HasItem(Settings.FoodName)) or (Settings.BuyWater and not self:HasItem(Settings.WaterName)) then
        Grindbot.Mode = Modes.Vendor
        if not VendorTask then VendorTask = true end
        return
    end

    -- if we are in combat and we are near hotspot, set to combat mode.
    if hasEnemy and Combat:UnitNearHotspot(theEnemy.Pointer) then
        Grindbot.Mode = Modes.Combat
        return
    end

    -- if we are not within 150 yards of the hotspots then walk to them no matter what. (IF WE CHOSE THE SKIP AGGRO SETTING)
    if not Navigation:NearHotspot(150) and DMW.Settings.profile.Grind.SkipCombatOnTransport then
        Grindbot.Mode = Modes.Roaming
        return
    end

    -- if we arent in combat and we arent casting and there are units around us, start grinding em.  (If we arent in combat or if we are in combat and our target is denied(grey) then search for new.)
    if (not DMW.Player.Combat or DMW.Player.Target and UnitIsTapDenied(DMW.Player.Target.Pointer)) and not DMW.Player.Casting and hasAttackable then
        Grindbot.Mode = Modes.Grinding
        return
    end

    -- if there isnt anything to attack and we arent in combat then roam around till we find something.
    if not hasAttackable and (not DMW.Player.Combat or DMW.Player.Target and UnitIsTapDenied(DMW.Player.Target.Pointer)) then
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

    if Settings.FoodName ~= DMW.Settings.profile.Grind.FoodName then
        Settings.FoodName = DMW.Settings.profile.Grind.FoodName
    end

    if Settings.WaterName ~= DMW.Settings.profile.Grind.WaterName then
        Settings.WaterName = DMW.Settings.profile.Grind.WaterName
    end
end