local DMW = DMW
DMW.Bot.Misc = {}
local LibDraw = LibStub("LibDraw-1.0")
local Misc = DMW.Bot.Misc
local Log = DMW.Bot.Log
local Navigation = DMW.Bot.Navigation
local Point = DMW.Classes.Point

local PauseFlags = {
    Hotspotting = false,
    Mapwalking = false
}

local mapX, mapY, mapZ

function Misc:ClamTask()
    -- instantly opens clams and deletes meat
    if not DMW.Player.Casting then
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
    -- Uses oozing bags
    if self:HasItem('Oozing Bag') then
        UseItemByName('Oozing Bag')
        self:LootAllSlots()
    end
end

function Misc:Hotspotter()
    local altDown = IsAltKeyDown()
    local shiftDown = IsShiftKeyDown()
    local ctrlDown = IsControlKeyDown()
    local vDown = GetKeyState(0x56)
    local middleMouseDown = GetKeyState(0x04)
    local roamSize = DMW.Settings.profile.Grind.RoamDistance / 2
    local deleteSize = 10
    local x, y = GetMousePosition()
    local mx, my, mz = ScreenToWorld(x, y)
    local engageSpot = middleMouseDown and mx ~= 0 and not PauseFlags.Hotspotting
    local point = Point(mx, my, mz)

    -- Return early
    if not point or not (point.X and point.Y and point.Z) then return end

    if altDown and shiftDown then
        -- Delete vendor waypoints and grind hotspots
        LibDraw.SetColor(255, 0, 0, 100)
        LibDraw.GroundCircle(mx, my, mz, deleteSize)
        LibDraw.Text("DELETE", "GameFontNormalLarge", mx, my, mz + 3)

        if not engageSpot then return end

        removedVendorWaypoint = self:RemoveClickSpot(point, DMW.Settings.profile.Grind.VendorWaypoints)
        if removedVendorWaypoint then
            Log:DebugInfo('Removed Vendor Waypoint: ' .. removedVendorWaypoint:ToString())
        end
        removedHotspotSpot = self:RemoveClickSpot(point, DMW.Settings.profile.Grind.HotSpots)
        if removedHotspotSpot then
            Log:DebugInfo('Removed Grind Hotspot: ' .. removedHotspotSpot:ToString())
        end
    elseif altDown and vDown then
        -- Add vendor waypoint
        LibDraw.SetColor(32, 178, 170, 100)
        LibDraw.GroundCircle(mx, my, mz, 5)
        LibDraw.Text("v", "GameFontNormalLarge", mx, my, mz + 1)

        if not engageSpot then return end

        addedPoint = self:AddClickSpot(point, DMW.Settings.profile.Grind.VendorWaypoints)
        if addedPoint then
            Log:DebugInfo('Added Vendor Waypoint: ' .. addedPoint:ToString())
        end
    elseif altDown then
        -- Add hotspot
        LibDraw.SetColor(0, 100, 0, 100)
        LibDraw.GroundCircle(mx, my, mz, roamSize)
        LibDraw.Text("x", "GameFontNormalLarge", mx, my, mz + 1)

        if not engageSpot then return end

        addedPoint = self:AddClickSpot(point, DMW.Settings.profile.Grind.HotSpots)
        if addedPoint then
            Log:DebugInfo('Added Grind Hotspot: ' .. addedPoint:ToString())
        end
    end
end

function Misc:RemoveClickSpot(point, spotTable)
    for k, spot in pairs(spotTable) do
        if point:Distance(spot) < 20 then
            spotTable[k] = nil

            PauseFlags.Hotspotting = true
            C_Timer.After(0.3, function()
                PauseFlags.Hotspotting = false
            end)

            CleanNils(spotTable)

            return spot
        end
    end

    return false
end

function Misc:AddClickSpot(point, spotTable)
    if point:NearAny(spotTable, DMW.Settings.profile.Grind.RoamDistance) then
        return false
    end

    table.insert(spotTable, point)

    PauseFlags.Hotspotting = true
    C_Timer.After(0.3, function()
        PauseFlags.Hotspotting = false
    end)

    return point
end

function Misc:RotationToggle()
    if DMW.Settings.profile.Grind.SkipCombatOnTransport then
        -- if we have skip aggro enabled then if we are near hotspot(200 yards) enable rotation otherwise disable it.
        if Navigation:NearHotspot(250) then
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

function Misc:WorldMapHook()
    if WorldMapFrame:IsVisible() and IsControlKeyDown() and IsMouseButtonDown("LeftButton") and not Mapwalking then
        local x, y = WorldMapFrame.ScrollContainer:GetNormalizedCursorPosition()
        local continentID, worldPosition = C_Map.GetWorldPosFromMapPos(WorldMapFrame:GetMapID(), CreateVector2D(x, y))
        local WX, WY = worldPosition:GetXY()
        local WZ = select(3, TraceLine(WX, WY, 10000, WX, WY, -10000, 0x110))
        if not WZ and WorldPreload(WX, WY, DMW.Player.PosZ) then
            WZ = select(3, TraceLine(WX, WY, 9999, WX, WY, -9999, 0x110))
        end
        if WZ then
            Log:NormalInfo('Moving to your selected destination.')
            mapX, mapY, mapZ = WX, WY, WZ
            Mapwalking = true
            C_Timer.After(1, function() Mapwalking = false end)
        end
    end

    if not mapX then return false end

    if mapX then
        local Distance = sqrt((mapX - DMW.Player.PosX) ^ 2) + ((mapY - DMW.Player.PosY) ^ 2)
        if Distance > 1 then
            Navigation:MoveTo(mapX, mapY, mapZ, true)
            return true
        else
            Log:NormalInfo('Destination reached.')
            mapX = nil mapY = nil mapZ = nil
        end
    end
end

function Misc:GetFreeSlots()
    local Total = 0
    for Bag = 0, NUM_BAG_SLOTS do
        local Free = GetContainerNumFreeSlots(Bag)
        Total = Total + Free
    end
    return Total
end
