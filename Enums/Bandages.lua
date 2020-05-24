DMW.Enums.Bandages = {
    [DMW.Enums.Items.LinenBandage] = {Name = "Linen Bandage", SkillReq = 1},
    [DMW.Enums.Items.HeavyLinenBandage] = {Name = "Heavy Linen Bandage", SkillReq = 20},
    [DMW.Enums.Items.WoolBandage] = {Name = "Wool Bandage", SkillReq = 50},
    [DMW.Enums.Items.HeavyWoolBandage] = {Name = "Heavy Wool Bandage", SkillReq = 75},
    [DMW.Enums.Items.SilkBandage] = {Name = "Silk Bandage", SkillReq = 100},
    [DMW.Enums.Items.HeavySilkBandage] = {Name = "Heavy Silk Bandage", SkillReq = 125},
    [DMW.Enums.Items.MageweaveBandage] = {Name = "Mageweave Bandage", SkillReq = 150},
    [DMW.Enums.Items.HeavyMageweaveBandage] = {Name = "Heavy Mageweave Bandage", SkillReq = 175},
    [DMW.Enums.Items.RuneclothBandage] = {Name = "Runecloth Bandage", SkillReq = 200},
    [DMW.Enums.Items.HeavyRuneclothBandage] = {Name = "Heavy Runecloth Bandage", SkillReq = 225}
}

function getBestUsableBandage()
    if not DMW.Player.Professions.FirstAid then return end

    local bestBandage = false

    for key, bandage in pairs(DMW.Enums.Bandages) do
        if bandage.SkillReq <= DMW.Player.Professions.FirstAid and GetItemCount(key) > 0 and (not bestBandage or bandage.SkillReq > bestBandage.SkillReq) then
            bestBandage = bandage
        end
    end

    return bestBandage
end
