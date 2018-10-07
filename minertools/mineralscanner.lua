
--[[

	Portable Mineral Scanner v2.0

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
local scan_range = scan_range_max
local ore_stones = { "default:stone_with_coal",
                     "default:stone_with_iron",
                     "default:stone_with_copper",
                     "default:stone_with_tin",
                     "default:stone_with_gold",
                     "default:stone_with_mese",
                     "default:stone_with_diamond",
		     "default:obsidian" }
if minetest.get_modpath("moreores") then
        ore_stones[#ore_stones + 1] = "moreores:mineral_silver"
        ore_stones[#ore_stones + 1] = "moreores:mineral_mithril"
end

-- scan for ores with center at current player position
function mineralscanner.scan_for_minerals(itemstack, user, pointed_thing)
	local player_name = user:get_player_name()
	local player_pos = vector.round(user:getpos())
	minertools.mineralscanner_use("MineralScanner", player_name, player_pos,
                                       scan_range, ore_stones)
	return nil
end

function mineralscanner.change_scan_range(itemstack, user_placer, pointed_thing)
	local player_name = user_placer:get_player_name()
	scan_range = minertools.mineralscanner_switch_range("MineralScanner",
			player_name, scan_range_min, scan_range_max, scan_range)
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

