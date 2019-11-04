local DMW = DMW
DMW.Bot.Log = {}
local Log = DMW.Bot.Log


function Log:NormalInfo(str)
    DEFAULT_CHAT_FRAME:AddMessage("|TInterface\\Icons\\Ability_DualWield:20:20:0:0:20:20:0:20:0:20|t |cfff54272[Lilium]|r |cff7CFC00[Normal]|r " .. str)
end

function Log:DebugInfo(str)
   DEFAULT_CHAT_FRAME:AddMessage("|TInterface\\Icons\\INV_Misc_Note_01:20:20:0:0:20:20:0:20:0:20|t |cfff54272[Lilium]|r |cffFFA500[Info]|r " .. str)
end

function Log:SevereInfo(str)
    DEFAULT_CHAT_FRAME:AddMessage("|TInterface\\Icons\\Ability_Creature_Cursed_02:20:20:0:0:20:20:0:20:0:20|t |cfff54272[Lilium]|r |cffFF0000[Error]|r " .. str)
end