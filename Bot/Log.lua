local DMW = DMW
DMW.Bot.Log = {}
local Log = DMW.Bot.Log


function Log:NormalInfo(str)
    DEFAULT_CHAT_FRAME:AddMessage("|cff7CFC00|TInterface\\Icons\\Ability_DualWield:20:20:0:0:20:20:0:20:0:20|t [BOT]|r " .. str)
end

function Log:DebugInfo(str)
   DEFAULT_CHAT_FRAME:AddMessage("|cffFFA500|TInterface\\Icons\\INV_Misc_Note_01:20:20:0:0:20:20:0:20:0:20|t [INFO]|r " .. str)
end

function Log:SevereInfo(str)
    DEFAULT_CHAT_FRAME:AddMessage("|cffFF0000|TInterface\\Icons\\Ability_Creature_Cursed_02:20:20:0:0:20:20:0:20:0:20|t [ERROR]|r " .. str)
end