
--[[

	Tubelib Biogas Burn
	===================

	Copyright (C) 2018 Michal Cieslakiewicz

	LGPLv2.1+
	See LICENSE.txt for more information

	gasifier.lua
	
	Converts Coal Blocks to Biogas
	
]]--


minetest.register_node("biogasmachines:gasifier", {
	description = "Tubelib Coal Gasifier",
	tiles = {
		-- up, down, right, left, back, front
		"biogasmachines_gasifier_top.png",
		"tubelib_front.png",
		"tubelib_front.png",
		"tubelib_front.png",
		"tubelib_front.png",
		"tubelib_front.png",
	},
	drawtype = "nodebox",
	node_box = {
		type = "fixed",
		fixed = {
			{-0.5, -0.5, -0.5, 0.5, 0.5, -0.375},
			{-0.5, -0.5, 0.375, 0.5, 0.5, 0.5},
			{-0.5, -0.5, -0.5, -0.375, 0.5, 0.5},
			{0.375, -0.5, -0.5, 0.5, 0.5, 0.5},
			{-0.375, -0.5, -0.375, 0.375, 0.375, 0.375},
		},
	},
	selection_box = {
                type = "fixed",
                fixed = {-0.5, -0.5, -0.5,   0.5, 0.5, 0.5},
        },

	paramtype = "light",
	sunlight_propagates = true,
	paramtype2 = "facedir",
	groups = {choppy=2, cracky=2, crumbly=2},
	is_ground_content = false,
	sounds = default.node_sound_wood_defaults(),
})

