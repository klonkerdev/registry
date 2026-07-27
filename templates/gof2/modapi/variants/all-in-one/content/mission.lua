local state = require("state")

RegisterEvent("OnStationDocked", function()
    if mission.id < 84 or state.mission_id == 0 then
        return
    end

    if state.stage == 0 then
        mission:Enable(state.mission_id)
        state.stage = 1
        return
    end

    if state.stage == 1 and station.id == state.station_id then
        mission:Disable(state.mission_id)
        wait(1)
        level:CreateDialogueWindow({
            {
                name = "Wayfinder",
                content = "Prototype delivered. Your payment is ready.",
                image = state.portrait,
                isplayer = 0,
            },
            {
                name = "Keith T. Maxwell",
                content = "Good doing business with you.",
                image = state.portrait,
                isplayer = 1,
            },
        })
        player.money = player.money + state.reward
        state.stage = 2
    end
end)
