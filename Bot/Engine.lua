local DMW = DMW
DMW.Bot.Engine = {}
local Engine = DMW.Bot.Engine
local Grindbot = DMW.Bot.Grindbot
local Fishbot = DMW.Bot.Fishbot
local Navigation = DMW.Bot.Navigation
local Log = DMW.Bot.Log

local Ready = false
local folderChecks = false
local readItemFile = false

function Engine:Pulse()
    -- Lets draw visuals if the user made the choice.
    if DMW.Settings.profile.HUD.DrawVisuals == 1 then Navigation:DrawVisuals() end
    if not IsHackEnabled('antiafk') then SetHackEnabled ('antiafk', true) Log:DebugInfo('AntiAFK Enabled') end
    if not folderChecks then self:SetupFolders() folderChecks = true end
    if not readItemFile then self:LoadFile() SetProfiles() readItemFile = true C_Timer.After(1, function() readItemFile = false end) end
    -- If Engine is enabled then start choice of bot.
    if DMW.Settings.profile.HUD.Engine == 1 and self:IsReady() then
        -- If we chose Grindbot then pulse Grindbot.
        if DMW.Settings.profile.HUD.BotMode == 1 then
            Grindbot:Pulse()
        elseif DMW.Settings.profile.HUD.BotMode == 2 then
            Fishbot:Pulse()
        end
    else
        if DMW.Settings.profile.HUD.BotMode == 1 then Grindbot:DisabledFunctions() end
    end
end

function Engine:SetupFolders()
    CreateDirectory(GetHackDirectory() .. "/Lilium/Grindbot/Profiles") 
    CreateDirectory(GetHackDirectory() .. "/Lilium/Fishbot")
    if #GetDirectoryFiles(GetHackDirectory() .. "/Lilium/Grindbot/*.txt") > 0 then
        self:LoadFile()
        Log:DebugInfo('ItemList Loaded.')
    else
        WriteFile(GetHackDirectory() .. "/Lilium/Grindbot/itemList.txt", "Golden Pearl\nBlack Pearl\n", true, true)
    end
end

function Engine:SetReady(bool)
    Ready = bool
end

function Engine:IsReady()
    return Ready
end

function Engine:LoadFile()
    local itemListPH = {}
    local itemSaveContent = ReadFile(GetHackDirectory() .. "/Lilium/Grindbot/itemList.txt")
    for s in itemSaveContent:gmatch("[^\r\n]+") do
        table.insert(itemListPH, s)
    end
    DMW.Settings.profile.Grind.itemSaveList = itemListPH
end