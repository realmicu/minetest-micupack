--[[

	=======================================================================
	Tubelib Biogas Machines Mod
	by Micu (c) 2018, 2019

	Copyright (C) 2018, 2019 Michal Cieslakiewicz

	Compactor is a heavy mechanical press with heating, compacting and
	cooling systems combined into one device.  It compresses stone-like
	resources into very dense and hard materials, mainly obsidian. Default
	recipes include converting cobble and compressed gravel to obsidian,
	flint to obsidian shards and coal blocks to diamonds. Machine consumes
	Biogas for heating/compacting and Ice for rapid cooling.
	More custom recipes can be added via API function.

	Operational info:
	* machine requires Biogas as fuel (one unit lasts for 12 seconds) and
	  ice for cooling (one ice cube per compaction process)
	* if there is nothing to process but there is still Biogas in tank,
	  machine enters standby mode; it will automatically pick up work as
	  soon as any valid item is loaded into input (source) tray and ice
	  is available
	* machine also enters standby mode if ice tray becomes empty;
	  production resumes automatically as soon as ice tray is loaded again
	* if there is nothing to compact in source tray and Biogas tank is
	  empty, machine switches off automatically
	* when fuel ends and there are still source items waiting in source
	  tray, machine enters fault mode and has to be manually powered on
	  again after refilling Biogas
	* if output tray is full and no new items can be put there, machine
	  changes state to blocked (special standby mode); it will resume
	  work as soon as there is space in output inventory
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

	Tubelib v2 implementation info:
	* device updates itself every tick, so cycle_time must be set to 1
	  even though production takes longer (start method sets timer to
	  this value)
	* keep_running function is called every time item is produced
	  (not every processing tick - function does not accept neither 0
	  nor fractional values for num_items parameter)
	* desired_state metadata allows to properly change non-running target
	  state during transition; when new state differs from old one, timer
	  is reset so it is guaranteed that each countdown starts from
	  COUNTDOWN_TICKS
	* num_items in keep_running method is set to 1 (default value);
	  machine aging is controlled by aging_factor solely; tubelib item
	  counter is used to count production iterations not actual items

	License: LGPLv2.1+
	=======================================================================
	
]]--

--[[
	---------
	Variables
	---------
]]--

-- Biogas time in ticks
local BIOGAS_TICKS = 12
-- timing
local TIMER_TICK_SEC = 1		-- Node timer tick
local STANDBY_TICKS = 4			-- Standby mode timer frequency factor
local COUNTDOWN_TICKS = 4		-- Ticks to standby

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
	biogas_time = tostring(BIOGAS_TICKS * TIMER_TICK_SEC),
}

