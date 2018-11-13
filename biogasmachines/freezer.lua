--[[

	=======================================================================
	Tubelib Biogas Machines Mod
	by Micu (c) 2018

	Copyright (C) 2018 Michal Cieslakiewicz

	Freezer - Biogas-powered machine that converts water to ice
	(technically Biogas is a coolant here, not fuel, however it
	is 'used' in the same way). Device changes water in bucket
	to ice and empty bucket. If pipeworks mod is installed and pipe
	with water is connected to device, in absence of water buckets
	it produces ice from water supplied via pipes at the same rate.
	Device automatically shuts off when there is nothing to freeze,
	so Biogas is not wasted. However when machine is powered off via
	button while item is being frozen, Biogas used to partially cool
	down water is lost.
	Internal water valve works only when device runs, so in off state
	water pipe detector is also off. This is a design feature to save
	CPU resources for inactive machine (timer is stopped).

	Operational info:
	* machine first checks for buckets with water, if there are none
	  then tries to take water from pipes
	* when fuel ends, machine switches off automatically and has to
	  be powered on by player after loading Biogas
	* if there is nothing to freeze, machine enters standby mode; it
	  will automatically pick up work as soon as any water source becomes
	  available again
	* there is 1 tick gap between items to unload ice and load internal
	  water tank or freezing tray
	* Biogas is used only when device actually freezes
	* partially frozen items (due to work being interrupted by on/off
	  switch) have to be frozen again from beginning, Biogas used for
	  such partial freeze is not recoverable
	* bucket freezing tray cannot be emptied manually, it becomes empty
	  only when device finishes converting water to ice
	* when using pipes, internal water tank is filled completely before
	  process starts; shutting down water source during freezing does
	  not stop it
	* machine cannot be recovered unless input, output and fuel trays
	  are all empty

	License: LGPLv2.1+
	=======================================================================
	
]]--

--[[
	---------
	Variables
	---------
]]--

-- timing
local BIOGAS_TIME_SEC = 24		-- Biogas work time
local ICE_TIME_SEC = 4			-- Ice creation time
local TIMER_TICK_SEC = 1		-- Node timer tick
local TICKS_TO_SLEEP = 5		-- Tubelib standby
-- machine inventory
local INV_H = 3				-- Inventory height
local INV_IN_W = 4			-- Input inventory width
local INV_OUT_W = (6 - INV_IN_W)	-- Output inventory width
-- item processed
local SOURCE_EMPTY = 0
local SOURCE_BUCKET = 1
local SOURCE_PIPE = 2
-- water sources
local water_buckets = { "bucket:bucket_water", "bucket:bucket_river_water" }

--[[
	--------
	Formspec
	--------
]]--

-- Parameters:
-- state - tubelib state
-- water_pipe -  water from pipeworks (bool)
-- fuel_percent - biogas used
-- item_percent - ice completion
-- show_icons - show image hints (bool)
local function formspec(state, water_pipe, fuel_percent, item_percent, show_icons)
	local h = tostring(INV_H)
	local wi = tostring(INV_IN_W)
	local wo = tostring(INV_OUT_W)
	local pr = tostring(INV_IN_W + 1)
	local po = tostring(INV_IN_W + 2)
	return "size[8,8.25]" ..
	default.gui_bg ..
	default.gui_bg_img ..
	default.gui_slots ..
	"list[context;src;0,0;" .. wi .. "," .. h .. ";]" ..
	(show_icons and "item_image[0,0;1,1;bucket:bucket_water]" or "") ..
	"list[context;cur;" .. wi .. ",0;1,1;]" ..
	"image[" .. pr .. ",0;1,1;biogasmachines_freezer_pipe_inv_" ..
		(water_pipe and "fg" or "bg") .. ".png]" ..
	"image[" .. wi ..
		",1;1,1;biogasmachines_freezer_inv_bg.png^[lowpart:" ..
		tostring(fuel_percent) ..
		":biogasmachines_freezer_inv_fg.png]" ..
	"image[" .. pr .. ",1;1,1;gui_furnace_arrow_bg.png^[lowpart:" ..
		tostring(item_percent) ..
		":gui_furnace_arrow_fg.png^[transformR270]" ..
	"list[context;fuel;" .. wi .. ",2;1,1;]" ..
	(show_icons and "item_image[" .. wi ..
		",2;1,1;tubelib_addons1:biogas]" or "") ..
	"image_button[" .. pr .. ",2;1,1;" .. tubelib.state_button(state) ..
		";button;]" ..
	"item_image[1,3.25;0.5,0.5;tubelib_addons1:biogas]" ..
	"label[1.5,3.25;= " .. tostring(BIOGAS_TIME_SEC) .. " sec]" ..
	"item_image[3,3.25;0.5,0.5;default:ice]" ..
	"label[3.5,3.25;= " .. tostring(ICE_TIME_SEC) .. " sec]" ..
	"item_image[5.25,3.25;0.5,0.5;tubelib_addons1:biogas]" ..
	"image[5.75,3.25;0.5,0.5;tubelib_gui_arrow.png^[resize:16x16]" ..
	"item_image[6.25,3.25;0.5,0.5;default:ice]" ..
	"label[6.75,3.25;x " .. tostring(BIOGAS_TIME_SEC / ICE_TIME_SEC) ..
		"]" ..
	(show_icons and "item_image[" .. po .. ",0;1,1;default:ice]" or "") ..
	"list[context;dst;" .. po .. ",0;" .. wo .. "," .. h .. ";]" ..
	"list[current_player;main;0,4;8,1;]" ..
	"list[current_player;main;0,5.25;8,3;8]" ..
	"listring[context;dst]" ..
	"listring[current_player;main]" ..
	"listring[context;src]" ..
	"listring[current_player;main]" ..
	"listring[context;fuel]" ..
	"listring[current_player;main]" ..
	default.get_hotbar_bg(0, 4)
