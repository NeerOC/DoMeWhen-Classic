local DMW = DMW
DMW.Bot.Pickpocket = {}
local Pickpocket = DMW.Bot.Pickpocket
local Navigation = DMW.Bot.Navigation
local Log = DMW.Bot.Log
local Hotspots = {}
local PauseFlags = {
    Hotspotting = false,
    Jumping = false
}
local WP = 1


function Pickpocket:Pulse()
    Pickpocket:WalkTheSpots()
end

function Pickpocket:WalkTheSpots()
    local Waypoints = DMW.Settings.profile.Pickpocket.Hotspots
    local CurrentX, CurrentY, CurrentZ, JumpType = Waypoints[WP].x, Waypoints[WP].y, Waypoints[WP].z, Waypoints[WP].j
    local DistanceToWP = Navigation:GetDistanceToPosition(CurrentX, CurrentY, CurrentZ)
    
    if DistanceToWP > 0.8 then
        if DistanceToWP > 0.8 and DistanceToWP < 3 and JumpType then
            if not PauseFlags.Jumping then
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
        DMW.Settings.profile.Pickpocket.Hotspots [keyremove] = nil
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