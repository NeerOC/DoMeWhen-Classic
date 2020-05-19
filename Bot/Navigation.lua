local DMW = DMW
local LibDraw = LibStub("LibDraw-1.0")
DMW.Bot.Navigation = {}
local Navigation = DMW.Bot.Navigation
local Log = DMW.Bot.Log
local Point = DMW.Classes.Point
local NavPath = nil
local pathIndex = 1
local HotSpotIndex = 1
local VendorWaypointIndex = 1
local lastX, lastY, lastZ = 0, 0, 0
local safeX, safeY, safeZ
local DestX, DestY, DestZ
local WaypointX, WaypointY, WaypointZ
local EndX, EndY, EndZ
local Mounting = false
local stuckCount = 0
local mountTries = 0
local unStucking = false
local strafeTime = false
local RandomedWaypoint = false
local pvpTimer
local timerStarted = false
local acceptedRess = false
local LoggingOut = false
local ObsDistance = 4
local ObsFlags = bit.bor(0x1, 0x10)

-- Misc
function CleanNils(t)
    local ans = {}
    for _,v in pairs(t) do
      ans[ #ans+1 ] = v
    end
    return ans
end

function AddMountBlackList()
    if DMW.Player.Position:NearAny(DMW.Settings.profile.Grind.MountBlacklist, 15) then
        return
    end

    table.insert(DMW.Settings.profile.Grind.MountBlacklist, DMW.Player.Position)
    Log:DebugInfo('Added Mount Blacklist Waypoint: ' .. DMW.Player.Position:ToString())
end


function DrawWaypoints(points, radius, text)
    if not points or #points == 0 then return end

    for i = 1, #points do
        if points[i] then
            points[i]:Draw(radius, text .. i)
        end
    end
end

function Navigation:SortHotspots()
    HotSpotIndex = 1
    DMW.Settings.profile.Grind.HotSpots = CleanNils(DMW.Settings.profile.Grind.HotSpots)

    -- No point in sorting
    if #DMW.Settings.profile.Grind.HotSpots <= 1 then return end

    table.sort(
        DMW.Settings.profile.Grind.HotSpots,
        function(a,b)
            return DMW.Player.Position:TwoDimensionalDistance(a) < DMW.Player.Position:TwoDimensionalDistance(b)
        end
    )
end

function Navigation:SortVendorWaypoints()
    DMW.Settings.profile.Grind.VendorWaypoints = CleanNils(DMW.Settings.profile.Grind.VendorWaypoints)

    -- No point in sorting
    if #DMW.Settings.profile.Grind.VendorWaypoints <= 1 then return end

    table.sort(
        DMW.Settings.profile.Grind.VendorWaypoints,
        function(a,b)
            return DMW.Player.Position:TwoDimensionalDistance(a) < DMW.Player.Position:TwoDimensionalDistance(b)
        end
    )
end

function Navigation:GetDistanceToPosition(x, y, z)
    local px, py, pz = ObjectPosition('player')
    return GetDistanceBetweenPositions(px, py, pz, x, y, z)
end

function Navigation:NearHotspot(yrds)
    return DMW.Player.Position:NearAny(DMW.Settings.profile.Grind.HotSpots, yrds)
end

function Navigation:DrawVisuals()
    LibDraw.SetWidth(4)
    LibDraw.SetColorRaw(0, 128, 128, 100)

    if NavPath and DMW.Settings.profile.Grind.drawPath then
        for i = pathIndex, #NavPath do
            if i == pathIndex then
                LibDraw.Line(DMW.Player.PosX, DMW.Player.PosY, DMW.Player.PosZ, NavPath[i][1], NavPath[i][2], NavPath[i][3])
            end
            if NavPath[i + 1] then
                LibDraw.Line(NavPath[i][1], NavPath[i][2], NavPath[i][3], NavPath[i + 1][1], NavPath[i + 1][2], NavPath[i + 1][3])
            end
        end
    end

    if DMW.Settings.profile.HUD.BotMode == 1 then
        if DMW.Settings.profile.Grind.drawHotspots then
            local HotSpots = DMW.Settings.profile.Grind.HotSpots
            LibDraw.SetColor(0, 100, 0, 100) -- dark green, easy for the eyes
            DrawWaypoints(HotSpots, DMW.Settings.profile.Grind.RoamDistance * 1.5 / 2, "x")

            local VendorWaypoints = DMW.Settings.profile.Grind.VendorWaypoints
            LibDraw.SetColor(32, 178, 170, 100) -- light sea green
            DrawWaypoints(VendorWaypoints, 5, "v")
        end
    end
end

function Navigation:NodeDistance()
    _,currentSpeed = GetUnitSpeed('player')

    if currentSpeed <= 7 then return 2 end
    if currentSpeed > 8 and currentSpeed < 13 then return 4 end
    if currentSpeed > 13 then return 5 end

    return 2
end

function Navigation:Movement()
    if IsMounted() and mountTries > 0 then mountTries = 0 end
    AscendStop()

    local isPathing = (
        NavPath and
        not DMW.Player.Casting and
        not DMW.Player.Wanding and
        not DMW.Player.Disabled and
        not DMW.Player.Rooted
    )
    if not isPathing then return end

    DestX = NavPath[pathIndex][1]
    DestY = NavPath[pathIndex][2]
    DestZ = NavPath[pathIndex][3]

    if self:CalcPathDistance(NavPath) > DMW.Settings.profile.Grind.mountDistance and DMW.Settings.profile.Grind.UseMount and self:CanMount() then
        self:Mount()
        return
    end

    if DMW.Settings.profile.Grind.vendorMount and DMW.Bot.Grindbot.Mode == 4 and self:CanMount() then
        self:Mount()
        return
    end

    local pX, pY, pZ = ObjectPosition('player')
    local Distance = sqrt((DestX - pX) ^ 2) + ((DestY - pY) ^ 2)

    if Distance <= self:NodeDistance() then
        pathIndex = pathIndex + 1
        if pathIndex > #NavPath then
            pathIndex = 1
            NavPath = nil
        end
    else
        if lastX == DMW.Player.PosX and lastY == DMW.Player.PosY and not DMW.Player.Swimming then
            stuckCount = stuckCount + 1
            if stuckCount > 85 then
                Dismount()
                if not unStucking then self:Unstuck() unStucking = true stuckCount = 0 end
            end
        end
        if DestX then MoveTo(DestX, DestY, DestZ)
            lastX = DMW.Player.PosX
            lastY = DMW.Player.PosY
            lastZ = DMW.Player.PosZ
        end
    end

end

function Navigation:MoveTo(toX, toY, toZ, straight)
    if DMW.Player.Casting or EndX and GetDistanceBetweenPositions(toX, toY, toZ, EndX, EndY, EndZ) < 0.1 and NavPath then return end
    straight = straight or false
    if DMW.Player.Swimming then straight = true end

    -- lets do straight lines if distance is really far. (Untested)
    if GetDistanceBetweenPositions(DMW.Player.PosX, DMW.Player.PosY, DMW.Player.PosZ, toX, toY, toZ) > 500 then straight = true end

    pathIndex = 1
    NavPath = CalculatePath(GetMapId(), DMW.Player.PosX, DMW.Player.PosY, DMW.Player.PosZ, toX, toY, toZ, straight, true, 1)

    if NavPath then
        EndX, EndY, EndZ = toX, toY, toZ
    end
end

function Navigation:RandomizePosition(x, y, z, dist)
    local rx, ry, rz = GetPositionFromPosition(x, y, z, dist, math.random(20, 360), 360)
    local CalcedPath = CalculatePath(GetMapId(), DMW.Player.PosX, DMW.Player.PosY, DMW.Player.PosZ, rx, ry, rz, true, false, 1)
    local GroundX, GroundY, GroundZ = TraceLine(CalcedPath[#CalcedPath][1], CalcedPath[#CalcedPath][2], CalcedPath[#CalcedPath][3] + 2, CalcedPath[#CalcedPath][1], CalcedPath[#CalcedPath][2], CalcedPath[#CalcedPath][3] - 200, bit.bor(0x110))
    if not GroundZ and WorldPreload(GroundX, GroundY, DMW.Player.PosZ) then
        GroundZ = select(3, TraceLine(GroundX, GroundY, 9999, GroundX, GroundY, -9999, 0x110))
    end

    if GroundX and GroundZ then
        return GroundX, GroundY, GroundZ
    else
        return false
    end
end

function Navigation:GrindRoam()
    local HotSpots = DMW.Settings.profile.Grind.HotSpots

    if not RandomedWaypoint and DMW.Settings.profile.Grind.randomizeWaypoints and self:NearHotspot(250) then
        WaypointX, WaypointY, WaypointZ = self:RandomizePosition(
            HotSpots[HotSpotIndex].X,
            HotSpots[HotSpotIndex].Y,
            HotSpots[HotSpotIndex].Z,
            DMW.Settings.profile.Grind.randomizeWaypointDistance
        )
        if WaypointX and WaypointZ then RandomedWaypoint = true end
        return
    end

    if DMW.Settings.profile.Grind.randomizeWaypoints and self:NearHotspot(250) then
        local PX, PY, PZ = ObjectPosition('player')

        if WaypointX and WaypointY and WaypointZ then
            self:MoveTo(WaypointX, WaypointY, WaypointZ)
            local Distance = GetDistanceBetweenPositions(PX, PY, PZ, WaypointX, WaypointY, WaypointZ)
            if HotSpotIndex == #HotSpots and Distance < 5 then
                HotSpotIndex = 1
                RandomedWaypoint = false
            else
                if Distance < 5 then
                    HotSpotIndex = HotSpotIndex + 1
                    RandomedWaypoint = false
                end
            end
        end
    else
        self:MoveTo(HotSpots[HotSpotIndex].X, HotSpots[HotSpotIndex].Y, HotSpots[HotSpotIndex].Z)
        local Distance = DMW.Player.Position:Distance(HotSpots[HotSpotIndex])
        if HotSpotIndex == #HotSpots and Distance < 5 then
            -- start over from first hotspot
            HotSpotIndex = 1
        elseif Distance < 5 then
            -- move to next hotspot
            HotSpotIndex = HotSpotIndex + 1
        end
    end
end

function Navigation:InitVendorSafePath()
    Log:DebugInfo("VendorSafePath initiating")
    VendorWaypointIndex = 1
    self:SortVendorWaypoints()
end

function Navigation:VendorSafePath()
    local VendorWaypoints = DMW.Settings.profile.Grind.VendorWaypoints
    local nextWaypoint = VendorWaypoints[VendorWaypointIndex]

    if not nextWaypoint then return false end

    self:MoveTo(nextWaypoint.X, nextWaypoint.Y, nextWaypoint.Z)

    local Distance = DMW.Player.Position:Distance(nextWaypoint)
    if VendorWaypointIndex ~= #VendorWaypoints and Distance < 5 then
        -- move to next hotspot
        VendorWaypointIndex = VendorWaypointIndex + 1
        return true
    elseif Distance > 5 then
        return true
    end

    return false
end

function Navigation:CanMount()
    return (
        not unStucking and
        not DMW.Player.Swimming and
        not UnitIsDeadOrGhost('player') and
        not IsIndoors() and
        not IsMounted() and
        not DMW.Player.Position:NearAny(DMW.Settings.profile.Grind.MountBlacklist, 15) and
        not DMW.Player.Combat
    )
end

function Navigation:Mount()
    local Spell = DMW.Player.Spells
    if mountTries > 1 then
        AddMountBlackList()
        mountTries = 0
    end
    if not DMW.Player.Casting and not IsMounted() then
        if DMW.Player.Moving then
            self:StopMoving()
            return
        else
            if Spell.SummonMount and Spell.SummonMount:IsReady() and not Mounting then
                Spell.SummonMount:Cast(DMW.Player)
                self:ResetPath()
                Mounting = true
                C_Timer.After(4, function() Mounting = false if not IsMounted() then mountTries = mountTries + 1 end end)
            else
                if not Mounting and DMW.Settings.profile.Grind.MountName ~= "" and GetItemCooldown(GetItemInfoInstant(DMW.Settings.profile.Grind.MountName)) == 0 then
                    UseItemByName(DMW.Settings.profile.Grind.MountName)
                    self:ResetPath()
                    Mounting = true
                    C_Timer.After(4, function() Mounting = false if not IsMounted() then mountTries = mountTries + 1 end end)
                end
            end
        end
    end
end

function Navigation:GetPathDistanceTo(unit)
    if unit then
        local UnitPath = CalculatePath(GetMapId(), DMW.Player.PosX, DMW.Player.PosY, DMW.Player.PosZ, unit.PosX, unit.PosY, unit.PosZ, false, true, 1)
        return Navigation:CalcPathDistance(UnitPath)
    end
end

function Navigation:ReturnPathEnd()
    if NavPath then
        return NavPath[#NavPath][1],NavPath[#NavPath][2],NavPath[#NavPath][3]
    end
end

function Navigation:GetDistanceBetweenPositions(pos_a, pos_b)
    return math.sqrt(((pos_a[1] - pos_b[1])^2) + ((pos_a[2] - pos_b[2])^2) + ((pos_a[3] - pos_b[3])^2))
end

function Navigation:CalcPathDistance(peff)
    local current_node = peff[1]
    local total_distance = 0
    for i=1, #peff, 1 do
        total_distance = total_distance + self:GetDistanceBetweenPositions(current_node, peff[i])
        current_node = peff[i]
    end

    return total_distance
end

function Navigation:ResetPath()
    RandomedWaypoint = false
    NavPath = nil
    pathIndex = 1
    DestX, DestY, DestZ = nil, nil, nil
    WaypointX, WaypointY, WaypointZ = nil, nil, nil
    EndX, EndY, EndZ = nil, nil, nil
    safeX, safeY, safeZ = nil, nil, nil
    stuckCount = 0
end

function Navigation:MoveToCorpse()
    if not UnitIsGhost('player') then RepopMe() return end
    local PosX, PosY, PosZ = GetCorpsePosition()
    local DistanceToCorpse = GetDistanceBetweenPositions(DMW.Player.PosX, DMW.Player.PosY, DMW.Player.PosZ, PosX, PosY, PosZ)

    if UnitIsDeadOrGhost('player') and DMW.Player.HP > 10 and not LoggingOut then
        Logout()
        LoggingOut = true
        C_Timer.After(40, function() LoggingOut = false end)
        return
    end

    if LoggingOut then return end

    if DistanceToCorpse > 30 then
        self:MoveTo(PosX, PosY, PosZ)
    else
        local safeSpot
        safeSpot, safeX, safeY, safeZ = self:GetSafetyPosition(PosX, PosY, PosZ, 25, 10)
        if not safeX or DMW.Bot.Combat:GetUnitsNear(safeX, safeY, safeZ) then safeSpot, safeX, safeY, safeZ = self:GetSafetyPosition(PosX, PosY, PosZ, 25, 10) end
        if DMW.Settings.profile.Grind.safeRess and safeSpot and GetDistanceBetweenPositions(DMW.Player.PosX, DMW.Player.PosY, DMW.Player.PosZ, safeX, safeY, safeZ) > 1 and DMW.Bot.Combat:GetUnitsNear(DMW.Player.PosX, DMW.Player.PosY, DMW.Player.PosZ) then
            self:MoveTo(safeX, safeY, safeZ)
        else
            if DMW.Settings.profile.Grind.safeRess and DMW.Bot.Combat:GetUnitsNear(DMW.Player.PosX, DMW.Player.PosY, DMW.Player.PosZ) then return end
            if DMW.Settings.profile.Grind.preventPVP then
                if StaticPopup1Button1:IsVisible() and StaticPopup1Button1:IsEnabled() then
                    if not timerStarted then
                        Log:DebugInfo('Will now wait for ' .. DMW.Settings.profile.Grind.preventPVPTime .. ' seconds ' .. 'or until no enemy players nearby.')
                        timerStarted = true
                        pvpTimer = DMW.Time
                    else
                        if DMW.Time - pvpTimer >= DMW.Settings.profile.Grind.preventPVPTime or not DMW.Bot.Combat:EnemyPlayerNearby() then
                            --print(DMW.Time - pvpTimer .. ' < TIME| No players > ' .. DMW.Bot.Combat:EnemyPlayerNearby())
                            RetrieveCorpse()
                            C_Timer.After(1, function() timerStarted = false end)
                            self:ResetPath()
                            pvpTimer = 0
                            return
                        end
                    end
                end
            else
                if StaticPopup1Button1:IsVisible() and StaticPopup1Button1:IsEnabled() and not acceptedRess then
                    acceptedRess = true
                    C_Timer.After(0.5, function() RetrieveCorpse() self:ResetPath() acceptedRess = false end)
                    return
                end
            end
        end
    end
end

function Navigation:GetPositionBehind(dist)
    local bX, bY, bZ = GetPositionFromPosition(DMW.Player.PosX, DMW.Player.PosY, DMW.Player.PosZ, -dist, ObjectFacing('Player'))
    bZ = select(3, TraceLine(bX, bY, 9999, bX, bY, -9999, 0x110)) or 0
    if bZ then
        local hdiff = math.abs(bZ - DMW.Player.PosZ)
        if hdiff > -3 and hdiff < 6 and not DMW.Bot.Combat:GetUnitsNear(bX, bY, bZ) then
            return bX, bY, bZ
        end
    end
end

function Navigation:GetSafetyPosition(x, y, z, distance, hdiff)
    if DMW.Player.Combat then
        local bX, bY, bZ = self:GetPositionBehind(14)
        local inWater = bX and TraceLine(bX, bY, bZ, bX, bY, bZ - 100, 0x10000) == nil
        if bX and not inWater then
            return true, bX, bY, bZ
        end
    end

    for i = 0, 180 do
        local rx, ry, rz = GetPositionFromPosition(x, y, z, -distance, i, i / 1000)
        local hasHostile = DMW.Bot.Combat:GetUnitsNear(rx, ry, rz)
        local inWater = TraceLine(rx, ry, rz, rx, ry, rz - 100, 0x10000)
        local inCastLOS = DMW.Player.Target and TraceLine(DMW.Player.Target.PosX, DMW.Player.Target.PosY, DMW.Player.Target.PosZ + 1.5, rx, ry, rz + 1.5) == nil

        if not hasHostile and not inWater and (inCastLOS or not DMW.Player.Target) then
            rz = select(3, TraceLine(rx, ry, 9999, rx, ry, -9999, 0x110)) or 0
            local heightdiff = math.abs(rz - DMW.Player.PosZ)
            if heightdiff > -3 and heightdiff < hdiff then
                return true, rx, ry, rz
            end
        end
    end

    for i = 0, 180 do
        local rx, ry, rz = GetPositionFromPosition(x, y, z, distance, i, i / 1000)
        local hasHostile = DMW.Bot.Combat:GetUnitsNear(rx, ry, rz)
        local inWater = TraceLine(rx, ry, rz, rx, ry, rz - 100, 0x10000)
        if DMW.Player.Target then local inCastLOS = TraceLine(DMW.Player.Target.PosX, DMW.Player.Target.PosY, DMW.Player.Target.PosZ + 1.5, rx, ry, rz + 1.5, 0x100111) == nil end

        if not hasHostile and not inWater and (inCastLOS or not DMW.Player.Target) then
            rz = select(3, TraceLine(rx, ry, 9999, rx, ry, -9999, 0x110)) or 0
            local heightdiff = math.abs(rz - DMW.Player.PosZ)
            if heightdiff > -3 and heightdiff < hdiff then
                return true, rx, ry, rz
            end
        end
    end

    return false
end

function Navigation:StopMoving()
    if DMW.Player.Moving then
        pX, pY, pZ = ObjectPosition('player')
        MoveTo(pX,pY,pZ, true)
        self:ResetPath()
    end
end

function Navigation:Unstuck()
    Log:SevereInfo('Unstuck!')
    MoveBackwardStart()
    if not DMW.Player.Swimming then JumpOrAscendStart() end
    C_Timer.After(1.4, function() unStucking = false end)
    C_Timer.After(0.7, function() MoveBackwardStop() strafeTime = true end)
    if strafeTime then
        strafeTime = false
        StrafeLeftStart()
        C_Timer.After(math.random() + math.random(0.1, 0.3), function() StrafeLeftStop() StrafeRightStart() C_Timer.After(math.random() + math.random(0.1, 0.3), function() StrafeRightStop() self:ResetPath() end) end)
    end
end
