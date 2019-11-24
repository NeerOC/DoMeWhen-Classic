local DMW = DMW
DMW.Bot.Combat = {}
local Combat = DMW.Bot.Combat
local Navigation = DMW.Bot.Navigation
local Grindbot = DMW.Bot.Grindbot
local Log = DMW.Bot.Log

local Kiting = false
local kitePause = false
local Juggling = false
local badBlacklist = {}
local BotTarget

function Combat:CanSeeUnit(unit)
    local los1 = TraceLine(DMW.Player.PosX, DMW.Player.PosY, DMW.Player.PosZ + 1, unit.PosX, unit.PosY, unit.PosZ + 1, 0x100111)
    local los1 = TraceLine(DMW.Player.PosX, DMW.Player.PosY, DMW.Player.PosZ + 1.5, unit.PosX, unit.PosY, unit.PosZ + 1.5, 0x100111)
    local los1 = TraceLine(DMW.Player.PosX, DMW.Player.PosY, DMW.Player.PosZ + 2, unit.PosX, unit.PosY, unit.PosZ + 2, 0x100111)
    return los1 == nil and los2 == nil and los3 == nil
end

function Combat:HasTarget()
    return BotTarget and not BotTarget.Dead and not UnitIsTapDenied(BotTarget.Pointer)
end

function Combat:EnemyPlayerNearby()
    for _, Unit in pairs(DMW.Attackable) do
        if Unit.Level >= DMW.Player.Level and Unit.Player then
            return true
        end
    end
end

function Combat:UnitNearHotspot(unit)
    local HotSpots = DMW.Settings.profile.Grind.HotSpots
    local ux, uy, uz = ObjectPosition(unit)
    for i = 1, #HotSpots do
        local hx, hy, hz = HotSpots[i].x, HotSpots[i].y, HotSpots[i].z
        if GetDistanceBetweenPositions(ux, uy, uz, hx, hy, hz) < DMW.Settings.profile.Grind.RoamDistance * 1.5 then
            return true
        end
    end
    return false
end

function Combat:BlacklistedUnit(name)
for i=1, #DMW.Settings.profile.Grind.targetBlacklist do
    if DMW.Settings.profile.Grind.targetBlacklist[i] == name then 
        return true
    end
end
return false
end

