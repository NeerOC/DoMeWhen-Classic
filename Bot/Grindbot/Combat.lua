local DMW = DMW
DMW.Bot.Combat = {}
local Combat = DMW.Bot.Combat
local Navigation = DMW.Bot.Navigation
local Grindbot = DMW.Bot.Grindbot
local Log = DMW.Bot.Log

local Juggling = false

function Combat:CanSeeUnit(unit)
    local los1 = TraceLine(DMW.Player.PosX, DMW.Player.PosY, DMW.Player.PosZ + 1, unit.PosX, unit.PosY, unit.PosZ + 1, 0x100111)
    local los1 = TraceLine(DMW.Player.PosX, DMW.Player.PosY, DMW.Player.PosZ + 1.5, unit.PosX, unit.PosY, unit.PosZ + 1.5, 0x100111)
    local los1 = TraceLine(DMW.Player.PosX, DMW.Player.PosY, DMW.Player.PosZ + 2, unit.PosX, unit.PosY, unit.PosZ + 2, 0x100111)
    return los1 == nil and los2 == nil and los3 == nil
end

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

function Combat:IsGoodUnit(unit)
    local minLvl = UnitLevel('player') - DMW.Settings.profile.Grind.minNPCLevel
    local maxLvl = UnitLevel('player') + DMW.Settings.profile.Grind.maxNPCLevel

    local Flags = {
        notPet = ObjectCreator(unit) == nil,
        noTargetOrMeOrPet = UnitTarget(unit) == nil or UnitIsUnit(UnitTarget(unit), 'player') or UnitIsUnit(UnitTarget(unit), 'pet'),
        isLevel = UnitLevel('player') == 60 or UnitLevel(unit) >= minLvl and UnitLevel(unit) <= maxLvl,
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
        if UnitClassification(Unit.Pointer) == 'normal' and self:IsGoodUnit(Unit.Pointer) and Unit.Distance < DMW.Settings.profile.Grind.RoamDistance and Unit:LineOfSight() then
            table.insert(Table, Unit)
        end
    end
    
    if #Table > 1 then
        table.sort(
            Table,
            function(x, y)
                return Navigation:GetPathDistanceTo(x) < Navigation:GetPathDistanceTo(y)
            end
        )
    end

    -- Lets get closest hostile first.
    for _, Unit in ipairs(Table) do
        if UnitReaction(Unit.Pointer, 'player') < 4 then
            return true, Unit
        end
    end

    for _, Unit in ipairs(Table) do
        return true, Unit
    end
end

function Combat:SearchEnemy()
    local Table = {}
    for _, Unit in pairs(DMW.Attackable) do
        if Unit.Distance < 50 then
            table.insert(Table, Unit)
        end
    end

    if #Table > 1 then
        table.sort(
            Table,
            function(x, y)
                return x.HP < y.HP
            end
        )
    end

    -- First check if there are totems then any of the mobs have mana (indicator of a caster) otherwise kill the one with lowest hp
    if DMW.Player.Combat then
        for _, Unit in ipairs(Table) do
            if Unit.Distance <= 8 and UnitCreatureTypeID(Unit.Pointer) == 11 then
                return true, Unit
            end
        end
    end

    if DMW.Player.Combat then
        for _, Unit in ipairs(Table) do
            if UnitAffectingCombat(Unit.Pointer) and not UnitIsTapDenied(Unit.Pointer) and Unit.Distance < 15 and Unit.HP < 100 then
                return true, Unit
            end
        end
    end

    for _, Unit in ipairs(Table) do
        if Unit.Player and Unit.Target == GetActivePlayer() and UnitAffectingCombat(Unit.Pointer) then
            return true, Unit
        end
    end

    for _, Unit in ipairs(Table) do
        if not Unit.Player and Unit.Target == GetActivePlayer() and Unit:Interrupt() then
            return true, Unit
        end
    end

    for _, Unit in ipairs(Table) do
        local PowerType = UnitPowerType(Unit.Pointer)
        if not Unit.Player and Unit.Target == GetActivePlayer() and PowerType == 0 then
            return true, Unit
        end
    end

    if UnitExists('pet') then
        for _, Unit in ipairs(Table) do
            if DMW.Player.PetActive and Unit.Target and ((UnitIsUnit(Unit.Target, 'pet') and UnitAffectingCombat('pet'))) then
                return true, Unit
            end
        end
    end

    for _, Unit in ipairs(Table) do
        if not Unit.Player and Unit.Target == GetActivePlayer() then
            return true, Unit
        end
    end
end

function Combat:EnemyBehind()
    for _, Unit in pairs(DMW.Attackable) do
        if Unit.Distance < 10 and Unit:UnitThreatSituation(DMW.Player) > 1 and ObjectIsBehind(Unit.Pointer, 'player') then
           return true
        end
    end
end

function Combat:Grinding()
    if not DMW.Player.Casting then
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
    if (Unit.Distance > DMW.Settings.profile.Grind.CombatDistance or not Unit:LineOfSight()) then
        Navigation:MoveTo(Unit.PosX, Unit.PosY, Unit.PosZ)
    else
        if DMW.Player.Moving then
            Navigation:StopMoving()
            Navigation:ResetPath()
        end
    end

    if not UnitIsUnit(Unit.Pointer, "target") then ClearTarget() SpellStopCasting() TargetUnit(Unit.Pointer) end

    if DMW.Settings.profile.Grind.CombatDistance > 9 then
        -- This is for ranged attackers
        if DMW.Settings.profile.Grind.beHuman and Unit.Distance > DMW.Settings.profile.Grind.CombatDistance and self:CanSeeUnit(Unit) and UnitIsFacing('player', Unit.Pointer, 60) and DMW.Player.Moving then if math.random(1, 1000) < 4 then JumpOrAscendStart() end end

        if not UnitIsFacing('player', Unit.Pointer, 60) and Unit.Distance < DMW.Settings.profile.Grind.CombatDistance and Unit:LineOfSight() then
            FaceDirection(Unit.Pointer, true)
        end

        if Unit.Distance <= DMW.Settings.profile.Grind.CombatDistance and IsMounted() then
            Dismount()
        end
    else
        -- This is for melee attackers
        if DMW.Settings.profile.Grind.beHuman and Unit.Distance > DMW.Settings.profile.Grind.CombatDistance + 3 and self:CanSeeUnit(Unit) and UnitIsFacing('player', Unit.Pointer, 60) and DMW.Player.Moving then if math.random(1, 1000) < 4 then JumpOrAscendStart() end end

        if not UnitIsFacing('player', Unit.Pointer, 60) and Unit.Distance <= DMW.Settings.profile.Grind.CombatDistance and Unit:LineOfSight() then
            FaceDirection(Unit.Pointer, true)
        elseif UnitIsFacing('player', Unit.Pointer, 60) and Unit.Distance <= DMW.Settings.profile.Grind.CombatDistance and Unit:LineOfSight() then
            -- If random is true then if theres not adds around us, juggle the enemy(Strafe) 
            if math.random(1, 1000) < 4 and DMW.Settings.profile.Grind.beHuman then
                if #DMW.Player:GetAttackable(20) <= 2 and not self:EnemyBehind() then self:JuggleEnemy() end
            end

            if self:EnemyBehind() then
                MoveForwardStart()
            else
                MoveForwardStop()
            end
        end
        if Unit.Distance <= 9 then
            Dismount()
        end
    end
end

function Combat:JuggleEnemy()
    if not Juggling then
        StrafeLeftStart()
        C_Timer.After(math.random() + math.random(0.1, 0.3), function() StrafeLeftStop() StrafeRightStart() C_Timer.After(math.random() + math.random(0.1, 0.3), function() StrafeRightStop() Juggling = false end) end)
        Juggling = true
    end
end