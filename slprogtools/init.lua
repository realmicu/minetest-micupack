--[[

	===============================================
	Smartline SaferLua Controller Programming Tools
	by Micu (c) 2018

	This file contains:
	* Memory Copier for SaferLua Controller

	Notice: SaferLua Controller uses node formspec
	so please switch to 'outp' or 'help' tab for
	upload data to all 3 meta strings (must not be
	an active tab)

	License: LGPLv2.1+
	===============================================

]]--


slprogtools = {}

--[[
	---------
	Variables
	---------
]]--

-- saferlua ctrl initial texts (should not be empty to not confuse metadata)
local init_empty = "--"
local loop_empty = "--"
local note_empty = "--"

-- colors
local msg_W = minetest.get_color_escape_sequence("#FFFFFF")
local msg_Y = minetest.get_color_escape_sequence("#FFFF00")
local msg_C = minetest.get_color_escape_sequence("#00FFFF")
local msg_M = minetest.get_color_escape_sequence("#FF00FF")
local msg_R = minetest.get_color_escape_sequence("#FFBFBF")

--[[
	---------------
	Sound functions
	---------------
]]--

local function play_beep_ok(player_name)
	minetest.sound_play("slprogtools_beep_ok", {
		to_player = player_name,
		gain = 0.8,
	})
end
local function play_beep_err(player_name)
	minetest.sound_play("slprogtools_beep_err", {
		to_player = player_name,
		gain = 0.5,
	})
end
local function play_click(player_name)
	minetest.sound_play("slprogtools_click", {
		to_player = player_name,
		gain = 0.6,
	})
end

--[[
	---------------
	Device formspec
	---------------
]]--

local function formspec(tool, tubelib_id)
	-- function requires all metadata to be accessible
	-- (or initialized elsewhere)
	local tool_def = tool:get_definition()
	local label = tool_def.description
	local tool_meta = tool:get_meta()
	local init_flag = tool_meta:get_int("init_flag") ~= 0
	local loop_flag = tool_meta:get_int("loop_flag") ~= 0
	local note_flag = tool_meta:get_int("note_flag") ~= 0
	local init_len = string.len(tool_meta:get_string("init_code"))
	local loop_len = string.len(tool_meta:get_string("loop_code"))
	local note_len = string.len(tool_meta:get_string("note_text"))
	return "size[7,4,true]"..
	"position[0.5,0.25]" ..
	"no_prepend[]" ..
	"label[1.5,0;" .. minetest.colorize("#FFFF00", label) .. "]" ..
	"label[0.5,1;" ..
		minetest.colorize("#00FFFF",
		"Connected to controller " .. tubelib_id) .. "]" ..
	"checkbox[0.5,1.5;init_flag;include " .. msg_M .. "init()" .. msg_W ..
		" code (size: " .. tostring(init_len) .. ");" ..
		tostring(init_flag) .. "]" ..
	"checkbox[0.5,2.25;loop_flag;include " .. msg_M .. "loop()" .. msg_W ..
		" code (size: " .. tostring(loop_len) .. ");" ..
		tostring(loop_flag) .. "]" ..
	"checkbox[0.5,3;note_flag;include " .. msg_M .. "notes" .. msg_W ..
		" text (size: " .. tostring(note_len) .. ");" ..
		tostring(note_flag) .. "]" ..
	"button_exit[5,0.75;1.5,1;clear;Clear]" ..
	"button_exit[5,1.5;1.5,1;download;Download]" ..
	"button_exit[5,2.25;1.5,1;upload;Upload]" ..
	"button_exit[5,3;1.5,1;exit;Exit]"
end

--[[
	---------------
	Device metadata
	---------------
]]--

