-- @filename: cl_roaming.lua
-- @credits: github.com/causaprima0/gm_roaming
-- @version: 1.1.0 @ 07/09/2025

require("fileio");

local roaming = setmetatable({
    client  = LocalPlayer(),
    salt    = os.time(),
}, {
    __index = function(self, key)
        self[key] = setmetatable({}, getmetatable(self));
        return self[key];
    end,
});

-- @function: roaming:Warning(<string: str>, <vararg: ...>)
-- @describe: Вызывается при создании предупреждения скриптом.
-- @arguments (2): <string: str>, <vararg: ...>
-- @returns: None
function roaming:Warning(str, ...)
    assert(isstring(str), "Argument #1 has to be a string");
    return MsgC(Color(255, 204, 0), "[ROAMING WARNING] ",
        string.format(str, ...), "\n");
end

-- @function: roaming:Error(<string: err>, <vararg: ...>)
-- @describe: Вызывается при возникновении внутренней ошибки скрипта.
-- @arguments (2): <string: err>, <vararg: ...>
-- @returns: None
function roaming:Error(err, ...)
    assert(isstring(err), "Argument #1 has to be a string");
    return MsgC(Color(255, 0, 0), "[ROAMING ERROR] ",
        string.format(err, ...), "\n");
end

-- @function: roaming:Abort()
-- @describe: Прерывает работу сценарного движения.
-- @arguments (0): None
-- @returns: None
function roaming:Abort()
    self.listener:Remove("CreateMove", "Move");
    self.listener:Remove("Think", "View");
    self.listener:Remove("PostDrawOpaqueRenderables", "Trace");
end

-- @function: roaming:MoveTo(<vector: vec>, <number: threshold>,
--  <function: callback>)
-- @describe: Создаёт задачу на передвижение клиента.
-- @arguments (3): <vector: vec>, <number: threshold>, <function: callback>
-- @returns: None
function roaming:MoveTo(vec, threshold, callback)
    assert(isvector(vec), "Argument #1 has to be a vector");
    assert(isnumber(threshold), "Argument #2 has to be a number");
    assert(isfunction(callback), "Argument #3 has to be a function");

    self.view:LockAtVector(vec, threshold);
    self.trace:Create(vec, threshold);
    self.move:GoTo(vec, threshold, callback);
end

-- @function: roaming.listener:GetIDX(<string: id>)
-- @describe: Возвращает безопасный идентификатор для обработчика.
-- @arguments (1): <string: id>
-- @returns: String
function roaming.listener:GetIDX(id)
    assert(isstring(id), "Argument #1 has to be a string");
    return util.SHA256(id .. roaming.salt);
end

-- @function: roaming.listener:Add(<string: event>, <string: id>,
--  <function: callback>)
-- @describe: Создаёт новый безопасный обработчик события.
-- @arguments (3): <string: event>, <string: id>, <function: callback>
-- @returns: None
function roaming.listener:Add(event, id, callback)
    assert(isstring(event), "Argument #1 has to be a string");
    assert(isstring(id), "Argument #2 has to be a string");
    assert(isfunction(callback), "Argument #3 has to be a function");

    return hook.Add(event, self:GetIDX(id), function(...)
        return callback(...);
    end);
end

-- @function: roaming.listener:Remove(<string: event>, <string: id>)
-- @describe: Удаляет существующий обработчик события.
-- @arguments (2): <string: event>, <string: id>
-- @returns: None
function roaming.listener:Remove(event, id)
    assert(isstring(event), "Argument #1 has to be a string");
    assert(isstring(id), "Argument #2 has to be a string");

    return hook.Remove(event, self:GetIDX(id));
end

-- @function: roaming.view:GetLookAtAngle(<vector: vec>)
-- @describe: Возвращает угол обзора по направлению вектора.
-- @arguments (1): <vector: vec>
-- @returns: Angle
function roaming.view:GetLookAtAngle(vec)
    assert(isvector(vec), "Argument #1 has to be a vector");
    return (vec - roaming.client:GetPos())
        :GetNormalized():Angle();
end

-- @function: roaming.view:LockAtVector(<vector: vec>, <number: threshold>)
-- @describe: Фокусирует камеру игрока на направлении вектора.
-- @arguments (2): <vector: vec>, <number: threshold>
-- @returns: None
function roaming.view:LockAtVector(vec, threshold)
    assert(isvector(vec), "Argument #1 has to be a vector");
    assert(isnumber(threshold), "Argument #2 has to be a number");

    return roaming.listener:Add("Think", "View", function()
        local pos = roaming.client:GetPos();
        if (pos:Distance(vec) > threshold) then
            local angles = self:GetLookAtAngle(vec);
            return roaming.client:SetEyeAngles(angles);
        else
            return roaming.listener:Remove("Think", "View");
        end
    end);
