
--[[

	Geothermometer device v1.0

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

-- ****************
-- Helper functions
-- ****************

-- check if node is of type that device can scan
-- (only nodes of natural origin can be analyzed properly)
local function is_mineral(name)
	if name == nil then return false end
	if minetest.get_item_group(name, "sand") > 0 then return true end
	if minetest.get_item_group(name, "soil") > 0 then return true end
	if minetest.get_item_group(name, "stone") > 0 then return true end
	if string.match(name, "^default:stone_with_") then return true end
	if minetest.get_modpath("moreores") then
		if string.match(name, "^moreores:mineral_") then
			return true
		end
	end
	return false
end

-- calculate and show relative temperature
function geothermometer.show_rel_temp(itemstack, user, pointed_thing)
	if pointed_thing.type ~= "node" then return nil end
	local node_pos = vector.new(pointed_thing.under)
	if not is_mineral(minetest.get_node(node_pos).name) then return nil end
	local player_name = user:get_player_name()
	local scan_vec = vector.new({x = scan_range, y = scan_range,
		z = scan_range})
	local scan_pos1 = vector.subtract(node_pos, scan_vec)
	local scan_pos2 = vector.add(node_pos, scan_vec)
	local water = minetest.find_nodes_in_area(scan_pos1, scan_pos2,
		{ "group:water" })
	local lava = minetest.find_nodes_in_area(scan_pos1, scan_pos2,
		{ "group:lava" })
	local temp_var = 0.0
	for _, v in ipairs(water) do
		local vd = vector.distance(node_pos, v)
		if vd <= scan_range then 
			temp_var = temp_var - 1 / ( vd * vd )
		end
	end
	for _, v in ipairs(lava) do
		local vd = vector.distance(node_pos, v)
		if vd <= scan_range then 
			temp_var = temp_var + 1 / ( vd * vd )
		end
	end
	minetest.chat_send_player(player_name,
		"[Geothermometer] Temperature gradient for this block is " ..
		string.format("%+.4f", temp_scale * temp_var))
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