local function init_metadata(player, tool)
	-- write correct metadata only if not present
	local tool_meta = tool:get_meta()
	local tool_upd = false
	local metatable = tool_meta:to_table()
	if not metatable.fields["init_flag"] then
		tool_meta:set_int("init_flag", 1)
		tool_upd = true
	end
	if not metatable.fields["loop_flag"] then
		tool_meta:set_int("loop_flag", 1)
		tool_upd = true
	end
	if not metatable.fields["note_flag"] then
		tool_meta:set_int("note_flag", 1)
		tool_upd = true
	end
	if not metatable.fields["init_code"] then
		tool_meta:set_string("init_code", init_empty)
		tool_upd = true
	end
	if not metatable.fields["loop_code"] then
		tool_meta:set_string("loop_code", loop_empty)
		tool_upd = true
	end
	if not metatable.fields["note_text"] then
		tool_meta:set_string("note_text", note_empty)
		tool_upd = true
	end
	-- all done
	if tool_upd then player:set_wielded_item(tool) end
	return tool_upd
end

--[[
	-----------
	Main Window
	-----------
]]--

-- formspec callback
minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "slprogtools:slc_memory_copier" then
		return false
	end
	if not fields then return true end
	local player_name = player:get_player_name()
	local tool = player:get_wielded_item()
	local label = tool:get_definition()._label
	local tool_meta = tool:get_meta()
	local tool_upd = false
	local play_snd = true
	if fields.clear or fields.download or fields.upload
		or fields.exit or fields.quit then
		play_snd = false
	end
	if fields.init_flag then
		tool_meta:set_int("init_flag", fields.init_flag == "true" and 1 or 0)
		if play_snd then play_click(player_name) end
		tool_upd = true
	end
	if fields.loop_flag then
		tool_meta:set_int("loop_flag", fields.loop_flag == "true" and 1 or 0)
		if play_snd then play_click(player_name) end
		tool_upd = true
	end
	if fields.note_flag then
		tool_meta:set_int("note_flag", fields.note_flag == "true" and 1 or 0)
		if play_snd then play_click(player_name) end
		tool_upd = true
	end
	if tool_upd then
		player:set_wielded_item(tool)  -- update data for buttons
		tool_upd = false
	end
	if fields.clear or fields.download or fields.upload then
		local slc_pos = minetest.deserialize(
			tool_meta:get_string("lua_pos"))
		local slc_meta = minetest.get_meta(slc_pos)
		local slc_id =slc_meta:get_string("number")
		local init_flag = tool_meta:get_int("init_flag") ~= 0
		local loop_flag = tool_meta:get_int("loop_flag") ~= 0
		local note_flag = tool_meta:get_int("note_flag") ~= 0
		local clr_list = {}
		if fields.clear then
			if init_flag then
				tool_meta:set_string("init_code", init_empty)
				clr_list[#clr_list + 1] =  "init"
				tool_upd = true
			end
			if loop_flag then
				tool_meta:set_string("loop_code", loop_empty)
				clr_list[#clr_list + 1] = "loop"
				tool_upd = true
			end
			if note_flag then
				tool_meta:set_string("note_text", note_empty)
				clr_list[#clr_list + 1] = "notes"
				tool_upd = true
			end
			play_click(player_name)
			minetest.chat_send_player(player_name,
				msg_Y .. "[" .. label .. "] " .. msg_W ..
				"Memory cleared (" ..
				table.concat(clr_list, ", ") .. ")")
		elseif fields.download then
			local init_len, loop_len, note_len = -1, -1, -1
			if init_flag then
				tool_meta:set_string("init_code",
					slc_meta:get_string("init"))
				init_len = string.len(
					tool_meta:get_string("init_code"))
				tool_upd = true
			end
			if loop_flag then
				tool_meta:set_string("loop_code",
					slc_meta:get_string("loop"))
				loop_len = string.len(
					tool_meta:get_string("loop_code"))
				tool_upd = true
			end
			if note_flag then
				tool_meta:set_string("note_text",
					slc_meta:get_string("notes"))
				note_len = string.len(
					tool_meta:get_string("note_text"))
				tool_upd = true
			end
			play_beep_ok(player_name)
			minetest.chat_send_player(player_name,
				msg_Y .. "[" .. label .. "] " .. msg_W ..
				"Download from " .. msg_M .. slc_id .. msg_W ..
				" completed (" .. msg_C .. "init " .. msg_W ..
				(init_len < 0 and "skipped" or tostring(init_len) .. " bytes")
				.. msg_C .. ", loop " .. msg_W ..
				(loop_len < 0 and "skipped" or tostring(loop_len) .. " bytes")
				.. msg_C .. ", notes " .. msg_W ..
				(note_len < 0 and "skipped" or tostring(note_len) .. " bytes)"))
		elseif fields.upload then
			local init_len, loop_len, note_len = -1, -1, -1
			if slc_meta:get_int("state") ~= tubelib.STOPPED then
				play_beep_err(player_name)
				minetest.close_formspec(player_name, formname)
				minetest.chat_send_player(player_name,
					msg_Y .. "[" .. label .. "] " .. msg_R ..
					"Cannot upload to running system!")
				return true
			end
			if init_flag then
				slc_meta:set_string("init",
					tool_meta:get_string("init_code"))
				init_len = string.len(
					slc_meta:get_string("init"))
			end
			if loop_flag then
				slc_meta:set_string("loop",
					tool_meta:get_string("loop_code"))
				loop_len = string.len(
					slc_meta:get_string("loop"))
			end
			if note_flag then
				slc_meta:set_string("notes",
					tool_meta:get_string("note_text"))
				note_len = string.len(
					slc_meta:get_string("notes"))
			end
			play_beep_ok(player_name)
			minetest.chat_send_player(player_name,
				msg_Y .. "[" .. label .. "] " .. msg_W ..
				"Upload to " .. msg_M .. slc_id .. msg_W ..
				" completed (" .. msg_C .. "init " .. msg_W ..
				(init_len < 0 and "skipped" or tostring(init_len) .. " bytes")
				.. msg_C .. ", loop " .. msg_W ..
				(loop_len < 0 and "skipped" or tostring(loop_len) .. " bytes")
				.. msg_C .. ", notes " .. msg_W ..
				(note_len < 0 and "skipped" or tostring(note_len) .. " bytes)"))
		end
	elseif fields.exit or fields.quit then
		play_click(player_name)
	end
	if tool_upd then player:set_wielded_item(tool) end
	return true
end)

-- show formspec
local function show_menu(item, player, pointed_thing)
	if pointed_thing.type ~= "node" then return nil end
	local player_name = player:get_player_name()
	local tool_def = item:get_definition()
	local label = tool_def._label
	if minetest.get_node(pointed_thing.under).name ~=
		"sl_controller:controller" then
		play_beep_err(player_name)
		return nil
	end
	local slc_meta = minetest.get_meta(pointed_thing.under)
	if slc_meta:get_string("owner") ~= player_name then
		play_beep_err(player_name)
		minetest.chat_send_player(player_name,
			msg_Y .. "[" .. label .. "] " ..
			msg_R ..  "Access denied - not owner!")
		return nil
	end
	tool_def._init_metadata(player, item)
	local tool_meta = item:get_meta()
	tool_meta:set_string("lua_pos",  -- for event function to get meta
		minetest.serialize(pointed_thing.under))
	player:set_wielded_item(item)
	local tubelib_id = slc_meta:get_string("number")
	play_beep_ok(player_name)
        minetest.show_formspec(player_name, tool_def.name,
		tool_def._formspec(item, tubelib_id))
	return item  -- we change metadata so on_use must receive updated item
end

--[[
	-----------------
	Tool registration
	-----------------
]]--

minetest.register_tool("slprogtools:slc_memory_copier", {
	description = "SaferLua Controller Memory Copier",
	wield_image = "slprogtools_memory_copier_hand.png",
	wield_scale = { x = 1, y = 1, z = 1 },
	inventory_image = "slprogtools_memory_copier_inv.png",
	stack_max = 1,
	range = 4,
	_label = "SLCMemoryCopier",
	_init_metadata = init_metadata,
	_formspec = formspec,
	on_use = show_menu,
})

--[[
	--------
	Crafting
	--------
]]--

minetest.register_craft({
	output = "slprogtools:slc_memory_copier",
	type = "shaped",
	recipe = {
		{ "", "default:steel_ingot", "" },
		{ "default:gold_ingot", "tubelib:wlanchip", "default:copper_ingot" },
		{ "", "dye:blue", "" },
	},
})

