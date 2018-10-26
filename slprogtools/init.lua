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
-- default programmer fields
local def_marker = "--@CONF@"
local def_this_var = "THIS"
local def_dev_array = "Machines"

-- colors
local msg_W = minetest.get_color_escape_sequence("#FFFFFF")
local msg_Y = minetest.get_color_escape_sequence("#FFFF00")
local msg_C = minetest.get_color_escape_sequence("#00FFFF")
local msg_M = minetest.get_color_escape_sequence("#FF00FF")
local msg_R = minetest.get_color_escape_sequence("#FFBFBF")

-- help
local help_text = [[SaferLua Controller Memory Programmer

MANUAL

NOTICE: Before accessing SaferLua Controller,
make sure active tab on target controller is
set to either 'outp' or 'help'. Attempt to
write text to active tab silently fails.

This gadget is designed to assist player in
managing SaferLua Controllers and to save
time in deployment and programming of these
useful computers.

Left click on a controller connects to the
computer and displays programmer GUI.
Left click on any Tubelib-compatible machine
stores its number (4-digit unique ID) in
memory. Right click performs quick erase
of this memory area.

Functions (tabs):

* info
  Basic information about connected controller.

* memory
  Memory Copier mode. Allows to transfer 'init',
  'loop' and 'notes' sections between device and
  connected SaferLua Controller. Checkboxes allow
  to select on which memory areas device operates.

* program
  Programmer mode. In many scenarios, SaferLua
  Controller manages Tubelib machines. This mode
  allows to fill a specially marked area in 'init'
  section of controller with collected machine
  numbers organized in array. It also creates
  variable with controller's own number.

  Example:

    Device has collected 3 machine numbers: 0101,
    0202 and 0303. It is connected to controller
    0555. Init section looks like below:
    -- some code
    a = 5
    -- default marker below
    --@CONF@
    -- some other code
    b = 0

    After pressing Rewrite button, init code of
    controller changes to:
    -- some code
    a = 5
    -- default marker below
    THIS = "0555" 
    Machines = Array( "0101", "0202", "0303" )
    -- some other code
    b = 0

* security
  Allows to protect main memory from read or write
  operations (or even both)

* help
  This window.

]]

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

local function formspec_copier(tool, tubelib_id)
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

local function formspec_programmer_info(tool, slc_meta)
	local slc_id = slc_meta:get_string("number")
	local slc_state = slc_meta:get_int("state") == tubelib.STOPPED
		and "stopped" or "running"
	local slc_init_len = string.len(slc_meta:get_string("init"))
	local slc_loop_len = string.len(slc_meta:get_string("loop"))
	local slc_note_len = string.len(slc_meta:get_string("notes"))
	return "tabheader[0,1.75;tab;info,memory,program,security,help;1;false;false]" ..
	"label[0,1.75;Connected to controller " .. msg_C ..
		slc_id .. msg_W .. "]" ..
	"label[0,2.25;Controller is " .. msg_C ..
		slc_state .. msg_W .. "]" ..
	"label[0,3;Code size of " .. msg_M .. "init()" .. msg_W ..
		" section is " .. msg_C .. tostring(slc_init_len) .. msg_W ..
		" bytes]" ..
	"label[0,3.5;Code size of " .. msg_M .. "loop()" .. msg_W ..
		" section is " .. msg_C .. tostring(slc_loop_len) .. msg_W ..
		" bytes]" ..
	"label[0,4;Text size of " .. msg_M .. "notes" .. msg_W ..
		" area is " .. msg_C .. tostring(slc_note_len) .. msg_W ..
		" bytes]" ..
	"button_exit[5,4.75;1.5,0;exit;Exit]"
end

