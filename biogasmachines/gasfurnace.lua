
--[[

	=======================================================================
	Tubelib Biogas Machines Mod
	by Micu (c) 2018

	Copyright (C) 2018 Michal Cieslakiewicz
	
	Biogas-fuelled burner that smelts and cookes like standard furnace.
	All cooking recipes, including duration, are identical to its stone
	counterpart.

	Main differences between this furnace and default one are as follows:
	* device accepts only Biogas as fuel, one unit lasts for 40 seconds
	* fuel (Biogas) is used only when cooking
	* device is fully Tubelib-compatible, no Hopper and no Furnace Monitor
	  are needed
	* there is 1 tick gap between processing items for unloading
	  and loading cooking tray; this is a design choice
	* both input and output trays are larger allowing more items to be
	  stored and processed
	* items that leave containers after cooking (for example farming:salt)
	  do not block cooking tray; such vessels (buckets in this case) are
	  routed to output tray as well, allowing to be picked up (and reused)
	  by Tubelib machinery
	* device always try to select source item that will fit output tray
	  after cooking, increasing efficiency and avoiding unnecessary
	  blocking

	Other important features:
	* if there is nothing to process, machine enters standby mode; it
	  will automatically pick up work as soon as any valid item is loaded
	  into input (source) tray
	* powering off device during cooking cancels the process; Biogas used
	  to partially cook item is not recoverable; operation starts from
	  beginning when device is on again
	* cooking tray can only be emptied when machine is stopped; this tray
	  is auto-loaded, source material should always go into input container
	* machine cannot be recovered unless input, fuel and output trays are
	  all empty
	* when active, due to high temperature inside, machine becomes a light
	  source of level 6

	License: LGPLv2.1+
	=======================================================================
	
]]--

--[[
        ---------
        Variables
        ---------
]]--

-- Coal block burn time is 370, Gasifier produces 9 Biogas units from it,
-- so let 1 Biogas unit burn for 40 sec (9 * 40 = 360)
local BIOGAS_BURN_TIME = 40
-- timing
local TIMER_TICK_SEC = 1		-- Node timer tick
local TICKS_TO_SLEEP = 5		-- Tubelib standby
-- machine inventory
local INV_H = 3				-- Inventory height
local INV_IN_W = 3			-- Input inventory width
local INV_OUT_W = (6 - INV_IN_W)	-- Output inventory width

--[[
	--------
	Formspec
	--------
]]--
-- static data for formspec
local fmxy = {
	inv_h = tostring(INV_H),
        inv_in_w = tostring(INV_IN_W),
        mid_x = tostring(INV_IN_W + 1),
        inv_out_w = tostring(INV_OUT_W),
        inv_out_x = tostring(INV_IN_W + 2),
	biogas_time = tostring(BIOGAS_BURN_TIME * TIMER_TICK_SEC)
}

-- Parameters:
-- state - tubelib state
-- fuel_percent - biogas used
-- item_percent - item completion
-- show_icons - show image hints (bool)
local function formspec(state, fuel_percent, item_percent, show_icons)
	return "size[8,8.25]" ..
	default.gui_bg ..
	default.gui_bg_img ..
	default.gui_slots ..
	"list[context;src;0,0;" .. fmxy.inv_in_w .. "," .. fmxy.inv_h .. ";]" ..
	"list[context;cur;" .. fmxy.inv_in_w .. ",0;1,1;]" ..
	"image[" .. fmxy.inv_in_w ..
		",1;1,1;biogasmachines_gasfurnace_inv_bg.png^[lowpart:" ..
		tostring(fuel_percent) ..
		":biogasmachines_gasfurnace_inv_fg.png]" ..
	"image[" .. fmxy.mid_x .. ",1;1,1;gui_furnace_arrow_bg.png^[lowpart:" ..
		tostring(item_percent) ..
		":gui_furnace_arrow_fg.png^[transformR270]" ..
	"list[context;fuel;" .. fmxy.inv_in_w .. ",2;1,1;]" ..
	(show_icons and "item_image[" .. fmxy.inv_in_w ..
		",2;1,1;tubelib_addons1:biogas]" or "") ..
	"image_button[" .. fmxy.mid_x .. ",2;1,1;" ..
		tubelib.state_button(state) .. ";button;]" ..
	"item_image[2.25,3.25;0.5,0.5;biogasmachines:gasfurnace]" ..
	"label[2.75,3.25;=]" ..
	"item_image[3,3.25;0.5,0.5;default:furnace]" ..
	"item_image[4.5,3.25;0.5,0.5;tubelib_addons1:biogas]" ..
	"label[5,3.25;= " .. fmxy.biogas_time .. " sec]" ..
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
	(state == tubelib.RUNNING and
                "box[" .. fmxy.inv_in_w .. ",0;0.82,0.9;#BF5F2F]" or
                "listring[context;cur]listring[current_player;main]") ..
	default.get_hotbar_bg(0, 4)
