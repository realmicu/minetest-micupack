
--[[

	Portable Mineral Finder v2.0

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
local cur_stone_idx = 1
local ore_stones = { "default:stone_with_coal",
		     "default:stone_with_iron",
		     "default:stone_with_copper",
		     "default:stone_with_tin",
		     "default:stone_with_gold",
		     "default:stone_with_mese",
		     "default:stone_with_diamond" }
if minetest.get_modpath("moreores") then
	ore_stones[#ore_stones + 1] = "moreores:mineral_silver"
	ore_stones[#ore_stones + 1] = "moreores:mineral_mithril"
end

-- scan for selected ore in front of device
function mineralfinder.scan_for_mineral(itemstack, user, pointed_thing)
	local player_name = user:get_player_name()
	local head_pos = vector.add(vector.round(user:getpos()),
			 minertools.head_vec)
	local look_dir = user:get_look_dir()  -- normalized vec (x,y,z = -1..1)
	minertools.mineralfinder_use("MineralFinder", player_name, head_pos,
				     look_dir, scan_range,
				     ore_stones[cur_stone_idx])
	return nil
end

function mineralfinder.change_mineral_type(itemstack, user_placer, pointed_thing)
	local player_name = user_placer:get_player_name()
	cur_stone_idx = minertools.mineralfinder_switch_ore("MineralFinder",
				player_name, ore_stones, cur_stone_idx)
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