end

--[[
	-------
	Helpers
	-------
]]--

-- check if item is bucket with water (bool)
local function is_water_bucket(stack)
	local stackname = stack:get_name()
	return biogasmachines.is_member_of(stackname, water_buckets)
end

-- get bucket with water (itemstack)
local function get_water_bucket(inv, listname)
	local stack = ItemStack({})
	for _, i in ipairs(water_buckets) do
		stack = inv:remove_item(listname, ItemStack(i .. " 1"))
		if not stack:is_empty() then break end
	end
	return stack
end

local function freezer_start(pos)
	local node = minetest.get_node(pos)
	local meta = minetest.get_meta(pos)
	local number = meta:get_string("number")
	local fuel = meta:get_int("fuel_ticks")
	local label = minetest.registered_nodes[node.name].description
	if meta:get_int("source") == SOURCE_PIPE then
		meta:set_int("source", SOURCE_EMPTY)
	end
	meta:set_int("item_ticks", ICE_TIME_SEC)
	meta:set_int("running", TICKS_TO_SLEEP)
	meta:set_string("infotext", label .. " " .. number .. ": running")
	meta:set_string("formspec", formspec(tubelib.RUNNING, false,
		100 * fuel / BIOGAS_TIME_SEC, 0, true))
	node.name = "biogasmachines:freezer_active"
	minetest.swap_node(pos, node)
	minetest.get_node_timer(pos):start(TIMER_TICK_SEC)
	return false
end

local function freezer_stop(pos)
	local node = minetest.get_node(pos)
	local meta = minetest.get_meta(pos)
	local number = meta:get_string("number")
	local fuel = meta:get_int("fuel_ticks")
	local label = minetest.registered_nodes[node.name].description
	if meta:get_int("source") == SOURCE_PIPE then
		meta:set_int("source", SOURCE_EMPTY)
	end
	meta:set_int("item_ticks", ICE_TIME_SEC)
	meta:set_int("running", tubelib.STATE_STOPPED)
	meta:set_string("infotext", label .. " " .. number .. ": stopped")
	meta:set_string("formspec", formspec(tubelib.STOPPED, false,
		100 * fuel / BIOGAS_TIME_SEC, 0, true))
	node.name = "biogasmachines:freezer"
	minetest.swap_node(pos, node)
        minetest.get_node_timer(pos):stop()
        return false
end

local function freezer_idle(pos)
	local node = minetest.get_node(pos)
	local meta = minetest.get_meta(pos)
	local number = meta:get_string("number")
	local fuel = meta:get_int("fuel_ticks")
	local label = minetest.registered_nodes[node.name].description
	meta:set_int("item_ticks", ICE_TIME_SEC)
	meta:set_int("running", tubelib.STATE_STANDBY)
	meta:set_string("infotext", label .. " " .. number .. ": standby")
	meta:set_string("formspec", formspec(tubelib.STANDBY, false,
		100 * fuel / BIOGAS_TIME_SEC, 0, true))
	node.name = "biogasmachines:freezer"
	minetest.swap_node(pos, node)
        minetest.get_node_timer(pos):start(TIMER_TICK_SEC * TICKS_TO_SLEEP)
        return false
end

local function freezer_fault(pos)
	local node = minetest.get_node(pos)
	local meta = minetest.get_meta(pos)
	local number = meta:get_string("number")
	local fuel = meta:get_int("fuel_ticks")
	local label = minetest.registered_nodes[node.name].description
	if meta:get_int("source") == SOURCE_PIPE then
		meta:set_int("source", SOURCE_EMPTY)
	end
	meta:set_int("item_ticks", ICE_TIME_SEC)
	meta:set_int("running", tubelib.STATE_FAULT)
	meta:set_string("infotext", label .. " " .. number .. ": fault")
	meta:set_string("formspec", formspec(tubelib.FAULT, false,
		100 * fuel / BIOGAS_TIME_SEC, 0, true))
	node.name = "biogasmachines:freezer"
	minetest.swap_node(pos, node)
	minetest.get_node_timer(pos):stop()
	return false
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
	if minetest.get_modpath("pipeworks") then
		pipeworks.scan_for_pipe_objects(pos)
	end
