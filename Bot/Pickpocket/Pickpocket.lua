local DMW = DMW
local LibDraw = LibStub("LibDraw-1.0")
DMW.Bot.Pickpocket = {}
local Pickpocket = DMW.Bot.Pickpocket
local Navigation = DMW.Bot.Navigation
local Log = DMW.Bot.Log
local Hotspots = {}

local MoveToMiddle = false
local MoveToSafe = false
local EscapeWaypoints = {
    [1] = {X = 596.455505, Y = -186.959457, Z = -12.560013},
    [2] = {X = 586.799011, Y = -250.788666, Z = -13.730086},
}

local PauseFlags = {
    Hotspotting = false,
    Jumping = false,
    startedVanishTimer = false,
    StandStill = false,
    StandingStill = false,
    Escaping = false
}
local WP = 1
local Pickpocketted = {}
local vanishTimer = 0
local Player, Buff, Spell

function Pickpocket:Escape()
    local DistanceToSafe = self:GetDistance(EscapeWaypoints[2].X, EscapeWaypoints[2].Y, EscapeWaypoints[2].Z)
    local DistanceToMiddle = self:GetDistance(EscapeWaypoints[1].X, EscapeWaypoints[1].Y, EscapeWaypoints[1].Z)
    if not IsHackEnabled('multijump') then SetHackEnabled ('multijump', true) Log:DebugInfo('Multijump Enabled') end
    
    if DistanceToSafe > 5 then
        if DMW.Player.PosZ < -12 then
            JumpOrAscendStart()
        end

        if not MoveToSafe and DistanceToMiddle > 50 then MoveToMiddle = true end
        if (DistanceToMiddle <= 50 or DMW.Player.PosZ > -12) and MoveToMiddle then MoveToSafe = true MoveToMiddle = false end
        if MoveToMiddle then MoveTo(EscapeWaypoints[1].X, EscapeWaypoints[1].Y, EscapeWaypoints[1].Z) end
        if MoveToSafe then MoveTo(EscapeWaypoints[2].X, EscapeWaypoints[2].Y, EscapeWaypoints[2].Z) end
    else
        MoveToMiddle = false
        MoveToSafe = false
        WP = 1
    end
end

function Pickpocket:GetDistance(x, y, z)
    local pX, pY, pZ = ObjectPosition('player')
    return sqrt((x - pX) ^ 2) + ((y - pY) ^ 2)
end

function Pickpocket:GetBestPockets()
    local Table = {}
    for _, Unit in pairs(DMW.Attackable) do
        if Unit.Distance <= 4.8 and not self:Pocketspicked(Unit.GUID) then
            table.insert(Table, Unit)
        end
    end

    if #Table > 1 then
        table.sort(
            Table,
            function(x, y)
                return x.Distance > y.Distance
            end
        )
    end

    return Table[1]
end

function Pickpocket:PulsePockets()
    for _, Unit in pairs(DMW.Attackable) do
        if Unit.Distance <= 4.8 then
           self:PickHisPockets(Unit)
        end
    end
end

function Pickpocket:AddPocketed(unit)
    table.insert(Pickpocketted, unit)
end

function Pickpocket:Pocketspicked(unit)
    for i=1, #Pickpocketted do
        if Pickpocketted[i] == unit then 
           return true
        end
     end
     return false
end

function Pickpocket:Pulse()
    Player = DMW.Player
    Buff = Player.Buffs
    Spell = Player.Spells
    self:LootSlots()

    if Player.Target then ClearTarget() end
    --if not Spell.Vanish:IsReady() and not Spell.Preparation:IsReady() then return end
    --if not Spell.Vanish:IsReady() and Spell.Preparation:IsReady() and not Player.Combat then if Spell.Preparation:Cast() then return end end
    
    -- if we are in combat do our best to vanish.
    if Player.Combat then
        --[[
        if not PauseFlags.startedVanishTimer then
            print('Started Vanish Flag.')
            vanishTimer = DMW.Time
            PauseFlags.startedVanishTimer = true
        else
            if DMW.Time - vanishTimer >= 1.3 then
                if Spell.Vanish:IsReady() then
                    if Spell.Vanish:Cast() then
                        PauseFlags.startedVanishTimer = false
                        vanishTimer = 0
                        return
                    end
                end
            end
        end
        return
        --]]
        if not PauseFlags.Escaping then self:Escape() PauseFlags.Escaping = true C_Timer.After(0.05, function() PauseFlags.Escaping = false end) end
        return
    end
    if DMW.Player.HP < 90 then return end
    if PauseFlags.StandStill then if not PauseFlags.StandingStill then self:StopMove() PauseFlags.StandingStill = true end C_Timer.After(0.45, function() PauseFlags.StandStill = false PauseFlags.StandingStill = false end) return end

    -- Just get stealth
    if not Buff.Stealth:Exist(Player) and Spell.Stealth:IsReady() then if Spell.Stealth:Cast() then return end end

    self:WalkTheSpots()
    self:PulsePockets()
end

function Pickpocket:PickHisPockets(unit)
    if Spell.PickPocket:IsReady() then
        if Spell.PickPocket:Cast(unit) then
            PauseFlags.StandStill = true
            return
		end
    end
end

function Pickpocket:DisabledFunctions()
    WP = 1
