local DMW = DMW
DMW.Bot.Fishbot = {}
local Fishbot = DMW.Bot.Fishbot
local Log = DMW.Bot.Log

local AnimationOffset = 0

function Fishbot:Pulse()
    if AnimationOffset == 0 then AnimationOffset = GetOffset("CGGameObject_C__Animation") end
    self:Fish()
end

function Fishbot:GetBobber()
    for _, Object in pairs(DMW.GameObjects) do
        if ObjectCreator(Object.Pointer) == DMW.Player.Pointer and Object.Name == "Fishing Bobber" then
            return Object.Pointer
        end
    end
end

function Fishbot:IsBobbing(Object)
    return ObjectField(Object, AnimationOffset, "bool")
end

function Fishbot:Fish()
    local Bobber = self:GetBobber()

    if Bobber then
        if self:IsBobbing(Bobber) then
            ObjectInteract(Bobber)
        end
    else
        if not DMW.Player.Casting then
            if DMW.Player.Spells.Fishing:IsReady() and DMW.Player.Spells.Fishing:TimeSinceLastCast() > 0.7 then
                if DMW.Player.Spells.Fishing:Cast() then
                    return true
                end
            end
        end
    end

end