end

-- validate incoming items
local function allow_metadata_inventory_put(pos, listname, index, stack, player)
	if minetest.is_protected(pos, player:get_player_name()) then
		return 0
	end
	if listname == "src" then
		if is_water_bucket(stack) then
			return stack:get_count()
		else
			return 0
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
		return 0
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
			 ["running"] = "#BFFFBF",
			 ["true"] = "#BFFFBF",
			 ["false"] = "#BFFFFF" }
	local state = tubelib.statestring(meta:get_int("running"))
	local pipe = tostring(biogasmachines.is_pipe_with_water(pos, node))
	minetest.chat_send_player(player_name,
		minetest.colorize("#FFFF00", "[WaterFreezer:" ..
		meta:get_string("number") .. "]") .. " Status is " ..
		minetest.colorize(msgclr[state], "\"" .. state .. "\"") ..
		", water pipe is " ..
		minetest.colorize(msgclr[pipe], "\"" .. pipe .. "\""))
	return true
end

-- formspec callback
local function on_receive_fields(pos, formname, fields, player)
	if minetest.is_protected(pos, player:get_player_name()) then
		return
	end
	local node = minetest.get_node(pos)
	local meta = minetest.get_meta(pos)
	local number = meta:get_string("number")
	local running = meta:get_int("running")
	local label = minetest.registered_nodes[node.name].description
	if fields and fields.button then
		if running > 0 or running == tubelib.STATE_FAULT then
			freezer_stop(pos)
		else
			freezer_start(pos)
		end
	end
end

