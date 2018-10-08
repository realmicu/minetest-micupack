
--[[

	Common functions for devices in this mod.

]]--

minertools = {}

-- *********
-- Constants
-- *********

-- colors
local msg_white = minetest.get_color_escape_sequence("#FFFFFF")
local msg_yellow = minetest.get_color_escape_sequence("#FFFF00")
local msg_warn = minetest.get_color_escape_sequence("#FF8080")
local msg_zero = minetest.get_color_escape_sequence("#00FFFF")
local msg_plus = minetest.get_color_escape_sequence("#FF00FF")
local msg_hot = minetest.get_color_escape_sequence("#FFC0C0")
local msg_cold = minetest.get_color_escape_sequence("#C0C0FF")
local msg_high = minetest.get_color_escape_sequence("#52D017")
local msg_medium = minetest.get_color_escape_sequence("#EAC117")
local msg_low = minetest.get_color_escape_sequence("#E56717")

-- mineral labels (for display)
local mineral_label = {}
mineral_label["default:stone_with_coal"] = "coal"
mineral_label["default:stone_with_iron"] = "iron"
mineral_label["default:stone_with_copper"] = "copper"
mineral_label["default:stone_with_tin"] = "tin"
mineral_label["default:stone_with_gold"] = "gold"
mineral_label["default:stone_with_mese"] = "mese"
mineral_label["default:stone_with_diamond"] = "diamond"
mineral_label["default:obsidian"] = "obsidian"
if minetest.get_modpath("moreores") then
        mineral_label["moreores:mineral_silver"] = "silver"
        mineral_label["moreores:mineral_mithril"] = "mithril"
end

-- public constants
minertools.head_vec = vector.new({x = 0, y = 1, z = 0})
minertools.dbl_click_us = 1000 * (tonumber(minetest.settings:get(
			  "minertools_double_click_ms")) or 300)

-- ****************
-- Helper functions
-- ****************

-- sounds
local function play_beep_ok(player_name)
	minetest.sound_play("minertools_beep_ok", {
		to_player = player_name,
		gain = 0.8,
	})
end
local function play_beep_err(player_name)
	minetest.sound_play("minertools_beep_err", {
		to_player = player_name,
		gain = 0.5,
	})
end
local function play_scan(player_name)
	minetest.sound_play("minertools_scan", {
		to_player = player_name,
		gain = 0.8,
	})
end
local function play_click(player_name)
	minetest.sound_play("minertools_click", {
		to_player = player_name,
		gain = 0.6,
	})
end
local function play_pulse(player_name)
	minetest.sound_play("minertools_pulse", {
		to_player = player_name,
		gain = 0.8,
	})
end
local function play_toggle(player_name)
	minetest.sound_play("minertools_toggle", {
		to_player = player_name,
		gain = 0.6,
	})
end

-- check if node is of type that device can scan
-- (only nodes of natural origin can be analyzed properly)
local function is_mineral(name)
	if name == nil then return false end
	if minetest.get_item_group(name, "sand") > 0 then return true end
	if minetest.get_item_group(name, "soil") > 0 then return true end
	if minetest.get_item_group(name, "stone") > 0 then return true end
	if string.match(name, "^default:stone_with_") then return true end
	if name == "default:gravel"
		or name == "default:clay" then return true end
	if minetest.get_modpath("moreores") then
		if string.match(name, "^moreores:mineral_") then
			return true
		end
	end
	return false
end

-- check if node is made of obsidian
local function has_obsidian(name)
	if name == nil then return false end
	if string.match(name, "^default:obsidian") then return true end
	if minetest.get_modpath("stairs") then  -- part of minetest game now
		if string.match(name, "^stairs:stair_obsidian") or
		   string.match(name, "^stairs:slab_obsidian") then
			return true
		end
	end
	return false
end

-- ************
-- Calculations
-- ************

-- calculate relative temperature (aka gradient based on thermal sources nearby)
-- return: temperature gradient
local function calculate_rel_temp(pos, radius)
	local scan_vec = vector.new({x = radius, y = radius, z = radius})
	local scan_pos1 = vector.subtract(pos, scan_vec)
	local scan_pos2 = vector.add(pos, scan_vec)
	local water = minetest.find_nodes_in_area(scan_pos1, scan_pos2,
		{ "group:water" })
	local lava = minetest.find_nodes_in_area(scan_pos1, scan_pos2,
		{ "group:lava" })
	local temp_var = 0.0
	for _, v in ipairs(water) do
		local vd = vector.distance(pos, v)
		if vd <= radius then
			temp_var = temp_var - 1 / ( vd * vd )
		end
	end
	for _, v in ipairs(lava) do
		local vd = vector.distance(pos, v)
		if vd <= radius then
			temp_var = temp_var + 1 / ( vd * vd )
		end
	end
	return temp_var
end

