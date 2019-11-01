local DMW = DMW
local LibDraw = LibStub("LibDraw-1.0")
DMW.Bot.Navigation = {}
local Navigation = DMW.Bot.Navigation
local Grindbot = DMW.Bot.Grindbot
local Log = DMW.Bot.Log
local NavPath = nil
local pathIndex = 1
local HotSpotIndex = 1
local lastX, lastY, lastZ = 0, 0, 0
local DestX, DestY, DestZ
local EndX, EndY, EndZ
local PathUpdated = false
local stuckCount = 0

local ObsDistance = 4
local ObsFlags = bit.bor(0x1, 0x10)

local mountBlackList = {
    x = 0,
    y = 0,
    z = 0
}

local Movement = {
    DistanceTraveled = 0,
    StartX,
    StartY,
    StartZ,
    MoveStartTimer = 0,
    MoveSpentTimer = 0,
    WeAreStuck = false,
    Unstucking = false,
    NeedMountPath = false,
    GotMountPath = false
}

-- Movement check functions
function GameObjectInfront()
    local px, py, pz = ObjectPosition('player')
    local facing = ObjectFacing('player')
    
    local hitcount = 0
    local misses = 0
    -- Center check
    local c = 1.2
    for i = 1, 3 do
       local HitFX,HitFY,HitFZ = TraceLine(px, py, pz + c, px + ObsDistance * math.cos(facing), py + ObsDistance * math.sin(facing), pz + c, ObsFlags)
       if HitFX ~= nil then
          hitcount = hitcount + 1
       else
          misses = misses + 1
       end
       c = c + 0.2
    end
    if hitcount > 0 then
       return true, hitcount - misses
    else
       return false
    end
end

local function GameObjectLeft()
    local px, py, pz = ObjectPosition('player')
    local facing = ObjectFacing('player')
    local hitcount = 0
    local misses = 0
    -- Left check
    local L = 0.2
    local H = 1
    for i = 1, 9 do
       local plx, ply, plz = px + L * math.cos(facing+math.pi/2), py + L * math.sin(facing+math.pi/2), pz
       local HitLX, HitLY, HitLZ = TraceLine(plx, ply, plz + H, px + ObsDistance * math.cos(facing), py + ObsDistance * math.sin(facing), pz + H, ObsFlags)
       if HitLX ~= nil then
          hitcount = hitcount + 1
       else
          misses = misses + 1
       end
       L = L + 0.2
    end
    if hitcount > 0 then
       return true, hitcount - misses
    else
       return false
    end
 end
 
local function GameObjectRight()
    local px, py, pz = ObjectPosition('player')
    local facing = ObjectFacing('player')
    local hitcount = 0
    local misses = 0
    -- Right check
    local R = 0.2
    local H = 1
    for i = 1, 9 do
       local plx, ply, plz = px + R * math.cos(facing-math.pi/2), py + R * math.sin(facing-math.pi/2), pz
       local HitRX, HitRY, HitRZ = TraceLine(plx, ply, plz + H, px + ObsDistance * math.cos(facing), py + ObsDistance * math.sin(facing), pz + H, ObsFlags)
       if HitRX ~= nil then
          hitcount = hitcount + 1
       else
          misses = misses + 1
       end
       R = R + 0.2
    end
    if hitcount > 0 then
       return true, hitcount - misses
    else
       return false
    end
end
-- Movement check functions/>

-- Misc
function SetMountBlackList()
    mountBlackList.x, mountBlackList.y, mountBlackList.z = ObjectPosition('player')
end

local function GetDistanceToPosition(x, y, z)
    local px, py, pz = ObjectPosition('player')
    return GetDistanceBetweenPositions(px, py, pz, x, y, z)
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

    if DMW.Settings.profile.Grind.drawHotspots then
        local HotSpots = DMW.Settings.profile.Grind.HotSpots
        LibDraw.SetColorRaw(76, 0, 153, 100)
        if #HotSpots > 0 then
            for i = 1, #HotSpots do
                if HotSpots[i] then
                    local x, y, z = HotSpots[i].x, HotSpots[i].y, HotSpots[i].z
                    LibDraw.Text("x", "GameFontNormalLarge", x, y, z)
                    if DMW.Settings.profile.Grind.drawCircles then LibDraw.Circle(x, y, z, DMW.Settings.profile.Grind.RoamDistance) end
                end
            end
        end
    end
end

function Navigation:GetActualGround(x, y, z)
    local HitX, HitY, HitZ = TraceLine (x, y, z + 0.5, x, y, z - 5 , bit.bor(0x30151))
    return HitZ
end

