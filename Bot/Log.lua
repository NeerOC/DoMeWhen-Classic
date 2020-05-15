local DMW = DMW
DMW.Bot.Log = {}
local Log = DMW.Bot.Log


function Log:NormalInfo(...)
    DEFAULT_CHAT_FRAME:AddMessage("|TInterface\\Icons\\Ability_DualWield:20:20:0:0:20:20:0:20:0:20|t |cfff54272[Lilium]|r |cff7CFC00[Normal]|r " .. ...)
end

function Log:DebugInfo(...)
   DEFAULT_CHAT_FRAME:AddMessage("|TInterface\\Icons\\INV_Misc_Note_01:20:20:0:0:20:20:0:20:0:20|t |cfff54272[Lilium]|r |cffFFA500[Info]|r " .. ...)
end

function Log:SevereInfo(...)
    DEFAULT_CHAT_FRAME:AddMessage("|TInterface\\Icons\\Ability_Creature_Cursed_02:20:20:0:0:20:20:0:20:0:20|t |cfff54272[Lilium]|r |cffFF0000[Error]|r " .. ...)
end