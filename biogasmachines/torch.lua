
--[[

	=======================================================================
	Tubelib Biogas Machines Mod
	by Micu (c) 2018, 2019

	Copyright (C) 2018, 2019 Michal Cieslakiewicz

	This file contains Biogas Torch, a Biogas-powered eternal light source
	that is a modern version of standard coal torch. It shares the same 3d
	models, light parameters and placement mechanics with default torch but
	has different textures and crafting recipes.
	Additionally, it becomes a heat source when placed, removing nearby
	snow and melting down ice to water (in a 3x3 cube around torch).
	There are many flavours of Biogas Torch, depending on metal used for
	handle, but these variations have only decorational purposes.

	Code based on torch (torch.lua) - part of Minetest Game default mod.
	(c) Copyright BlockMen (2013-2015)
	(c) Copyright sofar <sofar@foo-projects.org> (2016)
	Licensed under the GNU LGPL version 2.1 or higher.

	Meshes/Models:
	CC-BY 3.0 BlockMen
	Note that the models were entirely done from scratch by sofar.

	License: LGPLv2.1+
	=======================================================================

]]--

--[[
	---------
	Variables
	---------
]]--

local materials = { "Steel", "Copper", "Tin", "Bronze" }

--[[
	-----------------
	Registration loop
	-----------------
]]--

