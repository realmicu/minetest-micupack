
--[[

	Common functions for devices in this mod.

]]--

minertools = {}

-- ******************
-- Play sound effects
-- ******************

function minertools.play_beep_ok(player_name)
	minetest.sound_play("minertools_beep_ok", {
		to_player = player_name,
		gain = 0.8,
	})
end

function minertools.play_beep_err(player_name)
	minetest.sound_play("minertools_beep_err", {
		to_player = player_name,
		gain = 0.5,
	})
end

function minertools.play_scan(player_name)
	minetest.sound_play("minertools_scan", {
		to_player = player_name,
		gain = 0.8,
	})
end

function minertools.play_click(player_name)
	minetest.sound_play("minertools_click", {
		to_player = player_name,
		gain = 0.6,
	})
end

function minertools.play_pulse(player_name)
	minetest.sound_play("minertools_pulse", {
		to_player = player_name,
		gain = 0.8,
	})
end


-- *******************
-- Node classification
-- *******************

-- check if node is of type that device can scan
-- (only nodes of natural origin can be analyzed properly)
function minertools.is_mineral(name)
	if name == nil then return false end
	if minetest.get_item_group(name, "sand") > 0 then return true end
	if minetest.get_item_group(name, "soil") > 0 then return true end
	if minetest.get_item_group(name, "stone") > 0 then return true end
	if string.match(name, "^default:stone_with_") then return true end
	if name == "default:gravel"
		or name == "default:clay" then return true end
	if minetest.get_modpath("moreores") then
		if string.match(name, "^moreores:mineral_") then
			return true
		end
	end
	return false
end

-- check if node is made of obsidian
function minertools.has_obsidian(name)
	if name == nil then return false end
	if string.match(name, "^default:obsidian") then return true end
	if minetest.get_modpath("stairs") then  -- part of minetest game now
		if string.match(name, "^stairs:stair_obsidian") or
		   string.match(name, "^stairs:slab_obsidian") then
			return true
		end
	end
	return false
end

-- ************
-- Calculations
-- ************

-- calculate relative temperature (aka gradient based on thermal sources nearby)
-- return: temperature gradient
function minertools.calculate_rel_temp(pos, radius)
	local scan_vec = vector.new({x = radius, y = radius, z = radius})
	local scan_pos1 = vector.subtract(pos, scan_vec)
	local scan_pos2 = vector.add(pos, scan_vec)
	local water = minetest.find_nodes_in_area(scan_pos1, scan_pos2,
		{ "group:water" })
	local lava = minetest.find_nodes_in_area(scan_pos1, scan_pos2,
		{ "group:lava" })
	local temp_var = 0.0
	for _, v in ipairs(water) do
		local vd = vector.distance(pos, v)
		if vd <= radius then
			temp_var = temp_var - 1 / ( vd * vd )
		end
	end
	for _, v in ipairs(lava) do
		local vd = vector.distance(pos, v)
		if vd <= radius then
			temp_var = temp_var + 1 / ( vd * vd )
		end
	end
	return temp_var
end

-- directional scan for specified mineral
-- parameters:	pos - device position (vector)
-- 		range - scan depth (float)
-- 		look_dir - direction of looking (normalized vector)
--		name - ore to search for (string)
-- return: mineral count, blocked by obsidian true/false
function minertools.dir_mineral_scan(pos, range, look_dir, name)
	local node = {}
	local pos_vec = {}
	local last_vec = nil
	local orecount = 0
	local obsblock = false
	for i = 1, range, 1 do
		pos_vec = vector.add(pos, vector.round(vector.multiply(look_dir, i)))
                if not last_vec or not vector.equals(pos_vec, last_vec) then
			node = minetest.get_node_or_nil(pos_vec)
			if node then
				if node.name == name then
					orecount = orecount + 1
				elseif minertools.has_obsidian(node.name) then
					obsblock = true
					break
				end
			end
			last_vec = pos_vec  -- protects against double count
		end
	end
	return orecount, obsblock
end

-- scan for ores in cubic area
-- parameters:	pos - device position (vector)
-- 		range - scan max range (float)
-- 		nodes - node names to search for (array)
-- return: mineral table (keys - node names, values - node count)
function minertools.area_mineral_scan(pos, range, nodes)
        local scan_vec = vector.new({x = range, y = range, z = range})
        local scan_pos1 = vector.subtract(pos, scan_vec)
        local scan_pos2 = vector.add(pos, scan_vec)
        local _, minerals = minetest.find_nodes_in_area(scan_pos1, scan_pos2, nodes)
        return minerals
end