-- default Tubelib tick-based item production
local function on_timer(pos, elapsed)
	local node = minetest.get_node(pos)
	local meta = minetest.get_meta(pos)
	local inv = meta:get_inventory()
	local label = minetest.registered_nodes[node.name].description
	local number = meta:get_string("number")
	local running = meta:get_int("running")
	local source = meta:get_int("source")
	local fuelcnt = meta:get_int("fuel_ticks")
	local itemcnt = meta:get_int("item_ticks")
	if fuelcnt == 0 and inv:is_empty("fuel") then
		-- no fuel - no work
		return freezer_stop(pos)
	end
	local pipe = source == SOURCE_PIPE
	if source == SOURCE_EMPTY then
		-- try to start freezing bucket or water from pipe
		pipe = biogasmachines.is_pipe_with_water(pos, node)
		local output = { ItemStack("default:ice 1") }
		if not inv:is_empty("src") then
			-- source: water bucket
			source = SOURCE_BUCKET
			pipe = false
			output[#output + 1] = ItemStack("bucket:bucket_empty 1")
		elseif pipe then
			-- source: water pipe
			source = SOURCE_PIPE
		else
			-- no source, count towards standby
			if running > 0 then
				running = running - 1
				meta:set_int("running", running)
				if running == 0 then
					return freezer_idle(pos)
				end
			end
			return true
		end
		if running == tubelib.STATE_STANDBY then
			-- something to do, wake up and re-entry
			return freezer_start(pos)
		end
		-- check if there is space in output, if not - do nothing
		for _, stack in ipairs(output) do
			if not inv:room_for_item("dst", stack) then
				return true
			end
		end
		-- process another water unit
		if source == SOURCE_BUCKET then
			local inp = get_water_bucket(inv, "src")
			if inp:is_empty() then
				-- oops
				return freezer_fault(pos)
			end
			inv:add_item("cur", inp)
		end
		meta:set_int("source", source)
		itemcnt = ICE_TIME_SEC
		meta:set_int("item_ticks", itemcnt)
	else
		-- continue freezing process - add item tick
		itemcnt = itemcnt - 1
		if itemcnt == 0 then
			inv:add_item("dst", ItemStack("default:ice 1"))
			if source == SOURCE_BUCKET then
				inv:set_stack("cur", 1, ItemStack({}))
				inv:add_item("dst", ItemStack("bucket:bucket_empty 1"))
			end
			meta:set_int("source", SOURCE_EMPTY)
			itemcnt = ICE_TIME_SEC
		end
		meta:set_int("item_ticks", itemcnt)
		-- consume fuel tick
		if fuelcnt == 0 then
			if not inv:is_empty("fuel") then
				inv:remove_item("fuel",
					ItemStack("tubelib_addons1:biogas 1"))
				fuelcnt = BIOGAS_TIME_SEC
			else
				-- oops
				return freezer_fault(pos)
			end
		end
		fuelcnt = fuelcnt - 1
		meta:set_int("fuel_ticks", fuelcnt)
	end
	meta:set_int("running", TICKS_TO_SLEEP)
	meta:set_string("infotext", label .. " " .. number ..
		": running (water " ..
		(pipe and "from pipe" or "in buckets") .. ")")
	meta:set_string("formspec", formspec(tubelib.RUNNING, pipe,
		100 * fuelcnt / BIOGAS_TIME_SEC,
		100 * (ICE_TIME_SEC - itemcnt) / ICE_TIME_SEC, true))
	return true
end

--[[
	-----------------
	Node registration
	-----------------
]]--

minetest.register_node("biogasmachines:freezer", {
	-- TODO: textures
	description = "Tubelib Water Freezer",
	tiles = {
		-- up, down, right, left, back, front
		"tubelib_front.png",
		"tubelib_front.png",
		"tubelib_front.png",
		"tubelib_front.png",
		"tubelib_front.png",
		"default_steel_block.png",
	},

	paramtype = "light",
	sunlight_propagates = true,
	paramtype2 = "facedir",
	groups = { choppy = 2, cracky = 2, crumbly = 2 },
	is_ground_content = false,
	sounds = default.node_sound_metal_defaults(),

	pipe_connections = { top = 1,
			     bottom = 1,
			     front = 1,
			     back = 1,
			     left = 1,
			     right = 1 },
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
		local number = tubelib.add_node(pos, "biogasmachines:freezer")
		if minetest.get_modpath("pipeworks") then
			pipeworks.scan_for_pipe_objects(pos)
		end
		local inv = meta:get_inventory()
		inv:set_size('src', INV_H * INV_IN_W)
		inv:set_size('cur', 1)
		inv:set_size('fuel', 1)
		inv:set_size('dst', INV_H * INV_OUT_W)
		local label = minetest.registered_nodes[node.name].description
		meta:set_string("number", number)
		meta:set_string("owner", placer:get_player_name())
		meta:set_int("running", tubelib.STATE_STOPPED)
		meta:set_int("source", SOURCE_EMPTY)
		meta:set_int("fuel_ticks", 0)
		meta:set_int("item_ticks", 0)
		meta:set_string("infotext", label .. " " .. number .. ": stopped")
		meta:set_string("formspec", formspec(tubelib.STOPPED, false, 0, 0, true))
	end,
})

minetest.register_node("biogasmachines:freezer_active", {
	-- TODO: textures
	description = "Tubelib Water Freezer",
	tiles = {
		-- up, down, right, left, back, front
		"tubelib_front.png",
		"tubelib_front.png",
		"tubelib_front.png",
		"tubelib_front.png",
		"tubelib_front.png",
		"default_ice.png",
	},

	paramtype = "light",
	sunlight_propagates = true,
	paramtype2 = "facedir",
	groups = { crumbly = 0, not_in_creative_inventory = 1 },
	is_ground_content = false,
	sounds = default.node_sound_metal_defaults(),

	pipe_connections = { top = 1,
			     bottom = 1,
			     front = 1,
			     back = 1,
			     left = 1,
			     right = 1 },

	can_dig = can_dig,
	after_dig_node = after_dig_node,
	on_punch = on_punch,
	on_rotate = screwdriver.disallow,
	on_timer = on_timer,
	on_receive_fields = on_receive_fields,
	allow_metadata_inventory_put = allow_metadata_inventory_put,
	allow_metadata_inventory_move = allow_metadata_inventory_move,
	allow_metadata_inventory_take = allow_metadata_inventory_take,
	drop = "biogasmachines:freezer",
})

tubelib.register_node("biogasmachines:freezer", { "biogasmachines:freezer_active" }, {

	on_push_item = function(pos, side, item)
		local meta = minetest.get_meta(pos)
		if is_water_bucket(item) then
			return tubelib.put_item(meta, "src", item)
		elseif item:get_name() == "tubelib_addons1:biogas" then
			return tubelib.put_item(meta, "fuel", item)
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
                        freezer_start(pos)
		elseif topic == "off" then
			freezer_stop(pos)
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
	output = "biogasmachines:freezer",
	recipe = {
		{ "default:steelblock", "default:glass", "default:steelblock" },
		{ "default:mese_crystal", "bucket:bucket_empty", "tubelib:tube1" },
		{ "group:wood", "default:copper_ingot", "group:wood" },
	},
})

if minetest.get_modpath("unified_inventory") then
	unified_inventory.register_craft_type("freezing", {
		description = "Freezing",
		icon = 'biogasmachines_freezer_inv_fg.png',
		width = 1,
		height = 1,
	})
	for _, i in ipairs(water_buckets) do
		unified_inventory.register_craft({
			type = "freezing",
			items = { i },
			output = "default:ice",
		})
	end
end
