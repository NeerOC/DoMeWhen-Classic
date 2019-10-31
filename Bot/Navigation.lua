local DMW = DMW
local LibDraw = LibStub("LibDraw-1.0")
DMW.Bot.Navigation = {}
local Navigation = DMW.Bot.Navigation
local Grindbot = DMW.Bot.Grindbot
local Path = nil
local PathIndex = 1
local HotSpotIndex = 1
local DestX, DestY, DestZ
local lastX, lastY, lastZ = 0, 0, 0
local EndX, EndY, EndZ
local PathUpdated = false
local stuckCount = 0
local initNavigation = false

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

    if Path then
        for i = PathIndex, #Path do
            if i == PathIndex then
                LibDraw.Line(DMW.Player.PosX, DMW.Player.PosY, DMW.Player.PosZ, Path[i][1], Path[i][2], Path[i][3])
            end
            if Path[i + 1] then
                LibDraw.Line(Path[i][1], Path[i][2], Path[i][3], Path[i + 1][1], Path[i + 1][2], Path[i][3])
            end
        end
    end

    local HotSpots = DMW.Settings.profile.Grind.HotSpots
    LibDraw.SetColorRaw(76, 0, 153, 100)
    if #HotSpots > 0 then
        for i = 1, #HotSpots do
            if HotSpots[i] then
                local x, y, z = HotSpots[i].x, HotSpots[i].y, HotSpots[i].z
                LibDraw.Text("x", "GameFontNormalLarge", x, y, z)
            end
        end
    end
end

function Navigation:Movement()
    --[[
    if IsMounted() and not Movement.GotMountPath then Movement.NeedMountPath = true Path = nil end
    if not IsMounted() and Movement.NeedMountPath then Movement.NeedMountPath = false Movement.GotMountPath = false Path = nil end
    if self:CanMount() and Path and self:CalcPathDistance(Path) > 80 then self:Mount() return end

    if Path ~= nil then
        local PlayerX, PlayerY, PlayerZ = ObjectPosition("Player");
        DestX = Path[PathIndex][1]
        DestY = Path[PathIndex][2]
        DestZ = Path[PathIndex][3]

        
        local Distance = GetDistanceBetweenPositions(PlayerX,PlayerY,PlayerZ,DestX,DestY,DestZ)
        --local Distance = sqrt(((DestX - PlayerX) ^ 2) + ((DestY - PlayerY) ^ 2))
        if Distance < 1 then
            PathIndex = PathIndex + 1
            if PathIndex > #Path then
                PathIndex = 1
                Path = nil
            end
        else
            if lastX == PlayerX and lastY == PlayerY and lastZ == PlayerZ then
                stuckCount = stuckCount + 1
                if stuckCount > 65 then
                    MoveForwardStart()
                    JumpOrAscendStart()
                    MoveForwardStop()
                    self:Unstuck()
                    stuckCount = 0
                end
            end
            MoveTo(DestX, DestY, DestZ, true)
            lastX = PlayerX
            lastY = PlayerY
            lastZ = PlayerZ
        end
    end--]]
    local NoMoveFlags = bit.bor(DMW.Enums.UnitFlags.Stunned, DMW.Enums.UnitFlags.Confused, DMW.Enums.UnitFlags.Pacified, DMW.Enums.UnitFlags.Feared)
        if Path and not DMW.Player:HasFlag(NoMoveFlags) and not DMW.Player:HasMovementFlag(DMW.Enums.MovementFlags.Root) then
            DestX = Path[PathIndex][1]
            DestY = Path[PathIndex][2]
            DestZ = Path[PathIndex][3]
            if sqrt(((DestX - DMW.Player.PosX) ^ 2) + ((DestY - DMW.Player.PosY) ^ 2)) < 1 and math.abs(DestZ - DMW.Player.PosZ) < 4 then
                PathIndex = PathIndex + 1
                if PathIndex > #Path then
                    PathIndex = 1
                    Path = nil
                    return
                end
            elseif not DMW.Player.Moving or PathUpdated then
                PathUpdated = false
                MoveTo(DestX, DestY, DestZ, true)
            end
        end