-- directional scan for specified mineral
-- parameters:	pos - device position (vector)
-- 		range - scan depth (float)
-- 		look_dir - direction of looking (normalized vector)
--		name - ore to search for (string)
-- return: mineral count, blocked by obsidian true/false, closest ore distance
local function dir_mineral_scan(pos, range, look_dir, name)
	local node = {}
	local pos_vec = {}
	local last_vec = nil
	local orecount = 0
	local obsblock = false
	local oredepth = 0
	for i = 1, range, 1 do
		pos_vec = vector.add(pos, vector.round(vector.multiply(look_dir, i)))
                if not last_vec or not vector.equals(pos_vec, last_vec) then
			node = minetest.get_node_or_nil(pos_vec)
			if node then
				if node.name == name then
					orecount = orecount + 1
					if oredepth == 0 then oredepth = i end
				elseif has_obsidian(node.name) then
					obsblock = true
					break
				end
			end
			last_vec = pos_vec  -- protects against double count
		end
	end
	return orecount, obsblock, oredepth
end

-- scan for ores in cubic area
-- parameters:	pos - device position (vector)
-- 		range - scan max range (float)
-- 		nodes - node names to search for (array)
-- return: mineral table (keys - node names, values - node count)
local function area_mineral_scan(pos, range, nodes)
        local scan_vec = vector.new({x = range, y = range, z = range})
        local scan_pos1 = vector.subtract(pos, scan_vec)
        local scan_pos2 = vector.add(pos, scan_vec)
        local _, minerals = minetest.find_nodes_in_area(scan_pos1, scan_pos2, nodes)
        return minerals
end


-- ***************
-- Display helpers
-- ***************

function minertools.print_mineral_type_set_to(label, player_name, stone_name)
	minetest.chat_send_player(player_name,
		msg_yellow .. "[" .. label .. "]" .. msg_white ..
		" Mineral type set to " .. msg_zero ..
		mineral_label[stone_name] ..  msg_white)
end
function minertools.print_scan_range_set_to(label, player_name, scan_range)
	minetest.chat_send_player(player_name,
		msg_yellow .. "[" .. label .. "]" ..
		msg_white .. " Scan range set to "
		.. msg_zero .. scan_range .. msg_white)
end
function minertools.print_mineral_type_is_now(label, player_name, stone_name)
	minetest.chat_send_player(player_name,
		msg_yellow .. "[" .. label .. "]" .. msg_white ..
		" Mineral type is now " .. msg_zero ..
		mineral_label[stone_name] ..  msg_white)
end
function minertools.print_scan_range_is_now(label, player_name, scan_range)
	minetest.chat_send_player(player_name,
		msg_yellow .. "[" .. label .. "]" ..
		msg_white .. " Scan range is now "
		.. msg_zero .. scan_range .. msg_white)
end

-- *******
-- Modules
-- *******

-- geothermometer
-- parameters:	label - device name in chat (string)
-- 		player_name - owner of device (string)
-- 		node_pos - pointed node position (vector)
-- 		radius - area of heat calculation (number)
-- 		scale - scaling factor (number)
-- 		temp_fmt - format of display (string, default "%+.4f")
function minertools.geothermometer_use(label, player_name, node_pos,
				       radius, scale, temp_fmt)
	if not is_mineral(minetest.get_node(node_pos).name) then
		play_beep_err(player_name)
		return nil
	end
	local strfmt = "%+.4f"
	if temp_fmt then strfmt = temp_fmt end
	local temp_var = calculate_rel_temp(node_pos, radius)
	play_beep_ok(player_name)
	local msg_val_clr = msg_white
	if temp_var < 0 then msg_val_clr = msg_cold
	elseif temp_var > 0 then msg_val_clr = msg_hot end
        minetest.chat_send_player(player_name,
                msg_yellow .. "[" .. label .. "]" .. msg_white ..
                " Temperature gradient for this block is " ..
                msg_val_clr .. string.format(strfmt, scale * temp_var) ..
                msg_white)
        return nil
end

-- mineral finder
-- parameters:	label - device name in chat (string)
-- 		player_name - owner of device (string)
-- 		head_pos - player head position (vector)
-- 		look_dir - player looking direction (vector)
-- 		range - depth of scanning (number)
-- 		stone_name - name of ore node to search for (string)
-- 		disp_detail - show ore distance (0-none, 1-H/M/L, 2-percentage)
function minertools.mineralfinder_use(label, player_name, head_pos, look_dir,
				      range, stone_name, disp_detail)
	if not mineral_label[stone_name] then return nil end
	local rangeshow = 0
	if disp_detail then rangeshow = disp_detail end
	local orecount, obsblock, oredepth = dir_mineral_scan(head_pos,
						range, look_dir,
						stone_name)
	local oremsg = ""
	if orecount > 0 then oremsg = msg_plus
	else oremsg = msg_zero end
	oremsg = oremsg .. orecount
	if oredepth > 0 then
		if rangeshow == 1 then
			oremsg = oremsg .. msg_white .. " (signal strength: "
			if oredepth <= range / 3 then
				oremsg = oremsg .. msg_high .. "HIGH"
			elseif oredepth > range * 2 / 3 then
				oremsg = oremsg .. msg_low .. "LOW"
			else oremsg = oremsg .. msg_medium .. "MEDIUM" end
			oremsg = oremsg .. msg_white .. ")"
		elseif rangeshow == 2 then
			oremsg = oremsg .. msg_white .. " (signal strength: "
			local sigpct = 100.0 * (range - oredepth + 1) / range
			if sigpct >= 75 then oremsg = oremsg .. msg_high
			elseif sigpct < 25 then oremsg = oremsg .. msg_low
			else oremsg = oremsg .. msg_medium end
			oremsg = oremsg .. string.format("%d%%", sigpct) ..
				 msg_white .. ")"
		end
	end
	if obsblock then
		oremsg = oremsg .. msg_warn ..
			 " (warning - scan incomplete, blocked by obsidian)"
	end
	play_pulse(player_name)
	minetest.chat_send_player(player_name,
		msg_yellow .. "[" .. label .. "]" .. msg_white ..
		" Scan result for " .. msg_zero ..
		mineral_label[stone_name] ..  msg_white ..
		" : " .. oremsg .. msg_white)
        return nil