local function formspec_programmer_mem(tool, slc_meta)
	local tool_meta = tool:get_meta()
	local init_flag = tool_meta:get_int("init_flag") ~= 0
	local loop_flag = tool_meta:get_int("loop_flag") ~= 0
	local note_flag = tool_meta:get_int("note_flag") ~= 0
	local init_len = string.len(tool_meta:get_string("init_code"))
	local loop_len = string.len(tool_meta:get_string("loop_code"))
	local note_len = string.len(tool_meta:get_string("note_text"))
	return "tabheader[0,1.75;tab;info,memory,program,security,help;2;false;false]" ..
	"checkbox[0,2;init_flag;include " .. msg_M .. "init()" .. msg_W ..
		" code (" .. msg_C .. tostring(init_len) .. msg_W ..
		" bytes);" .. tostring(init_flag) .. "]" ..
	"checkbox[0,2.5;loop_flag;include " .. msg_M .. "loop()" .. msg_W ..
		" code (" .. msg_C .. tostring(loop_len) .. msg_W ..
		" bytes);" .. tostring(loop_flag) .. "]" ..
	"checkbox[0,3;note_flag;include " .. msg_M .. "notes" .. msg_W ..
		" text (" .. msg_C .. tostring(note_len) .. msg_W ..
		" bytes);" .. tostring(note_flag) .. "]" ..
	"button_exit[5,2.25;1.5,0;clear;Clear]" ..
	"button_exit[5,3;1.5,0;download;Download]" ..
	"button_exit[5,3.75;1.5,0;upload;Upload]" ..
	"button_exit[5,4.75;1.5,0;exit;Exit]"
end

