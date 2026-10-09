--[[
What's new in v2.0?
    FIXES: 
    -removed indicator in main menu
    -added teamkill filter - no longer count kills [for tks]
    -Now notification panel and text look much cleaner overall

    NEW FEATURES:
    Legitbot category:
    -added "Auto disable Legitbot on limit"
    -added "Disable auto stop in air" 
    -added "Disbale Nospread/Seed in air"
  # And i also separated them into 2 parts, one for kill timer indicator and the other one will be disabler things
]]

--https://aimware.net/forum/thread/181362--
--https://aimware.net/forum/user/650402/reputation
print("Kill Timer v2.0 loaded!")
print("youtube.com/@url.isp2")
print("discord: chillguy_2345")
print("please give me a like and subcribe to my youtube channel if you like this lua")
print("thank ya so much, hope you enjoy this lua^^")

local f, sin, max, min = math.floor, math.sin, math.max, math.min
local fmt = string.format
local get_time = globals.RealTime
local get_val, set_val = gui.GetValue, gui.SetValue
local drawclr, rrect, rrectfill, rect, drawtxt = draw.Color, draw.RoundedRect, draw.RoundedRectFill, draw.FilledRect, draw.Text
local get_pawn = entities.GetLocalPawn
local get_mouse, is_down = input.GetMousePos, input.IsButtonDown
local band = (bit and bit.band) or (bit32 and bit32.band)

local wtypes = {"shared", "pistol", "hpistol", "smg", "rifle", "shotgun", "scout", "sniper", "asniper", "lmg"}

--1. UI
local wnd = gui.Window("kt_wnd", "Kill Timer", 200, 200, 660, 400)
local key = get_val("adv.menukey")
if key and key ~= 0 then wnd:SetOpenKey(key) end

local gb1 = gui.Groupbox(wnd, "Kill Timer Settings", 15, 15, 305, 340)
local cfg_enable  = gui.Checkbox(gb1, "kt_en", "Enable Kill Timer Indicator", true)
local cfg_dur     = gui.Slider(gb1, "kt_dur", "Max Tempo Duration (s)", 5.0, 0, 15.0, 0.5)
local cfg_lim_en  = gui.Checkbox(gb1, "kt_lim_en", "Enable Kill Limit Notification", true)
local cfg_lim     = gui.Slider(gb1, "kt_lim", "Round Kill Limit", 5, 1, 5, 1)
local cfg_x       = gui.Slider(gb1, "kt_x", "Indicator X", 430, 0, 3840, 1)
local cfg_y       = gui.Slider(gb1, "kt_y", "Indicator Y", 500, 0, 2160, 1)
local cfg_drag    = gui.Checkbox(gb1, "kt_drag", "Draggable Indicator", false)

local gb2 = gui.Groupbox(wnd, "Ragebot Safety Disabler", 335, 15, 305, 125)
local cfg_rage_safe = gui.Checkbox(gb2, "kt_r_safe", "Auto Disable On Limit", false)
local cfg_rage_jump = gui.Checkbox(gb2, "kt_r_jump", "  |--- Jump check", false)

local gb3 = gui.Groupbox(wnd, "Legitbot Safety Disabler", 335, 150, 305, 205)
local cfg_legit_safe = gui.Checkbox(gb3, "kt_l_safe", "Auto Disable Legitbot On Limit", false)
local cfg_air_stop   = gui.Checkbox(gb3, "kt_air_stop", "Disable Auto Stop In Air", false)
local cfg_air_spread = gui.Checkbox(gb3, "kt_air_spread", "Disable Nospread/Seed In Air", false)

local font_main = draw.CreateFont("Segoe UI", 12, 700)
local font_warn = draw.CreateFont("Segoe UI", 11, 700)
local font_icon = draw.CreateFont("Segoe UI", 15, 900)
local menu_ref  = gui.Reference("MENU")