end

-- mineral scanner
-- parameters:	label - device name in chat (string)
-- 		player_name - owner of device (string)
-- 		player_pos - player position (vector)
-- 		range - cubic range of scanning (number)
-- 		stones_list - minerals to scan for (table)
function minertools.mineralscanner_use(label, player_name, player_pos,
				       range, stones_list)
	local minerals = area_mineral_scan(player_pos, range, stones_list)
	local oremsg = ""
	for orenode, orecount in pairs(minerals) do
		if mineral_label[orenode] then
			local oms = mineral_label[orenode] .. " = " .. orecount
			if orecount == 0 then oms = msg_zero .. oms
			else oms = msg_plus .. oms end
			if oremsg ~= "" then
				oremsg = oremsg .. msg_white .. ", " .. oms
			else oremsg = oms end
		end
	end
	play_scan(player_name)
	minetest.chat_send_player(player_name,
		msg_yellow .. "[" .. label .. "]" .. msg_white ..
		" Scan results for cubic range " .. range ..
		" : " .. oremsg .. msg_white)
        return nil
end

-- ************
-- Module modes
-- ************

-- mineral finder - change ore type
-- parameters:	label - device name in chat (string)
-- 		player_name - owner of device (string)
-- 		stones_list - known minerals (table)
-- 		stone_index - current index in stones_list (number)
-- return:	new ore index
function minertools.mineralfinder_switch_ore(label, player_name,
			stones_list, stone_index)
	play_click(player_name)
	local new_stone_idx = (stone_index % #stones_list) + 1
	minertools.print_mineral_type_set_to(label, player_name,
		stones_list[new_stone_idx])
	return new_stone_idx
end

-- mineral scanner - change scan range
-- parameters:	label - device name in chat (string)
-- 		player_name - owner of device (string)
-- 		player_pos - player position (vector)
-- 		min_range - minimal range of scanning (number)
-- 		max_range - maximal range of scanning (number)
-- 		range - current range of scanning (number)
-- return:	new range
function minertools.mineralscanner_switch_range(label, player_name,
			min_range, max_range, range)
	play_click(player_name)
	local new_range = range - 1
        if new_range < min_range then
                new_range = max_range
        end
	minertools.print_scan_range_set_to(label, player_name, new_range)
        return new_range
end


-- ****************
-- Computer helpers
-- ****************

-- play click and display new mode
function minertools.computer_mode_change_notify(label, player_name, mode_name)
	play_toggle(player_name)
	minetest.chat_send_player(player_name,
		msg_yellow .. "[" .. label .. "]" .. msg_white ..
		" Switching mode to " .. msg_yellow ..
		mode_name .. msg_white)
	return nil
end

-- revert last change, used by double-click routine (AMA, UMG)
function minertools.computer_mf_revert_ore_change(label, player_name,
			stones_list, stone_index)
	local new_stone_idx = stone_index - 1
	if new_stone_idx < 1 then new_stone_idx = #stones_list end
	minetest.chat_send_player(player_name,
		msg_yellow .. "[" .. label .. "]" .. msg_white ..
		" Changing back to " .. msg_zero ..
		mineral_label[stones_list[new_stone_idx]] ..
		msg_white .. " and saving")
	return new_stone_idx
end
function minertools.computer_ms_revert_range_change(label, player_name,
			min_range, max_range, range)
	local new_range = range + 1
	if new_range > max_range then
		new_range = min_range
	end
	minetest.chat_send_player(player_name,
		msg_yellow .. "[" .. label .. "]" .. msg_white ..
		" Changing back to range " .. msg_zero .. new_range ..
		msg_white .. " and saving")
	return new_range
end

-- flashlight, should be used with wielded_light mod for effect
function minertools.flashlight_use(label, player_name,
		item_name, light_flag)
	play_click(player_name)
	local new_light_on = not light_flag
	local lightsw = "OFF"
	local lightlvl = 0
	if new_light_on then
		lightsw = "ON"
		lightlvl = default.LIGHT_MAX
	end
	minetest.override_item(item_name, { light_source = lightlvl })
	minetest.chat_send_player(player_name,
		msg_yellow .. "[" .. label .. "]" .. msg_white ..
		" Switching flashlight to " .. msg_zero ..
		lightsw .. msg_white)
	return new_light_on
end
