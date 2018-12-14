--[[

	=======================================================================
	Tubelib Biogas Machines Mod
	by Micu (c) 2018

	Copyright (C) 2018 Michal Cieslakiewicz

	Compactor is a heavy mechanical press with heating, compacting and
	cooling systems combined into one device.  It compresses stone-like
	resources into very dense and hard materials, mainly obsidian. Default
	recipes include converting cobble and compressed gravel to obsidian,
	flint to obsidian shards and coal blocks to diamonds. Machine consumes
	Biogas for heating/compacting and Ice for rapid cooling.
	More custom recipes can be added via API function.

	Operational info:
	* machine requires Biogas as fuel (one unit lasts for 12 seconds) and
	  Ice for cooling (one ice cube per source item)
	* if there is nothing to process or there is no ice, machine enters
	  standby mode; it will automatically pick up work as soon as any valid
	  item is loaded into input (source) tray and ice is available
	* there is 1 tick gap between processing items to perform machinery
	  cleaning and reload working trays; this is a design choice
	* working trays can only be emptied when machine is stopped; these trays
	  are auto-loaded, source material should always go into input container
	  and ice into slot next to button
	* machine cannot be recovered unless input, output, fuel and ice trays
	  are all empty
	* powering off device during compacting cancels the process; Biogas used
	  to power the machine is not recoverable; operation starts from
	  beginning when device is powered on again
	* device always checks if expected products will fit output tray so
	  some input items may be omitted temporarily

	License: LGPLv2.1+
	=======================================================================
	
]]--

--[[
	---------
	Variables
	---------
]]--

-- Biogas time in ticks
local BIOGAS_WORK_TIME = 12
-- timing
local TIMER_TICK_SEC = 1                -- Node timer tick
local TICKS_TO_SLEEP = 5                -- Tubelib standby
-- machine inventory
local INV_H = 3                         -- Inventory height (do not change)
local INV_IN_W = 3                      -- Input inventory width
local INV_OUT_W = (5 - INV_IN_W)        -- Output inventory width

-- machine recipe table (key - source item name)
local compactor_recipes = {}
-- hintbar recipe index table (indexed by numbers for formspec recipe hint bar)
local hintbar_recipes = {}

--[[
	----------------
	Public functions
	----------------
]]--

