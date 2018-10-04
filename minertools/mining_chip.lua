
--[[

	Mining Chip v1.0

	Mandatory component for all electronic devices in this mod

]]--

-- *************
-- Register Item
-- *************

minetest.register_craftitem("minertools:mining_chip", {
	description = "Mining Chip",
	inventory_image = "minertools_miningchip_inv.png",
})

-- ************
-- Craft Recipe
-- ************

minetest.register_craft({
	output = "minertools:mining_chip",
	type = "shaped",
	recipe = {
		{ "default:copper_ingot", "default:gold_ingot", "default:copper_ingot" },
		{ "default:copper_ingot", "default:mese_crystal", "default:copper_ingot" },
		{ "default:copper_ingot", "group:sand", "default:copper_ingot" },
	},
})

