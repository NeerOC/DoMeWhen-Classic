local DMW = DMW
local GameObject = DMW.Classes.GameObject
local Throttle = false

function GameObject:New(Pointer)
    self.Pointer = Pointer
    self.Name = ObjectName(Pointer)
    self.ObjectID = ObjectID(Pointer)
end

function GameObject:Update()
    self.NextUpdate = DMW.Time + (math.random(100, 400) / 1000)
    self.PosX, self.PosY, self.PosZ = ObjectPosition(self.Pointer)
    self.Distance = self:GetDistance()
    if not Throttle then self.NavDistance = self:GetNavDistance() Throttle = true C_Timer.After(0.2, function() Throttle = false end) end
    if not self.Name or self.Name == "" then
        self.Name = ObjectName(self.Pointer)
    end
    self.Quest = self:IsQuest()
    self.Herb = self:IsHerb()
    self.Ore = self:IsOre()
    self.Trackable = self:IsTrackable()
end

function GameObject:GetDistance(OtherUnit)
    OtherUnit = OtherUnit or DMW.Player
    return sqrt(((self.PosX - OtherUnit.PosX) ^ 2) + ((self.PosY - OtherUnit.PosY) ^ 2) + ((self.PosZ - OtherUnit.PosZ) ^ 2))
end

function GameObject:GetNavDistance()
    if DMW.Bot.Engine:IsReady() then
        return DMW.Bot.Navigation:GetPathDistanceTo(self)
    end
    return 999
end

function GameObject:IsQuest()
    if self.ObjectID and DMW.Settings.profile.Tracker.QuestieHelper and DMW.QuestieTooltips and DMW.QuestieTooltips.tooltipLookup["o_" .. self.ObjectID] then
        for _, Tooltip in pairs(DMW.QuestieTooltips.tooltipLookup["o_" .. self.ObjectID]) do
            Tooltip.Objective:Update()
            if not Tooltip.Objective.Completed then
                return true
            end
        end
    end
    return false
end

function GameObject:IsHerb()
    if DMW.Enums.Herbs[self.ObjectID] and ((DMW.Player.Professions.Herbalism and DMW.Enums.Herbs[self.ObjectID].SkillReq <= DMW.Player.Professions.Herbalism)) then
        return true
    end
    return false
end

function GameObject:IsOre()
    if DMW.Enums.Ore[self.ObjectID] and ((DMW.Player.Professions.Mining and DMW.Enums.Ore[self.ObjectID].SkillReq <= DMW.Player.Professions.Mining)) then
        return true
    end
    return false
end

function GameObject:IsTrackable() --TODO: enums
    if DMW.Settings.profile.Tracker.Trackable and DMW.Enums.Trackable[self.ObjectID] then
        return true
    end
    if DMW.Settings.profile.Tracker.TrackObjects and DMW.Settings.profile.Tracker.TrackObjects ~= "" then
        for k in string.gmatch(DMW.Settings.profile.Tracker.TrackObjects, "([^,]+)") do
            if strmatch(string.lower(self.Name), string.lower(string.trim(k))) then
                return true
            end
        end
    end
    return false
end
