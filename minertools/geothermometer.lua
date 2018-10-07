
--[[

	Geothermometer device v2.0

	Principle of calculations:
	heat energy dissipates with square distance from source (twice the distance
	four times less heat)
	Works only on "natural" blocks like dirt, stone, sand and ores

	Calculations explained:
	* initial block temperature variation = 0.0
	* find all water blocks in range, count them and find distance from block,
	  then change temperature adding -sum(1/d^2)
	* find all lava blocks in range, count them and find distance from block,
	  then change temperature adding +sum(1/d^2)
	* resulting value shows how nearby water or lava affects block temperature
	* scale it by chosen factor to amplify differences

]]--

-- ************************
-- Namespaces and variables
-- ************************

local geothermometer = {}
local tool_range = 8
local scan_range = 10
local temp_scale = 50.0

-- calculate and show relative temperature
function geothermometer.show_rel_temp(itemstack, user, pointed_thing)
	if pointed_thing.type ~= "node" then return nil end
	local player_name = user:get_player_name()
	local node_pos = vector.new(pointed_thing.under)
	minertools.geothermometer_use("Geothermometer", player_name,
				      node_pos, scan_range, temp_scale)
	return nil
end

-- *************
-- Register Tool
-- *************

minetest.register_tool("minertools:geothermometer", {
	description = "Geothermometer",
	wield_image = "minertools_geothermometer_hand.png",
	wield_scale = { x = 1, y = 1, z = 2 },
	inventory_image = "minertools_geothermometer_inv.png",
	stack_max = 1,
	range = tool_range,
	on_use = geothermometer.show_rel_temp
})

-- ************
-- Craft Recipe
-- ************

minetest.register_craft({
	output = "minertools:geothermometer",
	type = "shaped",
	recipe = {
		{ "default:steel_ingot", "default:diamond", "default:steel_ingot" },
		{ "default:steel_ingot", "default:mese_crystal", "default:steel_ingot" },
		{ "default:steel_ingot", "minertools:mining_chip", "default:steel_ingot" },
	},
})

