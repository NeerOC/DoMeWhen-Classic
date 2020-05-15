local DMW = DMW
DMW.Bot.Follower = {}
local Follower = DMW.Bot.Follower
local Navigation = DMW.Bot.Navigation
local Log = DMW.Bot.Log

local leaderName = "Neer"
local followDistance = 10

function Follower:Pulse()
    -- Add setting box for leaderName & followDistance and let it update in this loop
    --leaderName = Settings.leaderName
    --followDistance = Settings.followDistance
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
        if theLeader.Target and theLeader.Target ~= Player.Target.GUID then
            TargetUnit(theLeader.GUID)
        end
    end

    -- If no leader then what should we do?
end

function Follower:GetLeader()
    for _, Unit in pairs(DMW.Friends) do
        if Unit.Name == leaderName then
            return Unit
        end
    end

    return false
end