function Combat:IsGoodUnit(unit)
    local minLvl = UnitLevel('player') - DMW.Settings.profile.Grind.minNPCLevel
    local maxLvl = UnitLevel('player') + DMW.Settings.profile.Grind.maxNPCLevel
    local UnitFlags = UnitMovementFlags(unit)
    
    local Flags = {
        notSwimming = not UnitFlags or bit.band(UnitFlags, DMW.Enums.MovementFlags.Swimming) == 0,
        notUnitBad = not self:UnitBad(unit),
        notBlacklisted = not self:BlacklistedUnit(UnitName(unit)),
        notCritter = UnitCreatureTypeID(unit) ~= 8,
        notPet = ObjectCreator(unit) == nil,
        noTargetOrMeOrPet = UnitTarget(unit) == nil or UnitIsUnit(UnitTarget(unit), 'player') or UnitIsUnit(UnitTarget(unit), 'pet'),
        isLevel = DMW.Settings.profile.Grind.attackAny or UnitLevel(unit) >= minLvl and UnitLevel(unit) <= maxLvl,
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

function Combat:UnitBad(unit)
    for i=1, #badBlacklist do
        if badBlacklist[i] == unit then 
            return true
        end
    end
    return false
end

function Combat:SearchAttackable()
    -- Search for hostiles around us and attack them first.
    
    if not self:HasTarget() then
        for _, Unit in pairs(DMW.Attackable) do
            if UnitClassification(Unit.Pointer) == 'normal' and UnitReaction(Unit.Pointer, 'player') < 4 and Unit.Distance <= Unit:AggroDistance() + 8 and not UnitIsPVP(Unit.Pointer) and not UnitIsTapDenied(Unit.Pointer) then
                return true, Unit
            end
        end
    end

    local Table = {}
    for _, Unit in pairs(DMW.Units) do
        if Unit.Distance < 80 and UnitClassification(Unit.Pointer) == 'normal' and self:IsGoodUnit(Unit.Pointer) and (Unit:LineOfSight() or DMW.Settings.profile.Grind.skipLOS) and #Unit:GetHostiles(20) < 2 then
            table.insert(Table, Unit)
        end
    end
    
    if #Table > 1 then
        table.sort(
            Table,
            function(x, y)
                return x.NavDistance < y.NavDistance
            end
        )
    end

    -- Lets get closest hostile first.
    for _, Unit in ipairs(Table) do
        if UnitReaction(Unit.Pointer, 'player') < 4 then
            return true, Unit
        end

        return true, Unit
    end
end

function Combat:SearchEnemy()
    local Table = {}
    for _, Unit in pairs(DMW.Attackable) do
        if Unit.Distance < 60 then
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

    if DMW.Player.Combat then
        for _, Unit in ipairs(Table) do
            -- Totems first
            if UnitCreatureTypeID(Unit.Pointer) == 11 or UnitCreatureTypeID(Unit.Pointer) == 10 then
                for _, totemLord in ipairs(Table) do
                    if ObjectCreator(Unit.Pointer) == totemLord.Pointer or UnitIsDead(ObjectCreator(Unit.Pointer)) then
                        return true, Unit
                    end
                end
            end

            -- Nearby fleeing targets then
            if not Unit.Player and UnitAffectingCombat(Unit.Pointer) and not UnitIsTapDenied(Unit.Pointer) and Unit.Distance < 30 and (Unit.HP < 100 or DMW.Player.Class == "MAGE" and DMW.Player.Debuffs.Polymorph:Exist(Unit, true)) then
                return true, Unit
            end
        end
    end

    -- focus pet target after that if we have pet
    if DMW.Player.Pet and not DMW.Player.Pet.Dead then
        for _, Unit in ipairs(Table) do
            if Unit.Target and (Unit.Target == DMW.Player.Pet.Pointer and DMW.Player.Pet.Combat) then
                return true, Unit
            end
        end
    end

    for _, Unit in ipairs(Table) do
        local PowerType = UnitPowerType(Unit.Pointer)
        local Casting = Unit:CastingInfo() ~= nil

        if not Unit.Player and Unit.Target == GetActivePlayer() and Unit.HP < 50 then
            return true, Unit
        end
        
        if not Unit.Player and Unit.Target == GetActivePlayer() and Casting then
            return true, Unit
        end
        
        if not Unit.Player and Unit.Target == GetActivePlayer() and PowerType == 0 then
            return true, Unit
        end

        if not Unit.Player and Unit.Target == GetActivePlayer() then
            return true, Unit
        end
        
        if Unit.Player and Unit.Target == GetActivePlayer() and UnitAffectingCombat(Unit.Pointer) and ObjectIsFacing(Unit.Pointer, GetActivePlayer()) then
            return true, Unit
        end
    end
end

function Combat:GetUnitsNear(x, y, z)
    for _, Unit in pairs(DMW.Attackable) do
        local unitAggro = Unit:AggroDistance() + 10
        if UnitReaction(Unit.Pointer, 'player') < 4 and Unit:GetDistanceToPosition(x, y, z) < unitAggro and not UnitIsTapDenied(Unit.Pointer) then
            return true
        end
    end
    return false
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
        if IsMounted() then Dismount() end
        self:InitiateAttack(theEnemy)
    end
end

function Combat:InitiateAttack(Unit)
    BotTarget = Unit
    if (Unit.Distance > DMW.Settings.profile.Grind.CombatDistance or not Unit:LineOfSight()) then
        Navigation:MoveTo(Unit.PosX, Unit.PosY, Unit.PosZ)
        
        if Navigation:ReturnPathEnd() ~= nil then
            local endX, endY, endZ = Navigation:ReturnPathEnd()
            local endPathToUnitDist = GetDistanceBetweenPositions(Unit.PosX, Unit.PosY, Unit.PosZ, endX, endY, endZ)
            if endPathToUnitDist > 4 then
                -- Blacklist unit
                Log:SevereInfo('Added Unit to badBlacklist')
                table.insert(badBlacklist, Unit.Pointer)
            end
        end
    else
        if DMW.Player.Moving and (not Kiting or not DMW.Settings.profile.Grind.rangeKite) then
            Navigation:StopMoving()
            Navigation:ResetPath()
        end
    end

    if not UnitIsUnit(Unit.Pointer, "target") then ClearTarget() SpellStopCasting() TargetUnit(Unit.Pointer) end

    if DMW.Settings.profile.Grind.CombatDistance > 9 then
        -- This is for ranged attackers
        if DMW.Settings.profile.Grind.beHuman and Unit.Distance > DMW.Settings.profile.Grind.CombatDistance and self:CanSeeUnit(Unit) and UnitIsFacing('player', Unit.Pointer, 60) and DMW.Player.Moving then if math.random(1, 1000) < 4 and not DMW.Player.Swimming then JumpOrAscendStart() end end

        if Kiting and (not DMW.Player.Moving or DMW.Player.Rooted or DMW.Player.Disabled) then Kiting = false end
        if DMW.Settings.profile.Grind.rangeKite and not kitePause then
            if not DMW.Player.Rooted and not DMW.Player.Disabled and (not DMW.Player.Debuffs.Daze:Exist() or DMW.Player.Target and DMW.Player.Target.Rooted and #DMW.Player:Gethostiles(25) == 1) and DMW.Player.Target and DMW.Player.Target.Distance <= 14 and DMW.Player.Target.Target == DMW.Player.Pointer then
                local cuSpeed, unitSpeed = GetUnitSpeed(DMW.Player.Target.Pointer)
                local cpSpeed, playerSpeed = GetUnitSpeed('player')

                if unitSpeed <= playerSpeed * 0.70 or DMW.Player.Target.Rooted then
                    Kiting = true
                    local _, safeX, safeY, safeZ = Navigation:GetSafetyPosition(DMW.Player.PosX, DMW.Player.PosY, DMW.Player.PosZ, 28, 5)
                    if not DMW.Player.Moving then
                        if safeX then Navigation:MoveTo(safeX, safeY, safeZ) end
                    end
                end
            else
                Navigation:ResetPath()
                kitePause = true
                C_Timer.After(1, function() kitePause = false end)
                Kiting = false
            end
        end

        if not UnitIsFacing('player', Unit.Pointer, 60) and Unit.Distance < DMW.Settings.profile.Grind.CombatDistance and Unit:LineOfSight() and not Kiting then
            print('face!')
            FaceDirection(Unit.Pointer, true)
        end

        if Unit.Distance <= DMW.Settings.profile.Grind.CombatDistance and IsMounted() then
            Dismount()
        end
    else
        -- This is for melee attackers
        if DMW.Settings.profile.Grind.beHuman and Unit.Distance > DMW.Settings.profile.Grind.CombatDistance + 3 and self:CanSeeUnit(Unit) and UnitIsFacing('player', Unit.Pointer, 60) and DMW.Player.Moving then if math.random(1, 1000) < 4 and not DMW.Player.Swimming then JumpOrAscendStart() end end

        if not UnitIsFacing('player', Unit.Pointer, 60) and Unit.Distance <= DMW.Settings.profile.Grind.CombatDistance and Unit:LineOfSight() then
            FaceDirection(Unit.Pointer, true)
        elseif UnitIsFacing('player', Unit.Pointer, 60) and Unit.Distance <= DMW.Settings.profile.Grind.CombatDistance and Unit:LineOfSight() then
            -- If random is true then if theres not adds around us, juggle the enemy(Strafe) 
            if math.random(1, 1000) < 4 and DMW.Settings.profile.Grind.beHuman and not DMW.Player.Casting then
                if #DMW.Player:GetAttackable(27) <= 2 and not self:EnemyBehind() then self:JuggleEnemy() end
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
