DMW.Enums.Foodlist = {
    [8932] = {Name = "Alterac Swiss", LevelReq = 45},
    [8957] = {Name = "Spinefin Halibut", LevelReq = 45},
    [8950] = {Name = " Homemade Cherry Pie", LevelReq = 45},
    [8953] = {Name = "Deep Fried Plantains", LevelReq = 45},
    [8948] = {Name = "Dried King Bolete", LevelReq = 45},
    [8952] = {Name = "Roasted Quail", LevelReq = 45},

    [4601] = {Name = "Soft Banana Bread", LevelReq = 35},
    [3927] = {Name = "Fine Aged Cheddar", LevelReq = 35},
    [21552] = {Name = "Striped Yellowtail", LevelReq = 35},
    [4602] = {Name = "Moon Harvest Pumpkin", LevelReq = 35},
    [4608] = {Name = "Raw Black Truffle", LevelReq = 35},
    [4599] = {Name = "Cured Ham Steak", LevelReq = 35},

    [3771] = {Name = "Wild Hog Shank", LevelReq = 25},
    [4544] = {Name = "Mulgore Spice Bread", LevelReq = 25},
    [1707] = {Name = "Stormwind Brie", LevelReq = 25},
    [4594] = {Name = "Rockscale Cod", LevelReq = 25},
    [4539] = {Name = "Goldenbark Apple", LevelReq = 25},
    [4607] = {Name = "Delicious Cave Mold", LevelReq = 25},

    [4542] = {Name = "Moist Cornbread", LevelReq = 15},
    [422] = {Name = "Dwarven Mild", LevelReq = 15},
    [4593] = {Name = "Bristle Whisker Catfish", LevelReq = 15},
    [4538] = {Name = "Snapvine Watermelon", LevelReq = 15},
    [4606] = {Name = "Spongy Morel", LevelReq = 15},
    [3770] = {Name = "Mutton Chop", LevelReq = 15},

    [4541] = {Name = "Freshly Baked Bread", LevelReq = 5},
    [414] = {Name = "Dalaran Sharp", LevelReq = 5},
    [4592] = {Name = "Longjaw Mud Snapper", LevelReq = 5},
    [4537] = {Name = "Tel'Abim Banana", LevelReq = 5},
    [4605] = {Name = "Red-speckled Mushroom", LevelReq = 5},
    [2287] = {Name = "Haunch of Meat", LevelReq = 5},

    [4540] = {Name = "Tough Hunk of Bread", LevelReq = 1},
    [2070] = {Name = "Darnassian Bleu", LevelReq = 1},
    [787] = {Name = "Slitherskin Mackerel", LevelReq = 1},
    [4536] = {Name = "Shiny Red Apple", LevelReq = 1},
    [4604] = {Name = "Forest Mushroom Cap", LevelReq = 1},
    [117] = {Name = "Tough Jerky", LevelReq = 1}
}

DMW.Enums.Waterlist = {
    [8766] = {Name = "Morning Glory Dew", LevelReq = 45},
    [1645] = {Name = "Moonberry Juice", LevelReq = 35},
    [1708] = {Name = "Sweet Nectar", LevelReq = 25},
    [1205] = {Name = "Melon Juice", LevelReq = 15},
    [1179] = {Name = "Ice Cold Milk", LevelReq = 5},
    [159] = {Name = "Refreshing Spring Water", LevelReq = 1}
}

function getBestFood()
    local playerLevel = UnitLevel('player')
    local bestFood = {}

    if DMW.Player.Class == 'MAGE' then
        local FoodRank = DMW.Player.Spells.ConjureFood:HighestRank()
        if FoodRank == 1 then
            return select(1, GetItemInfo(5349))
        elseif FoodRank == 2 then
            return select(1, GetItemInfo(1113))
        elseif FoodRank == 3 then
            return select(1, GetItemInfo(1114))
        elseif FoodRank == 4 then
            return select(1, GetItemInfo(1487))
        elseif FoodRank == 5 then
            return select(1, GetItemInfo(8075))
        elseif FoodRank == 6 then
            return select(1, GetItemInfo(8076))
        elseif FoodRank == 7 then
            return select(1, GetItemInfo(22895))
        else
            return ""
        end
    else
        for k,v in pairs(DMW.Enums.Foodlist) do
            if playerLevel >= 45 then
                if v.LevelReq == 45 then table.insert(bestFood, v.Name) end
            elseif playerLevel < 45 and playerLevel >= 35 then
                if v.LevelReq == 35 then table.insert(bestFood, v.Name) end
            elseif playerLevel < 35 and playerLevel >= 25 then
                if v.LevelReq == 25 then table.insert(bestFood, v.Name) end
            elseif playerLevel < 25 and playerLevel >= 15 then
                if v.LevelReq == 15 then table.insert(bestFood, v.Name) end
            elseif playerLevel < 15 and playerLevel >= 5 then
                if v.LevelReq == 5 then table.insert(bestFood, v.Name) end
            else
                if v.LevelReq == 1 then table.insert(bestFood, v.Name) end
            end
        end

        return bestFood
    end
end

function getBestWater()
    local playerLevel = UnitLevel('player')
    local bestWater

    if DMW.Player.Class == 'MAGE' then
        local waterRank = DMW.Player.Spells.ConjureWater:HighestRank()
        if waterRank == 1 then
            return GetItemInfo(5350)
        elseif waterRank == 2 then
            return GetItemInfo(2288)
        elseif waterRank == 3 then
            return GetItemInfo(2136)
        elseif waterRank == 4 then
            return GetItemInfo(3772)
        elseif waterRank == 5 then
            return GetItemInfo(8077)
        elseif waterRank == 6 then
            return GetItemInfo(8078)
        elseif waterRank == 7 then
            return GetItemInfo(8079)
        else
            return ""
        end
    end

    for k, v in pairs(DMW.Enums.Waterlist) do
        if not bestWater and v.LevelReq <= playerLevel or bestWater and v.LevelReq > bestWater.LevelReq and v.LevelReq <= playerLevel then
            bestWater = v
        end
    end

    return bestWater.Name
end

