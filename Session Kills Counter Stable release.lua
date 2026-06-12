print("Session Kills Counter - Stable release Loaded")

-- Localize Hệ Thống Tuyệt Đối (Triệt tiêu hoàn toàn Global Lookup / Absolute System Localization)
local math_floor, math_sin, math_max, math_min, math_abs = math.floor, math.sin, math.max, math.min, math.abs
local string_format = string.format
local globals_RealTime = globals.RealTime
local gui_GetValue = gui.GetValue
local draw_Color, draw_RoundedRect, draw_RoundedRectFill, draw_FilledRect, draw_Text = draw.Color, draw.RoundedRect, draw.RoundedRectFill, draw.FilledRect, draw.Text
local entities_GetLocalPlayer, entities_GetLocalPawn = entities.GetLocalPlayer, entities.GetLocalPawn

-- ==========================================
-- 1. INTERFACE GUI (GIAO DIỆN NGƯỜI DÙNG)
-- ==========================================
local wnd = gui.Window("skc_window", "Session Kills Counter", 300, 300, 350, 310)
local init_menukey = gui_GetValue("adv.menukey")
if init_menukey and init_menukey ~= 0 then wnd:SetOpenKey(init_menukey) end

local group_controls = gui.Groupbox(wnd, "Configuration", 15, 15, 320, 240)
local skc_enable = gui.Checkbox(group_controls, "skc_enable", "Enable Kills Counter", true)
local skc_duration = gui.Slider(group_controls, "skc_duration", "Max Tempo Duration (s)", 5.0, 1.0, 15.0, 0.5)

local skc_limit_enable = gui.Checkbox(group_controls, "skc_limit_enable", "Enable Kill Limit Notification", true)
local skc_limit = gui.Slider(group_controls, "skc_limit", "Round Kill Limit", 5, 1, 5, 1)

local skc_x = gui.Slider(group_controls, "skc_x", "Indicator X", 960, 0, 3840, 1)
local skc_y = gui.Slider(group_controls, "skc_y", "Indicator Y", 600, 0, 2160, 1)

local FONT_SESSION = draw.CreateFont("Segoe UI", 12, 700)
local FONT_WARNING = draw.CreateFont("Segoe UI", 11, 700)

-- ==========================================
-- PRE-CACHE MATHEMATICS (TOÁN HỌC TÍNH TOÁN TRƯỚC / ZERO-ALLOCATION)
-- ==========================================
local TIME_STRINGS = {}
for i = 0, 160 do
    TIME_STRINGS[i] = string_format("%.1fs", i / 10)
end

-- Bộ chuỗi tĩnh lưu sẵn TEXT ĐẾM MẠNG ROUND KILLS (Static Array for Render String Optimization)
local KILLS_STRINGS_WITH_LIMIT = {}
local KILLS_STRINGS_NO_LIMIT = {}
for k = 0, 50 do
    KILLS_STRINGS_NO_LIMIT[k] = string_format("ROUND KILLS: %d", k)
    KILLS_STRINGS_WITH_LIMIT[k] = {}
    for l = 1, 5 do
        KILLS_STRINGS_WITH_LIMIT[k][l] = string_format("ROUND KILLS: %d / %d", k, l)
    end
end

-- ==========================================
-- 2. BIẾN TRẠNG THÁI / STATE VARIABLES (RAM STORAGE)
-- ==========================================
local tempo_expire_time = 0.0
local current_kill_count = 0
local is_timer_active = false
local animated_width = 170
local animated_offset = 0 
local aimware_menu = gui.Reference("MENU")

local menu_enabled = true
local menu_duration = 5.0
local menu_limit_active = true
local menu_limit = 5
local menu_x, menu_y = 960, 600

local cached_kill_string = "ROUND KILLS: 0 / 5"
local WARNING_ICON_STR = "\xE2\x9A\xA0 !!!YOU HAVE REACHED YOUR KILLS LIMIT, LET YOUR TEAMMATES DO THE REST!!!"

local bit_band = (bit and bit.band) or (bit32 and bit32.band)
local function handle_to_index(h)
    if not h or h == 0 or h == 0xFFFFFFFF then return 0 end
    if h < 0 then h = h + 4294967296 end
    if bit_band then return bit_band(h, 0x7FFF) end
    return h % 0x8000
end

local function reset_system_state()
    tempo_expire_time = 0.0
    current_kill_count = 0
    is_timer_active = false
    animated_width = 170
    animated_offset = 0
    if menu_limit_active then
        cached_kill_string = KILLS_STRINGS_WITH_LIMIT[0][menu_limit] or "ROUND KILLS: 0 / 5"
    else
        cached_kill_string = KILLS_STRINGS_NO_LIMIT[0] or "ROUND KILLS: 0"
    end