end

--[[
	-------
	Helpers
	-------
]]--

local function gasfurnace_start(pos)
	local node = minetest.get_node(pos)
	local meta = minetest.get_meta(pos)
	local number = meta:get_string("number")
	local fuel = meta:get_int("fuel_ticks")
	local label = minetest.registered_nodes[node.name].description
	meta:set_int("item_ticks", -1)
	meta:set_int("running", TICKS_TO_SLEEP)
	meta:set_string("infotext", label .. " " .. number .. ": running")
	meta:set_string("formspec", formspec(tubelib.RUNNING,
		100 * fuel / BIOGAS_BURN_TIME, 0, true))
	node.name = "biogasmachines:gasfurnace_active"
	minetest.swap_node(pos, node)
	minetest.get_node_timer(pos):start(TIMER_TICK_SEC)
	return false
end

local function gasfurnace_stop(pos)
	local node = minetest.get_node(pos)
	local meta = minetest.get_meta(pos)
	local number = meta:get_string("number")
	local fuel = meta:get_int("fuel_ticks")
	local label = minetest.registered_nodes[node.name].description
	meta:set_int("item_ticks", -1)
	meta:set_int("running", tubelib.STATE_STOPPED)
	meta:set_string("infotext", label .. " " .. number .. ": stopped")
	meta:set_string("formspec", formspec(tubelib.STOPPED,
		100 * fuel / BIOGAS_BURN_TIME, 0, true))
	node.name = "biogasmachines:gasfurnace"
	minetest.swap_node(pos, node)
        minetest.get_node_timer(pos):stop()
        return false
end

local function gasfurnace_idle(pos)
	local node = minetest.get_node(pos)
	local meta = minetest.get_meta(pos)
	local number = meta:get_string("number")
	local fuel = meta:get_int("fuel_ticks")
	local label = minetest.registered_nodes[node.name].description
	meta:set_int("item_ticks", -1)
	meta:set_int("running", tubelib.STATE_STANDBY)
	meta:set_string("infotext", label .. " " .. number .. ": standby")
	meta:set_string("formspec", formspec(tubelib.STANDBY,
		100 * fuel / BIOGAS_BURN_TIME, 0, true))
	node.name = "biogasmachines:gasfurnace"
	minetest.swap_node(pos, node)
        minetest.get_node_timer(pos):start(TIMER_TICK_SEC * TICKS_TO_SLEEP)
        return false
end

local function gasfurnace_fault(pos)
	local node = minetest.get_node(pos)
	local meta = minetest.get_meta(pos)
	local number = meta:get_string("number")
	local fuel = meta:get_int("fuel_ticks")
	local label = minetest.registered_nodes[node.name].description
	meta:set_int("item_ticks", -1)
	meta:set_int("running", tubelib.STATE_FAULT)
	meta:set_string("infotext", label .. " " .. number .. ": fault")
	meta:set_string("formspec", formspec(tubelib.FAULT,
		100 * fuel / BIOGAS_BURN_TIME, 0, true))
	node.name = "biogasmachines:gasfurnace"
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
				return gasfurnace_stop(pos)
			else
				return gasfurnace_idle(pos)
			end
		end
	end
	return true
end