-- recipe hint bar
local function formspec_recipe_hint_bar(recipe_idx)
	if #hintbar_recipes == 0 or recipe_idx > #hintbar_recipes then
		return ""
	end
	local input_name = hintbar_recipes[recipe_idx]
	local recipe = compactor_recipes[input_name]
	local output_name = recipe.output:get_name()
	local input_count = tostring(recipe.input:get_count())
	local output_count = tostring(recipe.output:get_count())
	return "item_image[0,0;1,1;" .. input_name .. "]" .. "item_image[" ..
		fmxy.inv_out_x .. ",0;1,1;" .. output_name .. "]" ..
	"label[0,3.25;Recipe]" ..
	"image_button[0.8,3.3;0.5,0.5;;left;<]" ..
	"label[1.2,3.25;" ..
		string.format("%2d / %2d", recipe_idx, #hintbar_recipes) .. "]" ..
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

-- formspec
local function formspec(self, pos, meta)
	local state = meta:get_int("tubelib_state")
	local recipe_idx = meta:get_int("recipe_idx")
	local fuel_pct = tostring(100 * meta:get_int("fuel_ticks") / BIOGAS_TICKS)
	local item_pct = tostring(100 * (1 - meta:get_int("item_ticks") / meta:get_int("item_total")))
	return "size[8,8.25]" ..
	default.gui_bg ..
	default.gui_bg_img ..
	default.gui_slots ..
	"list[context;src;0,0;" .. fmxy.inv_in_w .. "," .. fmxy.inv_h .. ";]" ..
	"list[context;cur;" .. fmxy.mid_x05 .. ",0;1,1;]" ..
	"list[context;cic;" .. fmxy.mid_x15 .. ",0;1,1;]" ..
	"image[" .. fmxy.mid_x05 ..
		",1;1,1;biogasmachines_compactor_inv_bg.png^[lowpart:" ..
		fuel_pct .. ":biogasmachines_compactor_inv_fg.png]" ..
	"image[" .. fmxy.mid_x15 ..
		",1;1,1;gui_furnace_arrow_bg.png^[lowpart:" ..
		item_pct .. ":gui_furnace_arrow_fg.png^[transformR270]" ..
	"list[context;fuel;" .. fmxy.inv_in_w .. ",2;1,1;]" ..
	"list[context;ice;" .. fmxy.mid_x2 .. ",2;1,1;]" ..
	"item_image[" .. fmxy.inv_in_w .. ",2;1,1;tubelib_addons1:biogas]" ..
	"item_image[" .. fmxy.mid_x2 .. ",2;1,1;default:ice]" ..
	"image_button[" .. fmxy.mid_x1 .. ",2;1,1;" ..
		self:get_state_button_image(meta) .. ";state_button;]" ..
	formspec_recipe_hint_bar(recipe_idx) ..
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

-- reset processing data
local function state_meta_reset(pos, meta)
	meta:set_int("item_ticks", -1)
	meta:set_int("item_total", -1)
end

--[[
	-------------
	State machine
	-------------
]]--

local machine = tubelib.NodeStates:new({
	node_name_passive = "biogasmachines:compactor",
	node_name_active = "biogasmachines:compactor_active",
	node_name_defect = "biogasmachines:compactor_defect",
	infotext_name = "Compactor",
	cycle_time = TIMER_TICK_SEC,
	standby_ticks = STANDBY_TICKS,
	has_item_meter = true,	-- used for production iterations actually
	aging_factor = 24,
	on_start = function(pos, meta, oldstate)
		meta:set_int("desired_state", tubelib.RUNNING)
		state_meta_reset(pos, meta)
	end,
	on_stop = function(pos, meta, oldstate)
		meta:set_int("desired_state", tubelib.STOPPED)
		state_meta_reset(pos, meta)
	end,
	formspec_func = formspec,
})

-- fault function for convenience as there is no on_fault method (yet)
local function machine_fault(pos, meta)
	meta:set_int("desired_state", tubelib.FAULT)
	state_meta_reset(pos, meta)
	machine:fault(pos, meta)
end

-- customized version of NodeStates:idle()
local function countdown_to_halt(pos, meta, target_state)
	if target_state ~= tubelib.STANDBY and
	   target_state ~= tubelib.BLOCKED and
	   target_state ~= tubelib.STOPPED and
	   target_state ~= tubelib.FAULT then
		return true
	end
	if machine:get_state(meta) == tubelib.RUNNING and
	   meta:get_int("desired_state") ~= target_state then
		meta:set_int("tubelib_countdown", COUNTDOWN_TICKS)
		meta:set_int("desired_state", target_state)
	end
	local countdown = meta:get_int("tubelib_countdown") - 1
	if countdown >= -1 then
		-- we don't need anything less than -1
		meta:set_int("tubelib_countdown", countdown)
	end
	if countdown < 0 then
		if machine:get_state(meta) == target_state then
			return true
		end
		meta:set_int("desired_state", target_state)
		-- workaround for switching between non-running states
		meta:set_int("tubelib_state", tubelib.RUNNING)
		if target_state == tubelib.FAULT then
			machine_fault(pos, meta)
		elseif target_state == tubelib.STOPPED then
			machine:stop(pos, meta)
		elseif target_state == tubelib.BLOCKED then
			machine:blocked(pos, meta)
		else
			machine:standby(pos, meta)
		end
		return false
	end
	return true
end

-- countdown to one of two states depending on fuel availability
local function fuel_countdown_to_halt(pos, meta, target_state_fuel, target_state_empty)
	local inv = meta:get_inventory()
	if meta:get_int("fuel_ticks") == 0 and inv:is_empty("fuel") then
		return countdown_to_halt(pos, meta, target_state_empty)
	else
		return countdown_to_halt(pos, meta, target_state_fuel)
	end
end

--[[
	---------
	Callbacks
	---------
]]--

-- do not allow to dig protected or non-empty machine
local function can_dig(pos, player)
	if minetest.is_protected(pos, player:get_player_name()) then
		return false
	end
	local meta = minetest.get_meta(pos);
	local inv = meta:get_inventory()
	return inv:is_empty("src") and inv:is_empty("dst")
		and inv:is_empty("fuel") and inv:is_empty("ice")
end

-- cleanup after digging
local function after_dig_node(pos, oldnode, oldmetadata, digger)
	tubelib.remove_node(pos)
end

-- init machine after placement
local function after_place_node(pos, placer, itemstack, pointed_thing)
	local meta = minetest.get_meta(pos)
	local inv = meta:get_inventory()
	inv:set_size('src', INV_H * INV_IN_W)
	inv:set_size('cur', 1)	-- working tray (item)
	inv:set_size('cic', 1)	-- working tray (ice)
	inv:set_size('fuel', 1)
	inv:set_size('ice', 1)
	inv:set_size('dst', INV_H * INV_OUT_W)
	meta:set_string("owner", placer:get_player_name())
	meta:set_int("fuel_ticks", 0)
	state_meta_reset(pos, meta)
	meta:set_int("recipe_idx", 1)
	local number = tubelib.add_node(pos, "biogasmachines:compactor")
	machine:node_init(pos, number)
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
	   machine:get_state(meta) == tubelib.RUNNING) then
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
		if machine:get_state(meta) == tubelib.RUNNING then
			return 0
		end
	end
	return stack:get_count()
