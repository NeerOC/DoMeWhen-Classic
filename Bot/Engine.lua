local DMW = DMW
DMW.Bot.Engine = {}
local Engine = DMW.Bot.Engine
local Grindbot = DMW.Bot.Grindbot
local Pickpocket = DMW.Bot.Pickpocket
local Picklock = DMW.Bot.Picklock
local Navigation = DMW.Bot.Navigation

function Engine:Pulse()
    -- Lets draw visuals if the user made the choice.
    if DMW.Settings.profile.HUD.DrawVisuals == 1 then Navigation:DrawVisuals() end

    -- If Engine is enabled then start choice of bot.
    if DMW.Settings.profile.HUD.Engine == 1 then
        -- If we chose Grindbot then pulse Grindbot.
        if DMW.Settings.profile.HUD.BotMode == 1 then
            Grindbot:Pulse()
        end
        -- If we chose Pickpocket then pulse Pickpocket.
        if DMW.Settings.profile.HUD.BotMode == 2 then
            Pickpocket:Pulse()
        end
        -- If we chose Picklock then pulse Picklock.
        if DMW.Settings.profile.HUD.BotMode == 3 then
            Picklock:Pulse()
        end
    else
        Grindbot:DisabledFunctions()
    end
end