-- Wrapper for 'cooking' get_craft_result() function for specified ItemStack
-- Return values are as follows:
-- time - cooking time or 0 if not cookable
-- input - input itemstack (take it from source stack to get decremented input)
-- output - output itemstack array (all extra leftover products are also here)
-- decr_input - decremented input (without leftover products)
local function get_cooking_items(stack)
	if stack:is_empty() then
		return 0, nil, nil, nil
	end
	local cookout, decinp = minetest.get_craft_result({ method = "cooking",
		width = 1, items = { stack } })
	if cookout.time <= 0 or cookout.item:is_empty() then
		return 0, nil, nil, nil
	end
	local inp = stack
	local outp = { cookout.item }
	local decp = decinp and decinp.items and decinp.items[1] or nil
	if decp and not decp:is_empty() then
		if decp:get_name() ~= stack:get_name() then
			outp[#outp + 1] = decp
			decp = ItemStack({})
		else
			inp = ItemStack(stack:get_name() .. " " ..
			tostring(stack:get_count() - decp:get_count()))
		end
	end
	return cookout.time, inp, outp, decp
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
		and inv:is_empty("fuel")
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
	if listname == "src" then
		if stack:get_name() == "tubelib_addons1:biogas" then
			return 0
		else
			return stack:get_count()
		end
	elseif listname == "cur" or listname == "dst" then
		return 0
	elseif listname == "fuel" then
		if stack:get_name() == "tubelib_addons1:biogas" then
			return stack:get_count()
		else
			return 0
		end
	end
	return 0
end

-- validate items move
local function allow_metadata_inventory_move(pos, from_list, from_index, to_list, to_index, count, player)
	local meta = minetest.get_meta(pos)
	if to_list == "cur" or
	   (from_list == "cur" and meta:get_int("running") > 0) then
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
	if listname == "cur" then
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
		minetest.colorize("#FFFF00", "[BiogasFurnace:" ..
		meta:get_string("number") .. "]") .. " Status is " ..
		minetest.colorize(msgclr[state], "\"" .. state .. "\""))
	return true
end

-- formspec callback
local function on_receive_fields(pos, formname, fields, player)
	if minetest.is_protected(pos, player:get_player_name()) then
		return
	end
	local meta = minetest.get_meta(pos)
	local running = meta:get_int("running")
	if fields and fields.button then
		if running > 0 or running == tubelib.STATE_FAULT then
			gasfurnace_stop(pos)
		else
			gasfurnace_start(pos)
		end
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
	if fuel == 0 and inv:is_empty("fuel") then
		-- no fuel - no work (but wait a little)
		return countdown_to_idle_or_stop(pos, true)
	end
	local recipe = {}
	local inp
	if inv:is_empty("cur")  then
		-- idle and ready, check for something to work with
		if inv:is_empty("src") then
			return countdown_to_idle_or_stop(pos)
		end
		-- find item to cook/smelt that fits output tray
		-- (parse list items as first choice is not always the best one)
		local idx = -2
		for i = 1, inv:get_size("src") do
			inp = inv:get_stack("src", i)
			if not inp:is_empty() then
				recipe.time, recipe.input, recipe.output,
					recipe.decremented_input = get_cooking_items(inp)
				if recipe.time > 0 then
					idx = -1
					if inv:room_for_item("dst", recipe.output[1]) and
					   (not recipe.output[2] or
					    inv:room_for_item("dst", recipe.output[2])) then
						idx = i
						break
					end
				end
			end
		end
		-- (idx == -2 - nothing cookable found in src)
		-- (idx == -1 - cookable item in src but no space in dst)
		if idx < 0 then
			if idx < -1 then
				return countdown_to_idle_or_stop(pos)
			end
			return true
		end
		if meta:get_int("running") == tubelib.STATE_STANDBY then
			-- something to do, wake up and re-entry
			return gasfurnace_start(pos)
		end
		inv:set_stack("src", idx, recipe.decremented_input)
		inv:set_stack("cur", 1, recipe.input)
		meta:set_int("item_ticks", recipe.time)
		meta:set_int("item_total", recipe.time)
		itemcnt = recipe.time
	else
		-- production tick
		inp = inv:get_stack("cur", 1)
		if inp:is_empty() then
			return gasfurnace_fault(pos)	-- oops
		end
		recipe.time = meta:get_int("item_total")
		if itemcnt < 0 then
			itemcnt = recipe.time	-- cook again
		end
		itemcnt = itemcnt - 1
		if itemcnt == 0 then
			local zzz
			zzz, zzz, recipe.output = get_cooking_items(inp)
			for _, i in ipairs(recipe.output) do
				inv:add_item("dst", i)
			end
			inv:set_stack("cur", 1, ItemStack({}))
			itemcnt = -1
			recipe.time = -1
		end
		meta:set_int("item_ticks", itemcnt)
		-- consume fuel tick
		if fuel == 0 then
			if not inv:is_empty("fuel") then
				inv:remove_item("fuel",
					ItemStack("tubelib_addons1:biogas 1"))
				fuel = BIOGAS_BURN_TIME
			else
				-- oops
				return gasfurnace_fault(pos)
			end
		end
		fuel = fuel - 1
		meta:set_int("fuel_ticks", fuel)
	end
	meta:set_int("running", TICKS_TO_SLEEP)
	meta:set_string("infotext", label .. " " .. number .. ": running")
	meta:set_string("formspec", formspec(tubelib.RUNNING,
		100 * fuel / BIOGAS_BURN_TIME,
		100 * (recipe.time - itemcnt) / recipe.time, true))
	return true
