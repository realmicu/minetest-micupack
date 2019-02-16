--[[

	=======================================================
	SmartLine Modules
	by Micu (c) 2018, 2019

	This file contains:
	* Furnace Monitor
	* Digital Switch
	* AutoSieve Sensor

	*** Furnace Monitor ***

	Monitor Minetest Game standard furnace with
	Tubelib/Smartline devices like Controllers.
	It is a one-way (read-only) gateway that converts
	furnace operational status to Tubelib states.

	States are read through standard Tubelib status query
	(for example $get_status(...) function in SaferLua
	Controller).

	Device checks attached node only when status is
	requested so it does not consume CPU resources
	when idle.

	Placement: place on any side of a furnace, make
	sure back plate of device has contact with
	monitored node. In case of wrong orientation use
	screwdriver.

	Status:
	"fault" - monitor is not placed on a furnace
	"stopped" - furnace is not smelting/cooking
	"running" - furnace is smelting/cooking items
	"standby" - furnace is burning fuel but there
		    are no items loaded

	Punch node to see current status.

	*** Digital Switch ***

	Configurable multi-state switch panel with
	one-digit simple decimal LCD display. Its purpose is
	to enhance SaferLua Controller functionality by
	providing selectable input via standard Tubelib
	messaging. SL Controller is now able to perform
	different actions depending on value selected on panel.

	Right after placement, panel is in setup mode and
	should be configured; after successful configration,
	setup screen is no longer accessible. To change
	parameters again, simply collect and redeploy node.

	Switch value setting is changed with right click,
	like standard Tubelib buttons.

	To get value currently set on panel, query its status
	using SaferLua $get_status(NUMBER) function which
	returns "0" through "9" or "off" if panel is
	unconfigured. When panel is connected to Controller(s)
	(one or more numbers supplied on initial configuration
	screen), switch sends "on" events every time it is
	changed (please note Controller limit of one event per
	second!)

	Status (read):
	"0" .. "9" - current value
	"off" - placed but not yet configured

	Events (sent when connected to specific Controllers):
	"on" - on digit change

	*** AutoSieve Sensor ***

	This node is a sensor pad for Techpack Automated Gravel
	Sieve. Although AutoSieve can interact with Tubelib
	machinery like any other Techpack machine, it does
	not have Tubelib ID, so it cannot be controlled or
	monitored. Sensor pad node should be placed UNDER
	AutoSieve. It gets standard ID and its working
	principle is identical to Furnace Monitor.

	Sensor states are read through standard Tubelib status
	query (for example $get_status(...) function in
	SaferLua Controller). Item count is also supported
	($get_counter(...) command returns number of sieve
	items processed).

	Device checks attached node only when status is
	requested so it does not consume CPU resources when
	idle.

	Placement: place directly under Automated Gravel Sieve.

	Status:
	"fault" - there is no AutoSieve above sensor node
	"stopped" - AutoSieve is not working
	"running" - AutoSieve is running
	"defect" - AutoSieve is broken and needs to be
		   repaired

	Note: there is no "standby" state.

	Punch node to see current status.

	License: LGPLv2.1+
	=======================================================

]]--


slmodules = {}

--[[
	-------
	Helpers
	-------
]]--

-- get furnace status as tubelib text string:
-- not a furnace node = "fault"
-- furnace not burning = "stopped"
-- furnace smelting items = "running"
-- furnace burning without items = "standby"
local function get_tubelib_furnace_state(monitor_pos, monitor_node)
	local monnode = monitor_node or minetest.get_node(monitor_pos)
	local pos = vector.add(monitor_pos,
		minetest.facedir_to_dir(monnode.param2))
	local node = minetest.get_node(pos)
	local meta = minetest.get_meta(pos)
	if node.name == "default:furnace" then
		return tubelib.StateStrings[tubelib.STOPPED]
	elseif node.name == "default:furnace_active" then
		local inv = meta:get_inventory()
		if inv:is_empty("src") then
			return tubelib.StateStrings[tubelib.STANDBY]
		else
			return tubelib.StateStrings[tubelib.RUNNING]
		end
	end
	return tubelib.StateStrings[tubelib.FAULT]
