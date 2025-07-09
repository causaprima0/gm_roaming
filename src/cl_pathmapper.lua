-- @filename: cl_pathmapper.lua
-- @credits: github.com/causaprima0/gm_roaming
-- @version: 0.9 @ 07/09/2025

local pathmapper = {
    client      = LocalPlayer(),
    salt        = os.time(),
    listener    = {},
    spot        = {},
};

-- @function: pathmapper:Reset()
-- @describe: Сбрасывает сохранённые параметры.
-- @arguments (0): None
-- @returns: None
function pathmapper:Reset()
    pathmapper.spot.stored = {};
end

-- @function: pathmapper.listener:GetIDX(<string: id>)
-- @describe: Возвращает безопасный идентификатор для обработчика.
-- @arguments (1): <string: id>
-- @returns: String
function pathmapper.listener:GetIDX(id)
    assert(isstring(id), "Argument #1 has to be a string");
    return util.SHA256(id .. pathmapper.salt);
end

-- @function: pathmapper.listener:Add(<string: event>, <string: id>,
--  <function: callback>)
-- @describe: Создаёт новый безопасный обработчик события.
-- @arguments (3): <string: event>, <string: id>, <function: callback>
-- @returns: None
function pathmapper.listener:Add(event, id, callback)
    assert(isstring(event), "Argument #1 has to be a string");
    assert(isstring(id), "Argument #2 has to be a string");
    assert(isfunction(callback), "Argument #3 has to be a function");

    return hook.Add(event, self:GetIDX(id), function(...)
        return callback(...);
    end);
end

-- @function: pathmapper.listener:Remove(<string: event>, <string: id>)
-- @describe: Удаляет существующий обработчик события.
-- @arguments (2): <string: event>, <string: id>
-- @returns: None
function pathmapper.listener:Remove(event, id)
    assert(isstring(event), "Argument #1 has to be a string");
    assert(isstring(id), "Argument #2 has to be a string");

    return hook.Remove(event, self:GetIDX(id));
end

-- @function: pathmapper.spot:IsPathObstacle(<vector: vec>)
-- @describe: Ищет и возвращает, есть ли препятствие на пути.
-- @arguments (1): <vector: vec>
-- @returns: Boolean
function pathmapper.spot:IsPathObstacled(vec)
    assert(isvector(vec), "Argument #1 has to be a vector");

    local pos = pathmapper.client:GetPos();
    local step = pathmapper.client:GetStepSize();

    return util.TraceEntityHull({
        start   = Vector(pos.x, pos.y, pos.z + step),
        endpos  = vec,
        mask    = MASK_SOLID,
        filter  = pathmapper.client,
    }, pathmapper.client).HitPos ~= vec;
end

-- @function: pathmapper.spot:Add(<vector: pos>, <string: id>)
-- @describe: Добавляет новую точку в путевую карту.
-- @arguments (2): <vector: vec>, <string: id>
-- @returns: None
function pathmapper.spot:Add(pos, id)
    assert(isvector(pos), "Argument #1 has to be a vector");
    assert(not id or isstring(id), "Argument #2 has to be a string");

    local bSequential = #self.stored > 0;

    if (not bSequential and isstring(id)) then
        local followup = {};

        for name, payload in pairs(self.stored) do
            if (name == id) then continue; end
            local vec = Vector(payload.x, payload.y, payload.z);
            if (not self:IsPathObstacled(vec)) then
                table.insert(followup, name);
                table.insert(self.stored[name]["then"], id);
            end
        end

        return rawset(self.stored, id, {
            ["x"]       = pos.x,
            ["y"]       = pos.y,
            ["z"]       = pos.z,
            ["then"]    = followup,
        });
    else
        self.stored[#self.stored + 1] = {
            x   = pos.x,
            y   = pos.y,
            z   = pos.z,
        };
    end
end

pathmapper.listener:Add("PostDrawOpaqueRenderables", "Tracers", function()
    for name, payload in pairs(pathmapper.spot.stored) do
        local vec = Vector(payload.x, payload.y, payload.z);

        render.SetColorMaterial();
        render.DrawWireframeSphere(vec, 20, 10, 10,
            Color(255, 255, 255, 50), true);

        if (payload["then"]) then
            for idx, node in ipairs(payload["then"]) do
                local node = pathmapper.spot.stored[node];
                local origin = Vector(node.x, node.y, node.z);

                render.SetColorMaterial();
                render.DrawBeam(vec, origin, 3, 0, 1, Color(0, 255, 0));
            end
        elseif (pathmapper.spot.stored[name + 1]) then
            local node = pathmapper.spot.stored[name + 1];
            local origin = Vector(node.x, node.y, node.z);

            render.SetColorMaterial();
            render.DrawBeam(vec, origin, 3, 0, 1, Color(0, 255, 0));
        end
    end
end);

concommand.Add("+pathmapper", function(ply, cmd, args)
    local pos = pathmapper.client:GetPos();
    return pathmapper.spot:Add(pos, args[1]);
end);

concommand.Add("-pathmapper", function(ply, cmd, args)
    return pathmapper:Reset();
end);

concommand.Add("*pathmapper", function(ply, cmd, args)
    return file.Write("pathmapper@" .. game.GetMap() .. ".json",
        util.TableToJSON(pathmapper.spot.stored, true));
end);

return pathmapper:Reset()
