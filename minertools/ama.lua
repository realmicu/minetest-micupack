
--[[

	Advanced Mining Assistant aka AMA v1.0

	This one is an upgraded version of PMC. Adding one
	more Mining Chip, gold circuitry and obsidian resonators
	allows PMC ranges and overall sensivity to be safely
	increased.
	Operational actions remain identical to PMC.

	Left click - scan and show results
	Right click - change scan range/searched ore
	Double right click - change device mode

]]--

-- ************************
-- Namespaces and variables
-- ************************

local ama = {}
local MODE_GEOTHERM = 1
local MODE_OREFIND = 2
local MODE_ORESCAN = 3
local mode = MODE_GEOTHERM
local mode_name = { [MODE_GEOTHERM] = "Geothermometer",
		    [MODE_OREFIND] = "Mineral Finder",
		    [MODE_ORESCAN] = "Mineral Scanner", }
local tool_range = { [MODE_GEOTHERM] = 8, [MODE_OREFIND] = 5, [MODE_ORESCAN] = 0 }
local scan_range_min = 1
local scan_range_max = 12
local scan_range = scan_range_max
local find_range = 8
local temp_range = 12
local temp_scale = 50.0
local head_vec = vector.new({x = 0, y = 1, z = 0})
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
local find_ore_list = {}
find_ore_list["default:stone_with_coal"] = "coal"
find_ore_list["default:stone_with_iron"] = "iron"
find_ore_list["default:stone_with_copper"] = "copper"
find_ore_list["default:stone_with_tin"] = "tin"
find_ore_list["default:stone_with_gold"] = "gold"
find_ore_list["default:stone_with_mese"] = "mese"
find_ore_list["default:stone_with_diamond"] = "diamond"
if minetest.get_modpath("moreores") then
	find_ore_list["moreores:mineral_silver"] = "silver"
	find_ore_list["moreores:mineral_mithril"] = "mithril"
