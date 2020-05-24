local DMW = DMW

DMW:RegisterChatCommand("lilium", "ChatCommand")
DMW:RegisterChatCommand("lil", "ChatCommand")

local function SplitInput(Input)
    local Table = {}
    Input = strupper(Input)
    for i in string.gmatch(Input, "%S+") do
        table.insert(Table, i)
    end
    return Table
end

function DMW:ChatCommand(Input)
    if not Input or Input:trim() == "" then
        DMW.UI.Show()
    else
        local Commands = SplitInput(Input)
        if Commands[1] == "HUD" then
            if Commands[2] then
                if _G["DMWHUD" .. Commands[2]] then
                    _G["DMWHUD" .. Commands[2]]:Toggle(tonumber(Commands[3]))
                end
            end
        elseif Commands[1] == "HELP" then
            print("Main UI:")
            print("/Lilium")
            print("HUD Buttons:")
            for i = 1, #DMW.UI.HUD.Options do
                for Name, Setting in pairs(DMW.UI.HUD.Options[i]) do
                    print("/LILIUM HUD " .. Name .. " 1 - " .. #Setting)
                end
            end
        elseif Commands[1] == "DEBUG" then
            if not DMW.UI.Debug.Frame:IsShown() then
                DMW.UI.Debug.Frame:Show()
            else
                DMW.UI.Debug.Frame:Hide()
            end
        elseif Commands[1] == "REPAIR" then
            SetDurabilityVendor()
        elseif Commands[1] == "FOOD" then
           SetFoodVendor()
        elseif Commands[1] == "CLEAR" then
            ClearHotspot()
        elseif Commands[1] == "CLEARVENDOR" then
            ClearVendorWaypoints()
        elseif Commands[1] == "BLACKLIST" then
            if DMW.Player.Target then
                local Name = DMW.Player.Target.Name
                table.insert(DMW.Settings.profile.Grind.targetBlacklist, Name)
                DMW.Bot.Log:DebugInfo('[' .. Name .. '] Added to blacklist')
            else
                DMW.Bot.Log:SevereInfo('No Target, No Blacklist!')
            end
        else
            LibStub("AceConfigCmd-3.0").HandleCommand(DMW, "lilium", "LILIUM", Input)
        end
    end
end
