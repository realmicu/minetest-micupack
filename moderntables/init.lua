-- This mod adds modern IKEA-like tables
-- (c) Micu 2018
-- Node Box Editor, version 0.9.0

-- ******************************
-- Global namespace for functions
-- ******************************

moderntables = {}

-- ****************
-- Helper functions
-- ****************

-- subname (string) is one of: acacia_wood, aspen_wood, junglewood,
-- pine_wood, wood
function moderntables.register_simple_wood_table(subname, description)
	local fullname = "moderntables:simple_table_" .. subname
	minetest.register_node(fullname, {
		description = description,
		tiles = { "default_" .. subname .. ".png", },
		drawtype = "nodebox",
		node_box = {
			type = "fixed",
			fixed = {
				{-0.5, 0.375, -0.5, 0.5, 0.5, 0.5},
				{-0.5, -0.5, -0.5, -0.375, 0.375, -0.375},
				{0.375, -0.5, -0.5, 0.5, 0.375, -0.375},
				{0.375, -0.5, 0.375, 0.5, 0.375, 0.5},
				{-0.5, -0.5, 0.375, -0.375, 0.375, 0.5},
			}
		},
		selection_box = {
			type = "fixed",
			fixed = {-0.5, -0.5, -0.5,   0.5, 0.5, 0.5},
		},
		paramtype = "light",
        	paramtype2 = "facedir",
        	place_param2 = 0,
        	is_ground_content = false,
        	groups = { choppy = 2, oddly_breakable_by_hand = 2,
			flammable = 2, },
        	sounds = default.node_sound_wood_defaults(),
	})
	local slabitem = "stairs:slab_" .. subname
	local wooditem = "default:" .. subname
	minetest.register_craft({
		output = fullname,
		recipe = {
			{ slabitem, slabitem, slabitem },
			{ wooditem, "", wooditem },
			{ wooditem, "", wooditem },
		},
	})
end


-- ****************************
-- Register objects and recipes
-- ****************************

moderntables.register_simple_wood_table("acacia_wood", "Simple Acacia Wood Table")
moderntables.register_simple_wood_table("aspen_wood", "Simple Aspen Wood Table")
moderntables.register_simple_wood_table("junglewood", "Simple Junglewood Table")
moderntables.register_simple_wood_table("pine_wood", "Simple Pine Wood Table")
moderntables.register_simple_wood_table("wood", "Simple Wood Table")

