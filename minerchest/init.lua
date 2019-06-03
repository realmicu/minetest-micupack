--[[

	========================================================================
	Miner's Chest
	by Micu (c) 2019

	Copyright (C) 2019 Michal Cieslakiewicz

	This is source file for Miner's Chest - a high capacity storage chest
	that automatically combines selected resources into respective blocks.

	Chest is compatible with Techpack (Tubelib2 framework). It has capacity
	of 60 items and supports stack pulling (can be paired with HighPerf
	Pusher).

	It automatically combines following items into blocks:
	* steel ingot -> steel block
	* copper ingot -> copper block
	* bronze ingot -> bronze block
	* tin ingot -> tin block
	* gold ingot -> gold block
	* silver ingot (moreores mod) -> silver block
	* mithril ingot (moreores mod) -> mithril block
	* brass ingot (basic_materials mod) -> brass block
	* coal lump -> coal block
	* mese crystal -> mese block
	* diamond crystal -> diamond block
	* wheat -> straw
	* sand -> sandstone
	* desert sand -> desert sandstone
	* silver sand -> silver sandstone
	* clay lump -> clay block

	More allowed item combinations can be registered via API function.

	Chest supports only reversible combinations (example: metal blocks can
	be converted back to ingots) of popular minerals and resources (hence
	name Miner's Chest). Due to game internal design, chest requires some
	spare slots to perform item reorganization as it may process only
	things that are already in its inventory.

	Features:
	* automatic crafting of configured items into blocks
	* automatic stack merging
	* Tubelib I/O compatibility
	* support for Tubelib stack pulling (can be paired with HighPerf Pusher)
	* item prioritization for Tubelib pulling (stackable items go last)
	* no defects (not a machine)
	* support for standard SaferLua storage status (empty/loaded/full)
	* storage status visual indicator and infotext
	* infobar in inventory window
	* no node timer

	License: LGPLv2.1+
	========================================================================
	
]]--

--[[
	---------
	Variables
	---------
]]--

minerchest = {}

local INV_X = 12
local INV_Y = 5
local INV_SIZE = INV_X * INV_Y

--[[
	----------------------
	Public functions (API)
	----------------------
]]--

local combdata = {}

-- Allow chest to combine items into respective blocks
-- source_item - source item name
-- block_item - destination block item name
-- Note: do not put any quantities here - function automatically
-- picks up recipe based on supplied parameters; it returns true
-- if completed successfully, false if error or already defined.
function minerchest.allow_item_combine(source_item, block_item)
	if not source_item or not block_item then
		return false
	end
	local source_stack = ItemStack(source_item)
	local block_stack = ItemStack(block_item)
	if not source_stack:is_known() or not block_stack:is_known() then
		return false
	end
	local sn = source_stack:get_name()
	local bn = block_stack:get_name()
	if combdata[sn] then
		return false
	end
	local fis = nil
	local fib = nil
	-- find recipe for block that uses source item only
	local rt = minetest.get_all_craft_recipes(bn)
	for _, r in ipairs(rt) do
		if r.type == "normal" and r.method == "normal" then
			local o = ItemStack(r.output)
			if bn == o:get_name() then
				local icnt = 0
				local iok = true
				for _, i in ipairs(r.items) do
					local s = ItemStack(i)
					if s:get_name() ~= sn then
						iok = false
						break
					end
					icnt = icnt + s:get_count()
				end
				if iok then
					fis = sn .. " " .. icnt
					fib = o:to_string()
					break
				end
			end
		end
	end
	if not fis or not fib then
		return false
	end
	-- verify if recipe is reversible
	local isrev = false
	rt = minetest.get_all_craft_recipes(sn)
	for _, r in ipairs(rt) do
		if r.type == "normal" and r.method == "normal" then
			local o = ItemStack(r.output)
			if sn == o:get_name() then
				local iok = true
				for _, i in ipairs(r.items) do
					local s = ItemStack(i)
					if s:get_name() ~= bn then
						iok = false
						break
					end
				end
				if iok then
					isrev = true
					break
				end
			end
		end
	end
	if not isrev then
		return false
	end
	combdata[sn] = { items = fis, output = fib }
	return true
end

--[[
        --------
        Formspec
        --------
]]--

-- get node/item/tool description for tooltip
local function formspec_tooltip(name)
	local def = minetest.registered_nodes[name] or
		minetest.registered_craftitems[name] or
		minetest.registered_items[name] or
		minetest.registered_tools[name] or nil
	return def and def.description or ""
end

-- display info bar between chest and player repositories
local function formspec_item_bar(width, y)
	local cblen = 0
	for i, _ in pairs(combdata) do
		cblen = cblen + 1
	end
	local arrowup = "tubelib_gui_arrow.png^[transformR90"
	local mx = math.max((width - cblen * 0.5 - 1) / 2, 0)
	local itembar = "image[" .. tostring(mx) .. "," ..
		tostring(y + 0.25) .. ";0.5,0.5;" .. arrowup .. "]"
	local x = mx + 0.5
	for i, c in pairs(combdata) do
		local b = ItemStack(c.output)
		b = b:get_name()
		itembar = itembar ..
			"item_image[" .. tostring(x) .. "," .. tostring(y) .. ";0.5,0.5;" .. b .. "]" ..
			"tooltip[" .. tostring(x) .. "," .. tostring(y) .. ";0.5,0.5;" .. formspec_tooltip(b) .. "]" ..
			"item_image[" .. tostring(x) .. "," .. tostring(y + 0.5) .. ";0.5,0.5;" .. i .. "]" ..
			"tooltip[" .. tostring(x) .. "," .. tostring(y + 0.5) .. ";0.5,0.5;" .. formspec_tooltip(i) .. "]"
		x = x + 0.5
		if x >= width - mx - 0.5 then
			break
		end
	end
	local itembar = itembar .. "image[" .. tostring(x) .. "," ..
		tostring(y + 0.25) .. ";0.5,0.5;" .. arrowup .. "]"
	return itembar
end

-- formspec (with autoformatting)
local function formspec()
	local sizex = math.max(INV_X, 8)
	local invby = math.max(INV_Y, 2)
	local plrx = tostring((sizex - 8) / 2)
	return "size[" .. tostring(sizex) .. "," ..
		tostring(invby + 5.75) .. "]" ..
	default.gui_bg ..
	default.gui_bg_img ..
	default.gui_slots ..
	"list[context;main;" .. tostring((sizex - INV_X) / 2).. "," ..
		tostring((invby - INV_Y) / 2) .. ";" ..
		tostring(INV_X) .. "," ..
		tostring(INV_Y) .. ";]" ..
	formspec_item_bar(sizex, invby + 0.25) ..
	"list[current_player;main;" .. plrx .. "," ..
		tostring(invby + 1.5) .. "4;8,1;]" ..
	"list[current_player;main;" .. plrx .. "," ..
		tostring(invby + 2.75) .. ";8,3;8]" ..
	"listring[context;main]" ..
	"listring[current_player;main]" ..
	default.get_hotbar_bg(plrx, invby + 1.5)
end

--[[
	-------
	Helpers
	-------
]]--

-- swap chest node at pos to reflect current fill state
local function update_chest_node(pos)
	local node = minetest.get_node(pos)
	local meta = minetest.get_meta(pos)
	local number = meta:get_string("number")
	local state = tubelib.get_inv_state(meta, "main")
	meta:set_string("infotext", "Miner Chest " .. number ..
		" (" .. state .. ")")
	local newname
	if state == "full" then
		newname = "minerchest:chest_full"
	else
		newname = "minerchest:chest"
	end
	if newname ~= node.name then
		node.name = newname
		minetest.swap_node(pos, node)
	end
end

-- pile up all items to maximize free space
local function pile_up_items(inv, list)
	local invsz = inv:get_size(list)
	local itbl = {}
	for i = 1, invsz do
		local s = inv:get_stack(list, i)
		if not s:is_empty() then
			itbl[#itbl + 1] = s:to_string()	-- otherwise you get reference!
			s:clear()
			inv:set_stack(list, i, s)
		end
	end
	for i = 1, #itbl do
		inv:add_item(list, itbl[i])
	end
end

-- reorganize and combine items
local function combine_chest_items(pos)
	local node = minetest.get_node(pos)
	local meta = minetest.get_meta(pos)
	local inv = meta:get_inventory()
	if inv:is_empty("main") then
		return
	end
	-- pile up before
	pile_up_items(inv, "main")
	-- combine items when applicable
	for i, c in pairs(combdata) do
		local is = ItemStack(c.items)
		local bs = ItemStack(c.output)
		local iscnt = is:get_count()
		while true do
			local taken = inv:remove_item("main", is)
			if taken:is_empty() then
				break
			elseif taken:get_count() < iscnt or
			  not inv:room_for_item("main", bs) then
				inv:add_item("main", taken) -- put back
				break
			end
			inv:add_item("main", bs)	
		end
	end
	-- pile up after
	pile_up_items(inv, "main")
end

-- tubelib takes items in a round-robin fashion - this function
-- modifies this method a little by skipping items that can be
-- combined into blocks - until only these remain
local function set_next_tubelib_item(meta, list)
	local inv = meta:get_inventory()
	if inv:is_empty(list) then
		return
	end
	local invsz = inv:get_size(list)
	local i = meta:get_int("tubelib_startpos") or 0
	local c = 0
	while c < invsz do
		local ni = (i % invsz) + 1
		local s = inv:get_stack(list, ni)
		if not s:is_empty() and not combdata[s:get_name()] then
			break
		end
		i = ni
		c = c + 1
	end
	meta:set_int("tubelib_startpos", i)
end

--[[
	---------
	Callbacks
	---------
]]--

-- do not allow to dig protected or non-empty chest
local function can_dig(pos, player)
	if minetest.is_protected(pos, player:get_player_name()) then
		return false
	end
	local meta = minetest.get_meta(pos)
	local inv = meta:get_inventory()
	return inv:is_empty("main")
end

-- cleanup after digging
local function after_dig_node(pos, oldnode, oldmetadata, digger)
	tubelib.remove_node(pos)
end

-- init after placement
local function after_place_node(pos, placer, itemstack, pointed_thing)
	local node = minetest.get_node(pos)
	local meta = minetest.get_meta(pos)
	local inv = meta:get_inventory()
	inv:set_size("main", INV_SIZE)
	meta:set_string("owner", placer:get_player_name())
	local number = tubelib.add_node(pos, "minerchest:chest")
	meta:set_string("number", number)
	meta:set_string("formspec", formspec())
	update_chest_node(pos)
end

-- common function for on_metadata_inventory_* callbacks
local function on_metadata_inventory_change(pos)
	combine_chest_items(pos)
	update_chest_node(pos)
end

--[[
	-----------------
	Node registration
	-----------------
]]--

minetest.register_node("minerchest:chest", {
	description = "Miner Chest",
	tiles = {
		-- up, down, right, left, back, front
		"minerchest_plate.png",
		"minerchest_plate.png",
		"minerchest_side.png",
		"minerchest_side.png",
		"minerchest_side.png",
		"minerchest_front.png",
	},
	drawtype = "nodebox",

	paramtype = "light",
	sunlight_propagates = true,
	paramtype2 = "facedir",
	groups = { choppy = 2, cracky = 2, crumbly = 2 },
	is_ground_content = false,
	sounds = default.node_sound_metal_defaults(),

	after_place_node = after_place_node,
	can_dig = can_dig,
	after_dig_node = after_dig_node,
	on_rotate = screwdriver.disallow,
	on_metadata_inventory_move = on_metadata_inventory_change,
	on_metadata_inventory_put = on_metadata_inventory_change,
	on_metadata_inventory_take = on_metadata_inventory_change,
})

minetest.register_node("minerchest:chest_full", {
	description = "Miner Chest",
	tiles = {
		-- up, down, right, left, back, front
		"minerchest_plate.png",
		"minerchest_plate.png",
		"minerchest_side.png",
		"minerchest_side.png",
		"minerchest_side.png",
		"minerchest_front_full.png",
	},
	drawtype = "nodebox",

	paramtype = "light",
	sunlight_propagates = true,
	paramtype2 = "facedir",
	groups = { choppy = 2, cracky = 2, crumbly = 2,
		not_in_creative_inventory = 1 },
	is_ground_content = false,
	sounds = default.node_sound_metal_defaults(),

	drop = "minerchest:chest",
	after_place_node = after_place_node,
	can_dig = can_dig,
	after_dig_node = after_dig_node,
	on_rotate = screwdriver.disallow,
	on_metadata_inventory_move = on_metadata_inventory_change,
	on_metadata_inventory_put = on_metadata_inventory_change,
	on_metadata_inventory_take = on_metadata_inventory_change,
})

tubelib.register_node("minerchest:chest", { "minerchest:chest_full" }, {

	on_push_item = function(pos, side, item)
		local meta = minetest.get_meta(pos)
		local ret = tubelib.put_item(meta, "main", item)
		combine_chest_items(pos)
		update_chest_node(pos)
		return ret
	end,

	on_pull_item = function(pos, side)
		local meta = minetest.get_meta(pos)
		set_next_tubelib_item(meta, "main")
		local ret = tubelib.get_item(meta, "main")
		combine_chest_items(pos)
		update_chest_node(pos)
		return ret
	end,

	on_pull_stack = function(pos, side)
		local meta = minetest.get_meta(pos)
		set_next_tubelib_item(meta, "main")
		local ret = tubelib.get_stack(meta, "main")
		combine_chest_items(pos)
		update_chest_node(pos)
		return ret
	end,

	on_unpull_item = function(pos, side, item)
		local meta = minetest.get_meta(pos)
		local ret = tubelib.put_item(meta, "main", item)
		combine_chest_items(pos)
		update_chest_node(pos)
		return ret
	end,

	on_recv_message = function(pos, topic, payload)
                if topic == "state" then
			local meta = minetest.get_meta(pos)
			return tubelib.get_inv_state(meta, "main")
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
	output = "minerchest:chest",
	recipe = {
		{ "default:steelblock", "tubelib:tubeS", "default:goldblock" },
		{ "group:wood", "", "group:wood" },
		{ "default:copperblock", "group:wood", "default:tinblock" },
	},
})

--[[
	------------
	Combinations
	------------
]]--

minerchest.allow_item_combine("default:steel_ingot", "default:steelblock")
minerchest.allow_item_combine("default:copper_ingot", "default:copperblock")
minerchest.allow_item_combine("default:bronze_ingot", "default:bronzeblock")
minerchest.allow_item_combine("default:tin_ingot", "default:tinblock")
minerchest.allow_item_combine("default:gold_ingot", "default:goldblock")
minerchest.allow_item_combine("default:coal_lump", "default:coalblock")
minerchest.allow_item_combine("default:diamond", "default:diamondblock")
minerchest.allow_item_combine("default:mese_crystal", "default:mese")
minerchest.allow_item_combine("default:sand", "default:sandstone")
minerchest.allow_item_combine("default:desert_sand", "default:desert_sandstone")
minerchest.allow_item_combine("default:silver_sand", "default:silver_sandstone")
minerchest.allow_item_combine("default:clay_lump", "default:clay")
minerchest.allow_item_combine("farming:wheat", "farming:straw")

if minetest.global_exists("moreores") then
	minerchest.allow_item_combine("moreores:silver_ingot", "moreores:silver_block")
	minerchest.allow_item_combine("moreores:mithril_ingot", "moreores:mithril_block")
end

if minetest.global_exists("basic_materials") then
	minerchest.allow_item_combine("basic_materials:brass_ingot", "basic_materials:brass_block")
end