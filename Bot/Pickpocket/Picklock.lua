local DMW = DMW
DMW.Bot.Picklock = {}
local Picklock = DMW.Bot.Picklock
local Combat = DMW.Bot.Combat
local Log = DMW.Bot.Log
local Navigation = DMW.Bot.Navigation
local WaypointIndex = 1
local PauseFlags = {
    Interacting = false
}

function Picklock:Pulse()
    if GetItemCount(5060) == 0 then Log:DebugInfo('You dont have any Thieves tools, go get that first.') return end
    -- Lets always call movement
    Navigation:Movement()

    local hasEnemy, theEnemy = Combat:SearchEnemy()
    local hasLockbox, theLockbox = self:GetLocker()
    local distanceBetween = 500

    if hasEnemy and hasLockbox then
        distanceBetween = GetDistanceBetweenPosition(theEnemy.PosX, theEnemy.PosY, theEnemy.PosZ, theLockbox.PosX, theLockbox.PosY,theLockbox.PosZ)
    end
    

    if hasEnemy and hasLockbox and distanceBetween < 30 then
        Combat:InitiateAttack(theEnemy)
    else
        if hasLockbox then
            if theLockbox.Distance >= 5 then
                Navigation:MoveTo(theLockbox.PosX, theLockbox.PosY, theLockbox.PosZ)
            else
                if IsMounted() then Dismount() return end
                if DMW.Player.Moving then Navigation:StopMoving() return end
                if not PauseFlags.Interacting then ObjectInteract(theLockbox.Pointer) PauseFlags.Interacting = true C_Timer.After(0.5, function() PauseFlags.Interacting = false end) end
            end
        else
            --Start roaming if no lockbox
            self:Roam()
        end
    end
end

function Picklock:GetLocker()
    local Table = {}
    for _, Object in pairs(DMW.GameObjects) do
        local Name = Object.Name
        if string.find(Name, 'Footlocker') then
            table.insert(Table, Object)
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
    
    for _, Object in pairs(Table) do
        return true, Object
    end
end

function Picklock:Roam()
    local Hotspots = DMW.Settings.profile.Picklock.Hotspots
    local Distance = GetDistanceBetweenPositions(DMW.Player.PosX, DMW.Player.PosY, DMW.Player.PosZ, Hotspots[WaypointIndex].x, Hotspots[WaypointIndex].y, Hotspots[WaypointIndex].z)

    if WaypointIndex == #Hotspots and Distance < 5 then
        WaypointIndex = 1
    else
        if Distance < 5 then
            WaypointIndex = WaypointIndex + 1
        end
    end

    if IsSwimming() then
        AscendStop()
    end

    if Distance >= 5 then
        Navigation:MoveTo(Hotspots[WaypointIndex].x, Hotspots[WaypointIndex].y, Hotspots[WaypointIndex].z)
    end
end