end

-- @function: roaming.move:IsPathObstacled(<vector: pos>, <vector: vec>
--  <number: threshold>)
-- @describe: Возвращает, есть ли препятствие на пути от позиции до вектора.
-- @arguments (3): <vector: pos>, <vector: vec>, <number: threshold>
-- @returns: Boolean
function roaming.move:IsPathObstacled(pos, vec, threshold)
    assert(isvector(pos), "Argument #1 has to be a vector");
    assert(isvector(vec), "Argument #2 has to be a vector");

    local obstacle = self.obstacle:Find(pos, vec);
    return obstacle:IsValid() or obstacle == game.GetWorld();
end

-- @function: roaming.move:GoTo(<vector: vec>, <number: threshold>,
--  <function: callback>)
-- @describe: Выполняет передвижение клиента на заданный вектор.
-- @arguments (3): <vector: vec>, <number: threshold>, <function: callback>
-- @returns: None
function roaming.move:GoTo(vec, threshold, callback)
    assert(isvector(vec), "Argument #1 has to be a vector");
    assert(isnumber(threshold), "Argument #2 has to be a number");
    assert(isfunction(callback), "Argument #3 has to be a function");

    return roaming.listener:Add("CreateMove", "Move", function(cmd)
        local bExperimental = roaming.agent.instance.bExperimental == true;
        local pos = roaming.client:GetPos();

        if (not bExperimental
                or not self:IsPathObstacled(pos, vec, threshold)) then
            if (pos:Distance(vec) > threshold) then
                local mxspeed = roaming.client:GetMaxSpeed();
                cmd:SetForwardMove(mxspeed);
            else
                roaming.listener:Remove("CreateMove", "Move");
                return callback(pos);
            end
        elseif (bExperimental) then
            local obstacle = self.obstacle:Find(pos, vec);
            local path = self.obstacle.path:Find(obstacle, 10, vec);

            self.obstacle.path.previous = path;
            path = Vector(path.x, path.y, pos.z);

            return roaming:MoveTo(path, 20, function()
                return roaming:MoveTo(vec, threshold, callback);
            end);
        end
    end);
end

-- @function: roaming.move.obstacle:Find(<vector: pos>, <vector: vec>)
-- @describe: Ищет и возвращает энтити-препятствие на пути до вектора.
-- @arguments (2): <vector: pos>, <vector: vec>
-- @returns: Entity
function roaming.move.obstacle:Find(pos, vec)
    assert(isvector(pos), "Argument #1 has to be a vector");
    assert(isvector(vec), "Argument #2 has to be a vector");

    local step = roaming.client:GetStepSize();

    return util.TraceEntityHull({
        start   = Vector(pos.x, pos.y, pos.z + step),
        endpos  = vec,
        mask    = MASK_SOLID,
        filter  = roaming.client,
    }, roaming.client).Entity;
end

-- @function: roaming.move.obstacle.path:Find(<entity: target>,
--  <number: threshold>, <vector: vec>)
-- @describe: Возвращает наиболее подходящую для обхода точку.
-- @arguments (3): <entity: target>, <number: threshold>, <vector: vec>
-- @returns: Vector
function roaming.move.obstacle.path:Find(target, threshold, vec)
    assert(isentity(target), "Argument #1 has to be an entity");
    assert(isnumber(threshold), "Argument #2 has to be a number");
    assert(isvector(vec), "Argument #3 has to be a vector");

    local origin = roaming.client:GetPos();
    local obb = roaming.client:OBBMaxs();
    local angle = Angle();

    local pos = target:GetPos();
    local mins = target:OBBMins();
    local maxs = target:OBBMaxs();

    mins, maxs = target:GetRotatedAABB(mins, maxs);

    local z = (mins.z + maxs.z) / 2;
    local n = threshold;

    local A = Vector(maxs.x + obb.x + n, mins.y - obb.y - n, z);
    local B = Vector(mins.x - obb.x - n, mins.y - obb.y - n, z);
    local C = Vector(maxs.x + obb.x + n, maxs.y + obb.y + n, z);
    local D = Vector(mins.x - obb.x - n, maxs.y + obb.y + n, z);

    A = LocalToWorld(A, angle, pos, angle);
    B = LocalToWorld(B, angle, pos, angle);
    C = LocalToWorld(C, angle, pos, angle);
    D = LocalToWorld(D, angle, pos, angle);

    return self:GetDetour(origin, vec, A, B, C, D);
end

