
--[[

	Portable Mineral Scanner v1.0

	Scans cube around player with specified range and
	provides feedback with ore quantity.
	Notice: area scanned is cube (2 * range + 1) not sphere

	Left click - scan and show results
	Right click - change scan range

]]--

-- ************************
-- Namespaces and variables
-- ************************

local mineralscanner = {}
local tool_range = 0
local scan_range_min = 1
local scan_range_max = 8
local scan_range = scan_range_min
local msg_white = minetest.get_color_escape_sequence("#FFFFFF")
local msg_yellow = minetest.get_color_escape_sequence("#FFFF00")
local msg_zero = minetest.get_color_escape_sequence("#00FFFF")
local msg_plus = minetest.get_color_escape_sequence("#FF00FF")
local ore_list = {}
ore_list["default:stone_with_coal"] = "coal"
ore_list["default:stone_with_iron"] = "iron"
ore_list["default:stone_with_copper"] = "copper"
ore_list["default:stone_with_tin"] = "tin"
ore_list["default:stone_with_gold"] = "gold"
ore_list["default:stone_with_mese"] = "mese"
ore_list["default:stone_with_diamond"] = "diamond"
ore_list["default:obsidian"] = "obsidian"
if minetest.get_modpath("moreores") then
	ore_list["moreores:mineral_silver"] = "silver"
	ore_list["moreores:mineral_mithril"] = "mithril"
end
local ore_stones = {}
for i, _ in pairs(ore_list) do
	ore_stones[#ore_stones + 1] = i
end

-- ****************
-- Helper functions
-- ****************

-- produce sound
local function sound_scan(player_name)
	minetest.sound_play("minertools_scan", {
		to_player = player_name,
		gain = 0.8,
	})
end

local function sound_range(player_name)
	minetest.sound_play("minertools_click", {
		to_player = player_name,
		gain = 0.6,
	})
end

-- scan for ores with center at current player position
function mineralscanner.scan_for_minerals(itemstack, user, pointed_thing)
	local player_name = user:get_player_name()
	local player_pos = vector.round(user:getpos())
	local scan_vec = vector.new({x = scan_range, y = scan_range,
		z = scan_range})
	local scan_pos1 = vector.subtract(player_pos, scan_vec)
	local scan_pos2 = vector.add(player_pos, scan_vec)
	local _, minerals = minetest.find_nodes_in_area(scan_pos1, scan_pos2, ore_stones)
	local oremsg = ""
	for orenode, orecount in pairs(minerals) do
		local oms = ore_list[orenode] .. " = " .. orecount
		if orecount == 0 then oms = msg_zero .. oms
		else oms = msg_plus .. oms end
		if oremsg ~= "" then
			oremsg = oremsg .. msg_white .. ", " .. oms
		else
			oremsg = oms
		end
	end
	sound_scan(player_name)
	minetest.chat_send_player(player_name,
		msg_yellow .. "[MineralScanner]" .. msg_white ..
		" Scan results for cubic range " .. scan_range ..
		" : " .. oremsg .. msg_white)
	return nil
end

function mineralscanner.change_scan_range(itemstack, user_placer, pointed_thing)
	local player_name = user_placer:get_player_name()
	sound_range(player_name)
	scan_range = scan_range + 1
	if scan_range > scan_range_max then
		scan_range = scan_range_min
	end
	minetest.chat_send_player(player_name,
		msg_yellow .. "[MineralScanner]" .. msg_white ..
		" Scan range set to " .. msg_zero .. scan_range ..
		msg_white)
	return nil
end

-- *************
-- Register Tool
-- *************

minetest.register_tool("minertools:mineral_scanner", {
	description = "Portable Mineral Scanner",
	wield_image = "minertools_mineralscanner_hand.png",
	wield_scale = { x = 1, y = 1, z = 1 },
	inventory_image = "minertools_mineralscanner_inv.png",
	stack_max = 1,
	range = tool_range,
	on_use = mineralscanner.scan_for_minerals,
	on_place = mineralscanner.change_scan_range,
	on_secondary_use = mineralscanner.change_scan_range,
})

-- ************
-- Craft Recipe
-- ************

minetest.register_craft({
	output = "minertools:mineral_scanner",
	type = "shaped",
	recipe = {
		{ "default:steel_ingot", "default:steel_ingot", "default:steel_ingot" },
		{ "default:mese_crystal", "default:gold_ingot", "default:mese_crystal" },
		{ "default:copper_ingot", "minertools:mining_chip", "default:copper_ingot" },
	},
})

