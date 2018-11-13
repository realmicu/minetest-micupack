--[[

	=======================================================================
	Tubelib Biogas Machines Mod
	by Micu (c) 2018

	Copyright (C) 2018 Michal Cieslakiewicz

	Helper file for all machines that accept water through pipes from
	'pipeworks' mod.

	Note: due to pipeworks being WIP, the only valid water connection
	for now is from top or bottom - machine face orientation is apparently
	ignored by pipe logic, 'back' for pipes means always param2 = 0 (z+).

	License: LGPLv2.1+
	=======================================================================
	
]]--

-- all pipeworks objects that can carry water but are not junctions
local pipeworks_straight_objects = {
	"pipeworks:straight_pipe_loaded",
	"pipeworks:entry_panel_loaded",
	"pipeworks:valve_on_loaded",
	"pipeworks:flow_sensor_loaded" }

--[[
	------
	Public
	------
]]--

-- check if node is in array
function biogasmachines.is_member_of(name, array)
        for _, n in ipairs(array) do
                if n == name then return true end
        end
        return false
end

-- Check if machine is connected to pipe network and water flows into machine
-- Parameters: node position, node object (optional)
-- Returns: true if water is flowing into device node
function biogasmachines.is_pipe_with_water(pos, opt_node)
	if not minetest.get_modpath("pipeworks") then
		return false
	end
	local node = opt_node
	if not node then
		node = minetest.get_node_or_nil(pos)
		if not node then return false end
	end
	local node_def = minetest.registered_nodes[node.name]
	if not node_def then return false end
	local pipe_con = node_def.pipe_connections
	if not pipe_con then return false end
	local ctable = {
		["top"] = { dv = { x = 0, y = 1, z = 0 }, p2 = { 17 } },
		["bottom"] = { dv = { x = 0, y = -1, z = 0 }, p2 = { 17 } },
		["front"] = { dv = { x = 0, y = 0, z = -1 }, p2 = { 0, 2 } },
		["back"] = { dv = { x = 0, y = 0, z = 1 }, p2 = { 0, 2 } },
		["left"] = { dv = { x = -1, y = 0, z = 0 }, p2 = { 1, 3 } },
		["right"] = { dv = { x = 1, y = 0, z = 0 }, p2 = { 1, 3 } },
	}
	for d, v in pairs(pipe_con) do
		if v then
			local d_node = minetest.get_node_or_nil(
				vector.add(pos, ctable[d].dv))
			if d_node and string.match(d_node.name,
				"^pipeworks:pipe_.*_loaded") then
				return true
			end
			if d_node and biogasmachines.is_member_of(
					d_node.param2, ctable[d].p2)
				and biogasmachines.is_member_of(
					d_node.name, pipeworks_straight_objects)
					then
				return true
			end
		end
	end
	return false
end