end

-- ==========================================
-- 3. EVENTS
-- ==========================================
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
            
            if menu_limit_active then
                local sub_table = KILLS_STRINGS_WITH_LIMIT[current_kill_count]
                cached_kill_string = sub_table and sub_table[menu_limit] or "ROUND KILLS: 0 / 5"
            else
                cached_kill_string = KILLS_STRINGS_NO_LIMIT[current_kill_count] or "ROUND KILLS: 0"
            end
        end
    end
end)

-- ==========================================
-- 4. VẼ / GRAPHICS 
-- ==========================================
callbacks.Register("Draw", function()
    local is_menu_open = aimware_menu and aimware_menu:IsActive()

    if is_menu_open then
        menu_enabled = skc_enable:GetValue()
        menu_duration = skc_duration:GetValue() or 5.0
        menu_limit_active = skc_limit_enable:GetValue()
        menu_limit = skc_limit:GetValue() or 5
        menu_x = skc_x:GetValue() or 960
        menu_y = skc_y:GetValue() or 600
        
        -- DYNAMIC GUI OPTIMIZATION: Tự động ẩn Slider chọn số mạng nếu tắt Notification
        skc_limit:SetInvisible(not menu_limit_active)

        if menu_limit_active then
            local sub_table = KILLS_STRINGS_WITH_LIMIT[current_kill_count]
            cached_kill_string = sub_table and sub_table[menu_limit] or "ROUND KILLS: 0 / 5"
        else
            cached_kill_string = KILLS_STRINGS_NO_LIMIT[current_kill_count] or "ROUND KILLS: 0"
        end
        
        local current_menukey = gui_GetValue("adv.menukey")
        if current_menukey and current_menukey ~= 0 then wnd:SetOpenKey(current_menukey) end
    end

    if not menu_enabled then return end

    local local_player = entities_GetLocalPlayer() or entities_GetLocalPawn()
    if not local_player then
        reset_system_state()
        return
    end

    local real_time = globals_RealTime()
    local time_left = tempo_expire_time - real_time
    
    if time_left < 0.001 or time_left > menu_duration then time_left = 0.0 end

    local is_timer_ended = false
    if not is_timer_active or time_left <= 0.001 then
        time_left = 0.0
        is_timer_ended = true
    end

    local is_alert_triggered = menu_limit_active and (current_kill_count >= menu_limit)
    local is_faded_mode = (current_kill_count == 0) and is_timer_ended

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

    -- BÙ TRỪ BIÊN CHO MÀN HÌNH LỀ TRÁI / LEFT BORDER COMPENSATION LOGIC
    local render_x
    if is_alert_triggered then
        local compensation_delta = 0
        if menu_x < 160 then
            compensation_delta = 160 - menu_x
        end
        render_x = math_floor(menu_x - animated_offset + compensation_delta)
    else
        render_x = math_floor(menu_x)
    end
    
    local box_w = math_floor(animated_width)
    local box_h, radius = 36, 10

    -- PHỐI MÀU NHẤP NHÁY CHỚP STROBE / COLOR STROBE MANAGEMENT
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

    local alpha_bg = is_faded_mode and 140 or 240
    local alpha_neon = is_alert_triggered and alert_alpha_modifier or (is_faded_mode and 40 or 130)
    local alpha_text = is_faded_mode and 100 or 255

    -- RENDER KHỐI HÌNH HỌC / GEOMETRY RENDERING LAYER
    draw_Color(r, g, b, is_faded_mode and 5 or (is_alert_triggered and 25 or 15))
    draw_RoundedRectFill(render_x - 3, menu_y - 3, render_x + box_w + 3, menu_y + box_h + 3, radius + 1)
    
    draw_Color(12, 13, 16, alpha_bg)
    draw_RoundedRectFill(render_x, menu_y, render_x + box_w, menu_y + box_h, radius)

    draw_Color(r, g, b, alpha_neon)
    draw_RoundedRect(render_x, menu_y, render_x + box_w, menu_y + box_h, radius)

    -- RENDERING TEXT & PROGRESS BAR (IN CHỮ VÀ TIẾN TRÌNH THEO ĐIỀU KIỆN)
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
        
        if is_timer_ended then draw_Color(140, 145, 155, 100) else draw_Color(r, g, b, 255) end
        draw_Text(render_x + box_w - txt_w - 12, menu_y + 7, cached_time_string)

        local start_bar_x = render_x + 12
        local max_bar_w = box_w - 24
        
        draw_Color(40, 45, 55, is_faded_mode and 40 or 100)
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