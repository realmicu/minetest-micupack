
--[[

	Tubelib Biogas Burn Mod
	=======================

	Copyright (C) 2018 Michal Cieslakiewicz

	LGPLv2.1+
	See LICENSE.txt for more information

	smelter.lua
	
	Biogas-fuelled burner that smelts and cookes like standard furnace
	
]]--


minetest.register_node("biogasmachines:smelter", {
	description = "Tubelib Biogas Smelter",
	tiles = {
		-- up, down, right, left, back, front
		"biogasmachines_smelter_top.png",
		"tubelib_front.png",
		"tubelib_front.png",
		"tubelib_front.png",
		"tubelib_front.png",
		"tubelib_front.png",
	},

	paramtype = "light",
	sunlight_propagates = true,
	paramtype2 = "facedir",
	groups = {choppy=2, cracky=2, crumbly=2},
	is_ground_content = false,
	sounds = default.node_sound_wood_defaults(),
})
