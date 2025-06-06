/datum/material/flockium
	name = MAT_FLOKIUM
	//stack_type = /obj/item/stack/material/sandstone
	icon_base = "flock"
	icon_reinf = "flock"
	icon_colour = "#FFFFFF"
	//shard_type = SHARD_STONE_PIECE
	weight = 30
	hardness = 200
	protectiveness = 5 // 20%
	conductive = 0
	conductivity = 0
	door_icon_base = "flockdoor"
	sheet_singular_name = "quanta"
	sheet_plural_name = "quanta"
	wiki_flag = WIKI_SPOILER

/obj/structure/simple_door/flock
	name = "aperture"
	icon = 'icons/goonstation/featherzone.dmi'
	icon_state = "flockdoor"

/obj/structure/simple_door/flock/Initialize(mapload, var/newmat)
	. = ..(mapload, MAT_FLOKIUM)
