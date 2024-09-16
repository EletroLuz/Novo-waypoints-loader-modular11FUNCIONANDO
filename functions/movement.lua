-- functions/movement.lua

local waypoint_loader = require("functions.waypoint_loader")
local explorer = require("data.explorer")
local teleport = require("data.teleport")

local Movement = {}

-- Local variables
local waypoints = {}
local ni = 1
local is_moving = false
local is_interacting = false
local explorer_active = false
local moving_backwards = false
local previous_player_pos = nil
local last_movement_time = 0
local stuck_check_time = 0
local force_move_cooldown = 0
local explorer_end_time = 0
local interaction_end_time = nil

-- Configuration (these could be set via a config function)
local stuck_threshold = 10
local moveThreshold = 12

function Movement.set_interaction_end_time(end_time)
    interaction_end_time = end_time
end

function Movement.set_interacting(state)
    is_interacting = state
    if not state then
        interaction_end_time = nil
    end
end

-- Helper functions
local function get_distance(point)
    return get_player_position():dist_to(point)
end

local function update_waypoint_index()
    if moving_backwards then
        ni = ni - 1
    else
        ni = ni + 1
    end
end

local function handle_stuck_player(current_waypoint, current_time, teleport)
    if current_time - stuck_check_time > stuck_threshold and teleport.get_teleport_state() == "idle" then
        console.print("Player stuck for " .. stuck_threshold .. " seconds, calling explorer module")
        if current_waypoint then
            explorer.set_target(current_waypoint)
            explorer.enable()
            explorer_active = true
            console.print("Explorer activated")
            explorer_end_time = current_time + 30 -- 30 segundos de exploração, ajuste conforme necessário
        else
            console.print("Error: No current waypoint set")
        end
        return true
    end
    return false
end

local function force_move_if_stuck(player_pos, current_time, current_waypoint)
    if previous_player_pos and player_pos:dist_to(previous_player_pos) < 3 then
        if current_time - last_movement_time > 5 then
            console.print("Player stuck, using force_move_raw")
            local randomized_waypoint = waypoint_loader.randomize_waypoint(current_waypoint)
            pathfinder.force_move_raw(randomized_waypoint)
            last_movement_time = current_time
        end
    else
        previous_player_pos = player_pos
        last_movement_time = current_time
        stuck_check_time = current_time -- Reset stuck_check_time when moving
    end
end

-- Main movement function
function Movement.pulse(plugin_enabled, loopEnabled, teleport)
    local current_time = os.clock()

    if not plugin_enabled then
        return
    end

    -- Verifica se a interação terminou
    if is_interacting then
        if interaction_end_time and current_time > interaction_end_time then
            is_interacting = false
            console.print("Interaction complete, resuming movement")
        else
            return
        end
    end

    if not is_moving then
        is_moving = true
        console.print("Resuming movement")
    end

    -- Verifica se o tempo do explorer acabou
    if explorer_active and explorer_end_time and current_time > explorer_end_time then
        explorer_active = false
        console.print("Explorer deactivated, resuming normal movement")
    end

    if type(waypoints) ~= "table" or type(ni) ~= "number" then
        console.print("Error: Invalid waypoints or index")
        return
    end

    if ni > #waypoints or ni < 1 or #waypoints == 0 then
        if loopEnabled then
            ni = 1
        else
            return
        end
    end

    local current_waypoint = waypoints[ni]
    if current_waypoint then
        local current_time = os.clock()
        local player_pos = get_player_position()
        local distance = get_distance(current_waypoint)
        
        if distance < 2 then
            update_waypoint_index()
            last_movement_time = current_time
            force_move_cooldown = 0
            previous_player_pos = player_pos
            stuck_check_time = current_time
        else
            if not explorer_active then
                if handle_stuck_player(current_waypoint, current_time, teleport) then
                    return
                end
            end
            
            force_move_if_stuck(player_pos, current_time, current_waypoint)

            if current_time > force_move_cooldown then
                local randomized_waypoint = waypoint_loader.randomize_waypoint(current_waypoint)
                pathfinder.request_move(randomized_waypoint)
            end
        end
    end
end

-- Configuration functions
function Movement.set_waypoints(new_waypoints)
    waypoints = new_waypoints
    ni = 1
end

function Movement.set_moving(moving)
    is_moving = moving
end

function Movement.set_interacting(interacting)
    is_interacting = interacting
end

function Movement.reset()
    ni = 1
    is_moving = false
    is_interacting = false
    explorer_active = false
    moving_backwards = false
    previous_player_pos = nil
    last_movement_time = 0
    stuck_check_time = os.clock()
    force_move_cooldown = 0
end

return Movement