--2.state
local state = { expire = 0.0, kills = 0, active = false, width = 170, offset = 0 }
local drag  = { x = 0, y = 0, active = false }
local cache = { rage = false, orig_r = nil, legit = false, orig_lt = nil, orig_la = nil, stop = false, orig_stop = {}, spread = false, orig_spread = {} }

local ICON_WARN = "\xE2\x9A\xA0"
local TEXT_WARN = "YOU HAVE REACHED YOUR KILL LIMIT, LET YOUR TEAMMATES DO THE REST!"

local function ingame()
    local pawn = get_pawn()
    return pawn and pawn:GetHealth() > 0 and (pawn:GetTeamNumber() == 2 or pawn:GetTeamNumber() == 3)
end

local function restore_state()
    if cache.rage then
        if cache.orig_r ~= nil then set_val("rbot.enable", cache.orig_r) end
        cache.rage, cache.orig_r = false, nil
    end
    if cache.legit then
        if cache.orig_lt ~= nil then set_val("lbot.trg.enable", cache.orig_lt) end
        if cache.orig_la ~= nil then set_val("lbot.aim.enable", cache.orig_la) end
        cache.legit, cache.orig_lt, cache.orig_la = false, nil, nil
    end
    if cache.stop then
        for _, w in ipairs(wtypes) do
            if cache.orig_stop[w] ~= nil then set_val("lbot.weapon.accuracy." .. w .. ".stop", cache.orig_stop[w]) end
        end
        cache.stop, cache.orig_stop = false, {}
    end
    if cache.spread then
        for _, w in ipairs(wtypes) do
            if cache.orig_spread[w] ~= nil then set_val("lbot.trg.weapon." .. w .. ".antispreadtype", cache.orig_spread[w]) end
        end
        cache.spread, cache.orig_spread = false, {}
    end
end

local function reset_state()
    state.expire, state.kills, state.active = 0.0, 0, false
    state.width, state.offset = 170, 0
    restore_state()
end

local function update_visibility()
    cfg_lim:SetInvisible(not cfg_lim_en:GetValue())
    cfg_rage_jump:SetInvisible(not cfg_rage_safe:GetValue())
end
update_visibility()

--3.events
local evts = { "player_death", "round_start" }
for i = 1, #evts do client.AllowListener(evts[i]) end

callbacks.Register("FireGameEvent", function(e)
    if not e or not ingame() then return end
    local name = e:GetName()

    if name == "round_start" then
        reset_state()
    elseif name == "player_death" then
        local atk = e:GetInt("attacker_pawn")
        local vic = e:GetInt("userid_pawn")
        if atk == 0 or atk == 0xFFFFFFFF or atk == vic then return end

        local me = get_pawn()
        if me then
            local atkid = band(atk < 0 and atk + 4294967296 or atk, 0x7FFF)
            if atkid == me:GetIndex() then
                local vicid = band(vic < 0 and vic + 4294967296 or vic, 0x7FFF)
                local vicpawn = entities.GetByIndex(vicid)
                if vicpawn and vicpawn:GetTeamNumber() ~= me:GetTeamNumber() then
                    state.kills = state.kills + 1
                    state.expire = get_time() + cfg_dur:GetValue()
                    state.active = true
                    state.width = 140
                end
            end
        end
    end
end)

