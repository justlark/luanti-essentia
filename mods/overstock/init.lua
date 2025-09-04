core.register_node("overstock:barrel", {
	description = "Barrel",
	tiles = {
		"overstock_barrel_top.png",
		"overstock_barrel_bottom.png",
		"overstock_barrel_front.png",
		"overstock_barrel_side.png",
		"overstock_barrel_side.png",
		"overstock_barrel_side.png",
	},
	groups = {
		axey = 1,
		material_wood = 1,
	},
})

core.register_craft({
	type = "shaped",
	output = "overstock:barrel 1",
	recipe = {
		{ "group:tree", "group:wood_slab", "group:tree" },
		{ "group:tree", "mcl_chests:chest", "group:tree" },
		{ "group:tree", "group:tree", "group:tree" },
	},
})