local biogastorchnodes = {}
for _, i in ipairs(materials) do
	local m = string.lower(i)
	local basename = "biogasmachines:torch_" .. m
	local wallname = basename .. "_wall"
	local ceilname = basename .. "_ceiling"
	local baseimg = "biogasmachines_torch_" .. m .. ".png"
	local animimg = "biogasmachines_torch_" .. m .. "_flame.png"
	biogastorchnodes[#biogastorchnodes + 1] = basename
	biogastorchnodes[#biogastorchnodes + 1] = wallname
	biogastorchnodes[#biogastorchnodes + 1] = ceilname

	--[[
		-----------------
		Node registration
		-----------------
	]]--

	minetest.register_node(basename , {
		description = "Biogas " .. i .. " Torch",
		drawtype = "mesh",
		mesh = "torch_floor.obj",
		inventory_image = baseimg,
		wield_image = baseimg,
		tiles = {
			{
				image = animimg,
				animation = {
					type = "vertical_frames",
					aspect_w = 32,
					aspect_h = 32,
					length = 3.3
				},
			},
		},
		paramtype = "light",
		paramtype2 = "wallmounted",
		sunlight_propagates = true,
		walkable = false,
		liquids_pointable = false,
		light_source = 12,
		use_texture_alpha = biogasmachines.texture_alpha_mode,
		groups = { cracky = 2, dig_immediate = 3, attached_node = 1, torch = 1 },
		drop = basename,
		selection_box = {
			type = "wallmounted",
			wall_bottom = {-1/8, -1/2, -1/8, 1/8, 2/16, 1/8},
		},
		sounds = default.node_sound_metal_defaults(),
		on_place = function(itemstack, placer, pointed_thing)
			local under = pointed_thing.under
			local node = minetest.get_node(under)
			local def = minetest.registered_nodes[node.name]
			if def and def.on_rightclick and
				not (placer and placer:is_player() and
				placer:get_player_control().sneak) then
				return def.on_rightclick(under, node, placer, itemstack,
					pointed_thing) or itemstack
			end

			local above = pointed_thing.above
			local wdir = minetest.dir_to_wallmounted(vector.subtract(under, above))
			local fakestack = itemstack
			if wdir == 0 then
				fakestack:set_name(basename .. "_ceiling")
			elseif wdir == 1 then
				fakestack:set_name(basename)
			else
				fakestack:set_name(basename .. "_wall")
			end

			itemstack = minetest.item_place(fakestack, placer, pointed_thing, wdir)
			itemstack:set_name(basename)

			return itemstack
		end
	})

	minetest.register_node(wallname, {
		drawtype = "mesh",
		mesh = "torch_wall.obj",
		tiles = {
			{
				image = animimg,
				animation = {
					type = "vertical_frames",
					aspect_w = 32,
					aspect_h = 32,
					length = 3.3
				},
			},
		},
		paramtype = "light",
		paramtype2 = "wallmounted",
		sunlight_propagates = true,
		walkable = false,
		light_source = 12,
		use_texture_alpha = biogasmachines.texture_alpha_mode,
		groups = { cracky = 2, dig_immediate = 3, attached_node = 1, torch = 1, not_in_creative_inventory = 1 },
		drop = basename,
		selection_box = {
			type = "wallmounted",
			wall_side = {-1/2, -1/2, -1/8, -1/8, 1/8, 1/8},
		},
		sounds = default.node_sound_metal_defaults(),
	})

	minetest.register_node(ceilname, {
		drawtype = "mesh",
		mesh = "torch_ceiling.obj",
		tiles = {
			{
				image = animimg,
				animation = {
					type = "vertical_frames",
					aspect_w = 32,
					aspect_h = 32,
					length = 3.3
				},
			},
		},
		paramtype = "light",
		paramtype2 = "wallmounted",
		sunlight_propagates = true,
		walkable = false,
		light_source = 12,
		use_texture_alpha = biogasmachines.texture_alpha_mode,
		groups = { cracky = 2, dig_immediate = 3, attached_node = 1, torch = 1, not_in_creative_inventory = 1 },
		drop = basename,
		selection_box = {
			type = "wallmounted",
			wall_top = {-1/8, -1/16, -5/16, 1/8, 1/2, 1/8},
		},
		sounds = default.node_sound_metal_defaults(),
	})

	--[[
		--------
		Crafting
		--------
	]]--

	minetest.register_craft({
		output = basename .." 4",
		recipe = {
			{ "tubelib_addons1:biogas" },
			{ "default:" .. m .. "_ingot" },
		}
	})

	--[[
		------------------
		Model changing LBM
		------------------
	]]--

	minetest.register_lbm({
		name = basename .. "_3d",
		nodenames = { basename },
		action = function(pos, node)
			if node.param2 == 0 then
				minetest.set_node(pos, { name = ceilname,
					param2 = node.param2 })
			elseif node.param2 == 1 then
				minetest.set_node(pos, { name = basename,
					param2 = node.param2 })
			else
				minetest.set_node(pos, { name = wallname,
					param2 = node.param2 })
			end
		end
	})
end

--[[
	------------------------
	Snow and Ice melting ABM
	------------------------
]]--

-- please note that when torch is attached to a node that is melted,
-- it must be explicitly dropped via dig_node()
local coldnodes = { "default:dirt_with_snow", "default:snow", "default:snowblock", "default:ice" }
minetest.register_abm({
	label = "Biogas Torch heating",
	nodenames = biogastorchnodes,
	neighbors = coldnodes,
	interval = 5.0,
	chance = 1.0,
	catch_up = true,
	action = function(pos, node, active_object_count, active_object_count_wider)
		local attpos = vector.add(pos, minetest.wallmounted_to_dir(node.param2))
		local coldpos = minetest.find_nodes_in_area(vector.subtract(pos, 1),
			vector.add(pos, 1), coldnodes)
		local dropflag = false
		for _, i in ipairs(coldpos) do
			local n = minetest.get_node(i)
			local is_att = vector.equals(attpos, i)
			if n.name == "default:dirt_with_snow" then
				n.name = "default:dirt"
				minetest.set_node(i, n)
			elseif n.name == "default:snow" or n.name == "default:snowblock" then
				minetest.remove_node(i)
				if is_att then
					dropflag = true
				end
			elseif n.name == "default:ice" then
				n.name = "default:water_source"
				minetest.set_node(i, n)
				if is_att then
					dropflag = true
				end
			end
		end
		if dropflag then
			minetest.dig_node(pos)
		end
	end,
})
