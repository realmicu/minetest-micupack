--[[

	=======================================================
	SmartLine Modules Mod
	by Micu (c) 2018, 2019

	Copyright (C) 2018, 2019 Michal Cieslakiewicz

	License: LGPLv2.1+
	Media: CC BY-SA
	=======================================================

]]--


slmodules = {}

slmodules.texture_alpha_mode = minetest.features.use_texture_alpha_string_modes
        and "clip" or true

dofile(minetest.get_modpath("slmodules") .. "/furnacemonitor.lua")
dofile(minetest.get_modpath("slmodules") .. "/digitalswitch.lua")
dofile(minetest.get_modpath("slmodules") .. "/autosievesensor.lua")
dofile(minetest.get_modpath("slmodules") .. "/cropswatcher.lua")
dofile(minetest.get_modpath("slmodules") .. "/digilinesrelay.lua")
