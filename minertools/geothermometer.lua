
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
local msg_white = minetest.get_color_escape_sequence("#FFFFFF")
local msg_hot = minetest.get_color_escape_sequence("#FFC0C0")
local msg_cold = minetest.get_color_escape_sequence("#C0C0FF")
local msg_yellow = minetest.get_color_escape_sequence("#FFFF00")

-- calculate and show relative temperature
function geothermometer.show_rel_temp(itemstack, user, pointed_thing)
	if pointed_thing.type ~= "node" then return nil end
	local player_name = user:get_player_name()
	local node_pos = vector.new(pointed_thing.under)
	if not minertools.is_mineral(minetest.get_node(node_pos).name) then
		minertools.play_beep_err(player_name)
		return nil
	end
	local temp_var = minertools.calculate_rel_temp(node_pos, scan_range)
	minertools.play_beep_ok(player_name)
	local msg_val_clr = msg_white
	if temp_var < 0 then msg_val_clr = msg_cold
	elseif temp_var > 0 then msg_val_clr = msg_hot
	end
	minetest.chat_send_player(player_name,
		msg_yellow .. "[Geothermometer]" .. msg_white ..
		" Temperature gradient for this block is " ..
		msg_val_clr .. string.format("%+.4f", temp_scale * temp_var) ..
		msg_white)
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