function Navigation:Movement()
    if NavPath and not DMW.Player.Casting then
        DestX = NavPath[pathIndex][1]
        DestY = NavPath[pathIndex][2]
        DestZ = NavPath[pathIndex][3]

        if self:CalcPathDistance(NavPath) > 80 and self:CanMount() then
            self:Mount()
            return
        end

        local pX, pY, pZ = ObjectPosition('player')
       --local Distance = GetDistanceBetweenPositions(DMW.Player.PosX, DMW.Player.PosY, DMW.Player.PosZ, DestX, DestY, DestZ)
        local Distance = sqrt((DestX - pX) ^ 2) + ((DestY - pY) ^ 2) 

        if Distance <= 1 then
            pathIndex = pathIndex + 1
            if pathIndex > #NavPath then
                pathIndex = 1
                NavPath = nil
            end
        else
            if lastX == DMW.Player.PosX and lastY == DMW.Player.PosY and lastZ == DMW.Player.PosZ then
                stuckCount = stuckCount + 1
                if stuckCount > 100 then
                    JumpOrAscendStart()
                    self:Unstuck()
                    stuckCount = 0
                end
            end
            MoveTo(DestX, DestY, DestZ)
            lastX = DMW.Player.PosX
            lastY = DMW.Player.PosY
            lastZ = DMW.Player.PosZ
        end
    end
end

function Navigation:MoveTo(toX, toY, toZ)
    if EndX and GetDistanceBetweenPositions(toX, toY, toZ, EndX, EndY, EndZ) < 1 then return end

    pathIndex = 1
    NavPath = CalculatePath(GetMapId(), DMW.Player.PosX, DMW.Player.PosY, DMW.Player.PosZ, toX, toY, toZ, true, false)

    if NavPath then
        EndX, EndY, EndZ = toX, toY, toZ
    end
end

function Navigation:Roam()
    local HotSpots = DMW.Settings.profile.Grind.HotSpots
    local distance = GetDistanceToPosition(HotSpots[HotSpotIndex].x, HotSpots[HotSpotIndex].y, HotSpots[HotSpotIndex].z)

    if HotSpotIndex == #HotSpots and distance < 5 then
        HotSpotIndex = 1
    else
        if distance < 5 then
            HotSpotIndex = HotSpotIndex + 1
        end
    end

    self:MoveTo(HotSpots[HotSpotIndex].x, HotSpots[HotSpotIndex].y, HotSpots[HotSpotIndex].z)
end

function Navigation:CanMount()
    return DMW.Settings.profile.Grind.UseMount and not UnitIsDeadOrGhost('player') and not IsIndoors() and not IsMounted() and GetDistanceBetweenPositions(mountBlackList.x, mountBlackList.y, mountBlackList.z, DMW.Player.PosX, DMW.Player.PosY, DMW.Player.PosZ) > 8
end

function Navigation:Mount()
    if not DMW.Player.Casting and not IsMounted() then
        if DMW.Player.Moving then
            self:StopMoving()
            return
        else
            UseItemByName(DMW.Settings.profile.Grind.MountName)
        end
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
    if NavPath ~= nil then
        NavPath = nil
        pathIndex = 1
        DestX = nil 
        DestY = nil
        DestZ = nil
        EndX = nil
        EndY = nil 
        EndZ = nil
        stuckCount = 0
    end
end


function Navigation:MoveToCorpse()
    if not UnitIsGhost('player') then RepopMe() return end
    if StaticPopup1 and StaticPopup1:IsVisible() and (StaticPopup1.which == "DEATH" or StaticPopup1.which == "RECOVER_CORPSE") and StaticPopup1Button1 and StaticPopup1Button1:IsEnabled() then
        StaticPopup1Button1:Click()
        NavPath = nil
        return
    end
    local PosX, PosY, PosZ = GetCorpsePosition()
    self:MoveTo(PosX, PosY, PosZ)
end

function Navigation:StopMoving()
    if DMW.Player.Moving then
        pX, pY, pZ = ObjectPosition('player')
        MoveTo(pX,pY,pZ, true)
        --MoveForwardStart()
        --MoveForwardStop()
        self:ResetPath()
    end
end

function Navigation:Unstuck()
    local left, leftcount = GameObjectLeft()
    local right, rightcount = GameObjectRight()
    local front, frontcount = GameObjectInfront()

    print('|cffff0000Unstuck!')
    if left and right then
        if leftcount > rightcount then
            StrafeLeftStart()
            C_Timer.After(0.2, function() StrafeLeftStop() end)
        else
            StrafeRightStart()
            C_Timer.After(0.2, function() StrafeRightStop() end)
        end
    elseif left and not right then
        StrafeRightStart()
        C_Timer.After(0.2, function() StrafeRightStop() end)
    elseif right and not left then
        StrafeLeftStart()
        C_Timer.After(0.2, function() StrafeLeftStop() end)
    end
    self:ResetPath()
end