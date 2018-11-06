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
	local above = nil
	local below = nil
	if pipe_con.top then
		above = minetest.get_node_or_nil(
			vector.add(pos, { x = 0, y = 1, z = 0 }))
	end
	if pipe_con.bottom then
		below = minetest.get_node_or_nil(
			vector.add(pos, { x = 0, y = -1, z = 0 }))
	end
	-- try to detect connected pipes, valves etc. with water:
	-- 0. normal pipes at top or bottom (they will attach automatically)
	if (above and string.match(above.name, "^pipeworks:pipe_.*_loaded")) or
	   (below and string.match(below.name, "^pipeworks:pipe_.*_loaded")) then
		return true
	end
	-- 1. straight vertical pipes, valves and sensors
	if (above and above.param2 == 17 and
	     (above.name == "pipeworks:straight_pipe_loaded" or
	      above.name == "pipeworks:entry_panel_loaded" or
	      above.name == "pipeworks:valve_on_loaded" or
	      above.name == "pipeworks:flow_sensor_loaded")) or
	   (below and below.param2 == 17 and
	     (below.name == "pipeworks:straight_pipe_loaded" or
	      below.name == "pipeworks:entry_panel_loaded" or
	      below.name == "pipeworks:valve_on_loaded" or
	      below.name == "pipeworks:flow_sensor_loaded")) then
		return true
	end
	return false
end

