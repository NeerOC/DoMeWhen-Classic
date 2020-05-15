local DMW = DMW
DMW.Bot.Follower = {}
local Follower = DMW.Bot.Follower
local Navigation = DMW.Bot.Navigation
local Log = DMW.Bot.Log

local leaderName, followDistance

function Follower:Pulse()
    -- Add setting box for leaderName & followDistance and let it update in this loop
    leaderName = DMW.Settings.profile.Follower.LeaderName
    followDistance = DMW.Settings.profile.Follower.FollowDistance
    local theLeader = self:GetLeader()
    local Player = DMW.Player

    if theLeader then
        -- Movement
        if theLeader.Distance > followDistance and not Player.Casting then
            Navigation:MoveTo(theLeader.PosX, theLeader.PosY, theLeader.PosZ)
        else
            if Player.Moving then
                Navigation:StopMoving()
            end
        end

        -- Targetting
        if theLeader.Target then
            -- Target leader target
            if not Player.Target or Player.Target.GUID ~= theLeader.Target then
                TargetUnit(theLeader.Target)
            end

            -- Face leader target
            if not UnitIsFacing("player", theLeader.Target, 60) then
                FaceDirection(theLeader.Target, true)
            end
        else
            -- If leader has no target then face leader
            if not UnitIsFacing("player", theLeader.Pointer, 60) then
                FaceDirection(theLeader.Pointer, true)
            end
        end
    else
        -- If no leader then show message
        print("Leader not in party!")
    end
end

function Follower:GetLeader()
    for _, Unit in pairs(DMW.Friends.Units) do
        if Unit.Name == leaderName then
            return Unit
        end
    end

    return false
end