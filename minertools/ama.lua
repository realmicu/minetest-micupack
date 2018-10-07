
--[[

	Advanced Mining Assistant aka AMA v2.0

	This one is an upgraded version of PMC. Adding one
	more Mining Chip, gold circuitry and obsidian resonators
	allows PMC ranges and overall sensivity to be safely
	increased.
	Operational actions remain identical to PMC.

	Technical differences to PMC:
	* increased MineralFinder range
	* increased MineralScanner range
	* increased Geothermometer sensivity range
	* MS signal info (low/medium/high) indicates distance to ore
	* MF and MS settings are preserved during mode switch

	Left click - scan and show results
	Right click - change scan range/searched ore
	Double right click - change device mode

]]--

-- ************************
-- Namespaces and variables
-- ************************

local ama = {}
local MODE_GEOTHERM = 1
local MODE_OREFIND = 2
local MODE_ORESCAN = 3
local mode = MODE_GEOTHERM
local mode_name = { [MODE_GEOTHERM] = "Geothermometer",
		    [MODE_OREFIND] = "Mineral Finder",
		    [MODE_ORESCAN] = "Mineral Scanner", }
local tool_range = { [MODE_GEOTHERM] = 8, [MODE_OREFIND] = 5, [MODE_ORESCAN] = 0 }
local scan_range_min = 1
local scan_range_max = 12
local scan_range = scan_range_max
local find_range = 8
local find_stone_idx = 1
local temp_range = 12
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
function ama.use(itemstack, user, pointed_thing)
	local player_name = user:get_player_name()
	local player_pos = vector.round(user:getpos())
	local node_pos = vector.new(pointed_thing.under)
	if mode == MODE_GEOTHERM then
		if pointed_thing.type ~= "node" then return nil end
		minertools.geothermometer_use("AMA:Geothermometer", player_name,
					      node_pos, temp_range, temp_scale)
	elseif mode == MODE_OREFIND then
		local head_pos = vector.add(player_pos, minertools.head_vec)
		local look_dir = user:get_look_dir()
		minertools.mineralfinder_use("AMA:MineralFinder", player_name,
				head_pos, look_dir, find_range,
				find_ore_stones[find_stone_idx], 1)
	elseif mode == MODE_ORESCAN then
		minertools.mineralscanner_use("AMA:MineralScanner", player_name,
					      player_pos, scan_range,
					      scan_ore_stones)
	end
	return nil
end

function ama.change_mode(itemstack, user_placer, pointed_thing)
	local player_name = user_placer:get_player_name()
	local rclick_ts = minetest.get_us_time()
	-- detect right double-click
	if rclick_ts - last_rclick_ts < minertools.dbl_click_us then
		-- mode change
		mode = ((mode + 1) % #mode_name) + 1
		minetest.override_item("minertools:advanced_mining_assistant",
			{range = tool_range[mode]})
		minertools.computer_mode_change_notify("AMA", player_name,
			mode_name[mode])
		if mode == MODE_OREFIND then
			-- AMA remembers settings, do not reset ore
			minertools.print_mineral_type_is_now("AMA:MineralFinder",
				player_name, find_ore_stones[find_stone_idx])
		elseif mode == MODE_ORESCAN then
			-- AMA remembers settings, do not reset range
			minertools.print_scan_range_is_now("AMA:MineralScanner",
				player_name, scan_range)
		end
	else
		-- option change
		if mode == MODE_OREFIND then
			find_stone_idx = minertools.mineralfinder_switch_ore(
				"AMA:MineralFinder", player_name,
				find_ore_stones, find_stone_idx)
		elseif mode == MODE_ORESCAN then
			scan_range = minertools.mineralscanner_switch_range(
				"AMA:MineralScanner", player_name,
				scan_range_min, scan_range_max, scan_range)
		end
	end
	last_rclick_ts = rclick_ts
	return nil
end

-- *************
-- Register Tool
-- *************

minetest.register_tool("minertools:advanced_mining_assistant", {
	description = "Advanced Mining Assistant",
	wield_image = "minertools_ama_hand.png",
	wield_scale = { x = 1, y = 1, z = 1 },
	inventory_image = "minertools_ama_inv.png",
	stack_max = 1,
	range = tool_range[mode],
	on_use = ama.use,
	on_place = ama.change_mode,
	on_secondary_use = ama.change_mode,
})

-- ************
-- Craft Recipe
-- ************

minetest.register_craft({
	output = "minertools:advanced_mining_assistant",
	type = "shaped",
	recipe = {
		{ "default:obsidian", "default:mese_crystal", "default:obsidian" },
		{ "default:gold_ingot", "minertools:portable_mining_computer", "default:gold_ingot" },
		{ "default:obsidian", "minertools:mining_chip", "default:obsidian" },
	},
})

