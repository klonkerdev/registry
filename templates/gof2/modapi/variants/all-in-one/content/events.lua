local state = require("state")

RegisterEvent("IsInGame", function()
    state.in_game = true

    if not state.announced then
        print("[" .. state.mod_id .. "] gameplay active")
        state.announced = true
    end

    if not state.blueprint_unlocked and state.blueprint_id ~= 0 then
        item:UnlockBlueprint(state.blueprint_id)
        state.blueprint_unlocked = true
    end
end)

RegisterEvent("OnAsteroidDestroyed", function(count)
    state.asteroids_destroyed = count
    print("[" .. state.mod_id .. "] asteroids destroyed: " .. count)
end)