end

-- get AutoSieve status as tubelib text string:
-- not an AutoSieve node = "fault"
-- AutoSieve not working = "stopped"
-- AutoSieve processing gravel = "running"
-- AutoSieve broken due to aging = "defect"
-- (pos is sensor node position)
local function get_tubelib_autosieve_state(pos)
	local sievepos = vector.add(pos, { x = 0, y = 1, z = 0 })
	local node = minetest.get_node(sievepos)
	-- (we won't fire regexp cannon on mere 4 strings...)
	if node.name == "gravelsieve:auto_sieve0" or
	   node.name == "gravelsieve:auto_sieve1" or
	   node.name == "gravelsieve:auto_sieve2" or
	   node.name == "gravelsieve:auto_sieve3" then
		if minetest.get_node_timer(sievepos):is_started() then
			return tubelib.StateStrings[tubelib.RUNNING]
		else
			return tubelib.StateStrings[tubelib.STOPPED]
		end
	elseif node.name == "gravelsieve:sieve_defect" then
		return tubelib.StateStrings[tubelib.DEFECT]
	end
	return tubelib.StateStrings[tubelib.FAULT]
end

-- get AutoSieve item counter
-- (pos is sensor node position)
local function get_tubelib_autosieve_counter(pos)
	local sievepos = vector.add(pos, { x = 0, y = 1, z = 0 })
	local node = minetest.get_node(sievepos)
	if node.name == "gravelsieve:auto_sieve0" or
	   node.name == "gravelsieve:auto_sieve1" or
	   node.name == "gravelsieve:auto_sieve2" or
	   node.name == "gravelsieve:auto_sieve3" or
	   node.name == "gravelsieve:sieve_defect" then
		local meta = minetest.get_meta(sievepos)
		return meta:get_int("gravel_cnt") or 0
	end
	return -1
end

-- convert string to char table
-- return: char table, indexed set
local function string_to_char_table(str)
	local strtbl = {}
	local idxtbl = {}
	for i = 1, string.len(str) do
		local c = string.sub(str, i, i)
		strtbl[#strtbl + 1] = c
		idxtbl[c] = true
	end
	return strtbl, idxtbl
end

-- do not allow to dig protected node
local function can_dig(pos, player)
	if minetest.is_protected(pos, player:get_player_name()) then
		return false
	end
	return true
end

-- cleanup after digging
local function after_dig_node(pos, oldnode, oldmetadata, digger)
	tubelib.remove_node(pos)
end

-- change digit (configured only)
local function on_rightclick(pos, node, clicker, itemstack, pointed_thing)
	local meta = minetest.get_meta(pos)
	local number = meta:get_string("own_num")
	local numbers = meta:get_string("numbers") or ""
	local digits = meta:get_string("digits")
	local index = meta:get_int("index")
	local dir = meta:get_int("direction")
	local digtbl = string_to_char_table(digits)
	index = index + dir
	if index > #digtbl then
		index = 1
	elseif index < 1 then
		index = #digtbl
	end
	meta:set_int("index", index)
	node.name = "slmodules:digitalswitch" .. digtbl[index]
	minetest.swap_node(pos, node)
	minetest.sound_play("button", {
		pos = pos,
		gain = 0.5,
		max_hear_distance = 5,
	})
	if numbers ~= "" then
		-- send message: topic = "on", payload = "NUMBER"
		tubelib.send_message(numbers, meta:get_string("owner"),
			clicker:get_player_name(), "on", number)
	end
end

--[[
	--------
	Formspec
	--------
]]--

-- configuration formspec
local function formspec(meta)
	local number = meta:get_string("own_num")
	local dir = meta:get_int("direction") > 0 and "1" or "2"
	local cbdigits = meta:get_string("cbdigits")
	local _, cbset = string_to_char_table(cbdigits)
	local cbox = ""
	for i = 0, 9 do
		local c = tostring(i)
		cbox = cbox .. "checkbox[" .. tostring(2.2 + i * 0.6) ..
			",1.8;digit_" .. c .. ";" .. c .. ";" ..
			(cbset[c] and "true" or "false") .. "]"
	end
	return "size[8.4,3.6]" ..
	"label[3,0;" .. minetest.colorize("#FFFF00", "Digital Switch Panel ") ..
		minetest.colorize("#00FFFF", number) .. "]" ..
	"label[0,1;Enter destination number(s) (optional)]" ..
	"field[4,1.1;4.5,1;numbers;;${numbers}]" ..
	"field_close_on_enter[numbers;true]" ..
	"label[0,2;Select allowed digits]" .. cbox ..
	"label[0,3;Change direction]" ..
	"dropdown[2,2.9;1.6;dir;up,down;" .. dir .. "]" ..
	"button_exit[5.2,2.8;1.5,1;ok;OK]" ..
	"button_exit[6.8,2.8;1.5,1;cancel;Cancel]"
end

--[[
	-----------------
	Node registration
	-----------------
]]--

minetest.register_node("slmodules:furnacemonitor", {
	description = "SmartLine Furnace Monitor",
	inventory_image = "furnacemonitor_inventory.png",
	tiles = {
		-- up, down, right, left, back, front
		"smartline.png",
		"smartline.png",
		"smartline.png",
		"smartline.png",
		"smartline.png",
		"smartline.png^furnacemonitor_flame_black.png",
	},

	drawtype = "nodebox",
	node_box = {
		type = "fixed",
		fixed = {
			{ -6/32, -6/32, 14/32,  6/32,  6/32, 16/32},
		},
	},

	after_place_node = function(pos, placer, itemstack, pointed_thing)
		local meta = minetest.get_meta(pos)
		local number = tubelib.add_node(pos, "slmodules:furnacemonitor")
		meta:set_string("number", number)
		meta:set_string("infotext", "Furnace Monitor " .. number)
		meta:set_string("owner", placer:get_player_name())
	end,

	can_dig = can_dig,
	after_dig_node = after_dig_node,

	on_punch = function(pos, node, puncher, pointed_thing)
		local meta = minetest.get_meta(pos)
		local player_name = puncher:get_player_name()
		if meta:get_string("owner") ~= player_name then
			return false
		end
		local state = get_tubelib_furnace_state(pos, node)
		local msgclr = { ["fault"] = "#FFBFBF",
				 ["standby"] = "#BFFFFF",
				 ["stopped"] = "#BFBFFF",
				 ["running"] = "#BFFFBF" }
		minetest.chat_send_player(player_name,
			minetest.colorize("#FFFF00", "[FurnaceMonitor:" ..
			meta:get_string("number") .. "]") .. " Status is " ..
			minetest.colorize(msgclr[state],
			"\"" .. state .. "\""))
		return true
	end,

	paramtype = "light",
	sunlight_propagates = true,
	paramtype2 = "facedir",
	groups = { cracky = 2, crumbly = 2 },
	is_ground_content = false,
	sounds = default.node_sound_metal_defaults(),
})

minetest.register_node("slmodules:digitalswitch", {
	description = "SmartLine Digital Switch",
	inventory_image = "slmodules_digitalswitch_inv.png",
	tiles = {
		-- up, down, right, left, back, front
		"smartline.png",
		"smartline.png",
		"smartline.png",
		"smartline.png",
		"smartline.png",
		"smartline.png^slmodules_digitalswitch.png",
	},

	drawtype = "nodebox",
	node_box = {
		type = "fixed",
		fixed = {
			{ -6/32, -6/32, 14/32,  6/32,  6/32, 16/32},
		},
	},

	after_place_node = function(pos, placer, itemstack, pointed_thing)
		local meta = minetest.get_meta(pos)
		local number = tubelib.add_node(pos, "slmodules:digitalswitch")
		meta:set_string("own_num", number)
		meta:set_string("infotext", "Digital Switch " ..
			number .. " (unconfigured)")
		meta:set_string("owner", placer:get_player_name())
		meta:set_string("numbers", "")
		meta:set_string("digits", "0123456789")
		meta:set_string("cbdigits", "0123456789")	-- checkbox states
		meta:set_int("direction", 1)	-- 1 = up, -1 = down
		meta:set_int("index", -1)	-- selection index (not value)
		meta:set_string("formspec", formspec(meta))
	end,

	can_dig = can_dig,
	after_dig_node = after_dig_node,
	on_receive_fields = function(pos, formname, fields, sender)
		if minetest.is_protected(pos, sender:get_player_name()) then
			return
		end
		-- workaround for checkbox behaviour of not being
		-- sent on formspec closing
		local checkbox = false
		for i = 0, 9 do
			if fields["digit_" .. i] then
				checkbox = true
			end
		end
		local meta = minetest.get_meta(pos)
		if checkbox then
			local cbdigits = meta:get_string("cbdigits")
			local _, cbset = string_to_char_table(cbdigits)
			cbdigits = ""
			for i = 0, 9 do
				local c = tostring(i)
				local f = "digit_" .. c
				if fields[f] == "true" then
					cbset[c] = true
				elseif fields[f] == "false" then
					cbset[c] = false
				end
				if cbset[c] then
					cbdigits = cbdigits .. c
				end
			end
			meta:set_string("cbdigits", cbdigits)
		end
		-- buttons
		if fields.ok or fields.key_enter_field == "numbers" then
			local number = meta:get_string("own_num")
			local numbers = fields.numbers and fields.numbers:trim() or ""
			local cbdigits = meta:get_string("cbdigits")
			if string.len(cbdigits) == 0 then
				meta:set_string("cbdigits", "0123456789")
				return
			end
			meta:set_string("digits", cbdigits)
			meta:set_string("cbdigits", "")
			meta:set_string("numbers", numbers)
			meta:set_int("direction", fields.dir == "up" and 1 or -1)
			meta:set_int("index", 1)
			meta:set_string("infotext", "Digital Switch " ..
				number .. (numbers ~= "" and
				" (connected with: " .. numbers .. ")" or ""))
			meta:set_string("formspec", "")
			local node = minetest.get_node(pos)
			local digtbl = string_to_char_table(cbdigits)
			node.name = "slmodules:digitalswitch" .. digtbl[1]
			minetest.swap_node(pos, node)
		elseif fields.cancel or fields.quit then
			meta:set_string("cbdigits", "0123456789")
		end
	end,

	paramtype = "light",
	sunlight_propagates = true,
	paramtype2 = "facedir",
	groups = { cracky = 2, crumbly = 2 },
	is_ground_content = false,
	sounds = default.node_sound_metal_defaults(),
})

local digitalswitchnodes = {}
for i = 0, 9 do
	minetest.register_node("slmodules:digitalswitch" .. i, {
		description = "SmartLine Digital Switch",
		tiles = {
			-- up, down, right, left, back, front
			"smartline.png",
			"smartline.png",
			"smartline.png",
			"smartline.png",
			"smartline.png",
			"smartline.png^slmodules_digitalswitch_" .. i .. ".png",
		},

		drawtype = "nodebox",
		node_box = {
			type = "fixed",
			fixed = {
				{ -6/32, -6/32, 14/32,  6/32,  6/32, 16/32},
			},
		},

		can_dig = can_dig,
		after_dig_node = after_dig_node,
		on_rightclick = on_rightclick,

		paramtype = "light",
		sunlight_propagates = true,
		paramtype2 = "facedir",
		groups = { cracky = 2, crumbly = 2, not_in_creative_inventory = 1 },
		is_ground_content = false,
		sounds = default.node_sound_metal_defaults(),
		drop = "slmodules:digitalswitch",
	})
	digitalswitchnodes[#digitalswitchnodes + 1] = "slmodules:digitalswitch" .. i
end

minetest.register_node("slmodules:autosievesensor", {
	description = "SmartLine AutoSieve Sensor",
	tiles = {
		-- up, down, right, left, back, front
		"slmodules_autosievesensor_top.png",
		"slmodules_autosievesensor_bottom.png",
		"slmodules_autosievesensor_side.png",
		"slmodules_autosievesensor_side.png",
		"slmodules_autosievesensor_side.png",
		"slmodules_autosievesensor_side.png",
	},
	drawtype = "nodebox",

	after_place_node = function(pos, placer, itemstack, pointed_thing)
		local meta = minetest.get_meta(pos)
		local number = tubelib.add_node(pos, "slmodules:autosievesensor")
		meta:set_string("number", number)
		meta:set_string("infotext", "AutoSieve Sensor " .. number)
		meta:set_string("owner", placer:get_player_name())
	end,

	can_dig = can_dig,
	after_dig_node = after_dig_node,

	on_punch = function(pos, node, puncher, pointed_thing)
		local meta = minetest.get_meta(pos)
		local player_name = puncher:get_player_name()
		if meta:get_string("owner") ~= player_name then
			return false
		end
		local state = get_tubelib_autosieve_state(pos)
		local msgclr = { ["fault"] = "#FFBFBF",
				 ["defect"] = "#FFBFBF",
				 ["stopped"] = "#BFBFFF",
				 ["running"] = "#BFFFBF" }
		minetest.chat_send_player(player_name,
			minetest.colorize("#FFFF00", "[AutoSieveSensor:" ..
			meta:get_string("number") .. "]") .. " Status is " ..
			minetest.colorize(msgclr[state],
			"\"" .. state .. "\""))
		return true
	end,

	on_rotate = screwdriver.disallow,
	paramtype = "light",
	sunlight_propagates = true,
	paramtype2 = "facedir",
	groups = { choppy = 2, cracky = 2, crumbly = 2 },
	is_ground_content = false,
	sounds = default.node_sound_metal_defaults(),
})

tubelib.register_node("slmodules:furnacemonitor", {}, {
	on_recv_message = function(pos, topic, payload)
		if topic == "state" then
			return get_tubelib_furnace_state(pos)
		else
			return "unsupported"
		end
	end,
})

tubelib.register_node("slmodules:digitalswitch", digitalswitchnodes, {
	on_recv_message = function(pos, topic, payload)
		if topic == "state" then
			local meta = minetest.get_meta(pos)
			local digits = meta:get_string("digits")
			local index = meta:get_int("index")
			local digtbl = string_to_char_table(digits)
			if index < 1 or index > #digtbl then
				return "off"
			else
				return digtbl[index]
			end
		else
			return "unsupported"
		end
	end,
})

tubelib.register_node("slmodules:autosievesensor", {}, {
	on_recv_message = function(pos, topic, payload)
		if topic == "state" then
			return get_tubelib_autosieve_state(pos)
		elseif topic == "counter" then
			return get_tubelib_autosieve_counter(pos)
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
	output = "slmodules:furnacemonitor",
	type = "shaped",
	recipe = {
		{ "", "default:tin_ingot", "" },
		{ "dye:blue", "default:copper_ingot", "tubelib:wlanchip" },
		{ "", "dye:black", "" },
	},
})

minetest.register_craft({
	output = "slmodules:digitalswitch",
	type = "shaped",
	recipe = {
		{ "", "default:glass", "" },
		{ "dye:blue", "default:copper_ingot", "tubelib:wlanchip" },
		{ "", "dye:green", "" },
	},
})

minetest.register_craft({
	output = "slmodules:autosievesensor",
	type = "shaped",
	recipe = {
		{ "default:copperblock", "default:steel_ingot", "default:copperblock" },
		{ "dye:blue", "default:mese_crystal", "tubelib:wlanchip" },
		{ "group:wood", "default:steel_ingot", "group:wood" },
	},
})

--[[
	---------------------
	FurnaceMonitor update
	---------------------
]]--

minetest.register_lbm({
	label = "FurnaceMonitor update",
	name = "slmodules:furnacemonitor_update",
	nodenames = { "furnacemonitor:furnacemonitor", },
	run_at_every_load = true,
	action = function(pos, node)
		node.name = "slmodules:furnacemonitor"
		minetest.swap_node(pos, node)
	end
})
