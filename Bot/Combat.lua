local DMW = DMW
DMW.Bot.Combat = {}
local Combat = DMW.Bot.Combat
local Navigation = DMW.Bot.Navigation
local Grindbot = DMW.Bot.Grindbot
local Log = DMW.Bot.Log

function Combat:UnitNearHotspot(unit)
    local HotSpots = DMW.Settings.profile.Grind.HotSpots
    local ux, uy, uz = ObjectPosition(unit)
    for i = 1, #HotSpots do
        local hx, hy, hz = HotSpots[i].x, HotSpots[i].y, HotSpots[i].z
        if GetDistanceBetweenPositions(ux, uy, uz, hx, hy, hz) < DMW.Settings.profile.Grind.RoamDistance then
            return true
        end
    end
    return false
end

function Combat:DistanceToUnit(unit)
    local px, py, pz = ObjectPosition('player')
    local tx, ty, tz = ObjectPosition(unit)
    return GetDistanceBetweenPositions(px,py,pz,tx,ty,tz)
end

function Combat:IsGoodUnit(unit)
    local minLvl = UnitLevel('player') - DMW.Settings.profile.Grind.minNPCLevel
    local maxLvl = UnitLevel('player') + DMW.Settings.profile.Grind.maxNPCLevel

    local Flags = {
        isLevel = UnitLevel(unit) >= minLvl and UnitLevel(unit) <= maxLvl,
        isPVP = not UnitIsPVP(unit),
        inRange = self:UnitNearHotspot(unit),
        notDead = not UnitIsDeadOrGhost(unit),
        notPlayer = not ObjectIsPlayer(unit),
        canAttack = UnitCanAttack("player", unit),
        givesExp = not UnitIsTapDenied(unit),
        notPlayerPet = not ObjectIsPlayer(ObjectCreator(unit))
    }

    for k, v in pairs(Flags) do
        if not v then
            return false
        end
    end

    return true
end

function Combat:SearchAttackable()
    local Table = {}
    for _, Unit in pairs(DMW.Units) do
        table.insert(Table, Unit)
    end
    if #Table > 1 then
        table.sort(
            Table,
            function(x, y)
                return x.Distance < y.Distance
            end
        )
    end

    -- First get line of sight units if none exist, return the closest one. (Also make sure to priortize hostile enemies)
    for _, Unit in ipairs(Table) do
        if self:IsGoodUnit(Unit.Pointer) and Unit:LineOfSight() and UnitReaction(Unit.Pointer, 'player') < 4 then
            return true, Unit
        end
    end

    for _, Unit in ipairs(Table) do
        if self:IsGoodUnit(Unit.Pointer) and Unit:LineOfSight() then
            return true, Unit
        end
    end

    for _, Unit in ipairs(Table) do
        if self:IsGoodUnit(Unit.Pointer) then
            return true, Unit
        end
    end
    
end

function Combat:SearchEnemy()
    local Table = {}
    for _, Unit in pairs(DMW.Attackable) do
        table.insert(Table, Unit)
    end

    if #Table > 1 then
        table.sort(
            Table,
            function(x, y)
                return x.HP < y.HP
            end
        )
    end

    -- First check if any of the mobs have mana (indicator of a caster) otherwise kill the one with lowest hp

    for _, Unit in ipairs(Table) do
        local PowerType = UnitPowerType(Unit.Pointer)
        if Unit.Distance < 80 and (Unit:UnitThreatSituation() > 0 or (Unit.Target == GetActivePlayer() and UnitAffectingCombat(Unit.Pointer))) and PowerType == 0 then
            return true, Unit
        end
    end

    if UnitExists('pet') then
        for _, Unit in ipairs(Table) do
            if Unit.Distance < 80 and ((Unit.Target == 'pet' and UnitAffectingCombat('pet')) or Unit:UnitThreatSituation() > 0 or (Unit.Target == GetActivePlayer() and UnitAffectingCombat(Unit.Pointer))) then
                return true, Unit
            end
        end
    end

    for _, Unit in ipairs(Table) do
        if Unit.Distance < 80 and (Unit:UnitThreatSituation() > 0 or (Unit.Target == GetActivePlayer() and UnitAffectingCombat(Unit.Pointer))) then
            return true, Unit
        end
    end

    for _, Unit in ipairs(Table) do
        if Unit.Distance <= 10 and UnitAffectingCombat(Unit.Pointer) and string.find(Unit.Name, 'Totem') then
            return true, Unit
        end
    end
end

function Combat:Grinding()
    if not DMW.Player.Casting and not DMW.Player.Combat then
        local hasEnemy, theEnemy = self:SearchAttackable()
        if hasEnemy then 
            self:InitiateAttack(theEnemy)
        end
    end
end

function Combat:AttackCombat()
    local hasEnemy, theEnemy = self:SearchEnemy()
    if hasEnemy then
        self:InitiateAttack(theEnemy)
    end
end

function Combat:InitiateAttack(Unit)
    if (self:DistanceToUnit(Unit.Pointer) > DMW.Settings.profile.Grind.CombatDistance or not Unit:LineOfSight()) then
        Navigation:MoveTo(Unit.PosX, Unit.PosY, Unit.PosZ)
    else
        if DMW.Player.Moving then
            Navigation:StopMoving()
            Navigation:ResetPath()
        end
    end

    if not UnitIsUnit(Unit.Pointer, "target") then ClearTarget() SpellStopCasting() TargetUnit(Unit.Pointer) end

    if DMW.Settings.profile.Grind.CombatDistance > 9 then
        if not UnitIsFacing('player', Unit.Pointer, 60) and self:DistanceToUnit(Unit.Pointer) < DMW.Settings.profile.Grind.CombatDistance and Unit:LineOfSight() then
            FaceDirection(Unit.Pointer, true)
        end

        if self:DistanceToUnit(Unit.Pointer) <= DMW.Settings.profile.Grind.CombatDistance and IsMounted() then
            Dismount()
        end
    else
        if not UnitIsFacing('player', Unit.Pointer, 60) and self:DistanceToUnit(Unit.Pointer) <= 9 and Unit:LineOfSight() then
            FaceDirection(Unit.Pointer, true)
        end
        if self:DistanceToUnit(Unit.Pointer) <= 9 then
            Dismount()
        end
    end
end