-- 4.Main 
callbacks.Register("CreateMove", function()
    if not cfg_enable:GetValue() or not ingame() then
        restore_state()
        return
    end

    local me = get_pawn()
    if not me then return end

    local flags = me:GetFieldInt("m_fFlags")
    local on_ground = flags and band(flags, 1) ~= 0 or false

    -- Legit auto stop
    if cfg_air_stop:GetValue() and not on_ground then
        if not cache.stop then
            for _, w in ipairs(wtypes) do
                local path = "lbot.weapon.accuracy." .. w .. ".stop"
                local v = get_val(path)
                if v ~= nil then cache.orig_stop[w] = v; set_val(path, false) end
            end
            cache.stop = true
        end
    elseif cache.stop then
        for _, w in ipairs(wtypes) do
            if cache.orig_stop[w] ~= nil then set_val("lbot.weapon.accuracy." .. w .. ".stop", cache.orig_stop[w]) end
        end
        cache.stop, cache.orig_stop = false, {}
    end

    -- legit ns
    if cfg_air_spread:GetValue() and not on_ground then
        if not cache.spread then
            for _, w in ipairs(wtypes) do
                local path = "lbot.trg.weapon." .. w .. ".antispreadtype"
                local v = get_val(path)
                if v ~= nil then cache.orig_spread[w] = v; set_val(path, 0) end
            end
            cache.spread = true
        end
    elseif cache.spread then
        for _, w in ipairs(wtypes) do
            if cache.orig_spread[w] ~= nil then set_val("lbot.trg.weapon." .. w .. ".antispreadtype", cache.orig_spread[w]) end
        end
        cache.spread, cache.orig_spread = false, {}
    end

    -- ahhh toggle
    local now = get_time()
    local t_left = state.expire - now
    local timer_ended = not state.active or t_left <= 0.001
    local alert = cfg_lim_en:GetValue() and (state.kills >= cfg_lim:GetValue())

    -- rage disabler
    local r_disabler = (cfg_rage_safe:GetValue() and ((not timer_ended and state.kills > 0) or alert)) or (cfg_rage_jump:GetValue() and not on_ground)
    if r_disabler ~= cache.rage then
        if r_disabler then
            cache.orig_r = get_val("rbot.enable")
            set_val("rbot.enable", false)
        else
            if cache.orig_r ~= nil then set_val("rbot.enable", cache.orig_r) end
            cache.orig_r = nil
        end
        cache.rage = r_disabler
    end

    -- legit disabler
    local l_disabler = cfg_legit_safe:GetValue() and ((not timer_ended and state.kills > 0) or alert)
    if l_disabler ~= cache.legit then
        if l_disabler then
            cache.orig_lt, cache.orig_la = get_val("lbot.trg.enable"), get_val("lbot.aim.enable")
            set_val("lbot.trg.enable", false); set_val("lbot.aim.enable", false)
        else
            if cache.orig_lt ~= nil then set_val("lbot.trg.enable", cache.orig_lt) end
            if cache.orig_la ~= nil then set_val("lbot.aim.enable", cache.orig_la) end
            cache.orig_lt, cache.orig_la = nil, nil
        end
        cache.legit = l_disabler
    end
end)