end

-- formspec button handler
local function on_receive_fields(pos, formname, fields, player)
	if minetest.is_protected(pos, player:get_player_name()) then
		return
	end
	if machine:state_button_event(pos, fields) then
		return
	end
	if fields and (fields.left or fields.right) then
		local meta = minetest.get_meta(pos)
		local recipe_idx = meta:get_int("recipe_idx")
		if fields.left then
			recipe_idx = math.max(recipe_idx - 1, 1)
		end
		if fields.right then
			recipe_idx = math.min(recipe_idx + 1, #hintbar_recipes)
		end
		meta:set_int("recipe_idx", recipe_idx)
		meta:set_string("formspec", formspec(machine, pos, meta))
	end
end

-- tick-based item production
local function on_timer(pos, elapsed)
	local node = minetest.get_node(pos)
	local meta = minetest.get_meta(pos)
	local inv = meta:get_inventory()
	local fuel = meta:get_int("fuel_ticks")
	local ice = ItemStack("default:ice 1")
	local recipe = {}
	local inp
	if inv:is_empty("cur") then
		-- idle and ready, check for something to work with
		if inv:is_empty("src") or
		   (inv:is_empty("cic") and inv:is_empty("ice")) then
			return fuel_countdown_to_halt(pos, meta,
				tubelib.STANDBY, tubelib.STOPPED)
		end
		-- find item to compact that fits output tray
		local is_src_ok = false
		local src_copy = inv:set_list("src_copy", inv:get_list("src"))
		for _, r in pairs(compactor_recipes) do
			inp = inv:remove_item("src_copy", r.input)
			if inp:get_count() == r.input:get_count() then
				is_src_ok = true
				if inv:room_for_item("dst", r.output) then
					recipe = r
					break
				end
			end
		end
		inv:set_size("src_copy", 0)
		if not recipe.time then
			-- no processing possible
			if is_src_ok then
				-- source is ok but output tray is full
				if machine:get_state(meta) == tubelib.STANDBY then
					-- adapt behaviour to other biogas machines
					-- (standby->blocked should go through running)
					machine:start(pos, meta, true)
					return false
				else
					return fuel_countdown_to_halt(pos, meta,
						tubelib.BLOCKED, tubelib.FAULT)
				end
			else
				-- not enough items in source tray
				return fuel_countdown_to_halt(pos, meta,
					tubelib.STANDBY, tubelib.STOPPED)
			end
		elseif machine:get_state(meta) == tubelib.STANDBY or
		       machine:get_state(meta) == tubelib.BLOCKED then
			-- something to do, wake up and re-entry
			machine:start(pos, meta, true)
			return false
		end
		if fuel == 0 and inv:is_empty("fuel") then
			return countdown_to_halt(pos, meta, tubelib.FAULT)
		end
		inp = inv:remove_item("src", recipe.input)
		if inp:is_empty() or inp:get_count() < recipe.input:get_count() then
			machine_fault(pos, meta)	-- oops
			return false
		end
		inv:set_stack("cur", 1, recipe.input)
		if inv:is_empty("cic") then
			inp = inv:remove_item("ice", ice)
			if inp:is_empty() then
				machine_fault(pos, meta)	-- oops
				return false
			end
			inv:set_stack("cic", 1, inp)
		end
		meta:set_int("item_ticks", recipe.time)
		meta:set_int("item_total", recipe.time)
	elseif inv:is_empty("cic") then
		-- ice removed manually while machine was off - reload
		if fuel == 0 and inv:is_empty("fuel") then
			return countdown_to_halt(pos, meta, tubelib.FAULT)
		end
		if inv:is_empty("ice") then
			return countdown_to_halt(pos, meta, tubelib.STANDBY)
		elseif machine:get_state(meta) == tubelib.STANDBY then
			machine:start(pos, meta, true)
			return false
		end
		inp = inv:remove_item("ice", ice)
		inv:set_stack("cic", 1, inp)
	else
		-- production
		if machine:get_state(meta) ~= tubelib.RUNNING or
		   inv:is_empty("cur") or inv:is_empty("cic") then
			-- exception, should not happen - oops
			machine_fault(pos, meta)
			return false
		end
		if fuel == 0 and inv:is_empty("fuel") then
			return countdown_to_halt(pos, meta, tubelib.FAULT)
		end
		inp = inv:get_stack("cur", 1)
		recipe = compactor_recipes[inp:get_name()]	-- (reference!)
		if not recipe or not recipe.time or
		   inp:get_count() ~= recipe.input:get_count() then
			machine_fault(pos, meta)	-- oops
			return false
		end
		local itemcnt = meta:get_int("item_ticks")
		if itemcnt < 0 then
			meta:set_int("item_total", recipe.time)
			itemcnt = recipe.time	-- compact again
		end
		itemcnt = itemcnt - 1
		if itemcnt == 0 then
			inv:add_item("dst", recipe.output)
			inv:set_stack("cur", 1, ItemStack({}))
			inv:set_stack("cic", 1, ItemStack({}))
			state_meta_reset(pos, meta)
			-- item produced, increase aging
			machine:keep_running(pos, meta, COUNTDOWN_TICKS)
		else
			meta:set_int("item_ticks", itemcnt)
		end
		-- consume fuel tick
		if fuel == 0 then
			if not inv:is_empty("fuel") then
				inv:remove_item("fuel",
					ItemStack("tubelib_addons1:biogas 1"))
				fuel = BIOGAS_TICKS
			else
				machine_fault(pos, meta)	-- oops
				return false
			end
		end
		meta:set_int("fuel_ticks", fuel - 1)
	end
	meta:set_int("tubelib_countdown", COUNTDOWN_TICKS)
	meta:set_int("desired_state", tubelib.RUNNING)
	meta:set_string("formspec", formspec(machine, pos, meta))
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

	drop = "",
	can_dig = can_dig,

	after_dig_node = function(pos, oldnode, oldmetadata, digger)
		machine:after_dig_node(pos, oldnode, oldmetadata, digger)
		after_dig_node(pos, oldnode, oldmetadata, digger)
	end,

	on_rotate = screwdriver.disallow,
	on_timer = on_timer,
	on_receive_fields = on_receive_fields,
	allow_metadata_inventory_put = allow_metadata_inventory_put,
	allow_metadata_inventory_move = allow_metadata_inventory_move,
	allow_metadata_inventory_take = allow_metadata_inventory_take,
	after_place_node = after_place_node,
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

	drop = "",
	can_dig = can_dig,

	after_dig_node = function(pos, oldnode, oldmetadata, digger)
		machine:after_dig_node(pos, oldnode, oldmetadata, digger)
		after_dig_node(pos, oldnode, oldmetadata, digger)
	end,

	on_rotate = screwdriver.disallow,
	on_timer = on_timer,
	on_receive_fields = on_receive_fields,
	allow_metadata_inventory_put = allow_metadata_inventory_put,
	allow_metadata_inventory_move = allow_metadata_inventory_move,
	allow_metadata_inventory_take = allow_metadata_inventory_take,
})

