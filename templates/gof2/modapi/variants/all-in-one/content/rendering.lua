local state = require("state")

HookFunction("ModMainMenu::OnRender2D", function(ctx)
    ctx:DrawString(state.mod_name, 30, 30, 110, 174, 255, 255)
    ctx:call()
end)

local frame = 0

HookFunction("MGame::OnRender2D", function(ctx)
    frame = frame + 1

    local pulse = math.floor((math.sin(frame / 30) + 1) * 60) + 120
    local status = state.mod_id
        .. " | rocks "
        .. state.asteroids_destroyed
    ctx:DrawString(status, 30, 30, 110, pulse, 255, 255)

    -- This render hook wraps the original function, so preserve its call.
    ctx:call()
end)
