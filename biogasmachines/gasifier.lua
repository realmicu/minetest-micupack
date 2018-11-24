--[[

	=======================================================================
	Tubelib Biogas Machines Mod
	by Micu (c) 2018

	Copyright (C) 2018 Michal Cieslakiewicz

	Gasifier is a machine designed to slowly extract Biogas from fossil
	fuels and other compressed dry organic materials.
	Basic recipe is conversion of Coal Block into Biogas (heavier leftover
	fractions form Biofuel).  Another default recipe is clean and complete
	transformation of Straw Block into some Biogas units.
	Custom recipes can be added via simple API function.

	Operational info:
	* machine requires no extra fuel
	* if there is nothing to process, machine enters standby mode; it
	  will automatically pick up work as soon as any valid item is loaded
	  into input (source) tray
	* there is 1 tick gap between processing items to perform machinery
	  cleaning and reload working tray; this is a design choice
	* working tray can only be emptied when machine is stopped; this tray
	  is auto-loaded, source material should always go into input container
	* machine cannot be recovered unless input and output trays are all
	  empty
	* when active, due to high temperature inside, machine becomes a light
	  source of level 5

	License: LGPLv2.1+
	=======================================================================
	
]]--

--[[
	---------
	Variables
	---------
]]--

-- Biogas recipe table (key - source item name)
local biogas_recipes = {}
-- Biogas source table (indexed by numbers, used by formspec recipe hint bar)
local biogas_sources = {}
-- timing
local TIMER_TICK_SEC = 1		-- Node timer tick
local TICKS_TO_SLEEP = 5		-- Tubelib standby
-- machine inventory
local INV_H = 3				-- Inventory height (do not change)
local INV_IN_W = 2			-- Input inventory width
local INV_OUT_W = (6 - INV_IN_W)	-- Output inventory width

--[[
	----------------
	Public functions
	----------------
]]--