end

--[[
	-----------------
	Node registration
	-----------------
]]--

minetest.register_node("biogasmachines:gasfurnace", {
	description = "Tubelib Biogas Furnace",
	tiles = {
		-- up, down, right, left, back, front
		"biogasmachines_gasfurnace_top.png",
		"biogasmachines_bottom.png",
		"biogasmachines_gasfurnace_side.png",
		"biogasmachines_gasfurnace_side.png",
		"biogasmachines_gasfurnace_side.png",
		"biogasmachines_gasfurnace_side.png",
	},
	drawtype = "nodebox",

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
		local number = tubelib.add_node(pos, "biogasmachines:gasfurnace")
		local inv = meta:get_inventory()
		inv:set_size('src', INV_H * INV_IN_W)
		inv:set_size('cur', 1)
		inv:set_size('fuel', 1)
		inv:set_size('dst', INV_H * INV_OUT_W)
		local label = minetest.registered_nodes[node.name].description
		meta:set_string("number", number)
		meta:set_string("owner", placer:get_player_name())
		meta:set_int("running", tubelib.STATE_STOPPED)
		meta:set_int("fuel_ticks", 0)
		meta:set_int("item_ticks", -1)
		meta:set_int("item_total", 0)
		meta:set_string("infotext", label .. " " .. number .. ": stopped")
		meta:set_string("formspec", formspec(tubelib.STOPPED, 0, 0, true))
	end,
})

minetest.register_node("biogasmachines:gasfurnace_active", {
	description = "Tubelib Biogas Furnace",
	tiles = {
		-- up, down, right, left, back, front
		{
			image = "biogasmachines_gasfurnace_active_top.png",
			backface_culling = false,
			animation = {
				type = "vertical_frames",
				aspect_w = 32,
				aspect_h = 32,
				length = 1.5,
			},
		},
		"biogasmachines_bottom.png",
		"biogasmachines_gasfurnace_side.png",
		"biogasmachines_gasfurnace_side.png",
		"biogasmachines_gasfurnace_side.png",
		"biogasmachines_gasfurnace_side.png",
	},
	drawtype = "nodebox",

	paramtype = "light",
	sunlight_propagates = true,
	paramtype2 = "facedir",
	groups = { crumbly = 0, not_in_creative_inventory = 1 },
	is_ground_content = false,
	light_source = 6,
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
	drop = "biogasmachines:gasfurnace",
})
tubelib.register_node("biogasmachines:gasfurnace", { "biogasmachines:gasfurnace_active" }, {

	on_push_item = function(pos, side, item)
		local meta = minetest.get_meta(pos)
		if item:get_name() == "tubelib_addons1:biogas" then
			return tubelib.put_item(meta, "fuel", item)
		end
		return tubelib.put_item(meta, "src", item)
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
                        gasfurnace_start(pos)
		elseif topic == "off" then
			gasfurnace_stop(pos)
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
	output = "biogasmachines:gasfurnace",
	recipe = {
		{ "default:steelblock", "default:steel_ingot", "default:steelblock" },
		{ "default:mese_crystal", "default:furnace", "tubelib:tube1" },
		{ "group:wood", "default:steel_ingot", "group:wood" },
	},
})
