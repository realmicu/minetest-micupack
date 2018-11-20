
--[[

	=======================================================================
	Tubelib Biogas Machines Mod
	by Micu (c) 2018

	Copyright (C) 2018 Michal Cieslakiewicz
	
	Biogas-fuelled burner that smelts and cookes like standard furnace
	TODO: be more descriptive

	License: LGPLv2.1+
	=======================================================================
	
]]--

-- Coal block burn time is 370, our Gasifier produces 9 Biogas units from it,
-- so let 1 Biogas burn for 40 sec (9 * 40 = 360)

minetest.register_node("biogasmachines:gasfurnace", {
	description = "Tubelib Biogas Furnace",
	tiles = {
		-- up, down, right, left, back, front
		"biogasmachines_gasfurnace_top.png",
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

-- TODO: put machine code here
