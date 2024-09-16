-- Import modules
local menu = require("menu")
local menu_renderer = require("graphics.menu_renderer")
local revive = require("data.revive")
local explorer = require("data.explorer")
local automindcage = require("data.automindcage")
local actors = require("data.actors")
local waypoint_loader = require("functions.waypoint_loader")
local interactive_patterns = require("enums.interactive_patterns")
local teleport = require("data.teleport")
local Movement = require("functions.movement")

-- Initialize variables
local plugin_enabled = false
local doorsEnabled = false
local loopEnabled = false
local revive_enabled = false
local profane_mindcage_enabled = false
local profane_mindcage_count = 0
local graphics_enabled = false
local interactedObjects = {}
local was_in_helltide = false
local expiration_time = 10 -- Time to stop when interacting with a chest
local interaction_end_time = 0

-- Function to clear interacted objects
local function clear_interacted_objects()
    interactedObjects = {}
    console.print("Cleared interacted objects list")
end

-- Function to move to and interact with an object
local function moveToAndInteract(obj)
    local player_pos = get_player_position()
    local obj_pos = obj:get_position()
    local distanceThreshold = 2.0
    local moveThreshold = menu.move_threshold_slider:get()

    local distance = obj_pos:dist_to(player_pos)
    
    if distance < distanceThreshold then
        Movement.set_interacting(true)
        local obj_name = obj:get_skin_name()
        interactedObjects[obj_name] = os.clock() + expiration_time
        interact_object(obj)
        console.print("Interacting with " .. obj_name)
        Movement.set_interaction_end_time(os.clock() + 5) -- 5 segundos de interação, ajuste conforme necessário
        return true
    elseif distance < moveThreshold then
        pathfinder.request_move(obj_pos)
        return false
    end
end

-- Function to interact with objects
local function interactWithObjects()
    local local_player = get_local_player()
    if not local_player then return end

    local objects = actors_manager.get_ally_actors()
    if not objects then return end

    for _, obj in ipairs(objects) do
        if obj then
            local obj_name = obj:get_skin_name()
            if obj_name and interactive_patterns[obj_name] then
                if doorsEnabled and (not interactedObjects[obj_name] or os.clock() > interactedObjects[obj_name]) then
                    if moveToAndInteract(obj) then
                        return
                    end
                end
            end
        end
    end
end

-- Function to check if in loading screen
local function is_loading_screen()
    local world_instance = world.get_current_world()
    if world_instance then
        local zone_name = world_instance:get_current_zone_name()
        return zone_name == nil or zone_name == ""
    end
    return true
end

-- Function to check if in Helltide
local function is_in_helltide(local_player)
    if not local_player then return false end

    local buffs = local_player:get_buffs()
    if not buffs then return false end

    for _, buff in ipairs(buffs) do
        if buff and buff.name_hash == 1066539 then
            was_in_helltide = true
            return true
        end
    end
    return false
end

-- Function to update menu states
local function update_menu_states()
    local new_plugin_enabled = menu.plugin_enabled:get()
    if new_plugin_enabled ~= plugin_enabled then
        plugin_enabled = new_plugin_enabled
        console.print("Movement Plugin " .. (plugin_enabled and "enabled" or "disabled"))
        if plugin_enabled then
            local waypoints, _ = waypoint_loader.check_and_load_waypoints()
            Movement.set_waypoints(waypoints)
        end
    end

    doorsEnabled = menu.main_openDoors_enabled:get()
    loopEnabled = menu.loop_enabled:get()
    revive_enabled = menu.revive_enabled:get()
    profane_mindcage_enabled = menu.profane_mindcage_toggle:get()
    profane_mindcage_count = menu.profane_mindcage_slider:get()
end

-- Main update function
on_update(function()
    local current_time = os.clock()
    update_menu_states()

    if plugin_enabled then
        local local_player = get_local_player()
        if not local_player then return end

        local world_instance = world.get_current_world()
        if not world_instance then return end

        local teleport_state = teleport.get_teleport_state()

        if teleport_state ~= "idle" then
            if teleport.tp_to_next() then
                console.print("Teleport completed. Loading new waypoints...")
                local waypoints, _ = waypoint_loader.check_and_load_waypoints()
                Movement.set_waypoints(waypoints)
            end
        else
            local current_in_helltide = is_in_helltide(local_player)
            
            if was_in_helltide and not current_in_helltide then
                console.print("Helltide ended. Performing cleanup.")
                Movement.reset()
                clear_interacted_objects()
                was_in_helltide = false
            end

            if current_in_helltide then
                was_in_helltide = true
                if profane_mindcage_enabled then
                    automindcage.update()
                end
                interactWithObjects()
                Movement.set_moving(true)
                Movement.pulse(plugin_enabled, loopEnabled, teleport)
                if revive_enabled then
                    revive.check_and_revive()
                end
                actors.update()
            else
                console.print("Not in the Helltide zone. Attempting to teleport...")
                if teleport.tp_to_next() then
                    console.print("Teleported successfully. Loading new waypoints...")
                    local waypoints, _ = waypoint_loader.check_and_load_waypoints()
                    Movement.set_waypoints(waypoints)
                else
                    local state = teleport.get_teleport_state()
                    console.print("Teleport in progress. Current state: " .. state)
                end
            end
        end
    end
end)

-- Render menu function
on_render_menu(function()
    menu_renderer.render_menu(plugin_enabled, doorsEnabled, loopEnabled, revive_enabled, profane_mindcage_enabled, profane_mindcage_count)
end)