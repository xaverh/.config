#!/usr/bin/lua

local mode = {arg = arg[1] or "--focus", name = string.sub(arg[1],3)}

local panel_fg_color = os.getenv("PANEL_FG_COLOR") or "#424242"
local panel_bg_color = os.getenv("PANEL_BG_COLOR") or "#F9F8F4"
local font = os.getenv("PANEL_XFT_FONT") or "SGI Screen:pixelsize=14"

local query = io.popen("bspc query -N -n .window")
local ids = {}
for line in query:lines("l") do
	local query = io.popen("xdotool getwindowname " .. line)
	local name = query:read("l")
	local instance = name
	local i = 0
	if ids[instance] then
		i = i + 1
		instance = name .. " - " .. i
	end
	ids[instance] = line
	query:close()
end
query:close()

local dmenu_input = "/bin/sh -c 'echo \""
for k, v in pairs(ids) do
	dmenu_input = dmenu_input .. string.gsub(k, "'", "'\\''") .. '\n'
end
dmenu_input = dmenu_input .. "\" | dmenu -i -f -l 10 -p \"" .. mode.name .. "\" -fn \"" .. font .."\" -nb \"" .. panel_bg_color .. "\" -nf \"" .. panel_fg_color .. "\"'"
print(dmenu_input)

local dmenu = io.popen(dmenu_input)
local window_title = dmenu:read("l")
dmenu:close()
os.execute("bspc node " .. mode.arg .. " " .. ids[window_title])
