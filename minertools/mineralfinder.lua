
--[[

	Portable Mineral Finder v1.0

	Short range directional radar that detects
	presence of selected ore in front of device.
	Notice: obsidian blocks signal so area behind
	it remains unexplored.
	Node position calculation by multiplying directional
	normalized vector is susceptible to rounding
	errors, so device has limited range to preserve
	acceptable accuracy. More accurate methods involve
	numerical complexity (Bresenham for example) so
	IMHO its better to follow KISS principle.

	Left click - scan
	Right click - change mineral type

]]--

-- ************************
-- Namespaces and variables
-- ************************

local mineralfinder = {}
local tool_range = 4
local scan_range = 5
local msg_white = minetest.get_color_escape_sequence("#FFFFFF")
local msg_yellow = minetest.get_color_escape_sequence("#FFFF00")
local msg_warn = minetest.get_color_escape_sequence("#FF8080")
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
if minetest.get_modpath("moreores") then
	ore_list["moreores:mineral_silver"] = "silver"
	ore_list["moreores:mineral_mithril"] = "mithril"
end
local cur_stone_idx = 1
local ore_stones = {}
for i, _ in pairs(ore_list) do
	ore_stones[#ore_stones + 1] = i
	if i == "default:stone_with_coal" then
		cur_stone_idx = #ore_stones
	end
end
local head_vec = vector.new({x = 0, y = 1, z = 0})

-- scan for selected ore in front of device
function mineralfinder.scan_for_mineral(itemstack, user, pointed_thing)
	local player_name = user:get_player_name()
	local head_pos = vector.add(vector.round(user:getpos()), head_vec)
	local look_dir = user:get_look_dir()  -- normalized vec (x,y,z = -1..1)
	local orecount, obsblock, _ = minertools.dir_mineral_scan(head_pos,
					scan_range, look_dir,
					ore_stones[cur_stone_idx])
	local oremsg = ""
	if orecount > 0 then oremsg = msg_plus
	else oremsg = msg_zero end
	oremsg = oremsg .. orecount
	if obsblock then
		oremsg = oremsg .. msg_warn ..
			 " (warning - scan incomplete, blocked by obsidian)"
	end
	minertools.play_pulse(player_name)
	minetest.chat_send_player(player_name,
		msg_yellow .. "[MineralFinder]" .. msg_white ..
		" Scan result for " .. msg_zero ..
		ore_list[ore_stones[cur_stone_idx]] ..
		msg_white .. " : " ..
		oremsg .. msg_white)
	return nil
end

function mineralfinder.change_mineral_type(itemstack, user_placer, pointed_thing)
	local player_name = user_placer:get_player_name()
	minertools.play_click(player_name)
	cur_stone_idx = cur_stone_idx + 1
	if cur_stone_idx > #ore_stones then
		cur_stone_idx = 1
	end
	minetest.chat_send_player(player_name,
		msg_yellow .. "[MineralFinder]" .. msg_white ..
		" Mineral type set to " .. msg_zero ..
		ore_list[ore_stones[cur_stone_idx]] ..  msg_white)
	return nil
end

-- *************
-- Register Tool
-- *************

minetest.register_tool("minertools:mineral_finder", {
	description = "Portable Mineral Finder",
	wield_image = "minertools_mineralfinder_hand.png",
	wield_scale = { x = 1, y = 1, z = 1 },
	inventory_image = "minertools_mineralfinder_inv.png",
	stack_max = 1,
	range = tool_range,
	on_use = mineralfinder.scan_for_mineral,
	on_place = mineralfinder.change_mineral_type,
	on_secondary_use = mineralfinder.change_mineral_type,
})

-- ************
-- Craft Recipe
-- ************

minetest.register_craft({
	output = "minertools:mineral_finder",
	type = "shaped",
	recipe = {
		{ "default:steel_ingot", "default:gold_ingot", "default:steel_ingot" },
		{ "default:gold_ingot", "default:mese_crystal", "default:gold_ingot" },
		{ "default:copper_ingot", "minertools:mining_chip", "default:copper_ingot" },
	},
})

