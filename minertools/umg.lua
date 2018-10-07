
--[[

	Ultimate Mining Gizmo aka UMG v2.0

	This amazing device is an enhanced version of AMA.
	Ranges and sensivity are increased again, now thanks
	to optoelectronics based on diamonds and obsidian
	glass, all managed by (you guess it) dedicated Mining
	Chip.
	Operational actions remain identical to PMC and AMA.

	Technical differences to AMA:
	* increased tool range
	* increased MineralFinder range
	* increased MineralScanner range
	* increased Geothermometer sensivity range
	* increased Geothermometer display precision
	* MS signal strength (in percent) indicates distance to ore

	Left click - scan and show results
	Right click - change scan range/searched ore
	Double right click - change device mode

]]--

-- ************************
-- Namespaces and variables
-- ************************

local umg = {}
local MODE_GEOTHERM = 1
local MODE_OREFIND = 2
local MODE_ORESCAN = 3
local MODE_LIGHT = 4
local mode = MODE_GEOTHERM
local mode_name = { [MODE_GEOTHERM] = "Geothermometer",
		    [MODE_OREFIND] = "Mineral Finder",
		    [MODE_ORESCAN] = "Mineral Scanner", }
if minetest.get_modpath("wielded_light") then
	mode_name[MODE_LIGHT] = "Flashlight"
end
local tool_range = { [MODE_GEOTHERM] = 12, [MODE_OREFIND] = 8,
		     [MODE_ORESCAN] = 0, [MODE_LIGHT] = 4 }
local scan_range_min = 1
local scan_range_max = 16
local scan_range = scan_range_max
local find_range = 12
local find_stone_idx = 1
local temp_range = 16
local temp_scale = 50.0
local light_on = false
local last_rclick_ts = 0
local find_ore_stones = { "default:stone_with_coal",
			  "default:stone_with_iron",
			  "default:stone_with_copper",
			  "default:stone_with_tin",
			  "default:stone_with_gold",
			  "default:stone_with_mese",
			  "default:stone_with_diamond" }
if minetest.get_modpath("moreores") then
	find_ore_stones[#find_ore_stones + 1] = "moreores:mineral_silver"
	find_ore_stones[#find_ore_stones + 1] = "moreores:mineral_mithril"
end
local scan_ore_stones = table.copy(find_ore_stones)
scan_ore_stones[#scan_ore_stones + 1] = "default:obsidian"

-- activate device function
function umg.use(itemstack, user, pointed_thing)
	local player_name = user:get_player_name()
	local player_pos = vector.round(user:getpos())
	local node_pos = vector.new(pointed_thing.under)
	if mode == MODE_GEOTHERM then
		if pointed_thing.type ~= "node" then return nil end
		minertools.geothermometer_use("UMG:Geothermometer", player_name,
					      node_pos, temp_range, temp_scale,
					      "%+.6f")
	elseif mode == MODE_OREFIND then
		local head_pos = vector.add(player_pos, minertools.head_vec)
		local look_dir = user:get_look_dir()
		minertools.mineralfinder_use("UMG:MineralFinder", player_name,
				head_pos, look_dir, find_range,
				find_ore_stones[find_stone_idx], 2)
	elseif mode == MODE_ORESCAN then
		minertools.mineralscanner_use("UMG:MineralScanner", player_name,
					      player_pos, scan_range,
					      scan_ore_stones)
	elseif mode == MODE_LIGHT then
		light_on = minertools.flashlight_use("UMG:Flashlight",
			player_name, "minertools:ultimate_mining_gizmo",
			light_on)
	end
	return nil
end

function umg.change_mode(itemstack, user_placer, pointed_thing)
	local player_name = user_placer:get_player_name()
	local rclick_ts = minetest.get_us_time()
	-- detect right double-click
	if rclick_ts - last_rclick_ts < minertools.dbl_click_us then
		-- UMG saves last setting, so revert double-click change
		if mode == MODE_OREFIND then
			find_stone_idx = minertools.computer_mf_revert_ore_change(
				"UMG:MineralFinder", player_name,
				find_ore_stones, find_stone_idx)
		elseif mode == MODE_ORESCAN then
			scan_range = minertools.computer_ms_revert_range_change(
				"UMG:MineralScanner", player_name,
				scan_range_min, scan_range_max, scan_range)
		end
		-- mode change
		mode = (mode % #mode_name) + 1
		minetest.override_item("minertools:ultimate_mining_gizmo",
			{range = tool_range[mode]})
		minertools.computer_mode_change_notify("UMG", player_name,
			mode_name[mode])
		if mode == MODE_OREFIND then
			-- UMG remembers settings, do not reset ore
			minertools.print_mineral_type_is_now("UMG:MineralFinder",
				player_name, find_ore_stones[find_stone_idx])
		elseif mode == MODE_ORESCAN then
			-- UMG remembers settings, do not reset range
			minertools.print_scan_range_is_now("UMG:MineralScanner",
				player_name, scan_range)
		end
	else
		-- option change
		if mode == MODE_OREFIND then
			find_stone_idx = minertools.mineralfinder_switch_ore(
				"UMG:MineralFinder", player_name,
				find_ore_stones, find_stone_idx)
		elseif mode == MODE_ORESCAN then
			scan_range = minertools.mineralscanner_switch_range(
				"UMG:MineralScanner", player_name,
				scan_range_min, scan_range_max, scan_range)
		end
	end
	last_rclick_ts = rclick_ts
	return nil
end

-- *************
-- Register Tool
-- *************

minetest.register_tool("minertools:ultimate_mining_gizmo", {
	description = "Ultimate Mining Gizmo",
	wield_image = "minertools_umg_hand.png",
	wield_scale = { x = 1, y = 1, z = 1 },
	inventory_image = "minertools_umg_inv.png",
	stack_max = 1,
	range = tool_range[mode],
	on_use = umg.use,
	on_place = umg.change_mode,
	on_secondary_use = umg.change_mode,
})

-- ************
-- Craft Recipe
-- ************

minetest.register_craft({
	output = "minertools:ultimate_mining_gizmo",
	type = "shaped",
	recipe = {
		{ "default:obsidian_glass", "default:mese_crystal", "default:obsidian_glass" },
		{ "default:diamond", "minertools:advanced_mining_assistant", "default:diamond" },
		{ "default:obsidian_glass", "minertools:mining_chip", "default:obsidian_glass" },
	},
})

