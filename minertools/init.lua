--[[

	=========================================
	Miner's Electronic Tools by Micu (c) 2018

	License: LGPLv2.1+
	=========================================

]]--


minertools = {}

--[[
	---------
	Variables
	---------
]]--

-- parameters
local light_level = 0
if minetest.settings:get_bool("minertools_flashlight_on") then
	light_level = minetest.LIGHT_MAX
end

-- recognized ores
local find_ore_list = { "coal", "iron", "copper", "tin", "gold",
			"mese", "diamond" }
if minetest.global_exists("moreores") then
	find_ore_list[#find_ore_list + 1] = "silver"
	find_ore_list[#find_ore_list + 1] = "mithril"
end
local scan_ore_list = table.copy(find_ore_list)
scan_ore_list[#scan_ore_list + 1] = "obsidian"

-- colors
local msg_white = minetest.get_color_escape_sequence("#FFFFFF")
local msg_yellow = minetest.get_color_escape_sequence("#FFFF00")
local msg_warn = minetest.get_color_escape_sequence("#FF8080")
local msg_zero = minetest.get_color_escape_sequence("#00FFFF")
local msg_plus = minetest.get_color_escape_sequence("#FF00FF")
local msg_hot = minetest.get_color_escape_sequence("#FFC0C0")
local msg_cold = minetest.get_color_escape_sequence("#C0C0FF")
local msg_high = minetest.get_color_escape_sequence("#52D017")
local msg_medium = minetest.get_color_escape_sequence("#EAC117")
local msg_low = minetest.get_color_escape_sequence("#E56717")

-- mineral names
local ore_name = { ["coal"] = { "default:stone_with_coal",
				"default:coalblock" },
		   ["iron"] = { "default:stone_with_iron" },
		   ["copper"] = { "default:stone_with_copper" },
		   ["tin"] = { "default:stone_with_tin" },
		   ["gold"] = { "default:stone_with_gold" },
		   ["mese"] = { "default:stone_with_mese",
				"default:mese"},
		   ["diamond"] = { "default:stone_with_diamond",
				   "default:diamondblock" },
		   ["obsidian"] = { "default:obsidian" } }
if minetest.global_exists("moreores") then
	ore_name["silver"] = { "moreores:mineral_silver" }
	ore_name["mithril"] = { "moreores:mineral_mithril" }
end

-- multidevice
local MODE_GEOTHERM = 1
local MODE_ORESCAN = 2
local MODE_OREFIND = 3
local mode_name = { [MODE_GEOTHERM] = "Geothermometer",
		    [MODE_ORESCAN] = "Mineral Scanner",
		    [MODE_OREFIND] = "Mineral Finder" }

-- fast lookup tables
local rev_ore_name = {}
for n, a in pairs(ore_name) do
	for _, m in ipairs(a) do
		rev_ore_name[m] = n
	end
end
local rev_mode_name = {}
for i, m in pairs(mode_name) do
	rev_mode_name[m] = i
end

--[[
	---------------
	Sound functions
	---------------
]]--

local function play_beep_ok(player_name)
	minetest.sound_play("minertools_beep_ok", {
		to_player = player_name,
		gain = 0.8,
	})
end
local function play_beep_err(player_name)
	minetest.sound_play("minertools_beep_err", {
		to_player = player_name,
		gain = 0.5,
	})
end
local function play_scan(player_name)
	minetest.sound_play("minertools_scan", {
		to_player = player_name,
		gain = 0.8,
	})
end
local function play_click(player_name)
	minetest.sound_play("minertools_click", {
		to_player = player_name,
		gain = 0.6,
	})
end
local function play_pulse(player_name)
	minetest.sound_play("minertools_pulse", {
		to_player = player_name,
		gain = 0.8,
	})
end
local function play_toggle(player_name)
	minetest.sound_play("minertools_toggle", {
		to_player = player_name,
		gain = 0.6,
	})
end

--[[
	------------------
	Matching functions
	------------------
]]--

-- check if node is of type that device can scan
-- (only nodes of natural origin can be analyzed properly)
local function is_mineral(name)
	if name == nil then return false end
	if minetest.get_item_group(name, "sand") > 0 then return true end
	if minetest.get_item_group(name, "soil") > 0 then return true end
	if minetest.get_item_group(name, "stone") > 0 then return true end
	if string.match(name, "^default:stone_with_") then return true end
	if string.match(name, "^default:.*sandstone") then return true end
	if name == "default:gravel"
		or name == "default:clay" then return true end
	if minetest.global_exists("moreores") then
		if string.match(name, "^moreores:mineral_") then
			return true
		end
	end
	return false
end

-- check if node is made of obsidian
local function has_obsidian(name)
	if name == nil then return false end
	if string.match(name, "^default:obsidian") then return true end
	if minetest.global_exists("stairs") then  -- part of minetest game now
		if string.match(name, "^stairs:stair_obsidian") or
		   string.match(name, "^stairs:slab_obsidian") then
			return true
		end
	end
	return false
end

--[[
	-------------
	Settings Menu
	-------------
]]--

-- show formspec
local function show_menu(item, player, pointed_thing)
	local player_name = player:get_player_name()
	local tool_def = item:get_definition()
	tool_def._init_metadata(player, item)
	if not tool_def._is_multidevice then
		minetest.show_formspec(player_name, tool_def.name,
			tool_def._formspec(item))
	else
		local mode = item:get_meta():get_int("mode")
		minetest.show_formspec(player_name, tool_def.name,
			tool_def._formspec[mode](item))
	end
end

-- formspec callback
minetest.register_on_player_receive_fields(function(player, formname, fields)
	if not string.match(formname, "^minertools:") then return false end
	local player_name = player:get_player_name()
	local tool = player:get_wielded_item()
	local tool_meta = tool:get_meta()
	local tool_upd = false
	local play_snd = true
	if fields and (fields.ok or fields.quit) then
		play_click(player_name)
		play_snd = false
	end
	if formname == "minertools:mineral_scanner" then
		if fields and fields.range then
			tool_meta:set_int("scan_range", tonumber(fields.range))
			if play_snd then play_click(player_name) end
			tool_upd = true
		end
	elseif formname == "minertools:mineral_finder" then
		if fields and fields.ore then
			tool_meta:set_string("ore_type", fields.ore)
			if play_snd then play_click(player_name) end
			tool_upd = true
		end
	elseif formname == "minertools:portable_mining_computer" or
	       formname == "minertools:advanced_mining_assistant" or
	       formname == "minertools:ultimate_mining_gizmo" then
		if fields and fields.mode then
			local mode = rev_mode_name[fields.mode]
			tool_meta:set_int("mode", mode)
			if not fields.ok and not fields.quit then
				local tool_def = tool:get_definition()
				tool_def._init_metadata(player, tool)
				minetest.show_formspec(player_name, formname,
					tool_def._formspec[mode](tool))
			end
			if play_snd then play_toggle(player_name) end
			tool_upd = true
		end
		if fields and fields.range then
			tool_meta:set_int("scan_range",
				tonumber(fields.range))
			if play_snd then play_click(player_name) end
			tool_upd = true
		end
		if fields and fields.ore then
			tool_meta:set_string("ore_type", fields.ore)
			if play_snd then play_click(player_name) end
			tool_upd = true
		end
	end
	if tool_upd then player:set_wielded_item(tool) end
	return true
end)

--[[
	----------------
	Device formspecs
	----------------
]]--

local function mineralscanner_formspec(tool)
	-- function requires all metadata to be accessible
	-- (or initialized elsewhere)
	local tool_def = tool:get_definition()
	local range_min = tool_def._scan_range_min
	local range_max = tool_def._scan_range_max
	local tool_meta = tool:get_meta()
	local range = tool_meta:get_int("scan_range")
	local range_opts = ""
	for i = range_min, range_max, 1 do
		range_opts = range_opts .. tostring(i)
		if i < range_max then range_opts = range_opts .. "," end
	end
	return "size[3,2,true]"..
	"position[0.5,0.25]" ..
	"no_prepend[]" ..
	"label[0.5,0;" ..
	minetest.colorize("#FFFF00", "Mineral Scanner") .. "]" ..
	"label[0,0.75;Scan range]" ..
	"dropdown[1.75,0.625;1;range;" .. range_opts .. ";" ..
	(range - range_min + 1) .. "]" ..
	"button_exit[0.75,1.75;1.5,0.5;ok;OK]"
end

local function mineralfinder_formspec(tool)
	-- function requires all metadata to be accessible
	-- (or initialized elsewhere)
	local tool_def = tool:get_definition()
	local ore_list = tool_def._find_ore_list
	local tool_meta = tool:get_meta()
	local ore_type = tool_meta:get_string("ore_type")
	local ore_opts = ""
	local ore_idx = 0
	for i, n in ipairs(ore_list) do
		ore_opts = ore_opts .. n
		if i < #ore_list then ore_opts = ore_opts .. "," end
		if n == ore_type then ore_idx = i end
	end
	return "size[3,2,true]"..
	"position[0.5,0.25]" ..
	"no_prepend[]" ..
	"label[0.5,0;" ..
	minetest.colorize("#FFFF00", "Mineral Finder") .. "]" ..
	"label[0.25,0.75;Ore]" ..
	"dropdown[1.25,0.625;1.5;ore;" .. ore_opts .. ";" ..
	ore_idx .. "]" ..
	"button_exit[0.75,1.75;1.5,0.5;ok;OK]"
end

local function multidevice_formspec_gt(tool)
	-- function requires all metadata to be accessible
	-- (or initialized elsewhere)
	local label = tool:get_definition().description
	local mode_opts = ""
	for i, n in ipairs(mode_name) do
		mode_opts = mode_opts .. n
		if i < #mode_name then mode_opts = mode_opts .. "," end
	end
	return "size[4.25,3,true]"..
	"position[0.5,0.25]" ..
	"no_prepend[]" ..
	"label[0.5,0;" .. minetest.colorize("#FFFF00", label) .. "]" ..
	"label[0,0.75;" .. minetest.colorize("#00FFFF", "Mode") .. "]" ..
	"dropdown[1.75,0.625;2.5;mode;" .. mode_opts .. ";" ..
		MODE_GEOTHERM .. "]" ..
	"button_exit[1.25,2.75;1.5,0.5;ok;OK]"
end

local function multidevice_formspec_ms(tool)
	-- function requires all metadata to be accessible
	-- (or initialized elsewhere)
	local tool_def = tool:get_definition()
	local label = tool_def.description
	local mode_opts = ""
	for i, n in ipairs(mode_name) do
		mode_opts = mode_opts .. n
		if i < #mode_name then mode_opts = mode_opts .. "," end
	end
	local range_min = tool_def._scan_range_min
	local range_max = tool_def._scan_range_max
	local range = tool:get_meta():get_int("scan_range")
	local range_opts = ""
	for i = range_min, range_max, 1 do
		range_opts = range_opts .. tostring(i)
		if i < range_max then range_opts = range_opts .. "," end
	end
	return "size[4.25,3,true]"..
	"position[0.5,0.25]" ..
	"no_prepend[]" ..
	"label[0.5,0;" .. minetest.colorize("#FFFF00", label) .. "]" ..
	"label[0,0.75;" .. minetest.colorize("#00FFFF", "Mode") .. "]" ..
	"dropdown[1.75,0.625;2.5;mode;" .. mode_opts .. ";" ..
		MODE_ORESCAN .. "]" ..
	"label[0.5,1.75;" .. " Scan range]" ..
	"dropdown[2.5,1.625;1;range;" .. range_opts .. ";" ..
		(range - range_min + 1) .. "]" ..
	"button_exit[1.25,2.75;1.5,0.5;ok;OK]"
end

local function multidevice_formspec_mf(tool)
	-- function requires all metadata to be accessible
	-- (or initialized elsewhere)
	local tool_def = tool:get_definition()
	local label = tool_def.description
	local mode_opts = ""
	for i, n in ipairs(mode_name) do
		mode_opts = mode_opts .. n
		if i < #mode_name then mode_opts = mode_opts .. "," end
	end
	local ore_list = tool_def._find_ore_list
	local ore_type = tool:get_meta():get_string("ore_type")
	local ore_opts = ""
	local ore_idx = 0
	for i, n in ipairs(ore_list) do
		ore_opts = ore_opts .. n
		if i < #ore_list then ore_opts = ore_opts .. "," end
		if n == ore_type then ore_idx = i end
	end
	return "size[4.25,3,true]"..
	"position[0.5,0.25]" ..
	"no_prepend[]" ..
	"label[0.5,0;" .. minetest.colorize("#FFFF00", label) .. "]" ..
	"label[0,0.75;" .. minetest.colorize("#00FFFF", "Mode") .. "]" ..
	"dropdown[1.75,0.625;2.5;mode;" .. mode_opts .. ";" ..
		MODE_OREFIND .. "]" ..
	"label[0.5,1.75;" .. " Ore]" ..
	"dropdown[2,1.625;1.5;ore;" .. ore_opts .. ";" ..
		ore_idx .. "]" ..
	"button_exit[1.25,2.75;1.5,0.5;ok;OK]"
end

--[[
	---------------
	Device metadata
	---------------
]]--

local function mineralscanner_init_metadata(player, tool)
	-- write correct metadata only if not present or invalid
	local tool_def = tool:get_definition()
	local range_min = tool_def._scan_range_min
	local range_max = tool_def._scan_range_max
	local tool_meta = tool:get_meta()
	local range = tool_meta:get_int("scan_range")
	if range < range_min or range > range_max then
		tool_meta:set_int("scan_range", range_max)
		player:set_wielded_item(tool)  -- update item
		return true
	end
	return false
end

local function mineralfinder_init_metadata(player, tool)
	-- write correct metadata only if not present or invalid
	local tool_def = tool:get_definition()
	local ore_list = tool_def._find_ore_list
	local tool_meta = tool:get_meta()
	local ore_type = tool_meta:get_string("ore_type")
	if table.indexof(ore_list, ore_type) < 0 then
		tool_meta:set_string("ore_type", "coal")
		player:set_wielded_item(tool)  -- update item
		return true
	end
	return false
end

local function multidevice_init_metadata(player, tool)
	-- write correct metadata only if not present or invalid
	local tool_def = tool:get_definition()
	local tool_meta = tool:get_meta()
	local tool_upd = false
	-- mode select
	local mode = tool_meta:get_int("mode")
	if mode < 1 or mode > #mode_name then
		tool_meta:set_int("mode", MODE_GEOTHERM)
		tool_upd = true
	end
	-- mineral scanner module
	local range_min = tool_def._scan_range_min
	local range_max = tool_def._scan_range_max
	local range = tool_meta:get_int("scan_range")
	if range < range_min or range > range_max then
		tool_meta:set_int("scan_range", range_max)
		tool_upd = true
	end
	-- mineral finder module
	local ore_list = tool_def._find_ore_list
	local ore_type = tool_meta:get_string("ore_type")
	if table.indexof(ore_list, ore_type) < 0 then
		tool_meta:set_string("ore_type", "coal")
		tool_upd = true
	end
	-- all done
	if tool_upd then player:set_wielded_item(tool) end
	return tool_upd
end

--[[
	----------------
	Device functions
	----------------
]]--

-- geothermometer (GT)
-- parameters:	item - item object (itemstack)
-- 		player - player object (player)
-- 		pointed_thing - node object (node)
local function geothermometer_use(item, player, pointed_thing)
	if pointed_thing.type ~= "node" then return nil end
	local player_name = player:get_player_name()
	local node_pos = vector.new(pointed_thing.under)
	if not is_mineral(minetest.get_node(node_pos).name) then
		play_beep_err(player_name)
		return nil
	end
	local tool_def = item:get_definition()
	local label = tool_def._temp_label
	local radius = tool_def._temp_radius
	local scale = tool_def._temp_scale
	local strfmt = tool_def._temp_fmt
	local scan_vec = vector.new({x = radius, y = radius, z = radius})
	local scan_pos1 = vector.subtract(node_pos, scan_vec)
	local scan_pos2 = vector.add(node_pos, scan_vec)
	local water = minetest.find_nodes_in_area(scan_pos1, scan_pos2,
		{ "group:water" })
	local lava = minetest.find_nodes_in_area(scan_pos1, scan_pos2,
		{ "group:lava" })
	local temp_var = 0.0
	for _, v in ipairs(water) do
		local vd = vector.distance(node_pos, v)
		if vd <= radius then
			temp_var = temp_var - 1 / ( vd * vd )
		end
	end
	for _, v in ipairs(lava) do
		local vd = vector.distance(node_pos, v)
		if vd <= radius then
			temp_var = temp_var + 1 / ( vd * vd )
		end
	end
	local msg_val_clr = msg_white
	if temp_var < 0 then msg_val_clr = msg_cold
	elseif temp_var > 0 then msg_val_clr = msg_hot end
	play_beep_ok(player_name)
        minetest.chat_send_player(player_name,
                msg_yellow .. "[" .. label .. "]" .. msg_white ..
                " Temperature gradient for this block is " ..
                msg_val_clr .. string.format(strfmt, scale * temp_var) ..
                msg_white)
        return nil
end

-- mineral scanner (MS)
-- parameters:	item - item object (itemstack)
-- 		player - player object (player)
-- 		pointed_thing - node object (node)
local function mineralscanner_use(item, player, pointed_thing)
	local player_name = player:get_player_name()
	local player_pos = vector.round(player:getpos())
	local tool_def = item:get_definition()
	tool_def._init_metadata(player, item)
	local label = tool_def._scan_label
	local range_min = tool_def._scan_range_min
	local range_max = tool_def._scan_range_max
	local ore_list = tool_def._scan_ore_list
	local ore_nodes = {}
	for _, n in ipairs(ore_list) do
		for _, o in pairs(ore_name[n]) do
			ore_nodes[#ore_nodes + 1] = o
		end
	end
	local item_meta = item:get_meta()
	local range = item_meta:get_int("scan_range")
        local scan_vec = vector.new({x = range, y = range, z = range})
        local scan_pos1 = vector.subtract(player_pos, scan_vec)
        local scan_pos2 = vector.add(player_pos, scan_vec)
        local _, minerals = minetest.find_nodes_in_area(scan_pos1,
		scan_pos2, ore_nodes)
	local oremsg = ""
	local orecount = 0
	-- we do like our ore order
	for i, n in ipairs(ore_list) do
		orecount = 0
		for _, o in ipairs(ore_name[n]) do
			orecount = orecount + minerals[o]
		end
		if orecount == 0 then oremsg = oremsg .. msg_zero
		else oremsg = oremsg .. msg_plus end
		oremsg = oremsg .. n .. " = " .. orecount
		if i < #ore_list then
			oremsg = oremsg .. msg_white .. ", "
		end
	end
	play_scan(player_name)
	minetest.chat_send_player(player_name,
		msg_yellow .. "[" .. label .. "]" .. msg_white ..
		" Scan results for cubic range " .. range ..
		" : " .. oremsg .. msg_white)
        return item
end

-- mineral finder (MF)
-- parameters:	item - item object (itemstack)
-- 		player - player object (player)
-- 		pointed_thing - node object (node)
local function mineralfinder_use(item, player, pointed_thing)
	local player_name = player:get_player_name()
	local tool_def = item:get_definition()
	tool_def._init_metadata(player, item)
	local label = tool_def._find_label
	local depth = tool_def._find_depth
	local det_lvl = tool_def._find_detail
	local item_meta = item:get_meta()
	local ore_type = item_meta:get_string("ore_type")
	local head_pos = vector.add(vector.round(player:get_pos()), { x = 0, y = 1, z = 0 })
	local end_pos = vector.add(head_pos, vector.round(vector.multiply(player:get_look_dir(), depth)))
	local orecount = 0
	local obsblock = false
	local oredepth = 0
	local ray = minetest.raycast(head_pos, end_pos, false, false)
	for pt in ray do
		local node = minetest.get_node_or_nil(pt.under)
		if node then
			if rev_ore_name[node.name] == ore_type then
				orecount = orecount + 1
				if oredepth == 0 then
					oredepth = vector.distance(head_pos, pt.under)
				end
			elseif has_obsidian(node.name) then
				obsblock = true
				break
			end
		end
	end
	local oremsg = ""
	if orecount > 0 then oremsg = msg_plus
	else oremsg = msg_zero end
	oremsg = oremsg .. orecount
	if oredepth > 0 then
		if det_lvl == 1 then
			oremsg = oremsg .. msg_white .. " (signal strength: "
			if oredepth <= depth / 3 then
				oremsg = oremsg .. msg_high .. "HIGH"
			elseif oredepth > depth * 2 / 3 then
				oremsg = oremsg .. msg_low .. "LOW"
			else oremsg = oremsg .. msg_medium .. "MEDIUM" end
			oremsg = oremsg .. msg_white .. ")"
		elseif det_lvl == 2 then
			oremsg = oremsg .. msg_white .. " (signal strength: "
			local sigpct = 100.0 * (depth - oredepth + 1) / depth
			if sigpct >= 75 then oremsg = oremsg .. msg_high
			elseif sigpct < 25 then oremsg = oremsg .. msg_low
			else oremsg = oremsg .. msg_medium end
			oremsg = oremsg .. string.format("%d%%", sigpct) ..
				 msg_white .. ")"
		end
	end
	if obsblock then
		oremsg = oremsg .. msg_warn ..
			 " (warning - scan incomplete, blocked by obsidian)"
	end
	play_pulse(player_name)
	minetest.chat_send_player(player_name,
		msg_yellow .. "[" .. label .. "]" .. msg_white ..
		" Scan result for " .. msg_zero ..
		ore_type .. msg_white .. " : " .. oremsg .. msg_white)
        return item
end

-- multidevices (PMC, AMA, UMG)
-- parameters:	item - item object (itemstack)
-- 		player - player object (player)
-- 		pointed_thing - node object (node)
local function multidevice_use(item, player, pointed_thing)
	local player_name = player:get_player_name()
	local tool_def = item:get_definition()
	tool_def._init_metadata(player, item)
	local tool_meta = item:get_meta()
	local mode = tool_meta:get_int("mode")
	if mode == MODE_GEOTHERM then 
		geothermometer_use(item, player, pointed_thing)
	elseif mode == MODE_ORESCAN then
		mineralscanner_use(item, player, pointed_thing)
	elseif mode == MODE_OREFIND then
		mineralfinder_use(item, player, pointed_thing)
	end
	return item
end

--[[
	-----------------
	Tool registration
	-----------------
]]--

--[[

	Mining Chip v1.0

	Mandatory component for all electronic devices in this mod

]]--


minetest.register_craftitem("minertools:mining_chip", {
	description = "Mining Chip",
	inventory_image = "minertools_miningchip_inv.png",
})

--[[

	Geothermometer device v3.0

	Principle of calculations:
	heat energy dissipates with square distance from source (twice the distance
	four times less heat)
	Works only on "natural" blocks like dirt, stone, sand and ores

	Calculations explained:
	* initial block temperature variation = 0.0
	* find all water blocks in range, count them and find distance from block,
	  then change temperature adding -sum(1/d^2)
	* find all lava blocks in range, count them and find distance from block,
	  then change temperature adding +sum(1/d^2)
	* resulting value shows how nearby water or lava affects block temperature
	* scale it by chosen factor to amplify differences

]]--

minetest.register_tool("minertools:geothermometer", {
	description = "Geothermometer",
	wield_image = "minertools_geothermometer_hand.png",
	wield_scale = { x = 1, y = 1, z = 1 },
	inventory_image = "minertools_geothermometer_inv.png",
	stack_max = 1,
	range = 8,
	_is_multidevice = false,
	_temp_label = "Geothermometer",
	_temp_radius = 10,	-- radius for heat calculation
	_temp_scale = 50,	-- scaling factor for output value
	_temp_fmt = "%+.4f",	-- display format
	on_use = geothermometer_use
})

--[[

	Portable Mineral Scanner v3.0

	Scans cube around player with specified range and
	provides feedback with ore quantity.
	Notice: area scanned is cube (2 * range + 1) not sphere

	Left click - scan and show results
	Right click - device menu

]]--

minetest.register_tool("minertools:mineral_scanner", {
	description = "Portable Mineral Scanner",
	wield_image = "minertools_mineralscanner_hand.png",
	wield_scale = { x = 1, y = 1, z = 1 },
	inventory_image = "minertools_mineralscanner_inv.png",
	stack_max = 1,
	range = 0,
	_init_metadata = mineralscanner_init_metadata,
	_formspec = mineralscanner_formspec,
	_is_multidevice = false,
	_scan_label = "MineralScanner",
	_scan_range_min = 1,
	_scan_range_max = 8,
	_scan_ore_list = scan_ore_list,
	on_use = mineralscanner_use,
	on_place = show_menu,
	on_secondary_use = show_menu,
})

--[[

	Portable Mineral Finder v3.0

	Short range directional radar that detects
	presence of selected ore in front of device.
	Notice: obsidian blocks signal so area behind
	it remains unexplored.
	Node position calculation by multiplying directional
	normalized vector is susceptible to rounding
	errors, so device has limited range to preserve
	acceptable accuracy. More accurate methods involve
	numerical complexity (Bresenham for example) so
	IMHO its better to follow KISS principle.

	Left click - scan
	Right click - device menu

]]--

minetest.register_tool("minertools:mineral_finder", {
	description = "Portable Mineral Finder",
	wield_image = "minertools_mineralfinder_hand.png",
	wield_scale = { x = 1, y = 1, z = 1 },
	inventory_image = "minertools_mineralfinder_inv.png",
	stack_max = 1,
	range = 4,
	_init_metadata = mineralfinder_init_metadata,
	_formspec = mineralfinder_formspec,
	_is_multidevice = false,
	_find_label = "MineralFinder",
	_find_depth = 5,
	_find_detail = 0,
	_find_ore_list = find_ore_list,
        on_use = mineralfinder_use,
        on_place = show_menu,
        on_secondary_use = show_menu,
})

--[[

	Portable Mineral Computer aka PMC v3.0

	This is all-in-one device that provides functionality
	of geothermometer, mineral scanner and mineral finder.
	These basic components are all connected and managed
	by dedicated Mining Chip. Thanks to this, although
	in one box, there is no signal loss or decreased range.

	Technical info:
	3 devices combined into one with no modifications

	Left click - scan and show results
	Right click - device menu

]]--

minetest.register_tool("minertools:portable_mining_computer", {
	description = "Portable Mining Computer",
	wield_image = "minertools_pmc_hand.png",
	wield_scale = { x = 1, y = 1, z = 1 },
	inventory_image = "minertools_pmc_inv.png",
	stack_max = 1,
	range = 8,
	_init_metadata = multidevice_init_metadata,
	_formspec = { [MODE_GEOTHERM] = multidevice_formspec_gt,
		      [MODE_ORESCAN] = multidevice_formspec_ms,
		      [MODE_OREFIND] = multidevice_formspec_mf },
	_is_multidevice = true,
	_temp_label = "PMC:Geothermometer",
	_temp_radius = 10,
	_temp_scale = 50,
	_temp_fmt = "%+.4f",
	_scan_label = "PMC:MineralScanner",
	_scan_range_min = 1,
	_scan_range_max = 8,
	_scan_ore_list = scan_ore_list,
	_find_label = "PMC:MineralFinder",
	_find_depth = 5,
	_find_detail = 0,
	_find_ore_list = find_ore_list,
	on_use = multidevice_use,
	on_place = show_menu,
	on_secondary_use = show_menu,
})

--[[

	Advanced Mining Assistant aka AMA v3.0

	This one is an upgraded version of PMC. Adding one
	more Mining Chip, gold circuitry and obsidian dampers
	allows PMC ranges and overall sensivity to be safely
	increased.
	Operational actions remain identical to PMC.

	Technical differences to PMC:
	* increased tool range
	* increased MineralFinder range
	* increased MineralScanner range
	* increased Geothermometer sensivity range
	* finder signal strength (low/medium/high) indicates distance to ore

	Left click - scan and show results
	Right click - device menu

]]--

minetest.register_tool("minertools:advanced_mining_assistant", {
	description = "Advanced Mining Assistant",
	wield_image = "minertools_ama_hand.png",
	wield_scale = { x = 1, y = 1, z = 1 },
	inventory_image = "minertools_ama_inv.png",
	stack_max = 1,
	range = 10,			-- PMC + 2
	_init_metadata = multidevice_init_metadata,
	_formspec = { [MODE_GEOTHERM] = multidevice_formspec_gt,
		      [MODE_ORESCAN] = multidevice_formspec_ms,
		      [MODE_OREFIND] = multidevice_formspec_mf },
	_is_multidevice = true,
	_temp_label = "AMA:Geothermometer",
	_temp_radius = 12,		-- PMC + 2
	_temp_scale = 50,
	_temp_fmt = "%+.4f",
	_scan_label = "AMA:MineralScanner",
	_scan_range_min = 1,
	_scan_range_max = 12,		-- PMC + 2
	_scan_ore_list = scan_ore_list,
	_find_label = "AMA:MineralFinder",
	_find_depth = 8,		-- PMC + 3
	_find_detail = 1,		-- PMC ++
	_find_ore_list = find_ore_list,
	on_use = multidevice_use,
	on_place = show_menu,
	on_secondary_use = show_menu,
})

--[[

	Ultimate Mining Gizmo aka UMG v3.0

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
	* finder signal strength (in percent) indicates distance to ore

	Left click - scan and show results
	Right click - device menu

]]--

minetest.register_tool("minertools:ultimate_mining_gizmo", {
	description = "Ultimate Mining Gizmo",
	wield_image = "minertools_umg_hand.png",
	wield_scale = { x = 1, y = 1, z = 1 },
	inventory_image = "minertools_umg_inv.png",
	light_source = light_level,
	stack_max = 1,
	range = 12,			-- AMA + 2
	_init_metadata = multidevice_init_metadata,
	_formspec = { [MODE_GEOTHERM] = multidevice_formspec_gt,
		      [MODE_ORESCAN] = multidevice_formspec_ms,
		      [MODE_OREFIND] = multidevice_formspec_mf },
	_is_multidevice = true,
	_temp_label = "UMG:Geothermometer",
	_temp_radius = 16,		-- AMA + 4
	_temp_scale = 50,
	_temp_fmt = "%+.6f",		-- AMA ++
	_scan_label = "UMG:MineralScanner",
	_scan_range_min = 1,
	_scan_range_max = 16,		-- AMA + 4
	_scan_ore_list = scan_ore_list,
	_find_label = "UMG:MineralFinder",
	_find_depth = 12,		-- AMA + 4
	_find_detail = 2,		-- AMA ++
	_find_ore_list = find_ore_list,
	on_use = multidevice_use,
	on_place = show_menu,
	on_secondary_use = show_menu,
})

--[[
	--------
	Crafting
	--------
]]--

minetest.register_craft({
	output = "minertools:mining_chip",
	type = "shaped",
	recipe = {
		{ "default:copper_ingot", "default:gold_ingot", "default:copper_ingot" },
		{ "default:copper_ingot", "default:mese_crystal", "default:copper_ingot" },
		{ "default:copper_ingot", "group:sand", "default:copper_ingot" },
	},
})

minetest.register_craft({
	output = "minertools:geothermometer",
	type = "shaped",
	recipe = {
		{ "default:steel_ingot", "default:diamond", "default:steel_ingot" },
		{ "default:steel_ingot", "default:mese_crystal", "default:steel_ingot" },
		{ "default:steel_ingot", "minertools:mining_chip", "default:steel_ingot" },
	},
})

minetest.register_craft({
	output = "minertools:mineral_scanner",
	type = "shaped",
	recipe = {
		{ "default:steel_ingot", "default:steel_ingot", "default:steel_ingot" },
		{ "default:mese_crystal", "default:gold_ingot", "default:mese_crystal" },
		{ "default:copper_ingot", "minertools:mining_chip", "default:copper_ingot" },
	},
})

minetest.register_craft({
	output = "minertools:mineral_finder",
	type = "shaped",
	recipe = {
		{ "default:steel_ingot", "default:gold_ingot", "default:steel_ingot" },
		{ "default:gold_ingot", "default:mese_crystal", "default:gold_ingot" },
		{ "default:copper_ingot", "minertools:mining_chip", "default:copper_ingot" },
	},
})

minetest.register_craft({
	output = "minertools:portable_mining_computer",
	type = "shaped",
	recipe = {
		{ "default:steel_ingot", "minertools:geothermometer", "default:steel_ingot" },
		{ "minertools:mineral_finder", "minertools:mining_chip", "minertools:mineral_scanner" },
		{ "default:steel_ingot", "default:mese_crystal", "default:steel_ingot" },
	},
})

minetest.register_craft({
	output = "minertools:advanced_mining_assistant",
	type = "shaped",
	recipe = {
		{ "default:obsidian", "default:mese_crystal", "default:obsidian" },
		{ "default:gold_ingot", "minertools:portable_mining_computer", "default:gold_ingot" },
		{ "default:obsidian", "minertools:mining_chip", "default:obsidian" },
	},
})

minetest.register_craft({
	output = "minertools:ultimate_mining_gizmo",
	type = "shaped",
	recipe = {
		{ "default:obsidian_glass", "default:mese_crystal", "default:obsidian_glass" },
		{ "default:diamond", "minertools:advanced_mining_assistant", "default:diamond" },
		{ "default:obsidian_glass", "minertools:mining_chip", "default:obsidian_glass" },
	},
})

