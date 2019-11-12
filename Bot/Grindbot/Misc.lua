local DMW = DMW
DMW.Bot.Misc = {}
local Misc = DMW.Bot.Misc

local PauseFlags = {
    Hotspotting = false
}

function Misc:ClamTask()
    -- instantly opens clams and deletes meat
    for BagID = 0, 4 do
        for BagSlot = 1, GetContainerNumSlots(BagID) do
            CurrentItemLink = GetContainerItemLink(BagID, BagSlot)
            if CurrentItemLink then
                name = GetItemInfo(CurrentItemLink)
                if string.find(name, 'Clam Meat') then
                    PickupContainerItem(BagID,BagSlot); 
                    DeleteCursorItem();
                    return
                end
                
                if name == 'Big-mouth Clam' or name == 'Thick-shelled Clam' or name == 'Small Barnacled Clam' then
                    UseContainerItem(BagID, BagSlot)
                    return
                end
            end
        end
    end
    self:LootAllSlots()
end

function Misc:LootAllSlots()
    for i = GetNumLootItems(), 1, -1 do
        LootSlot(i)
        ConfirmLootSlot(i)
    end
    CloseLoot()
end

function Misc:DeleteTask()
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

function Misc:Hotspotter()
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

        if altdown and not shiftdown and leftmousedown and ctype and cx ~= 0 then
            if self:AddClickSpot(cx, cy, cz) then
                Log:DebugInfo('Added Grind Hotspot [X: ' .. Round(cx) .. '] [Y: ' .. Round(cy) .. '] [Z: ' .. Round(cz) .. '] [Distance: ' .. Round(GetDistanceBetweenPositions(DMW.Player.PosX, DMW.Player.PosY, DMW.Player.PosZ, cx, cy, cz)) .. ']')
            end
        end
    end
end

function Misc:RemoveClickSpot(x, y, z)
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

function Misc:AddClickSpot(xx, yy, zz)
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

function Misc:RotationToggle()
    if DMW.Settings.profile.Grind.SkipCombatOnTransport then
        -- if we have skip aggro enabled then if we are near hotspot(150 yards) enable rotation otherwise disable it.
        if Navigation:NearHotspot(130) then
            RunMacroText('/LILIUM HUD Rotation 1')
        else
            RunMacroText('/LILIUM HUD Rotation 2')
        end
    else
        -- If we dont have skip aggro then Enable rotation if its disabled
            RunMacroText('/LILIUM HUD Rotation 1')
    end
end

function Misc:HasItem(itemname)
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

function Misc:GetFreeSlots()
    local Total = 0
    for Bag = 0, NUM_BAG_SLOTS do
        local Free = GetContainerNumFreeSlots(Bag)
        Total = Total + Free
    end
    return Total
end