end
local def_stone_idx = 1
local find_ore_stones = {}
for i, _ in pairs(find_ore_list) do
	find_ore_stones[#find_ore_stones + 1] = i
        if i == "default:stone_with_coal" then
                def_stone_idx = #find_ore_stones
        end
end
local cur_stone_idx = def_stone_idx
local scan_ore_list = {}
for i, n in pairs(find_ore_list) do
	scan_ore_list[i] = n
end
scan_ore_list["default:obsidian"] = "obsidian"
local scan_ore_stones = {}
for i, _ in pairs(scan_ore_list) do
	scan_ore_stones[#scan_ore_stones + 1] = i
end
local dbl_click_ms = 400
local last_rclick_ts = minetest.get_us_time()

-- activate device function
function ama.use(itemstack, user, pointed_thing)
	local player_name = user:get_player_name()
	local player_pos = vector.round(user:getpos())
	local node_pos = vector.new(pointed_thing.under)
	if mode == MODE_GEOTHERM then
		if pointed_thing.type ~= "node" then return nil end
		if not minertools.is_mineral(minetest.get_node(node_pos).name) then
			minertools.play_beep_err(player_name)
			return nil
		end
		local temp_var = minertools.calculate_rel_temp(node_pos, temp_range)
		minertools.play_beep_ok(player_name)
		local msg_val_clr = msg_white
		if temp_var < 0 then msg_val_clr = msg_cold
		elseif temp_var > 0 then msg_val_clr = msg_hot end
		minetest.chat_send_player(player_name,
			msg_yellow .. "[AMA:Geothermometer]" ..
			msg_white ..
			" Temperature gradient for this block is " ..
			msg_val_clr ..
			string.format("%+.4f", temp_scale * temp_var) ..
			msg_white)
	elseif mode == MODE_OREFIND then
		local head_pos = vector.add(vector.round(user:getpos()), head_vec)
		local look_dir = user:get_look_dir()
		local orecount, obsblock, oredepth =
			minertools.dir_mineral_scan(head_pos, find_range,
			look_dir, find_ore_stones[cur_stone_idx])
		local oremsg = ""
		if orecount > 0 then oremsg = msg_plus
		else oremsg = msg_zero end
		oremsg = oremsg .. orecount
		if oredepth > 0 then
			oremsg = oremsg .. msg_white .. " (signal strength: "
			if oredepth <= find_range / 3 then
				oremsg = oremsg .. msg_high .. "HIGH"
			elseif oredepth > find_range * 2 / 3 then
				oremsg = oremsg .. msg_low .. "LOW"
			else oremsg = oremsg .. msg_medium .. "MEDIUM" end
			oremsg = oremsg .. msg_white .. ")"
		end
		if obsblock then
			oremsg = oremsg .. msg_warn ..
			" (warning - scan incomplete, blocked by obsidian)"
		end
		minertools.play_pulse(player_name)
		minetest.chat_send_player(player_name,
			msg_yellow .. "[AMA:MineralFinder]" .. msg_white ..
			" Scan result for " .. msg_zero ..
			find_ore_list[find_ore_stones[cur_stone_idx]] ..
			msg_white .. " : " ..
			oremsg .. msg_white)
	elseif mode == MODE_ORESCAN then
		local minerals = minertools.area_mineral_scan(player_pos,
				 scan_range, scan_ore_stones)
		local oremsg = ""
		for orenode, orecount in pairs(minerals) do
			local oms = scan_ore_list[orenode] .. " = " .. orecount
			if orecount == 0 then oms = msg_zero .. oms
			else oms = msg_plus .. oms end
			if oremsg ~= "" then
				oremsg = oremsg .. msg_white .. ", " .. oms
			else
				oremsg = oms
			end
		end
		minertools.play_scan(player_name)
		minetest.chat_send_player(player_name,
			msg_yellow .. "[AMA:MineralScanner]" .. msg_white ..
			" Scan results for cubic range " .. scan_range ..
			" : " .. oremsg .. msg_white)
	end
	return nil
end

function ama.change_mode(itemstack, user_placer, pointed_thing)
	local player_name = user_placer:get_player_name()
	local rclick_ts = minetest.get_us_time()
	-- detect right double-click
	if rclick_ts - last_rclick_ts < dbl_click_ms * 1000 then
		-- mode change
		minertools.play_click(player_name)
		mode = ((mode + 1) % 3) + 1
		minetest.override_item("minertools:advanced_mining_assistant",
			{range = tool_range[mode]})
		minetest.chat_send_player(player_name,
			msg_yellow .. "[AMA]" .. msg_white ..
			" Switching mode to " .. msg_yellow ..
			mode_name[mode] .. msg_white)
		if mode == MODE_OREFIND then
			cur_stone_idx = def_stone_idx
			minetest.chat_send_player(player_name,
				msg_yellow .. "[AMA:MineralFinder]" .. msg_white ..
				" Mineral type is now " .. msg_zero ..
				find_ore_list[find_ore_stones[cur_stone_idx]] ..
				msg_white)
		elseif mode == MODE_ORESCAN then
			scan_range = scan_range_max
			minetest.chat_send_player(player_name,
				msg_yellow .. "[AMA:MineralScanner]" ..
				msg_white .. " Scan range is now "
				.. msg_zero .. scan_range .. msg_white)
		end
	else
		-- option change
		if mode == MODE_OREFIND then
			cur_stone_idx = cur_stone_idx + 1
			if cur_stone_idx > #find_ore_stones then
				cur_stone_idx = 1
			end
			minertools.play_click(player_name)
			minetest.chat_send_player(player_name,
			msg_yellow .. "[AMA:MineralFinder]" .. msg_white ..
			" Mineral type set to " .. msg_zero ..
			find_ore_list[find_ore_stones[cur_stone_idx]] ..
			msg_white)
		elseif mode == MODE_ORESCAN then
			scan_range = scan_range - 1
			if scan_range == 0 then
				scan_range = scan_range_max
			end
			minertools.play_click(player_name)
			minetest.chat_send_player(player_name,
			msg_yellow .. "[AMA:MineralScanner]" .. msg_white ..
			" Scan range set to " .. msg_zero .. scan_range ..
			msg_white)
		end
	end
	last_rclick_ts = rclick_ts
	return nil
end

-- *************
-- Register Tool
-- *************

minetest.register_tool("minertools:advanced_mining_assistant", {
	description = "Advanced Mining Assistant",
	wield_image = "minertools_ama_hand.png",
	wield_scale = { x = 1, y = 1, z = 1 },
	inventory_image = "minertools_ama_inv.png",
	stack_max = 1,
	range = tool_range[mode],
	on_use = ama.use,
	on_place = ama.change_mode,
	on_secondary_use = ama.change_mode,
})

-- ************
-- Craft Recipe
-- ************

minetest.register_craft({
	output = "minertools:advanced_mining_assistant",
	type = "shaped",
	recipe = {
		{ "default:obsidian", "default:mese_crystal", "default:obsidian" },
		{ "default:gold_ingot", "minertools:portable_mining_computer", "default:gold_ingot" },
		{ "default:obsidian", "minertools:mining_chip", "default:obsidian" },
	},
})

