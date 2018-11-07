--[[

	=======================================================================
	Tubelib Biogas Machines Mod
	by Micu (c) 2018

	Copyright (C) 2018 Michal Cieslakiewicz

	Freezer - Biogas-powered machine that converts water to ice
	(technically Biogas is a coolant here, not fuel, however it
	is 'used' in the same way). Device changes water in bucket
	to ice and empty bucket. If pipeworks mod is installed and pipe
	with water is connected to device, in absence of water buckets
	it produces ice from water supplied via pipes.
	Device automatically shuts off when there is nothing to freeze,
	so Biogas is not wasted.

	Note: due to pipeworks being WIP, the only valid water connections
	for now are from top and bottom (see waterpipes.lua).

	License: LGPLv2.1+
	=======================================================================
	
]]--

minetest.register_node("biogasmachines:freezer", {
	description = "Tubelib Water Freezer",
	tiles = {
		-- up, down, right, left, back, front
		"tubelib_front.png",
		"tubelib_front.png",
		"tubelib_front.png",
		"tubelib_front.png",
		"tubelib_front.png",
		"default_ice.png",
	},

	paramtype = "light",
	sunlight_propagates = true,
	paramtype2 = "facedir",
	groups = {choppy = 2, cracky = 2, crumbly = 2},
	is_ground_content = false,
	sounds = default.node_sound_metal_defaults(),

	pipe_connections = { top = 1, bottom = 1 },

	after_place_node = function(pos, placer, itemstack, pointed_thing)
		local node = minetest.get_node(pos)
		local meta = minetest.get_meta(pos)
		local number = tubelib.add_node(pos, "biogasmachines:freezer")
		local inv = meta:get_inventory()
		inv:set_size('src', 9)
		inv:set_size('fuel', 1)
		inv:set_size('dst', 18)
		local label = minetest.registered_nodes[node.name].description
		meta:set_string("number", number)
		meta:set_string("owner", placer:get_player_name())
		meta:set_string("infotext", label .. " " .. number .. ": stopped")
		--meta:set_string("formspec", formspec(tubelib.STOPPED))
		if minetest.get_modpath("pipeworks") then
			pipeworks.scan_for_pipe_objects(pos)
		end
	end,

	after_dig_node = function(pos, oldnode, oldmetadata, digger)
		tubelib.remove_node(pos)
		if minetest.get_modpath("pipeworks") then
			pipeworks.scan_for_pipe_objects(pos)
		end
	end,

	on_rotate = screwdriver.disallow,

	on_punch = function(pos, node, puncher, pointed_thing)
		local meta = minetest.get_meta(pos)
		local player_name = puncher:get_player_name()
		if meta:get_string("owner") ~= player_name then
			return false
		end
		minetest.chat_send_player(player_name,
			minetest.colorize("#FFFF00", "[BiogasFreezer:" ..
			meta:get_string("number") .. "] ") ..
			(biogasmachines.is_pipe_with_water(pos, node)
			and "Water flows" or "No water"))
		return true
	end,

})