-- @function: roaming.move.obstacle.path:GetConnections(<table: points>)
-- @describe: Ищет и возвращает таблицу связей между точками в таблице.
-- @arguments (1): <table: points>
-- @returns: Table
function roaming.move.obstacle.path:GetConnections(points)
    assert(istable(points), "Argument #1 has to be a table");
    assert(#points > 0, "Argument #1 has to be a sequential table");

    local connections = {};

    for k, v in ipairs(points) do
        connections[v] = {};
        for x, y in ipairs(points) do
            if (not roaming.move:IsPathObstacled(v, y)) then
                connections[v][#connections[v] + 1] = y;
            end
        end
    end

    return connections;
end

-- @function: roaming.move.obstacle.path:GetDetour(<vector: origin>,
--  <vector: vec>, <vararg: ...>)
-- @describe: Возвращает наиболее подходящую точку из представленных.
-- @arguments (3): <vector: origin>, <vector: vec>, <vararg: ...>
-- @returns: Vector
function roaming.move.obstacle.path:GetDetour(origin, vec, ...)
    assert(isvector(origin), "Argument #1 has to be a vector");
    assert(isvector(vec), "Argument #2 has to be a vector");

    local connections = self:GetConnections({...});

    local A = ({...})[1];
    local C;
    for idx, B in ipairs({unpack({...})}) do
        A, B, C = unpack(self:Compare(origin, vec,
            connections, A, B, C));
    end

    return A;
end

-- @function: roaming.move.obstacle.path:Compare(<vector: origin>,
--  <vector: vec>  <table: points>, <vararg: ...>)
-- @describe: Возвращает, является ли представленная B-точка лучшей, чем A.
-- @arguments (4): <vector: origin>, <vector: vec>, <table: points>, <vararg: ...>
-- @returns: Table
function roaming.move.obstacle.path:Compare(origin, vec, points, ...)
    assert(isvector(origin), "Argument #1 has to be a vector");
    assert(isvector(vec), "Argument #2 has to be a vector");
    assert(istable(points), "Argument #3 has to be a table");

    local A = ({...})[1];
    local B = ({...})[2];
    local C = ({...})[3];

    if (B ~= self.previous
            and not roaming.move:IsPathObstacled(origin, B)) then
        if (B:Distance(origin) < A:Distance(origin)
                and (not roaming.move:IsPathObstacled(B, vec)
                    or roaming.move:IsPathObstacled(A, vec))) then
            A = B;
        elseif (roaming.move:IsPathObstacled(A, vec)
                and not roaming.move:IsPathObstacled(B, vec)) then
            A = B;
        end

        if (roaming.move:IsPathObstacled(A, vec)
                and roaming.move:IsPathObstacled(B, vec)
                and not C) then
            for k, v in ipairs(points[B]) do
                if (not roaming.move:IsPathObstacled(v, vec)
                        or not roaming.move:IsPathObstacled(B, v)) then
                    C = v;
                    A = B;
                end
            end
        end
    end

    return {A, B, C};
end

-- @function: roaming.trace:GetColor(<number: distance>, <number: threshold>)
-- @describe: Возвращает цвет для визуального трейсера с учётом дистанции.
-- @arguments (2): <number: distance>, <number: threshold>
-- @returns: None
function roaming.trace:GetColor(distance, threshold)
    assert(isnumber(distance), "Argument #1 has to be a number");
    assert(isnumber(threshold), "Argument #2 has to be a number");

    return distance < (threshold + 120)
        and Color(51, 255, 0) or Color(255, 255, 0);
end

-- @function: roaming.trace:Create(<vector: vec>, <number: threshold>)
-- @describe: Создаёт новый визуальный обработчик для сопровождения движения.
-- @arguments (2): <vector: vec>, <number: threshold>
-- @returns: None
function roaming.trace:Create(vec, threshold)
    assert(isvector(vec), "Argument #1 has to be a vector");
    assert(isnumber(threshold), "Argument #2 has to be a number");

    return roaming.listener:Add("PostDrawOpaqueRenderables", "Trace", function()
        local pos = roaming.client:GetPos();
        local obbcenter = pos + roaming.client:OBBCenter();
        local accent = self:GetColor(pos:Distance(vec), threshold);

        render.SetColorMaterial();

        if (pos:Distance(vec) > threshold) then
            render.DrawBeam(pos, vec, 3, 0, 1, accent);
            render.DrawWireframeSphere(obbcenter, 50, 10, 10,
                Color(255, 255, 255, 10));
            render.DrawSphere(vec, 10, 30, 30, accent);
            render.DrawWireframeSphere(vec, threshold, 10, 10,
                Color(255, 255, 255, 10));
        else
            return roaming.listener:Remove("PostDrawOpaqueRenderables", "Trace");
        end
    end);
end

-- @function: roaming.agent:Import(<string: name>, <function: onSuccess>
--  <function: onError>)
-- @describe: Вызывается при испорте нового сценарного агента.
-- @arguments (3): <string: name>, <function: onSuccess>, <function: onError>
-- @returns: None
function roaming.agent:Import(name, onSuccess, onError)
    assert(isstring(name), "Argument #1 has to be a string");
    assert(isfunction(onSuccess), "Argument #2 has to be a function");
    assert(isfunction(onError), "Argument #3 has to be a function");

    local dir = string.format("../../GarrysMod.Roaming/%s/", name);
    local executable = fileio.Read(string.format("%scl_%s.lua", dir, name));
    local pathmap = fileio.Read(string.format("%spathmap.json", dir, name));

    pathmap = util.JSONToTable(pathmap or "{}");

    if (not executable or not istable(pathmap)) then
        return roaming:Error("Couldn't import a new agent: '%s'", name);
    else
        self.pathmap.instance = pathmap.sites;
        self.pathmap.bSequential = #pathmap.sites > 0;
        return self:Compile(executable, onSuccess, onError);
    end
end

-- @local: roaming.agent.public
-- @describe: Окружение, передаваемое в функцию агента.
roaming.agent.public = setmetatable({}, {
    __index = function(self, key)
        if (key == "pathmap") then
            return setmetatable(roaming.agent.pathmap, {
                __index = roaming.agent.pathmap.instance,
            });
        elseif (key ~= "agent") then
            return roaming[key];
        end
    end,
});

-- @function: roaming.agent:Compile(<string: executable>, <function: onSuccess>,
--  <function: onError>)
-- @describe: Подготавливает и вызывает функцию исполняемого скрипта.
-- @arguments (3): <string: executable>, <function: onSuccess>,
--  <function: onError>
-- @returns: Function
function roaming.agent:Compile(executable, onSuccess, onError)
    assert(isstring(executable), "Argument #1 has to be a string");
    assert(isfunction(onSuccess), "Argument #2 has to be a function");
    assert(isfunction(onError), "Argument #3 has to be a function");

    local executable = CompileString(executable, "@roaming", false);

    if (isfunction(executable)) then
        setfenv(executable, setmetatable({
            ROAMING = self.public,
            AGENT   = self.instance,
        }, {
            __index = _G,
        }))();
        return onSuccess(self.instance);
    else
        return onError(executable);
    end
end

-- @function: roaming.agent.pathmap:GetPointVector(<string: id>)
-- @describe: Возвращает вектор позиции по её наименованию.
-- @arguments (1): <string: id>
-- @returns: Vector
function roaming.agent.pathmap:GetPointVector(id)
    assert(isnumber(id) or isstring(id), "Argument #1 has to be a string");
    local point = self.instance[id];
    return Vector(point.x or -1, point.y or -1, point.z or -1);
end

-- @function: roaming.agent.pathmap:FindEntryPoint()
-- @describe: Ищет и возвращает первую подходящую точку входа в Pathmap.
-- @arguments (0): None
-- @returns: String
function roaming.agent.pathmap:FindEntryPoint()
    for idx, payload in pairs(self.instance) do
        local vec = Vector(payload.x, payload.y, payload.z);
        local pos = roaming.client:GetPos();
        if (not roaming.move:IsPathObstacled(pos, vec)) then
            return idx;
        end
    end
    return false;
end

concommand.Add("+roaming", function(client, cmd, args)
    if (isstring(args[1])) then
        return roaming.agent:Import(args[1], function(agent)
            if (not agent.bExperimental) then return; end
            roaming:Warning("Agent '%s' has experimental mode enabled", args[1]);
            return roaming:Warning("Certain features may not work as intended");
        end, function(err)
            return roaming:Error("An error occured while compiling: %s", err);
        end);
    elseif (isfunction(roaming.agent.instance.OnActivate)) then
        local pos = roaming.client:GetPos();
        roaming.agent.instance:OnActivate(pos, args[1]);
    else
        return roaming:Error("Missing OnActivate(...) handler");
    end
end);

concommand.Add("-roaming", function(client, cmd, args)
    if (isfunction(roaming.agent.instance.OnDeactivate)) then
        local pos = roaming.client:GetPos();
        roaming.agent.instance:OnDeactivate(pos);
    else
        return roaming:Error("Missing OnDeactivate(...) handler");
    end
end);

concommand.Add("$roaming", function(ply, cmd, args)
    if (isfunction(roaming.agent.instance.OnActivate)) then
        local pos = roaming.client:GetPos();
        roaming.agent.instance:OnActivate(pos, unpack(args));
    else
        return roaming:Error("Missing OnActivate(...) handler");
    end
end);