end

function Pickpocket:LootSlots()
    for i = GetNumLootItems(), 1, -1 do
        LootSlot(i)
        ConfirmLootSlot(i)
    end
    CloseLoot()
end

function Pickpocket:StopMove()
    MoveForwardStart()
    MoveForwardStop()
end

function Pickpocket:WalkTheSpots()
    local Waypoints = DMW.Settings.profile.Pickpocket.Hotspots
    local CurrentX, CurrentY, CurrentZ, JumpType = Waypoints[WP].x, Waypoints[WP].y, Waypoints[WP].z, Waypoints[WP].j
    local DistanceToWP = Navigation:GetDistanceToPosition(CurrentX, CurrentY, CurrentZ)
    local HeightDiff = CurrentZ - DMW.Player.PosZ

    if DistanceToWP > 0.8 then
        if DistanceToWP > 0.8 and DistanceToWP < 4 and JumpType then
            if not PauseFlags.Jumping and HeightDiff > 0.4 then
                FaceDirection(CurrentX, CurrentY, CurrentZ, true)
                JumpOrAscendStart()
                PauseFlags.Jumping = true
                C_Timer.After(1, function() PauseFlags.Jumping = false end)
            end
        end
        MoveTo(CurrentX, CurrentY, CurrentZ, true)
    else
        if WP == #Waypoints then
            WP = 1
        else
            WP = WP + 1
        end
    end
end

function Pickpocket:Hotspotter()
    if IsForeground() then
        local cx, cy, cz, ctype = GetLastClickInfo()
        local altdown, alttoggle = GetKeyState(0x12)
        local ctrldown, ctrltoggle = GetKeyState(0x11)
        local shiftdown, shifttoggle = GetKeyState(0x10)
        local leftmousedown, leftmousetoggle = GetKeyState(0x01)
        local rightmousedown, rightmousetoggle = GetKeyState(0x02)
        
        if shiftdown and altdown and leftmousedown and ctype and not PauseFlags.Hotspotting then
            if self:RemoveClickSpot(cx, cy, cz) then
                Log:DebugInfo('Removed Pickpocket Hotspot [X: ' .. Round(cx) .. '] [Y: ' .. Round(cy) .. '] [Z: ' .. Round(cz) .. '] [Distance: ' .. Round(GetDistanceBetweenPositions(DMW.Player.PosX, DMW.Player.PosY, DMW.Player.PosZ, cx, cy, cz)) .. ']')
            end
        end

        if altdown and not shiftdown and not ctrldown and leftmousedown and ctype and cx ~= 0 and not PauseFlags.Hotspotting then
            if self:AddWalkSpot(cx, cy, cz) then
                Log:DebugInfo('Added Pickpocket Walk Hotspot [X: ' .. Round(cx) .. '] [Y: ' .. Round(cy) .. '] [Z: ' .. Round(cz) .. '] [Distance: ' .. Round(GetDistanceBetweenPositions(DMW.Player.PosX, DMW.Player.PosY, DMW.Player.PosZ, cx, cy, cz)) .. ']')
            end
        end

        if ctrldown and not altdown and not shiftdown and leftmousedown and ctype and cx ~= 0 and not PauseFlags.Hotspotting then
            if self:AddJumpSpot(cx, cy, cz) then
                Log:DebugInfo('Added Pickpocket Jump Hotspot [X: ' .. Round(cx) .. '] [Y: ' .. Round(cy) .. '] [Z: ' .. Round(cz) .. '] [Distance: ' .. Round(GetDistanceBetweenPositions(DMW.Player.PosX, DMW.Player.PosY, DMW.Player.PosZ, cx, cy, cz)) .. ']')
            end
        end
    end
end

function Pickpocket:RemoveClickSpot(x, y, z)
    local keyremove
    for k in pairs (DMW.Settings.profile.Pickpocket.Hotspots) do
        local hx, hy, hz = DMW.Settings.profile.Pickpocket.Hotspots[k].x, DMW.Settings.profile.Pickpocket.Hotspots[k].y, DMW.Settings.profile.Pickpocket.Hotspots[k].z
        local dist = GetDistanceBetweenPositions(x, y, z, hx, hy, hz)
        if dist < 1 then
            keyremove = k
            break
        end
    end
    if keyremove then
        table.remove(DMW.Settings.profile.Pickpocket.Hotspots, keyremove)
        PauseFlags.Hotspotting = true
        C_Timer.After(0.3, function()
            PauseFlags.Hotspotting = false
        end)
        return true
    end
    return false
end

function Pickpocket:AddWalkSpot(xx, yy, zz)
    local Spot = {x = xx, y = yy, z = zz, j = false}
    table.insert(DMW.Settings.profile.Pickpocket.Hotspots, Spot)
    PauseFlags.Hotspotting = true
    C_Timer.After(0.3, function()
        PauseFlags.Hotspotting = false
    end)
    return true
end

function Pickpocket:AddJumpSpot(xx, yy, zz)
    local Spot = {x = xx, y = yy, z = zz, j = true}
    table.insert(DMW.Settings.profile.Pickpocket.Hotspots, Spot)
    PauseFlags.Hotspotting = true
    C_Timer.After(0.3, function()
        PauseFlags.Hotspotting = false
    end)
    return true
end