-- 5.render
callbacks.Register("Draw", function()
    local menu_open = menu_ref and menu_ref:IsActive()

    if menu_open then
        update_visibility()
        local k = get_val("adv.menukey")
        if k and k ~= 0 then wnd:SetOpenKey(k) end
    end

    if not ingame() then
        if cache.rage or cache.legit or cache.stop or cache.spread or state.active or state.kills > 0 then
            reset_state()
        end
        return
    end

    if not cfg_enable:GetValue() then return end

    local now = get_time()
    local mx, my = cfg_x:GetValue() or 430, cfg_y:GetValue() or 500
    local dur = cfg_dur:GetValue() or 5.0
    local lim = cfg_lim:GetValue() or 5
    local lim_en = cfg_lim_en:GetValue()

    local t_left = state.expire - now
    if t_left < 0.001 or t_left > dur then t_left = 0.0 end

    local timer_ended = not state.active or t_left <= 0.001
    local alert = lim_en and (state.kills >= lim)
    local faded = (state.kills == 0) and timer_ended

    -- alert text
    draw.SetFont(font_warn)
    local tw = draw.GetTextSize(TEXT_WARN)
    draw.SetFont(font_icon)
    local iw = draw.GetTextSize(ICON_WARN)

    local inner_w = iw + 6 + tw + 6 + iw
    local total_w = inner_w + 24

    -- animation abcxyz
    local base_w = (state.kills > 0 and not timer_ended) and 190 or 170
    local target_w = alert and total_w or base_w
    local target_off = alert and f((total_w - base_w) / 2) or 0

    state.width = state.width + (target_w - state.width) * 0.15
    state.offset = state.offset + (target_off - state.offset) * 0.15

    local rx = alert and f(mx - state.offset + (mx < state.offset and state.offset - mx or 0)) or f(mx)
    local ry = f(my)
    local bw, bh = f(state.width), 36

    -- dragging
    if menu_open and cfg_drag:GetValue() then
        local cur_x, cur_y = get_mouse()
        if is_down(1) then
            if not drag.active then
                if cur_x >= rx and cur_x <= (rx + bw) and cur_y >= ry and cur_y <= (ry + bh) then
                    drag.active = true
                    drag.x, drag.y = cur_x - mx, cur_y - my
                end
            else
                cfg_x:SetValue(f(cur_x - drag.x))
                cfg_y:SetValue(f(cur_y - drag.y))
            end
        else drag.active = false end
    else drag.active = false end

    -- colors & indicator
    local r, g, b, alpha
    if alert then
        local pulse = sin(now * 8.0)
        r, g, b = f(pulse * 60 + 195), f((pulse + 1) * 15), 20
        alpha = f(pulse * 100 + 155)
    elseif state.kills >= 5 and not timer_ended then
        r, g, b, alpha = 255, 40, 40, 130
    else
        local t = now * 4.0
        r, g, b = f(sin(t) * 40 + 215), f(sin(t + 2.0) * 40 + 100), f(sin(t + 4.0) * 40 + 50)
        alpha = faded and 35 or 130
    end

    drawclr(r, g, b, faded and 3 or (alert and 25 or 15))
    rrectfill(rx - 3, ry - 3, rx + bw + 3, ry + bh + 3, 11)

    drawclr(12, 13, 16, faded and 120 or 240)
    rrectfill(rx, ry, rx + bw, ry + bh, 10)

    drawclr(r, g, b, alpha)
    rrect(rx, ry, rx + bw, ry + bh, 10)

    if alert then
        local start_x = rx + f((bw - inner_w) / 2)

        draw.SetFont(font_icon); drawclr(255, 205, 0, alpha); drawtxt(start_x, ry + 5, ICON_WARN)
        draw.SetFont(font_warn); drawclr(255, 75, 75, alpha); drawtxt(start_x + iw + 6, ry + 8, TEXT_WARN)
        draw.SetFont(font_icon); drawclr(255, 205, 0, alpha); drawtxt(start_x + iw + 6 + tw + 6, ry + 5, ICON_WARN)

        drawclr(r, g, b, alpha); rect(rx + 12, ry + bh - 7, rx + bw - 12, ry + bh - 4)
    else
        draw.SetFont(font_main); drawclr(245, 248, 255, faded and 90 or 255)
        local k_str = lim_en and fmt("ROUND KILLS: %d / %d", state.kills, lim) or fmt("ROUND KILLS:  %d", state.kills)
        drawtxt(rx + 12, ry + 7, k_str)

        local t_str = fmt("%.1fs", t_left)
        drawclr(timer_ended and 140 or r, timer_ended and 145 or g, timer_ended and 155 or b, faded and 90 or 255)
        drawtxt(rx + bw - (#t_str > 4 and 34 or 27) - 12, ry + 7, t_str)

        drawclr(40, 45, 55, faded and 30 or 100)
        rect(rx + 12, ry + bh - 7, rx + bw - 12, ry + bh - 4)

        if not timer_ended then
            local fill_w = f((bw - 24) * max(0.0, min(t_left / dur, 1.0)))
            if fill_w > 0 then
                drawclr(r, g, b, 220)
                rect(rx + 12, ry + bh - 7, rx + 12 + fill_w, ry + bh - 4)
            end
        end
    end
end)

callbacks.Register("Unload", restore_state)
