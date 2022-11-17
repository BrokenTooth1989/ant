local ecs = ...
local world = ecs.world
local rhwi  = import_package "ant.hwi"
local utils = ecs.require "mathutils"
local imgui = require "imgui"
local m     = ecs.system 'input_system'
local event_mouse = world:sub {"mouse"}
local event_mouse_wheel = world:sub {"mouse_wheel"}
local event_keyboard = world:sub{"keyboard"}
local last_mouse
local last_vx, last_vy
local last_wx, last_wy

function m:input_filter()
    for _,what,state,x,y in event_mouse:unpack() do
        if x and y then
            if state == "DOWN" then
                last_vx, last_vy = x, y
                last_mouse = what
                world:pub {"mousedown", what, x, y}
            elseif state == "MOVE" and last_mouse == what then
                local dpiX, dpiY = rhwi.dpi()
                local dx, dy = (x - last_vx) / dpiX, (y - last_vy) / dpiY
                if what == "LEFT" or what == "RIGHT" or what == "MIDDLE" then
                    world:pub { "mousedrag", what, x, y, dx, dy }
                end
                last_vx, last_vy = x, y
            elseif state == "UP" then
                world:pub {"mouseup", what, x, y}
            else
                world:pub {"mousemove", what, x, y}
            end
        end
    end
end
