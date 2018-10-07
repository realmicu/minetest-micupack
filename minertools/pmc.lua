
--[[

	Portable Mineral Computer aka PMC v2.0

	This is all-in-one device that provides functionality
	of geothermometer, mineral scanner and mineral finder.
	These basic components are all connected and managed
	by dedicated Mining Chip. Thanks to this, although
	in one box, there is no signal loss or decreased range.

	Technical info:
	3 devices combined into one with no modifications

	Left click - scan and show results
	Right click - change scan range/searched ore
	Double right click - change device mode

]]--

-- ************************
-- Namespaces and variables
-- ************************

local pmc = {}
local MODE_GEOTHERM = 1
local MODE_OREFIND = 2
local MODE_ORESCAN = 3
local mode = MODE_GEOTHERM
local mode_name = { [MODE_GEOTHERM] = "Geothermometer",
		    [MODE_OREFIND] = "Mineral Finder",
		    [MODE_ORESCAN] = "Mineral Scanner", }
local tool_range = { [MODE_GEOTHERM] = 8, [MODE_OREFIND] = 5, [MODE_ORESCAN] = 0 }
local scan_range_min = 1
local scan_range_max = 8
local scan_range = scan_range_max
local find_range = 5
local find_stone_idx = 1
local temp_range = 10
local temp_scale = 50.0
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
function pmc.use(itemstack, user, pointed_thing)
	local player_name = user:get_player_name()
	local player_pos = vector.round(user:getpos())
	local node_pos = vector.new(pointed_thing.under)
	if mode == MODE_GEOTHERM then
		if pointed_thing.type ~= "node" then return nil end
	        minertools.geothermometer_use("PMC:Geothermometer", player_name,
					      node_pos, temp_range, temp_scale)
	elseif mode == MODE_OREFIND then
		local head_pos = vector.add(player_pos, minertools.head_vec)
		local look_dir = user:get_look_dir()
		minertools.mineralfinder_use("PMC:MineralFinder", player_name,
				head_pos, look_dir, find_range,
				find_ore_stones[find_stone_idx])
	elseif mode == MODE_ORESCAN then
		minertools.mineralscanner_use("PMC:MineralScanner", player_name,
					      player_pos, scan_range,
					      scan_ore_stones)
	end
	return nil
end

function pmc.change_mode(itemstack, user_placer, pointed_thing)
	local player_name = user_placer:get_player_name()
	local rclick_ts = minetest.get_us_time()
	-- detect right double-click
	if rclick_ts - last_rclick_ts < minertools.dbl_click_us then
		-- mode change
		mode = ((mode + 1) % #mode_name) + 1
		minetest.override_item("minertools:portable_mining_computer",
			{range = tool_range[mode]})
		minertools.computer_mode_change_notify("PMC", player_name,
			mode_name[mode])
		if mode == MODE_OREFIND then
			find_stone_idx = 1
			minertools.print_mineral_type_set_to("PMC:MineralFinder",
				player_name, find_ore_stones[find_stone_idx])
		elseif mode == MODE_ORESCAN then
			scan_range = scan_range_max
			minertools.print_scan_range_set_to("PMC:MineralScanner",
				player_name, scan_range)
		end
	else
		-- option change
		if mode == MODE_OREFIND then
			find_stone_idx = minertools.mineralfinder_switch_ore(
				"PMC:MineralFinder", player_name,
				find_ore_stones, find_stone_idx)
		elseif mode == MODE_ORESCAN then
			scan_range = minertools.mineralscanner_switch_range(
				"PMC:MineralScanner", player_name,
				scan_range_min, scan_range_max, scan_range)
		end
	end
	last_rclick_ts = rclick_ts
	return nil
end

-- *************
-- Register Tool
-- *************

minetest.register_tool("minertools:portable_mining_computer", {
	description = "Portable Mining Computer",
	wield_image = "minertools_pmc_hand.png",
	wield_scale = { x = 1, y = 1, z = 1 },
	inventory_image = "minertools_pmc_inv.png",
	stack_max = 1,
	range = tool_range[mode],
	on_use = pmc.use,
	on_place = pmc.change_mode,
	on_secondary_use = pmc.change_mode,
})

-- ************
-- Craft Recipe
-- ************

minetest.register_craft({
	output = "minertools:portable_mining_computer",
	type = "shaped",
	recipe = {
		{ "default:steel_ingot", "minertools:geothermometer", "default:steel_ingot" },
		{ "minertools:mineral_finder", "minertools:mining_chip", "minertools:mineral_scanner" },
		{ "default:steel_ingot", "default:mese_crystal", "default:steel_ingot" },
	},
})