-- Add Compactor recipe
-- Returns true if recipe added successfully, false if error or already present
-- recipe = {
--	input = "itemstring",	-- source items (req)
--	output = "itemstring",	-- product items (req)
--	time = number		-- production time in ticks (req, max: 99)
-- }
function biogasmachines.add_compactor_recipe(recipe)
	if not recipe then return false end
	if not recipe.input or not recipe.output or not recipe.time or
	   recipe.time < 1 or recipe.time > 99 then
		return false
	end
	local input_item = ItemStack(recipe.input)
	local output_item = ItemStack(recipe.output)
	if not input_item or not input_item:is_known() or
	   not output_item or not output_item:is_known() then
		return false
	end
	local input_name = input_item:get_name()
	if compactor_recipes[input_name] then return false end
	compactor_recipes[input_name] = {
		input = input_item,	-- (duplicated for faster access)
		output = output_item,
		time = recipe.time
        }
	hintbar_recipes[#hintbar_recipes + 1] = input_name
	if minetest.get_modpath("unified_inventory") and unified_inventory then
		unified_inventory.register_craft({
			type = "compactor",
			items = { input_item:to_string() },
			output = output_item:to_string(),
		})
	end
	return true
end


--[[
        --------
        Formspec
        --------
]]--

-- static data for formspec
local fmxy = {
	inv_h = tostring(INV_H),
	inv_in_w = tostring(INV_IN_W),		-- (also 1st col of mid panel)
	mid_x05 = tostring(INV_IN_W + 0.5),
	mid_x1 = tostring(INV_IN_W + 1),	-- (2nd col of mid panel)
	mid_x15 = tostring(INV_IN_W + 1.5),
	mid_x2 = tostring(INV_IN_W + 2),	-- (3rd col of mid panel)
	inv_out_x = tostring(INV_IN_W + 3),	-- (1st col of dst inv)
	inv_out_w = tostring(INV_OUT_W),
	biogas_time = tostring(BIOGAS_WORK_TIME * TIMER_TICK_SEC),
}

-- recipe hint
local function formspec_recipe_hint_bar(recipe_idx, show_icons)
	if #hintbar_recipes == 0 or recipe_idx > #hintbar_recipes then
		return ""
	end
	local input_name = hintbar_recipes[recipe_idx]
	local recipe = compactor_recipes[input_name]
	local output_name = recipe.output:get_name()
	local input_count = tostring(recipe.input:get_count())
	local output_count = tostring(recipe.output:get_count())
	--local input_desc = minetest.registered_nodes[input_name].description
	--local output_desc = minetest.registered_nodes[output_name].description
	return (show_icons and "item_image[0,0;1,1;" .. input_name .. "]" ..
		"item_image[" .. fmxy.inv_out_x .. ",0;1,1;" .. output_name ..
		"]" or "") ..
	"label[0,3.25;Recipe]" ..
	"image_button[0.8,3.3;0.5,0.5;;left;<]" ..
	"label[1.2,3.25;" ..
		string.format("%2d / %2d", recipe_idx, #hintbar_recipes) ..
		"]" ..
	"image_button[1.9,3.3;0.5,0.5;;right;>]" ..
	"item_image[2.4,3.25;0.5,0.5;" .. input_name .. "]" ..
	"label[2.9,3.25;x " .. input_count .. "]" ..
	"image[3.3,3.25;0.5,0.5;tubelib_gui_arrow.png^[resize:16x16]" ..
	"label[3.7,3.25;" ..
		string.format("%2d sec +", recipe.time * TIMER_TICK_SEC) .. "]" ..
	"item_image[4.5,3.25;0.5,0.5;default:ice]" ..
	"image[4.9,3.25;0.5,0.5;tubelib_gui_arrow.png^[resize:16x16]" ..
	"item_image[5.3,3.25;0.5,0.5;" .. output_name .. "]" ..
	"label[5.8,3.25;x " .. output_count .. "]" ..
	"item_image[6.5,3.25;0.5,0.5;tubelib_addons1:biogas]" ..
	"label[7,3.25;= " .. fmxy.biogas_time .. " sec]"
end

-- Parameters:
-- state - tubelib state
-- fuel_percent - biogas used
-- item_percent - item completion
-- recipe_idx - index of recipe shown at hint bar
-- show_icons - show image hints (bool)
local function formspec(state, fuel_percent, item_percent,
			recipe_idx, show_icons)
	return "size[8,8.25]" ..
	default.gui_bg ..
	default.gui_bg_img ..
	default.gui_slots ..
	"list[context;src;0,0;" .. fmxy.inv_in_w .. "," .. fmxy.inv_h .. ";]" ..
	"list[context;cur;" .. fmxy.mid_x05 .. ",0;1,1;]" ..
	"list[context;cic;" .. fmxy.mid_x15 .. ",0;1,1;]" ..
	"image[" .. fmxy.mid_x05 ..
		",1;1,1;biogasmachines_compactor_inv_bg.png^[lowpart:" ..
		tostring(fuel_percent) ..
		":biogasmachines_compactor_inv_fg.png]" ..
	"image[" .. fmxy.mid_x15 ..
		",1;1,1;gui_furnace_arrow_bg.png^[lowpart:" ..
		tostring(item_percent) ..
		":gui_furnace_arrow_fg.png^[transformR270]" ..
	"list[context;fuel;" .. fmxy.inv_in_w .. ",2;1,1;]" ..
	"list[context;ice;" .. fmxy.mid_x2 .. ",2;1,1;]" ..
	(show_icons and "item_image[" .. fmxy.inv_in_w ..
		",2;1,1;tubelib_addons1:biogas]" ..
		"item_image[" .. fmxy.mid_x2 .. ",2;1,1;default:ice]" or "") ..
	"image_button[" .. fmxy.mid_x1 .. ",2;1,1;" ..
		tubelib.state_button(state) .. ";button;]" ..
	formspec_recipe_hint_bar(recipe_idx, show_icons) ..
	"list[context;dst;" .. fmxy.inv_out_x .. ",0;" .. fmxy.inv_out_w ..
	"," .. fmxy.inv_h .. ";]" ..
	"list[current_player;main;0,4;8,1;]" ..
	"list[current_player;main;0,5.25;8,3;8]" ..
	"listring[context;dst]" ..
	"listring[current_player;main]" ..
	"listring[context;src]" ..
	"listring[current_player;main]" ..
	"listring[context;fuel]" ..
	"listring[current_player;main]" ..
	"listring[context;ice]" ..
	"listring[current_player;main]" ..
	(state == tubelib.RUNNING and
		"box[" .. fmxy.mid_x05 .. ",0;0.82,0.9;#BF5F2F]" ..
		"box[" .. fmxy.mid_x15 .. ",0;0.82,0.9;#2F4FBF]"
		or "listring[context;cur]listring[current_player;main]" ..
		"listring[context;cic]listring[current_player;main]") ..
	default.get_hotbar_bg(0, 4)
end

--[[
	-------
	Helpers
	-------
]]--

local function compactor_start(pos)
	local node = minetest.get_node(pos)
	local meta = minetest.get_meta(pos)
	local number = meta:get_string("number")
	local fuel = meta:get_int("fuel_ticks")
	local recipe_idx = meta:get_int("recipe_idx")
	local label = minetest.registered_nodes[node.name].description
	meta:set_int("item_ticks", -1)
	meta:set_int("running", TICKS_TO_SLEEP)
	meta:set_string("infotext", label .. " " .. number .. ": running")
	meta:set_string("formspec", formspec(tubelib.RUNNING,
		100 * fuel / BIOGAS_WORK_TIME, 0, recipe_idx, true))
	node.name = "biogasmachines:compactor_active"
	minetest.swap_node(pos, node)
	minetest.get_node_timer(pos):start(TIMER_TICK_SEC)
	return false
end

local function compactor_stop(pos)
	local node = minetest.get_node(pos)
	local meta = minetest.get_meta(pos)
	local number = meta:get_string("number")
	local fuel = meta:get_int("fuel_ticks")
	local recipe_idx = meta:get_int("recipe_idx")
	local label = minetest.registered_nodes[node.name].description
	meta:set_int("item_ticks", -1)
	meta:set_int("running", tubelib.STATE_STOPPED)
	meta:set_string("infotext", label .. " " .. number .. ": stopped")
	meta:set_string("formspec", formspec(tubelib.STOPPED,
		100 * fuel / BIOGAS_WORK_TIME, 0, recipe_idx, true))
	node.name = "biogasmachines:compactor"
	minetest.swap_node(pos, node)
	minetest.get_node_timer(pos):stop()
	return false
end

local function compactor_idle(pos)
	local node = minetest.get_node(pos)
	local meta = minetest.get_meta(pos)
	local number = meta:get_string("number")
	local fuel = meta:get_int("fuel_ticks")
	local recipe_idx = meta:get_int("recipe_idx")
	local label = minetest.registered_nodes[node.name].description
	meta:set_int("item_ticks", -1)
	meta:set_int("running", tubelib.STATE_STANDBY)
	meta:set_string("infotext", label .. " " .. number .. ": standby")
	meta:set_string("formspec", formspec(tubelib.STANDBY,
		100 * fuel / BIOGAS_WORK_TIME, 0, recipe_idx, true))
	node.name = "biogasmachines:compactor"
	minetest.swap_node(pos, node)
	minetest.get_node_timer(pos):start(TIMER_TICK_SEC * TICKS_TO_SLEEP)
	return false
end

local function compactor_fault(pos)
	local node = minetest.get_node(pos)
	local meta = minetest.get_meta(pos)
	local number = meta:get_string("number")
	local fuel = meta:get_int("fuel_ticks")
	local recipe_idx = meta:get_int("recipe_idx")
	local label = minetest.registered_nodes[node.name].description
	meta:set_int("item_ticks", -1)
	meta:set_int("running", tubelib.STATE_FAULT)
	meta:set_string("infotext", label .. " " .. number .. ": fault")
	meta:set_string("formspec", formspec(tubelib.FAULT,
		100 * fuel / BIOGAS_WORK_TIME, 0, recipe_idx, true))
	node.name = "biogasmachines:compactor"
	minetest.swap_node(pos, node)
	minetest.get_node_timer(pos):stop()
	return false
end

local function countdown_to_idle_or_stop(pos, stop)
	local meta = minetest.get_meta(pos)
	local running = meta:get_int("running")
	if running > 0 then
		running = running - 1
		meta:set_int("running", running)
		if running == 0 then
			if stop then
				return compactor_stop(pos)
			else
				return compactor_idle(pos)
			end
		end
	end
	return true
end

--[[
	---------
	Callbacks
	---------
]]--

-- do not allow to dig non-empty machine
local function can_dig(pos, player)
	local meta = minetest.get_meta(pos);
	local inv = meta:get_inventory()
	return inv:is_empty("src") and inv:is_empty("dst")
		and inv:is_empty("fuel") and inv:is_empty("ice")
end

-- cleanup after digging
local function after_dig_node(pos, oldnode, oldmetadata, digger)
	tubelib.remove_node(pos)
end

-- validate incoming items
local function allow_metadata_inventory_put(pos, listname, index, stack, player)
	if minetest.is_protected(pos, player:get_player_name()) then
		return 0
	end
	local item_name = stack:get_name()
	if listname == "src" then
		if compactor_recipes[item_name] then
			return stack:get_count()
		else
			return 0
		end
	elseif listname == "cur" or listname == "cic" or listname == "dst" then
		return 0
	elseif listname == "fuel" then
		if item_name == "tubelib_addons1:biogas" then
			return stack:get_count()
		else
			return 0
		end
	elseif listname == "ice" then
		if item_name == "default:ice" then
			return stack:get_count()
		else
			return 0
		end
	end
	return 0
end

-- validate items move
local function allow_metadata_inventory_move(pos, from_list, from_index,
					     to_list, to_index, count, player)
	local meta = minetest.get_meta(pos)
	if to_list == "cur" or to_list == "cic" or
	   ((from_list == "cur" or from_list == "cic") and
	     meta:get_int("running") > 0) then
		return 0
	end
	local inv = meta:get_inventory()
	local stack = inv:get_stack(from_list, from_index)
	return allow_metadata_inventory_put(pos, to_list, to_index, stack, player)
end

-- validate items retrieval
local function allow_metadata_inventory_take(pos, listname, index, stack, player)
	if minetest.is_protected(pos, player:get_player_name()) then
		return 0
	end
	if listname == "cur" or listname == "cic" then
		local meta = minetest.get_meta(pos)
		if meta:get_int("running") > 0 then
			return 0
		end
	end
	return stack:get_count()
end

-- punch machine to see status info
local function on_punch(pos, node, puncher, pointed_thing)
	local meta = minetest.get_meta(pos)
	local player_name = puncher:get_player_name()
	if meta:get_string("owner") ~= player_name then
		return false
	end
	local msgclr = { ["fault"] = "#FFBFBF",
			 ["standby"] = "#BFFFFF",
			 ["stopped"] = "#BFBFFF",
			 ["running"] = "#BFFFBF"
	}
	local state = tubelib.statestring(meta:get_int("running"))
	minetest.chat_send_player(player_name,
		minetest.colorize("#FFFF00", "[Compactor:" ..
		meta:get_string("number") .. "]") .. " Status is " ..
		minetest.colorize(msgclr[state], "\"" .. state .. "\""))
	return true
end

-- formspec button handler
local function on_receive_fields(pos, formname, fields, player)
	if minetest.is_protected(pos, player:get_player_name()) then
		return
	end
	local meta = minetest.get_meta(pos)
	local running = meta:get_int("running")
	if fields and fields.button then
		if running > 0 or running == tubelib.STATE_FAULT then
			compactor_stop(pos)
		else
			compactor_start(pos)
		end
	end
	if fields and (fields.left or fields.right) then
		-- update hintbar
		local fuel = meta:get_int("fuel_ticks")
		local item_ticks = meta:get_int("item_ticks")
		local recipe_idx = meta:get_int("recipe_idx")
		if fields.left then
			recipe_idx = math.max(recipe_idx - 1, 1)
		end
		if fields.right then
			recipe_idx = math.min(recipe_idx + 1, #hintbar_recipes)
		end
		local item_pct = 0
		if item_ticks >= 0 then
			local item_time = meta:get_int("item_total")
			item_pct = 100 * (item_time - item_ticks) / item_time
		end
		meta:set_int("recipe_idx", recipe_idx)
		meta:set_string("formspec", formspec(tubelib.state(running),
			100 * fuel / BIOGAS_WORK_TIME, item_pct, recipe_idx,
			true))
	end
end

-- tick-based item production
local function on_timer(pos, elapsed)
	local node = minetest.get_node(pos)
	local meta = minetest.get_meta(pos)
	local inv = meta:get_inventory()
	local label = minetest.registered_nodes[node.name].description
	local number = meta:get_string("number")
	local running = meta:get_int("running")
	local itemcnt = meta:get_int("item_ticks")
	local fuel = meta:get_int("fuel_ticks")
	local recipe_idx = meta:get_int("recipe_idx")
	if fuel == 0 and inv:is_empty("fuel") then
		-- no fuel - no work (but wait a little)
		return countdown_to_idle_or_stop(pos, true)
	end
	local recipe = {}
	local prodtime = -1
	local ice = ItemStack("default:ice 1")
	if inv:is_empty("cur")  then
		-- idle and ready, check for something to work with
		if inv:is_empty("src") or inv:is_empty("ice") then
			return countdown_to_idle_or_stop(pos)
		end
		-- find item to compact that fits output tray
		local is_src_ok = false
		local src_copy = inv:set_list("src_copy", inv:get_list("src"))
		for _, r in pairs(compactor_recipes) do
			local s = inv:remove_item("src_copy", r.input)
			if s:get_count() == r.input:get_count() then
				is_src_ok = true
				if inv:room_for_item("dst", r.output) then
					recipe = r
					break
				end
			end
		end
		inv:set_size("src_copy", 0)
		if not recipe.time then
			if is_src_ok then
				return true	-- busy wait for space in dst
			else
				return countdown_to_idle_or_stop(pos)
			end
		elseif running == tubelib.STATE_STANDBY then
			-- something to do, wake up and re-entry
			return compactor_start(pos)
		end
		local s = inv:remove_item("src", recipe.input)
		if s:is_empty() or s:get_count() < recipe.input:get_count() then
			return compactor_fault(pos)	-- oops
		end
		inv:set_stack("cur", 1, recipe.input)
		if inv:is_empty("cic") then
			s = inv:remove_item("ice", ice)
			if s:is_empty() then
				return compactor_fault(pos)	-- oops
			end
			inv:set_stack("cic", 1, s)
		end
		meta:set_int("item_ticks", recipe.time)
		meta:set_int("item_total", recipe.time)
		itemcnt = recipe.time
		prodtime = recipe.time
	else
		-- production tick
		if inv:is_empty("cic") then
			if inv:is_empty("ice") then
				return countdown_to_idle_or_stop(pos)
			end
			local s = inv:remove_item("ice", ice)
			if s:is_empty() then
				return compactor_fault(pos)	-- oops
			end
			inv:set_stack("cic", 1, s)
		end
		local s = inv:get_stack("cur", 1)
		if s:is_empty() then
			return compactor_fault(pos)	-- oops
		end
		recipe = compactor_recipes[s:get_name()]	-- (reference!)
		if not recipe or not recipe.time then
			return compactor_fault(pos)	-- oops
		end
		if itemcnt < 0 then
			itemcnt = recipe.time	-- compact again
		end
		itemcnt = itemcnt - 1
		if itemcnt == 0 then
			inv:add_item("dst", recipe.output)
			inv:set_stack("cur", 1, ItemStack({}))
			inv:set_stack("cic", 1, ItemStack({}))
			itemcnt = -1
		else
			prodtime = recipe.time
		end
		meta:set_int("item_ticks", itemcnt)
		-- consume fuel tick
		if fuel == 0 then
			if not inv:is_empty("fuel") then
				inv:remove_item("fuel",
					ItemStack("tubelib_addons1:biogas 1"))
				fuel = BIOGAS_WORK_TIME
			else
				-- oops
				return compactor_fault(pos)
			end
		end
		fuel = fuel - 1
		meta:set_int("fuel_ticks", fuel)
	end
	meta:set_int("running", TICKS_TO_SLEEP)
	meta:set_string("infotext", label .. " " .. number .. ": running")
	meta:set_string("formspec", formspec(tubelib.RUNNING,
		100 * fuel / BIOGAS_WORK_TIME,
		100 * (recipe.time - itemcnt) / prodtime, recipe_idx, true))
	return true
end

--[[
	-----------------
	Node registration
	-----------------
]]--

minetest.register_node("biogasmachines:compactor", {
	description = "Tubelib Compactor",
	tiles = {
		-- up, down, right, left, back, front
		"biogasmachines_compactor_top.png",
		"biogasmachines_bottom.png",
		"biogasmachines_compactor_side.png",
		"biogasmachines_compactor_side.png",
		"biogasmachines_compactor_side.png",
		"biogasmachines_compactor_side.png",
	},
	drawtype = "nodebox",
	node_box = {
		type = "fixed",
		fixed = {
			{ -0.5, -0.5, -0.5, 0.5, 0.375, 0.5 },
			{ -0.375, 0.4375, -0.375, 0.375, 0.5, 0.375 },
			{ -0.3125, 0.375, -0.3125, 0.3125, 0.4375, 0.3125 },
		}
	},
	selection_box = {
		type = "fixed",
		fixed = { -0.5, -0.5, -0.5, 0.5, 0.375, 0.5 },
	},

	paramtype = "light",
	sunlight_propagates = true,
	paramtype2 = "facedir",
	groups = { choppy = 2, cracky = 2, crumbly = 2 },
	is_ground_content = false,
	sounds = default.node_sound_metal_defaults(),

	can_dig = can_dig,
	after_dig_node = after_dig_node,
	on_punch = on_punch,
	on_rotate = screwdriver.disallow,
	on_timer = on_timer,
	on_receive_fields = on_receive_fields,
	allow_metadata_inventory_put = allow_metadata_inventory_put,
	allow_metadata_inventory_move = allow_metadata_inventory_move,
	allow_metadata_inventory_take = allow_metadata_inventory_take,

	after_place_node = function(pos, placer, itemstack, pointed_thing)
		local node = minetest.get_node(pos)
		local meta = minetest.get_meta(pos)
		local number = tubelib.add_node(pos, "biogasmachines:compactor")
		local inv = meta:get_inventory()
		inv:set_size('src', INV_H * INV_IN_W)
		inv:set_size('cur', 1)		-- working tray (item)
		inv:set_size('cic', 1)		-- working tray (ice)
		inv:set_size('fuel', 1)
		inv:set_size('ice', 1)
		inv:set_size('dst', INV_H * INV_OUT_W)
		local label = minetest.registered_nodes[node.name].description
		meta:set_string("number", number)
		meta:set_string("owner", placer:get_player_name())
		meta:set_int("running", tubelib.STATE_STOPPED)
		meta:set_int("fuel_ticks", 0)
		meta:set_int("item_ticks", -1)
		meta:set_int("item_total", 0)
		meta:set_int("recipe_idx", 1)
		meta:set_string("infotext", label .. " " .. number .. ": stopped")
		meta:set_string("formspec", formspec(tubelib.STOPPED, 0, 0, 1, true))
	end,
})

minetest.register_node("biogasmachines:compactor_active", {
	description = "Tubelib Compactor",
	tiles = {
		-- up, down, right, left, back, front
		{
			image = "biogasmachines_compactor_active_top.png",
			backface_culling = false,
			animation = {
				type = "vertical_frames",
				aspect_w = 32,
				aspect_h = 32,
				length = 2.0,
			},
		},
		"biogasmachines_bottom.png",
		"biogasmachines_compactor_active_side.png",
		"biogasmachines_compactor_active_side.png",
		"biogasmachines_compactor_active_side.png",
		"biogasmachines_compactor_active_side.png",
	},
	drawtype = "nodebox",
		node_box = {
		type = "fixed",
		fixed = {
			{ -0.5, -0.5, -0.5, 0.5, 0.375, 0.5 },
			{ -0.25, 0.4375, -0.25, 0.25, 0.5, 0.25 },
			{ -0.375, 0.375, -0.375, 0.375, 0.4375, 0.375 },
		},
	},
	selection_box = {
		type = "fixed",
		fixed = { -0.5, -0.5, -0.5, 0.5, 0.375, 0.5 },
	},

	paramtype = "light",
	sunlight_propagates = true,
	paramtype2 = "facedir",
	groups = { crumbly = 0, not_in_creative_inventory = 1 },
	is_ground_content = false,
	sounds = default.node_sound_metal_defaults(),

	can_dig = can_dig,
	after_dig_node = after_dig_node,
	on_punch = on_punch,
	on_rotate = screwdriver.disallow,
	on_timer = on_timer,
	on_receive_fields = on_receive_fields,
	allow_metadata_inventory_put = allow_metadata_inventory_put,
	allow_metadata_inventory_move = allow_metadata_inventory_move,
	allow_metadata_inventory_take = allow_metadata_inventory_take,
	drop = "biogasmachines:compactor",
})
tubelib.register_node("biogasmachines:compactor", { "biogasmachines:compactor_active" }, {

	on_push_item = function(pos, side, item)
		local meta = minetest.get_meta(pos)
		local item_name = item:get_name()
		if item_name == "tubelib_addons1:biogas" then
			return tubelib.put_item(meta, "fuel", item)
		elseif item_name == "default:ice" then
			return tubelib.put_item(meta, "ice", item)
		elseif compactor_recipes[item_name] then
			return tubelib.put_item(meta, "src", item)
		end
		return false
	end,

	on_pull_item = function(pos, side)
		local meta = minetest.get_meta(pos)
		return tubelib.get_item(meta, "dst")
	end,

	on_unpull_item = function(pos, side, item)
		local meta = minetest.get_meta(pos)
		return tubelib.put_item(meta, "dst", item)
	end,

	on_recv_message = function(pos, topic, payload)
		local meta = minetest.get_meta(pos)
		if topic == "on" then
                        compactor_start(pos)
		elseif topic == "off" then
			compactor_stop(pos)
		elseif topic == "state" then
			return tubelib.statestring(meta:get_int("running"))
		elseif topic == "fuel" then
			return tubelib.fuelstate(meta, "fuel")
		else
			return "unsupported"
		end
	end,
})

--[[
	--------
	Crafting
	--------
]]--

minetest.register_craft({
	output = "biogasmachines:compactor",
	recipe = {
		{ "default:obsidian_block", "biogasmachines:gasfurnace", "" },
		{ "biogasmachines:freezer", "default:diamondblock", "" },
		{ "", "", "" },
	},
})

--[[
	-------
	Recipes
	-------
]]--

-- Unified Inventory hints
if minetest.get_modpath("unified_inventory") and unified_inventory then
	unified_inventory.register_craft_type("compactor", {
		description = "Compactor",
		icon = 'biogasmachines_compactor_top.png',
		width = 1,
		height = 1,
	})
end

-- default recipes
if minetest.get_modpath("gravelsieve") and gravelsieve then
	biogasmachines.add_compactor_recipe({
		input = "gravelsieve:compressed_gravel 8",
		output = "default:obsidian 1",
		time = 12,
	})
end

biogasmachines.add_compactor_recipe({
	input = "default:cobble 4",
	output = "default:obsidian 1",
	time = 8,
})

biogasmachines.add_compactor_recipe({
	input = "default:mossycobble 4",
	output = "default:obsidian 1",
	time = 8,
})

biogasmachines.add_compactor_recipe({
	input = "default:desert_cobble 4",
	output = "default:obsidian 1",
	time = 8,
})

biogasmachines.add_compactor_recipe({
	input = "default:coalblock 4",
	output = "default:diamond 1",
	time = 16,
})

biogasmachines.add_compactor_recipe({
	input = "default:flint 4",
	output = "default:obsidian_shard 1",
	time = 4,
})