-- Add Biogas recipe
-- Returns true if recipe added successfully, false if error or already present
-- biogas_recipe = {
-- 	input = "itemstring",		-- source item, always 1 (req)
--	count = number,			-- biogas units produced (opt, def: 1)
--	time = number,			-- production time in ticks (req, max: 99)
--	extra = "itemstring" }		-- additional product (opt, def: nil)
function biogasmachines.add_gasifier_recipe(biogas_recipe)
	if not biogas_recipe then return false end
	if not biogas_recipe.input or not biogas_recipe.time or
	   biogas_recipe.time < 1 or biogas_recipe.time > 99 then
		return false
	end
	local input_item = ItemStack(biogas_recipe.input)
	if not input_item or input_item:get_count() > 1 then
		return false
	end
	local input_name = input_item:get_name()
	if not minetest.registered_items[input_name] then
		return false
	end
	if biogas_recipes[input_name] then return false end
	local extra_item = nil
	if biogas_recipe.extra then
		extra_item = ItemStack(biogas_recipe.extra)
		if not minetest.registered_items[extra_item:get_name()] then
			extra_item = nil
		end
	end
	local count = 1
	if biogas_recipe.count and biogas_recipe.count > 1 and
	   biogas_recipe.count < 100 then
		count = biogas_recipe.count
	end
	biogas_recipes[input_name] = {
		count = count,
		time = biogas_recipe.time,
		extra = extra_item,
	}
	biogas_sources[#biogas_sources + 1] = input_name
	return true
end

--[[
	--------
	Formspec
	--------
]]--

-- static data for formspec
local fmxy = { inv_h = tostring(INV_H),
	inv_in_w = tostring(INV_IN_W),
	mid_x = tostring(INV_IN_W + 0.5),
	inv_out_w = tostring(INV_OUT_W),
	inv_out_x = tostring(INV_IN_W + 2),
}

-- recipe hint
local function formspec_recipe_hint_bar(recipe_idx)
	if #biogas_sources == 0 or recipe_idx > #biogas_sources then
		return ""
	end
	local input_item = biogas_sources[recipe_idx]
	local input_desc = minetest.registered_nodes[input_item].description
	local recipe = biogas_recipes[input_item]
	return "label[0.5,3.25;Recipe]" ..
	"image_button[1.5,3.3;0.5,0.5;;left;<]" ..
	"label[2,3.25;" ..
		string.format("%2d / %2d", recipe_idx, #biogas_sources) ..
		"]" ..
	"image_button[2.8,3.3;0.5,0.5;;right;>]" ..
	"item_image[3.6,3.25;0.5,0.5;" .. input_item .. "]" ..
	--"tooltip[3.6,3.25;0.5,0.5;" ..	-- not supported in 0.4.x
	--	minetest.registered_nodes[input_item].description ..
	--	";;]" ..
	"image[4,3.25;0.5,0.5;tubelib_gui_arrow.png^[resize:16x16]" ..
	"label[4.4,3.25;" ..
		string.format("%2d sec", recipe.time * TIMER_TICK_SEC) ..
		"]" ..
	"image[5,3.25;0.5,0.5;tubelib_gui_arrow.png^[resize:16x16]" ..
	"item_image[5.5,3.25;0.5,0.5;tubelib_addons1:biogas]" ..
	"label[6,3.25;x " .. tostring(recipe.count) .. "]" ..
	(recipe.extra and "item_image[6.5,3.25;0.5,0.5;" ..
		recipe.extra:get_name() .. "]label[7,3.25;x " ..
		tostring(recipe.extra:get_count()) .. "]" or "")
end

-- Parameters:
-- state - tubelib state
-- item_percent - item completion
-- recipe_idx - index of recipe shown at hint bar
-- show_icons - show image hints (bool)
local function formspec(state, item_percent, recipe_idx, show_icons)
	local inv_hint = show_icons and #biogas_sources > 0
	local inv_key = inv_hint and biogas_sources[1] or ""
	return "size[8,8.25]" ..
	default.gui_bg ..
	default.gui_bg_img ..
	default.gui_slots ..
	"list[context;src;0,0;" .. fmxy.inv_in_w .. "," .. fmxy.inv_h .. ";]" ..
	(inv_hint and "item_image[0,0;1,1;" .. inv_key .. "]" or "") ..
	"list[context;cur;" .. fmxy.mid_x .. ",0;1,1;]" ..
	"image[" .. fmxy.mid_x .. ",1;1,1;gui_furnace_arrow_bg.png^[lowpart:" ..
		tostring(item_percent) ..
		":gui_furnace_arrow_fg.png^[transformR270]" ..
	"image_button[" .. fmxy.mid_x .. ",2;1,1;" ..
		tubelib.state_button(state) .. ";button;]" ..
	formspec_recipe_hint_bar(recipe_idx) ..
	(inv_hint and "item_image[" .. fmxy.inv_out_x ..
		",0;1,1;tubelib_addons1:biogas]" or "") ..
	"list[context;dst;" .. fmxy.inv_out_x .. ",0;" .. fmxy.inv_out_w ..
		"," .. fmxy.inv_h .. ";]" ..
	"list[current_player;main;0,4;8,1;]" ..
	"list[current_player;main;0,5.25;8,3;8]" ..
	"listring[context;dst]" ..
	"listring[current_player;main]" ..
	"listring[context;src]" ..
	"listring[current_player;main]" ..
	(state == tubelib.RUNNING and
		"box[" .. fmxy.mid_x .. ",0;0.82,0.9;#9F3F1F]" or
		"listring[context;cur]listring[current_player;main]") ..
	default.get_hotbar_bg(0, 4)
end

--[[
	-------
	Helpers
	-------
]]--

-- check if item is valid biogas source (bool)
local function is_input_item(stack)
	local stackname = stack:get_name()
	return biogas_recipes[stackname] and true or false
end

-- get one source item (itemstack)
local function get_input_item(inv, listname)
	local stack = ItemStack({})
	for i, _ in pairs(biogas_recipes) do
		stack = inv:remove_item(listname, ItemStack(i .. " 1"))
		if not stack:is_empty() then break end
	end
	return stack
end

local function gasifier_start(pos)
	local node = minetest.get_node(pos)
	local meta = minetest.get_meta(pos)
	local number = meta:get_string("number")
	local recipe_idx = meta:get_int("recipe_idx")
	local label = minetest.registered_nodes[node.name].description
	meta:set_int("item_ticks", -1)
	meta:set_int("running", TICKS_TO_SLEEP)
	meta:set_string("infotext", label .. " " .. number .. ": running")
	meta:set_string("formspec", formspec(tubelib.RUNNING, 0, recipe_idx, true))
	node.name = "biogasmachines:gasifier_active"
	minetest.swap_node(pos, node)
	minetest.get_node_timer(pos):start(TIMER_TICK_SEC)
	return false
end

local function gasifier_stop(pos)
	local node = minetest.get_node(pos)
	local meta = minetest.get_meta(pos)
	local number = meta:get_string("number")
	local recipe_idx = meta:get_int("recipe_idx")
	local label = minetest.registered_nodes[node.name].description
	meta:set_int("item_ticks", -1)
	meta:set_int("running", tubelib.STATE_STOPPED)
	meta:set_string("infotext", label .. " " .. number .. ": stopped")
	meta:set_string("formspec", formspec(tubelib.STOPPED, 0, recipe_idx, true))
	node.name = "biogasmachines:gasifier"
	minetest.swap_node(pos, node)
        minetest.get_node_timer(pos):stop()
        return false
end

local function gasifier_idle(pos)
	local node = minetest.get_node(pos)
	local meta = minetest.get_meta(pos)
	local number = meta:get_string("number")
	local recipe_idx = meta:get_int("recipe_idx")
	local label = minetest.registered_nodes[node.name].description
	meta:set_int("item_ticks", -1)
	meta:set_int("running", tubelib.STATE_STANDBY)
	meta:set_string("infotext", label .. " " .. number .. ": standby")
	meta:set_string("formspec", formspec(tubelib.STANDBY, 0, recipe_idx, true))
	node.name = "biogasmachines:gasifier"
	minetest.swap_node(pos, node)
        minetest.get_node_timer(pos):start(TIMER_TICK_SEC * TICKS_TO_SLEEP)
        return false
end

local function gasifier_fault(pos)
	local node = minetest.get_node(pos)
	local meta = minetest.get_meta(pos)
	local number = meta:get_string("number")
	local recipe_idx = meta:get_int("recipe_idx")
	local label = minetest.registered_nodes[node.name].description
	meta:set_int("item_ticks", -1)
	meta:set_int("running", tubelib.STATE_FAULT)
	meta:set_string("infotext", label .. " " .. number .. ": fault")
	meta:set_string("formspec", formspec(tubelib.FAULT, 0, recipe_idx, true))
	node.name = "biogasmachines:gasifier"
	minetest.swap_node(pos, node)
	minetest.get_node_timer(pos):stop()
	return false
end

local function update_recipe_hint_bar(pos)
	local meta = minetest.get_meta(pos)
	local recipe_idx = meta:get_int("recipe_idx")
	local state = tubelib.state(meta:get_int("running"))
	local item_name = meta:get_string("item_name")
	local item_ticks = meta:get_int("item_ticks")
	local item_pct = 0
	if item_name ~= "" and item_ticks >= 0 then
		local tot_ticks = biogas_recipes[item_name].time
		item_pct = 100 * (tot_ticks - item_ticks) / tot_ticks
	end
	meta:set_string("formspec", formspec(state, item_pct, recipe_idx, true))
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
		if is_input_item(stack) then
			return stack:get_count()
		else
			return 0
		end
	elseif listname == "cur" or listname == "dst" then
		return 0
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
	local pipe = tostring(biogasmachines.is_pipe_with_water(pos, node))
	minetest.chat_send_player(player_name,
		minetest.colorize("#FFFF00", "[Gasifier:" ..
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
			gasifier_stop(pos)
		else
			gasifier_start(pos)
		end
	end
	if fields and (fields.left or fields.right) then
		local recipe_idx = meta:get_int("recipe_idx")
		if fields.left then
			recipe_idx = math.max(recipe_idx - 1, 1)
		end
		if fields.right then
			recipe_idx = math.min(recipe_idx + 1, #biogas_sources)
		end
		meta:set_int("recipe_idx", recipe_idx)
		update_recipe_hint_bar(pos)
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
	local itemname = meta:get_string("item_name")
	local prodtime = -1
	if itemcnt < 0 or itemname == "" then
		-- idle and ready, check for something to work with
		if inv:is_empty("src") then
			if running > 0 then
				-- no source item, count towards standby
				running = running - 1
				meta:set_int("running", running)
				if running == 0 then
					return gasifier_idle(pos)
				end
			end
			return true
		end
		if running == tubelib.STATE_STANDBY then
			-- something to do, wake up and re-entry
			return gasifier_start(pos)
		end
		-- choose item
		local inputname = nil
		if not inv:is_empty("cur") then
			-- leftover item, start from beginning
			local inp = inv:get_stack("cur", 1)
			inputname = inp:get_name()
			if not biogas_recipes[inputname] then
				return gasifier_fault(pos)	-- oops
			end
			prodtime = biogas_recipes[inputname].time
		else
			-- prepare item, next tick will start processing
			for i, r in pairs(biogas_recipes) do
				if inv:contains_item("src", ItemStack(i .. " 1")) and
				   inv:room_for_item("dst",
					ItemStack("tubelib_addons1:biogas " ..
					tostring(r.count))) and
				   (not r.extra or inv:room_for_item("dst", r.extra))
				   then
					inputname = i
					prodtime = r.time
					break
				end
			end
			if not inputname then
				return true
			end
			local inp = inv:remove_item("src", ItemStack(inputname .. " 1"))
			if inp:is_empty() then
				return gasifier_fault(pos)	-- oops
			end
			inv:add_item("cur", inp)
		end
		meta:set_string("item_name", inputname)
		itemcnt = prodtime
	else
		-- production tick
		itemcnt = itemcnt - 1
		local recipe = biogas_recipes[itemname]
		if itemcnt == 0 then
			inv:add_item("dst",
				ItemStack("tubelib_addons1:biogas " ..
				tostring(recipe.count)))
			if recipe.extra then
				inv:add_item("dst", recipe.extra)
			end
			inv:set_stack("cur", 1, ItemStack({}))
			meta:set_string("item_name", "")
			itemcnt = -1
		else
			prodtime = recipe.time
		end
	end
	meta:set_int("item_ticks", itemcnt)
	meta:set_int("running", TICKS_TO_SLEEP)
	meta:set_string("infotext", label .. " " .. number .. ": running")
	meta:set_string("formspec", formspec(tubelib.RUNNING,
		100 * (prodtime - itemcnt) / prodtime,
		meta:get_int("recipe_idx"), true))
	return true
end

--[[
	-----------------
	Node registration
	-----------------
]]--

minetest.register_node("biogasmachines:gasifier", {
	description = "Tubelib Gasifier",
	tiles = {
		-- up, down, right, left, back, front
		"biogasmachines_gasifier_top.png",
		"biogasmachines_bottom.png",
		"biogasmachines_gasifier_side.png",
		"biogasmachines_gasifier_side.png",
		"biogasmachines_gasifier_side.png",
		"biogasmachines_gasifier_side.png"
	},

	drawtype = "nodebox",
	node_box = {
		type = "fixed",
		fixed = {
			{ -0.5, -0.5, -0.5, 0.5, 0.375, 0.5 },
			{ -0.375, 0.375, -0.375, 0.375, 0.5, 0.375 },
		},
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
		local number = tubelib.add_node(pos, "biogasmachines:gasifier")
		local inv = meta:get_inventory()
		inv:set_size('src', INV_H * INV_IN_W)
		inv:set_size('cur', 1)
		inv:set_size('dst', INV_H * INV_OUT_W)
		local label = minetest.registered_nodes[node.name].description
		meta:set_string("number", number)
		meta:set_string("owner", placer:get_player_name())
		meta:set_int("running", tubelib.STATE_STOPPED)
		meta:set_string("item_name", "")
		meta:set_int("item_ticks", -1)
		meta:set_int("recipe_idx", 1)
		meta:set_string("infotext", label .. " " .. number .. ": stopped")
		meta:set_string("formspec", formspec(tubelib.STOPPED, 0, 1, true))
	end,
})

minetest.register_node("biogasmachines:gasifier_active", {
	description = "Tubelib Gasifier",
	tiles = {
		-- up, down, right, left, back, front
		{
			image = "biogasmachines_gasifier_active_top.png",
			backface_culling = false,
			animation = {
				type = "vertical_frames",
				aspect_w = 32,
				aspect_h = 32,
				length = 4.0,
			},
		},
		"biogasmachines_bottom.png",
		"biogasmachines_gasifier_side.png",
		"biogasmachines_gasifier_side.png",
		"biogasmachines_gasifier_side.png",
		"biogasmachines_gasifier_side.png"
	},
	drawtype = "nodebox",
	node_box = {
		type = "fixed",
		fixed = {
			{ -0.5, -0.5, -0.5, 0.5, 0.375, 0.5 },
			{ -0.375, 0.375, -0.375, 0.375, 0.5, 0.375 },
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
	light_source = 5,
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
	drop = "biogasmachines:gasifier",
})

tubelib.register_node("biogasmachines:gasifier", { "biogasmachines:gasifier_active" }, {

	on_push_item = function(pos, side, item)
		local meta = minetest.get_meta(pos)
		if is_input_item(item) then
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
			gasifier_start(pos)
		elseif topic == "off" then
			gasifier_stop(pos)
		elseif topic == "state" then
			return tubelib.statestring(meta:get_int("running"))
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
	output = "biogasmachines:gasifier",
	recipe = {
		{ "default:steelblock", "default:glass", "default:steelblock" },
		{ "default:mese_crystal", "default:gold_ingot", "tubelib:tube1" },
		{ "group:wood", "default:gold_ingot", "group:wood" },
	},
})

--[[
	-------
	Recipes
	-------
]]--

biogasmachines.add_gasifier_recipe({
	input = "default:coalblock",
	count = 9,
	time = 12,
	extra = "default:gravel 1",
})

biogasmachines.add_gasifier_recipe({
	input = "farming:straw",
	count = 2,
	time = 8,
})

-- Unified Inventory hints
if minetest.get_modpath("unified_inventory") then
	unified_inventory.register_craft_type("gasifier", {
		description = "Gasifier",
		icon = 'biogasmachines_gasifier_top.png',
		width = 1,
		height = 1,
	})
	for i, r in pairs(biogas_recipes) do
		unified_inventory.register_craft({
			type = "gasifier",
			items = { i },
			output = "tubelib_addons1:biogas " .. tostring(r.count),
		})
	end
end