local function formspec_programmer_prog(tool, slc_meta)
	local tool_meta = tool:get_meta()
	local prog_mark = tool_meta:get_string("prog_mark")
	local this_var = tool_meta:get_string("this_var")
	local dev_array = tool_meta:get_string("dev_array")
	local numlist = minetest.deserialize(
		tool_meta:get_string("number_list"))
	return "tabheader[0,1.75;tab;info,memory,program,security,help;3;false;false]" ..
	"label[0,1.75;Machine numbers in memory: " .. msg_C ..
		tostring(#numlist) .. msg_W .. "]" ..
	"label[0,2.75;Substitution marker in init()]" ..
	"field[3.4,3.3;1.75,0;marker_text;;" .. prog_mark .. "]" ..
	"field_close_on_enter[marker_text;false]" ..
	"label[0,3.5;Controller number variable]" ..
	"field[3.4,4.05;1.75,0;slc_var;;" .. this_var .. "]" ..
	"field_close_on_enter[slc_var;false]" ..
	"label[0,4.25;Machine numbers array]" ..
	"field[3.4,4.8;1.75,0;dev_array;;" .. dev_array .. "]" ..
	"field_close_on_enter[dev_array;false]" ..
	"button_exit[5,2.5;1.5,0;erase;Erase]" ..
	"button_exit[5,3.25;1.5,0;rewrite;Rewrite]" ..
	"button_exit[5,4.75;1.5,0;exit;Exit]"
end

local function formspec_programmer_sec(tool, slc_meta)
	local tool_meta = tool:get_meta()
	local ro_flag = tool_meta:get_int("ro_flag") ~= 0
	local wo_flag = tool_meta:get_int("wo_flag") ~= 0
	return "tabheader[0,1.75;tab;info,memory,program,security,help;4;false;false]" ..
	"checkbox[0.5,2;ro_flag;write protection (disable download and clear);" ..
		tostring(ro_flag) .. "]" ..
	"checkbox[0.5,2.5;wo_flag;read protection (disable upload);" ..
		tostring(wo_flag) .. "]" ..
	"button_exit[5,4.75;1.5,0;exit;Exit]"
end

local function formspec_programmer_help(tool, slc_meta)
	return "tabheader[0,1.75;tab;info,memory,program,security,help;5;false;false]" ..
	"textarea[0.25,1.75;7,2.75;help;;" .. help_text .. "]" ..
	"button_exit[5,4.75;1.5,0;exit;Exit]"
end

local function formspec_programmer(tool, slc_meta, tab_idx)
	-- function requires all metadata to be accessible
	-- (or initialized elsewhere)
	local tool_def = tool:get_definition()
	local label = tool_def.description
	local formspec_header = "size[7,5.25,true]" ..
		"position[0.5,0.25]" ..  "no_prepend[]" ..
		"label[1.25,0;" .. minetest.colorize("#FFFF00", label) .. "]"
	if not tab_idx or tab_idx == 1 then
		-- info
		return formspec_header ..
			formspec_programmer_info(tool, slc_meta)
	elseif tab_idx == 2 then
		-- memory
		return formspec_header ..
			formspec_programmer_mem(tool, slc_meta)
	elseif tab_idx == 3 then
		-- program
		return formspec_header ..
			formspec_programmer_prog(tool, slc_meta)
	elseif tab_idx == 4 then
		-- security
		return formspec_header ..
			formspec_programmer_sec(tool, slc_meta)
	elseif tab_idx == 5 then
		-- help
		return formspec_header ..
			formspec_programmer_help(tool, slc_meta)
	end
end

--[[
	---------------
	Device metadata
	---------------
]]--

local function init_metadata_copier(player, tool)
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

local function init_metadata_programmer(player, tool)
	-- write correct metadata only if not present
	local tool_meta = tool:get_meta()
	local tool_upd = false
	local metatable = tool_meta:to_table()
	if not metatable.fields["wo_flag"] then
		tool_meta:set_int("wo_flag", 0)
		tool_upd = true
	end
	if not metatable.fields["ro_flag"] then
		tool_meta:set_int("ro_flag", 0)
		tool_upd = true
	end
	if not metatable.fields["prog_mark"] then
		tool_meta:set_string("prog_mark", def_marker)
		tool_upd = true
	end
	if not metatable.fields["this_var"] then
		tool_meta:set_string("this_var", def_this_var)
		tool_upd = true
	end
	if not metatable.fields["dev_array"] then
		tool_meta:set_string("dev_array", def_dev_array)
		tool_upd = true
	end
	if not metatable.fields["number_list"] then
		tool_meta:set_string("number_list", minetest.serialize({}))
		tool_upd = true
	end
	if tool_upd then player:set_wielded_item(tool) end
	-- copier metadata is part of device
	return init_metadata_copier(player, tool) or tool_upd
end

--[[
	-----------
	Main Window
	-----------
]]--

-- formspec callback
minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "slprogtools:slc_memory_copier" and
	   formname ~= "slprogtools:slc_memory_programmer" then
		return false
	end
	if not fields then return true end
	local player_name = player:get_player_name()
	local tool = player:get_wielded_item()
	local tool_def = tool:get_definition()
	local label = tool_def._label
	local tool_meta = tool:get_meta()
	local slc_pos = minetest.deserialize(
		tool_meta:get_string("lua_pos"))
	local slc_meta = minetest.get_meta(slc_pos)
	local slc_id = slc_meta:get_string("number")
	local tool_upd = false
	local play_snd = true
	if fields.tab then
		minetest.show_formspec(player_name, tool_def.name,
			tool_def._formspec(tool, slc_meta, tonumber(fields.tab)))
		return true
	end
	if fields.clear or fields.download or fields.upload
		or fields.erase or fields.rewrite
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
	if fields.ro_flag then
		tool_meta:set_int("ro_flag", fields.ro_flag == "true" and 1 or 0)
		if play_snd then play_click(player_name) end
		tool_upd = true
	end
	if fields.wo_flag then
		tool_meta:set_int("wo_flag", fields.wo_flag == "true" and 1 or 0)
		if play_snd then play_click(player_name) end
		tool_upd = true
	end
	if fields.marker_text then
		local prog_mark = fields.marker_text:trim()
		if prog_mark == "" then prog_mark = def_marker end
		tool_meta:set_string("prog_mark", prog_mark)
		if play_snd then play_click(player_name) end
		tool_upd = true
	end
	if fields.slc_var then
		local this_var = fields.slc_var:trim()
		if this_var == "" then this_var = def_this_var end
		tool_meta:set_string("this_var", this_var)
		if play_snd then play_click(player_name) end
		tool_upd = true
	end
	if fields.dev_array then
		local dev_array = fields.dev_array:trim()
		if dev_array == "" then dev_array = def_dev_array end
		tool_meta:set_string("dev_array", dev_array)
		if play_snd then play_click(player_name) end
		tool_upd = true
	end
	if tool_upd then
		player:set_wielded_item(tool)  -- update data for buttons
		tool_upd = false
	end
	if fields.clear or fields.download or fields.upload then
		-- copier window or memory tab buttons
		-- (this must work also for copier which has no RW flags)
		local ro_flag = tool_meta:get_int("ro_flag") == 1
		local wo_flag = tool_meta:get_int("wo_flag") == 1
		if (fields.clear or fields.download) and ro_flag then
			play_beep_err(player_name)
			minetest.chat_send_player(player_name,
				msg_Y .. "[" .. label .. "] " .. msg_R ..
				"Device memory is write-protected! (see security tab)")
			return true
		elseif fields.upload and wo_flag then
			play_beep_err(player_name)
			minetest.chat_send_player(player_name,
				msg_Y .. "[" .. label .. "] " .. msg_R ..
				"Device memory is read-protected! (see security tab)")
			return true
		end
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
				"Download from " .. msg_C .. slc_id .. msg_W ..
				" completed (init " .. msg_C ..
				(init_len < 0 and "skipped" or tostring(init_len) ..
				msg_W .. " bytes") .. msg_W .. ", loop " .. msg_C ..
				(loop_len < 0 and "skipped" or tostring(loop_len) ..
				msg_W .. " bytes") .. msg_W .. ", notes " .. msg_C ..
				(note_len < 0 and "skipped" or tostring(note_len) ..
				msg_W .. " bytes)"))
		elseif fields.upload then
			local init_len, loop_len, note_len = -1, -1, -1
			if slc_meta:get_int("state") ~= tubelib.STOPPED then
				play_beep_err(player_name)
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
				"Upload to " .. msg_C .. slc_id .. msg_W ..
				" completed (init " .. msg_C ..
				(init_len < 0 and "skipped" or tostring(init_len) ..
				msg_W .. " bytes") .. msg_W .. ", loop " .. msg_C ..
				(loop_len < 0 and "skipped" or tostring(loop_len) ..
				msg_W .. " bytes") .. msg_W .. ", notes " .. msg_C ..
				(note_len < 0 and "skipped" or tostring(note_len) ..
				msg_W .. " bytes)"))
		end
	elseif fields.erase or fields.rewrite then
		-- programmer tab buttons
		if fields.erase then
			tool_meta:set_string("number_list",
				minetest.serialize({}))
			tool_upd = true
			play_click(player_name)
			minetest.chat_send_player(player_name,
				msg_Y .. "[" .. label .. "] " .. msg_W ..
				"All machine numbers erased from memory")
		elseif fields.rewrite then
			if slc_meta:get_int("state") ~= tubelib.STOPPED then
				play_beep_err(player_name)
				minetest.chat_send_player(player_name,
					msg_Y .. "[" .. label .. "] " .. msg_R ..
					"Cannot rewrite code of running system!")
				return true
			end
			local prog_mark = tool_meta:get_string("prog_mark")
			local this_var = tool_meta:get_string("this_var")
			local dev_array = tool_meta:get_string("dev_array")
			local newcode = this_var .. " = \"" ..
				slc_id .. "\"\n" ..dev_array .. " = Array( "
			local numlist = minetest.deserialize(
				tool_meta:get_string("number_list"))
			for i, n in ipairs(numlist) do
				newcode = newcode .. "\"" .. n .. "\""
				if i < #numlist then
					newcode = newcode .. ", "
				end
			end
			newcode = newcode .. " )"
			local init = slc_meta:get_string("init")
			local newinit, replnum = string.gsub(init, prog_mark,
				newcode, 1)
			slc_meta:set_string("init", newinit)
			if replnum > 0 then
				play_beep_ok(player_name)
				minetest.chat_send_player(player_name,
					msg_Y .. "[" .. label .. "] " ..
					msg_W .. "Machine numbers injected into " ..
					msg_C .. slc_id .. msg_W .. " init code")
			else
				play_beep_err(player_name)
				minetest.chat_send_player(player_name,
					msg_Y .. "[" .. label .. "] " .. msg_R ..
					"No marker in code for machine numbers")
				return true
			end
		end
	elseif fields.exit or fields.quit then
		play_click(player_name)
	end
	if tool_upd then player:set_wielded_item(tool) end
	return true