minetest.register_node("biogasmachines:compactor_defect", {
	description = "Tubelib Compactor",
	tiles = {
		-- up, down, right, left, back, front
		"biogasmachines_compactor_top.png",
		"biogasmachines_bottom.png",
		"biogasmachines_compactor_side.png^tubelib_defect.png",
		"biogasmachines_compactor_side.png^tubelib_defect.png",
		"biogasmachines_compactor_side.png^tubelib_defect.png",
		"biogasmachines_compactor_side.png^tubelib_defect.png",
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
	groups = { choppy = 2, cracky = 2, crumbly = 2, not_in_creative_inventory = 1 },
	is_ground_content = false,
	sounds = default.node_sound_metal_defaults(),

	can_dig = can_dig,
	after_dig_node = after_dig_node,
	on_rotate = screwdriver.disallow,
	allow_metadata_inventory_put = allow_metadata_inventory_put,
	allow_metadata_inventory_move = allow_metadata_inventory_move,
	allow_metadata_inventory_take = allow_metadata_inventory_take,

	after_place_node = function(pos, placer, itemstack, pointed_thing)
		after_place_node(pos, placer, itemstack, pointed_thing)
		machine:defect(pos, minetest.get_meta(pos))
	end,
})

tubelib.register_node("biogasmachines:compactor",
	{ "biogasmachines:compactor_active", "biogasmachines:compactor_defect" }, {

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
		if topic == "fuel" then
			return tubelib.fuelstate(meta, "fuel")
		end
		local resp = machine:on_receive_message(pos, topic, payload)
		if resp then
			return resp
		else
			return "unsupported"
		end
	end,

	on_node_load = function(pos)
		machine:on_node_load(pos)
	end,

	on_node_repair = function(pos)
		return machine:on_node_repair(pos)
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
		{ "default:steelblock", "default:obsidian_block", "default:steelblock" },
		{ "default:mese_crystal", "default:diamondblock", "tubelib:tubeS" },
		{ "group:wood", "default:obsidian_block", "group:wood" },
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
