-- @filename: cl_construct.lua
-- @credits: github.com/causaprima0/gm_roaming
-- @version: 1.0.0 @ 07/09/2025

local AGENT     = AGENT;
local PATHMAP   = PATHMAP;
local ROAMING   = ROAMING;

AGENT.bExperimental = true;

-- @function: AGENT:IsPlayerVisible(<player: target>, <vector: vec>)
-- @describe: Возвращает, находится ли игрок в зоне видимости клиента.
-- @arguments (1): <player: target>
-- @returns: Boolean
function AGENT:IsPlayerVisible(target, vec)
    assert(isentity(target), "Argument #1 has to be an entity");
    assert(not vec or isvector(vec), "Argument #2 has to be a vector");

    if (target:IsValid()) then
        local vec = vec or target:GetPos();
        return ROAMING.client:IsLineOfSightClear(vec)
            or ROAMING.client:IsLineOfSightClear(vec + target:OBBCenter())
            or ROAMING.client:IsLineOfSightClear(vec + target:OBBMaxs());
    else
        return false;
    end
end

-- @function: AGENT:OnActivate(<vector: worldpos>, <string: target>)
-- @describe: Вызывается при активации агента.
-- @arguments (2): <vector: worldpos>, <string: target>
-- @returns: None
function AGENT:OnActivate(worldpos, target)
    assert(isvector(worldpos), "Argument #1 has to be a vector");
    assert(not target or isstring(target), "Argument #2 has to be a string");

    local entry = ROAMING.pathmap:FindEntryPoint();

    if (isstring(target)) then
        local target = Player(target);
        if (target:IsValid() and self:IsPlayerVisible(target)) then
            AGENT.bExperimental = false;
            return self.follower:OnTargetFound(target, 40);
        else
            return ROAMING:Error("Couldn't follow a specified target");
        end
    elseif (isstring(entry) or isnumber(entry)) then
        local vec = ROAMING.pathmap:GetPointVector(entry);
        AGENT.bExperimental = true;
        return ROAMING:MoveTo(vec, 20, function(pos)
            return self:OnFinishMove(entry, pos);
        end, true);
    else
        ROAMING:Error("Couldn't find an entry point");
        return self:OnDeactivate();
    end
end

-- @function: AGENT:OnDeactivate()
-- @describe: Вызывается при деактивации агента.
-- @arguments (0): None
-- @returns: None
function AGENT:OnDeactivate()
    ROAMING.listener:Remove("Think", "Watchdog");
    ROAMING.listener:Remove("Think", "Trampoline");
    return ROAMING:Abort();
end

-- @function: AGENT:OnFinishMove(<string: point>, <vector: vec>)
-- @describe: Вызывается при завершении задачи передвижения.
-- @arguments (2): <string: point>, <vector: vec>
-- @returns: None
function AGENT:OnFinishMove(point, vec)
    assert(isnumber(point) or isstring(point), "Argument #1 has to be a string");
    assert(isvector(vec), "Argument #2 has to be a vector");

    if (not ROAMING.pathmap.bSequential) then
        local row = ROAMING.pathmap[point]["then"] or {};
        if (#row > 0) then
            local followup = row[math.random(1, #row)];
            local worldpos = ROAMING.pathmap:GetPointVector(followup);

            return ROAMING:MoveTo(worldpos, 20, function(pos)
                return self:OnFinishMove(followup, pos);
            end, true);
        else
            return ROAMING:Error("Couldn't find a follow-up point");
        end
    else
        local iterator = self.bReverse == true
            and point - 1 or point + 1;
        local followup = ROAMING.pathmap[iterator];

        if (followup) then
            local worldpos = ROAMING.pathmap:GetPointVector(iterator);
            return ROAMING:MoveTo(worldpos, 20, function(pos)
                return AGENT:OnFinishMove(iterator, pos);
            end, true);
        else
            self.bReverse = not self.bReverse;
            return AGENT:OnFinishMove(point, vec);
        end
    end
end

-- @function: AGENT.follower:OnTargetFound(<player: target>, <number: threshold>)
-- @describe: Вызывается при обнаружении цели для преследования.
-- @arguments (2): <player: target>, <number: threshold>
-- @returns: None
function AGENT.follower:OnTargetFound(target, threshold)
    assert(isentity(target), "Argument #1 has to be an entity");
    assert(isnumber(threshold), "Argument #2 has to be a number");

    self:OnTrampolineCreate(target, threshold);

    return ROAMING.listener:Add("Think", "Watchdog", function()
        local vec = target:GetPos();
        local prev = self.hotspots[#self.hotspots];
        if (not isvector(prev)
                or prev:Distance(vec) > threshold) then
            self.hotspots[#self.hotspots + 1] = vec;
        end
    end);
end

-- @function: AGENT.follower:OnTrampolineCreate(<player: target>,
--  <number: threshold>)
-- @describe: Вызывается при ожидании новых точек для передвижения.
-- @arguments (2): <player: target>, <number: threshold>
-- @returns: None
function AGENT.follower:OnTrampolineCreate(target, threshold)
    assert(isentity(target), "Argument #1 has to be an entity");
    assert(isnumber(threshold), "Argument #2 has to be a number");

    self.hotspots = {};

    return ROAMING.listener:Add("Think", "Trampoline", function()
        local pos = ROAMING.client:GetPos();
        local vec = self.hotspots[1];

        if (isvector(vec)
                and pos:Distance(target:GetPos()) > threshold) then
            ROAMING.listener:Remove("Think", "Trampoline");
            if (AGENT:IsPlayerVisible(target, vec)) then
                return ROAMING:MoveTo(vec, threshold, function(pos)
                    return self:OnFinishMove(target, threshold, 1);
                end);
            else
                ROAMING:Error("The target is out of sight");
                return AGENT:OnDeactivate();
            end
        end
    end);
end

-- @function: AGENT.follower:OnFinishMove(<player: target>, <number: threshold>,
--  <number: iterator>)
-- @describe: Вызывается при завершении передвижения при преследовании игрока.
-- @arguments (3): <player: target>, <number: threshold>, <number: iterator>
-- @returns: None
function AGENT.follower:OnFinishMove(target, threshold, iterator)
    assert(isentity(target), "Argument #1 has to be an entity");
    assert(isnumber(threshold), "Argument #2 has to be a number");
    assert(isnumber(iterator), "Argument #3 has to be a number");

    local vec = self.hotspots[iterator];

    if (isvector(vec)) then
        if (AGENT:IsPlayerVisible(target, vec)) then
            return ROAMING:MoveTo(vec, threshold, function(pos)
                self.hotspots[iterator] = 0;
                return self:OnFinishMove(target, threshold,
                    iterator + 1);
            end);
        else
            ROAMING:Error("The target is out of sight");
            return AGENT:OnDeactivate();
        end
    else
        return self:OnTrampolineCreate(target, threshold);
    end
end