end)

-- show formspec
local function show_menu_copier(item, player, pointed_thing)
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

local function on_use_programmer(item, player, pointed_thing)
	if pointed_thing.type ~= "node" then return nil end
	local player_name = player:get_player_name()
	local tool_def = item:get_definition()
	local label = tool_def._label
	local pt_id = tubelib.get_node_number(pointed_thing.under)
	if not pt_id then
		play_beep_err(player_name)
		minetest.chat_send_player(player_name,
			msg_Y .. "[" .. label .. "] " ..
			msg_R ..  "Incompatible logic - unable to read ID!")
		return nil
	end
	local pt_meta = minetest.get_meta(pointed_thing.under)
	local owner = pt_meta:get_string("owner") or ""
	if owner ~= "" and owner ~= player_name then
		play_beep_err(player_name)
		minetest.chat_send_player(player_name,
			msg_Y .. "[" .. label .. "] " ..
			msg_R ..  "Access denied - not owner!")
		return nil
	end
	tool_def._init_metadata(player, item)
	local tool_meta = item:get_meta()
	if minetest.get_node(pointed_thing.under).name ==
		"sl_controller:controller" then
		-- pointing at SaferLua Controller
		tool_meta:set_string("lua_pos",  -- for event function
		minetest.serialize(pointed_thing.under))
		player:set_wielded_item(item)
		play_beep_ok(player_name)
		minetest.show_formspec(player_name, tool_def.name,
			tool_def._formspec(item, pt_meta, 1))
	else
		-- pointing at Techpack device
		local numlist = minetest.deserialize(
			tool_meta:get_string("number_list"))
		numlist[#numlist + 1] = pt_id
		tool_meta:set_string("number_list", minetest.serialize(numlist))
		play_beep_ok(player_name)
		minetest.chat_send_player(player_name,
			msg_Y .. "[" .. label .. "] " .. msg_W ..
			"Machine with number " .. msg_C .. pt_id ..
			msg_W .. " stored at position " .. msg_M ..
			tostring(#numlist))
	end
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
	_init_metadata = init_metadata_copier,
	_formspec = formspec_copier,
	on_use = show_menu_copier,
})

minetest.register_tool("slprogtools:slc_memory_programmer", {
	description = "SaferLua Controller Memory Programmer",
	wield_image = "slprogtools_memory_programmer_hand.png",
	wield_scale = { x = 1, y = 1, z = 1 },
	inventory_image = "slprogtools_memory_programmer_inv.png",
	stack_max = 1,
	range = 4,
	_label = "SLCMemoryProgrammer",
	_init_metadata = init_metadata_programmer,
	_formspec = formspec_programmer,
	on_use = on_use_programmer,
	on_secondary_use = function(item, user, pointed_thing)
		-- quick erase machine codes
		local player_name = user:get_player_name()
		local label = item:get_definition()._label
		local tool_meta = item:get_meta()
		tool_meta:set_string("number_list",
			minetest.serialize({}))
		play_click(player_name)
		minetest.chat_send_player(player_name,
			msg_Y .. "[" .. label .. "] " .. msg_W ..
			"All machine numbers erased from memory")
		return item
	end
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

minetest.register_craft({
	output = "slprogtools:slc_memory_programmer",
	type = "shapeless",
	recipe = { "slprogtools:slc_memory_copier", "default:mese_crystal", "tubelib_addons2:programmer" },
})
