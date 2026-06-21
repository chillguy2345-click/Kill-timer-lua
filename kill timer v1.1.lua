print("Kill Timer v1.1 loaded!")
print("youtube.com/@url.isp2")
print("discord: chillguy_2345")
print("please give me a like and a subcribe at my youtube channel if you like this lua")
print("thank ya so much, hope you enjoy this lua^^")


local math_floor, math_sin, math_max, math_min, math_abs = math.floor, math.sin, math.max, math.min, math.abs
local string_format = string.format
local globals_RealTime = globals.RealTime
local gui_GetValue, gui_SetValue = gui.GetValue, gui.SetValue
local draw_Color, draw_RoundedRect, draw_RoundedRectFill, draw_FilledRect, draw_Text = draw.Color, draw.RoundedRect, draw.RoundedRectFill, draw.FilledRect, draw.Text
local entities_GetLocalPlayer, entities_GetLocalPawn = entities.GetLocalPlayer, entities.GetLocalPawn
local input_GetMousePos, input_IsButtonDown = input.GetMousePos, input.IsButtonDown


-- 1. GUI 

local wnd = gui.Window("kt_window", "Kill Timer", 300, 300, 350, 330)
local init_menukey = gui_GetValue("adv.menukey")
if init_menukey and init_menukey ~= 0 then wnd:SetOpenKey(init_menukey) end

local group_controls = gui.Groupbox(wnd, "Configuration", 15, 15, 320, 260)
local kt_enable = gui.Checkbox(group_controls, "kt_enable", "Enable Kill Timer", true)
local kt_duration = gui.Slider(group_controls, "kt_duration", "Max Tempo Duration (s)", 5.0, 1.0, 15.0, 0.5)

local kt_limit_enable = gui.Checkbox(group_controls, "kt_limit_enable", "Enable Kill Limit Notification", true)
local kt_limit = gui.Slider(group_controls, "kt_limit", "Round Kill Limit", 5, 1, 5, 1)

local kt_extra_safety = gui.Checkbox(group_controls, "kt_extra_safety", "Extra Safety: Auto Disable Ragebot", false)


local kt_x = gui.Slider(group_controls, "kt_x", "Indicator X", 960, 0, 3840, 1)
local kt_y = gui.Slider(group_controls, "kt_y", "Indicator Y", 600, 0, 2160, 1)

local kt_draggable = gui.Checkbox(group_controls, "kt_draggable", "Draggable Indicator (Optional)", false)

local FONT_SESSION = draw.CreateFont("Segoe UI", 12, 700)
local FONT_WARNING = draw.CreateFont("Segoe UI", 11, 700)


local TIME_STRINGS = {}
for i = 0, 160 do TIME_STRINGS[i] = string_format("%.1fs", i / 10) end

local KILL_STRINGS_WITH_LIMIT = {}
local KILL_STRINGS_NO_LIMIT = {}
for k = 0, 50 do
    KILL_STRINGS_NO_LIMIT[k] = string_format("ROUND KILLS: %d", k)
    KILL_STRINGS_WITH_LIMIT[k] = {}
    for l = 1, 5 do KILL_STRINGS_WITH_LIMIT[k][l] = string_format("ROUND KILLS: %d / %d", k, l) end
end


-- 2. STATE

local tempo_expire_time = 0.0
local current_kill_count = 0
local is_timer_active = false
local animated_width = 170
local animated_offset = 0 
local aimware_menu = gui.Reference("MENU")

local menu_enabled = true
local menu_draggable = false
local menu_duration = 5.0
local menu_limit_active = true
local menu_limit = 5
local menu_extra_safety = false

local menu_x, menu_y = 960, 600
local drag_offset_x, drag_offset_y = 0, 0
local is_dragging = false

local last_rage_override = false
local cached_kill_string = "ROUND KILLS: 0 / 5"
local WARNING_ICON_STR = "\xE2\x9A\xA0 !!!YOU HAVE REACHED YOUR KILL LIMIT, LET YOUR TEAMMATES DO THE REST!!!"


local bit_band = (bit and bit.band) or (bit32 and bit32.band)
local function handle_to_index(h)
    if not h or h == 0 or h == 0xFFFFFFFF then return 0 end
    if h < 0 then h = h + 4294967296 end
    if bit_band then return bit_band(h, 0x7FFF) end
    return h % 0x8000
end

local function update_kill_string()
    if menu_limit_active then
        local sub_table = KILL_STRINGS_WITH_LIMIT[current_kill_count]
        cached_kill_string = sub_table and sub_table[menu_limit] or "ROUND KILLS: 0 / 5"
    else
        cached_kill_string = KILL_STRINGS_NO_LIMIT[current_kill_count] or "ROUND KILLS: 0"
    end
end