end

function Navigation:Roam()
    local HotSpots = DMW.Settings.profile.Grind.HotSpots
    local distance = GetDistanceToPosition(HotSpots[HotSpotIndex].x, HotSpots[HotSpotIndex].y, HotSpots[HotSpotIndex].z)

    if HotSpotIndex == #HotSpots and distance < 5 then
        HotSpotIndex = 1
    else
        if distance < 5 then
            print('hop')
            HotSpotIndex = HotSpotIndex + 1
        end
    end


    self:MoveTo(HotSpots[HotSpotIndex].x, HotSpots[HotSpotIndex].y, HotSpots[HotSpotIndex].z)

end

function Navigation:CanMount()
    return DMW.Settings.profile.Grind.UseMount and not IsIndoors() and not IsMounted() and GetDistanceBetweenPositions(mountBlackList.x, mountBlackList.y, mountBlackList.z, DMW.Player.PosX, DMW.Player.PosY, DMW.Player.PosZ) > 8
end

function Navigation:Mount()
    if not DMW.Player.Casting and not IsMounted() then
        if DMW.Player.Moving then
            MoveTo(ObjectPosition('player'))
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

function Navigation:AddYardToPos(x, y, z, yrd)
    local facing = ObjectFacing('player')
    local fx, fy, fz = x + yrd * math.cos(facing), y + yrd * math.sin(facing), z
    fx, fy, fz = GetGroundZ(fx, fy, 0x100)
    return fx, fy, fz
end

function Navigation:ResetPath()
    if Path ~= nil then
        Path = nil
        PathIndex = 1
        DestX = nil 
        DestY = nil
        DestZ = nil
        EndX = nil
        EndY = nil 
        EndZ = nil
        stuckCount = 0
    end
end

function Navigation:MoveTo(toX, toY, toZ)
    --if toX == EndX and toY == EndY and toZ == EndZ then return end
    --PathIndex = 1
    --local PlayerX, PlayerY, PlayerZ = ObjectPosition("Player");
    --Path = CalculatePath(GetMapId(), PlayerX, PlayerY,PlayerZ, toX, toY, toZ, false)
    --if Path then
     --   EndX, EndY, EndZ = toX, toY, toZ
    --end
    PathIndex = 1
    Path = CalculatePath(GetMapId(), DMW.Player.PosX, DMW.Player.PosY, DMW.Player.PosZ, toX, toY, toZ, false)
    if Path then
        EndX, EndY, EndZ = toX, toY, toZ
        PathUpdated = true
        return true
    end
    return false

    
    --[[
    if Movement.NeedMountPath then
        Path = CalculatePath(GetMapId(), PlayerX, PlayerY, PlayerZ, toX, toY, toZ, true, false, 6)
        Movement.GotMountPath = true
    else
        Path = CalculatePath(GetMapId(), PlayerX, PlayerY, PlayerZ, toX, toY, toZ, false, false, 6)
    end
    --]]


    --]]
end

function Navigation:MoveToCorpse()
    if not UnitIsGhost('player') then RepopMe() return end
    if StaticPopup1 and StaticPopup1:IsVisible() and (StaticPopup1.which == "DEATH" or StaticPopup1.which == "RECOVER_CORPSE") and StaticPopup1Button1 and StaticPopup1Button1:IsEnabled() then
        StaticPopup1Button1:Click()
        Path = nil
        return
    end
    local PosX, PosY, PosZ = GetCorpsePosition()
    self:MoveTo(PosX, PosY, PosZ)
end

function Navigation:StopMoving()
    local px, py, pz = ObjectPosition('player')
    MoveTo(px, py, pz, true)
end

function Navigation:Unstuck()
    local px, py, pz = ObjectPosition('player')
    local left, leftcount = GameObjectLeft()
    local right, rightcount = GameObjectRight()
    local front, frontcount = GameObjectInfront()

    print('|cffff0000Unstuck!')
    MoveTo(px, py, pz, true)
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