local function reset_system_state()
    tempo_expire_time = 0.0
    current_kill_count = 0
    is_timer_active = false
    animated_width = 170
    animated_offset = 0
    update_kill_string()
    
    if last_rage_override then
        gui_SetValue("rbot.enable", true)
        last_rage_override = false
    end
end


-- 3. Events

client.AllowListener("player_death")
client.AllowListener("round_start")

callbacks.Register("FireGameEvent", function(event)
    if not event then return end
    local event_name = event:GetName()

    if event_name == "round_start" then
        reset_system_state()
        return
    end

    if event_name == "player_death" then
        local attacker_pawn = event:GetInt("attacker_pawn")
        if attacker_pawn == 0 or attacker_pawn == 0xFFFFFFFF then return end
        if attacker_pawn == event:GetInt("userid_pawn") then return end

        local me = entities_GetLocalPlayer() or entities_GetLocalPawn()
        if not me then return end
        
        if handle_to_index(attacker_pawn) == me:GetIndex() then
            current_kill_count = current_kill_count + 1
            tempo_expire_time = globals_RealTime() + menu_duration
            is_timer_active = true
            animated_width = 140
            update_kill_string()
        end
    end
end)


local last_config_tick = 0.0


-- 4. render

callbacks.Register("Draw", function()
    local real_time = globals_RealTime()
    local is_menu_open = false

    if real_time < last_config_tick then last_config_tick = 0 end
    if real_time - last_config_tick > 0.1 then
        is_menu_open = aimware_menu and aimware_menu:IsActive()
        menu_enabled = kt_enable:GetValue()
        menu_draggable = kt_draggable:GetValue()
        menu_duration = kt_duration:GetValue() or 5.0
        menu_limit_active = kt_limit_enable:GetValue()
        menu_limit = kt_limit:GetValue() or 5
        menu_extra_safety = kt_extra_safety:GetValue()
        
        if is_menu_open then
            kt_limit:SetInvisible(not menu_limit_active)
            local current_menukey = gui_GetValue("adv.menukey")
            if current_menukey and current_menukey ~= 0 then wnd:SetOpenKey(current_menukey) end
        end
        
        update_kill_string()
        last_config_tick = real_time
    else
        is_menu_open = aimware_menu and aimware_menu:IsActive()
    end

    if is_menu_open then
        if not is_dragging then
            menu_x = kt_x:GetValue() or 960
            menu_y = kt_y:GetValue() or 600
        end
    else
        menu_x = kt_x:GetValue() or 960
        menu_y = kt_y:GetValue() or 600
    end

    if not menu_enabled then return end

    local local_player = entities_GetLocalPlayer() or entities_GetLocalPawn()
    if not local_player then
        reset_system_state()
        return
    end

    local time_left = tempo_expire_time - real_time
    if time_left < 0.001 or time_left > menu_duration then time_left = 0.0 end

    local is_timer_ended = false
    if not is_timer_active or time_left <= 0.001 then
        time_left = 0.0
        is_timer_ended = true
    end

    local is_alert_triggered = menu_limit_active and (current_kill_count >= menu_limit)
    local is_faded_mode = (current_kill_count == 0) and is_timer_ended

    -- Extra Safety 
    if menu_extra_safety then
        local should_disable_rage = (not is_timer_ended and current_kill_count > 0) or is_alert_triggered
        if should_disable_rage then
            if not last_rage_override then
                gui_SetValue("rbot.enable", false)
                last_rage_override = true
            end
        else
            if last_rage_override then
                gui_SetValue("rbot.enable", true)
                last_rage_override = false
            end
        end
    else
        if last_rage_override then
            gui_SetValue("rbot.enable", true)
            last_rage_override = false
        end
    end


    local target_width = 170
    local target_offset = 0 
    if is_alert_triggered then
        target_width = 490
        target_offset = 160 
    elseif current_kill_count > 0 and not is_timer_ended then
        target_width = 190
    end

    if animated_width ~= target_width then
        local delta_w = target_width - animated_width
        animated_width = animated_width + delta_w * 0.15
        if math_abs(delta_w) < 0.1 then animated_width = target_width end
    end

    if animated_offset ~= target_offset then
        local delta_o = target_offset - animated_offset
        animated_offset = animated_offset + delta_o * 0.15
        if math_abs(delta_o) < 0.1 then animated_offset = target_offset end
    end

    local render_x
    if is_alert_triggered then
        local compensation_delta = 0
        if menu_x < 160 then compensation_delta = 160 - menu_x end
        render_x = math_floor(menu_x - animated_offset + compensation_delta)
    else
        render_x = math_floor(menu_x)
    end
    
    local box_w = math_floor(animated_width)
    local box_h, radius = 36, 10

    -- drag and drop things
    if is_menu_open and menu_draggable then
        local mouse_x, mouse_y = input_GetMousePos()
        local is_mouse_down = input_IsButtonDown(1)

        if is_mouse_down then
            if not is_dragging then
                if mouse_x >= render_x and mouse_x <= (render_x + box_w) and
                   mouse_y >= menu_y and mouse_y <= (menu_y + box_h) then
                    is_dragging = true
                    drag_offset_x = mouse_x - menu_x
                    drag_offset_y = mouse_y - menu_y
                end
            else
                local new_x = mouse_x - drag_offset_x
                local new_y = mouse_y - drag_offset_y
                
                if math_floor(new_x) ~= math_floor(menu_x) or math_floor(new_y) ~= math_floor(menu_y) then
                    menu_x = new_x
                    menu_y = new_y
                    kt_x:SetValue(math_floor(menu_x))
                    kt_y:SetValue(math_floor(menu_y))
                end
            end
        else
            is_dragging = false
        end
    else
        is_dragging = false
    end

    local r, g, b
    local alert_alpha_modifier = 255

    if is_alert_triggered then
        local pulse = math_sin(real_time * 8.0)
        r = math_floor(pulse * 60 + 195) 
        g = math_floor((pulse + 1) * 15) 
        b = 20
        alert_alpha_modifier = math_floor(pulse * 100 + 155)
    elseif current_kill_count >= 5 and not is_timer_ended then 
        r, g, b = 255, 40, 40 
    else 
        local dynamic_time = real_time * 4.0
        r = math_floor(math_sin(dynamic_time) * 40 + 215)
        g = math_floor(math_sin(dynamic_time + 2.0) * 40 + 100)
        b = math_floor(math_sin(dynamic_time + 4.0) * 40 + 50)
    end

    local alpha_bg = is_faded_mode and 120 or 240
    local alpha_neon = is_alert_triggered and alert_alpha_modifier or (is_faded_mode and 35 or 130)
    local alpha_text = is_faded_mode and 90 or 255

    draw_Color(r, g, b, is_faded_mode and 3 or (is_alert_triggered and 25 or 15))
    draw_RoundedRectFill(render_x - 3, menu_y - 3, render_x + box_w + 3, menu_y + box_h + 3, radius + 1)
    
    draw_Color(12, 13, 16, alpha_bg)
    draw_RoundedRectFill(render_x, menu_y, render_x + box_w, menu_y + box_h, radius)

    draw_Color(r, g, b, alpha_neon)
    draw_RoundedRect(render_x, menu_y, render_x + box_w, menu_y + box_h, radius)

    if is_dragging then
        draw_Color(r, g, b, 80)
        draw_RoundedRect(render_x - 5, menu_y - 5, render_x + box_w + 5, menu_y + box_h + 5, radius)
    end

    if is_alert_triggered then
        draw.SetFont(FONT_WARNING)
        draw_Color(255, 60, 60, alert_alpha_modifier)
        draw_Text(render_x + 14, menu_y + 7, WARNING_ICON_STR)

        local start_bar_x = render_x + 12
        local max_bar_w = box_w - 24
        draw_Color(40, 45, 55, 100)
        draw_FilledRect(start_bar_x, menu_y + box_h - 7, start_bar_x + max_bar_w, menu_y + box_h - 4)
        
        draw_Color(r, g, b, alert_alpha_modifier)
        draw_FilledRect(start_bar_x, menu_y + box_h - 7, start_bar_x + max_bar_w, menu_y + box_h - 4)
    else
        draw.SetFont(FONT_SESSION)

        draw_Color(245, 248, 255, alpha_text)
        draw_Text(render_x + 12, menu_y + 7, cached_kill_string)

        local time_check_step = math_floor(time_left * 10)
        local cached_time_string = TIME_STRINGS[time_check_step] or "0.0s"
        local txt_w = (time_check_step >= 100) and 34 or 27
        
        if is_timer_ended then draw_Color(140, 145, 155, alpha_text - 20) else draw_Color(r, g, b, 255) end
        draw_Text(render_x + box_w - txt_w - 12, menu_y + 7, cached_time_string)

        local start_bar_x = render_x + 12
        local max_bar_w = box_w - 24
        
        draw_Color(40, 45, 55, is_faded_mode and 30 or 100)
        draw_FilledRect(start_bar_x, menu_y + box_h - 7, start_bar_x + max_bar_w, menu_y + box_h - 4)

        if not is_timer_ended then
            local current_bar_w = math_floor(max_bar_w * math_max(0.0, math_min(time_left / menu_duration, 1.0)))
            if current_bar_w > 0 then
                draw_Color(r, g, b, 220)
                draw_FilledRect(start_bar_x, menu_y + box_h - 7, start_bar_x + current_bar_w, menu_y + box_h - 4)
            end
        end
    end
end)
