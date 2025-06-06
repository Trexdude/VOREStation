//Food items that are eaten normally and don't leave anything behind.
/obj/item/reagent_containers/food/snacks
	name = "snack"
	desc = "yummy"
	icon = 'icons/obj/food.dmi'
	icon_state = null
	center_of_mass_x = 16
	center_of_mass_y = 16
	w_class = ITEMSIZE_SMALL
	force = 0
	volume = 80

	var/bitesize = 1
	var/bitecount = 0
	var/trash = null
	var/slice_path
	var/slices_num
	var/dried_type = null
	var/dry = 0
	var/survivalfood = FALSE
	var/nutriment_amt = 0
	var/list/nutriment_desc = list("food" = 1)
	var/datum/reagent/nutriment/coating/coating = null
	var/icon/flat_icon = null //Used to cache a flat icon generated from dipping in batter. This is used again to make the cooked-batter-overlay
	var/do_coating_prefix = 1 //If 0, we wont do "battered thing" or similar prefixes. Mainly for recipes that include batter but have a special name

	/// Used for foods that are "cooked" without being made into a specific recipe or combination.
	/// Generally applied during modification cooking with oven/fryer
	/// Used to stop deepfried meat from looking like slightly tanned raw meat, and make it actually look cooked
	var/cooked_icon = null

	/// If this has a wrapper on it. If true, it will print a message and ask you to remove it
	var/package = FALSE
	/// Packaged meals drop this trash type item when opened, if set
	var/package_trash
	/// Packaged meals switch to this state when opened, if set
	var/package_open_state
	/// Packaged meals that have opening animation
	var/package_opening_state

	/// If this is canned. If true, it will print a message and ask you to open it
	var/canned = FALSE
	/// Canned food switch to this state when opened, if set
	var/canned_open_state

	/// For packaged/canned food sounds
	var/opening_sound = null
	/// Sound of eating.
	var/eating_sound = 'sound/items/eatfood.ogg'

	/// Yems.
	food_can_insert_micro = TRUE

/obj/item/reagent_containers/food/snacks/Initialize(mapload)
	. = ..()
	if(nutriment_amt)
		reagents.add_reagent(REAGENT_ID_NUTRIMENT,(nutriment_amt*2),nutriment_desc)

//Placeholder for effect that trigger on eating that aren't tied to reagents.
/obj/item/reagent_containers/food/snacks/proc/On_Consume(var/mob/living/M)
	if(food_inserted_micros && food_inserted_micros.len)
		if(M.can_be_drop_pred && M.food_vore && M.vore_selected)
			for(var/mob/living/F in food_inserted_micros)
				if(!F.can_be_drop_prey || !F.food_vore)
					continue

				var/do_nom = FALSE

				if(!reagents.total_volume)
					do_nom = TRUE
				else
					var/nom_chance = (bitecount/(bitecount + (bitesize / reagents.total_volume) + 1))*100
					if(prob(nom_chance))
						do_nom = TRUE

				if(do_nom)
					F.forceMove(M.vore_selected)
					food_inserted_micros -= F

	if(!reagents.total_volume)
		M.balloon_alert_visible("eats \the [src].","finishes eating \the [src].")

		M.drop_from_inventory(src) // Drop food from inventory so it doesn't end up staying on the hud after qdel, and so inhands go away

		if(trash)
			var/obj/item/TrashItem = new trash(M)
			M.put_in_hands(TrashItem)
		qdel(src)

/obj/item/reagent_containers/food/snacks/attack_self(mob/user as mob)
	if(package && !user.incapacitated())
		unpackage(user)

	if(canned && !user.incapacitated())
		uncan(user)

/obj/item/reagent_containers/food/snacks/attack(mob/living/M as mob, mob/user as mob, def_zone)
	if(reagents && !reagents.total_volume)
		balloon_alert(user, "none of \the [src] left!")
		user.drop_from_inventory(src)
		qdel(src)
		return 0

	if(package)
		balloon_alert(user, "the package is in the way!")
		return FALSE

	if(canned)
		balloon_alert(user, "the can is closed!")
		return FALSE

	if(istype(M, /mob/living/carbon))
		//TODO: replace with standard_feed_mob() call.

		if(!M.consume_liquid_belly)
			if(liquid_belly_check())
				to_chat(user, span_infoplain("[user == M ? "You can't" : "\The [M] can't"] consume that, it contains something produced from a belly!"))
				return FALSE
		var/swallow_whole = FALSE
		var/obj/belly/belly_target				// These are surprise tools that will help us later

		var/fullness = M.nutrition + (M.reagents.get_reagent_amount(REAGENT_ID_NUTRIMENT) * 25)
		if(M == user)								//If you're eating it yourself
			if(ishuman(M))
				var/mob/living/carbon/human/H = M
				if(!H.check_has_mouth())
					balloon_alert(user, "you don't have a mouth!")
					return
				var/obj/item/blocked = null
				if(survivalfood)
					blocked = H.check_mouth_coverage_survival()
				else
					blocked = H.check_mouth_coverage()
				if(blocked)
					balloon_alert(user, "\the [blocked] is in the way!")
					return

			user.setClickCooldown(user.get_attack_speed(src)) //puts a limit on how fast people can eat/drink things
			if (fullness <= 50)
				to_chat(M, span_danger("You hungrily chew out a piece of [src] and gobble it!"))
			if (fullness > 50 && fullness <= 150)
				to_chat(M, span_notice("You hungrily begin to eat [src]."))
			if (fullness > 150 && fullness <= 350)
				to_chat(M, span_notice("You take a bite of [src]."))
			if (fullness > 350 && fullness <= 550)
				to_chat(M, span_notice("You unwillingly chew a bit of [src]."))
			if (fullness > 550 && fullness <= 650)
				to_chat(M, span_notice("You swallow some more of the [src], causing your belly to swell out a little."))
			if (fullness > 650 && fullness <= 1000)
				to_chat(M, span_notice("You stuff yourself with the [src]. Your stomach feels very heavy."))
			if (fullness > 1000 && fullness <= 3000)
				to_chat(M, span_notice("You gluttonously swallow down the hunk of [src]. You're so gorged, it's hard to stand."))
			if (fullness > 3000 && fullness <= 5500)
				to_chat(M, span_danger("You force the piece of [src] down your throat. You can feel your stomach getting firm as it reaches its limits."))
			if (fullness > 5500 && fullness <= 6000)
				to_chat(M, span_danger("You barely glug down the bite of [src], causing undigested food to force into your intestines. You can't take much more of this!"))
			if (fullness > 6000) // There has to be a limit eventually.
				to_chat(M, span_danger("Your stomach blorts and aches, prompting you to stop. You literally cannot force any more of [src] to go down your throat."))
				return 0

		else if(user.a_intent == I_HURT)
			return ..()

		else
			if(ishuman(M))
				var/mob/living/carbon/human/H = M
				if(!H.check_has_mouth())
					// to_chat(user, "Where do you intend to put \the [src]? \The [H] doesn't have a mouth!")
					balloon_alert(user, "\the [H] doesn't have a mouth!")
					return
				var/obj/item/blocked = null
				var/unconcious = FALSE
				blocked = H.check_mouth_coverage()
				if(survivalfood)
					blocked = H.check_mouth_coverage_survival()
					if(H.stat && H.check_mouth_coverage())
						unconcious = TRUE
						blocked = H.check_mouth_coverage()

				if(isliving(user))	// We definitely are, but never hurts to check
					var/mob/living/L = user
					swallow_whole = L.stuffing_feeder
				if(swallow_whole)
					belly_target = tgui_input_list(user, "Choose Belly", "Belly Choice", M.feedable_bellies())

				if(unconcious)
					to_chat(user, span_warning("You can't feed [H] through \the [blocked] while they are unconcious!"))
					return

				if(blocked)
					// to_chat(user, span_warning("\The [blocked] is in the way!"))
					balloon_alert(user, "\the [blocked] is in the way!")
					return

				if(swallow_whole)
					if(!(M.feeding))
						balloon_alert(user, "you can't feed [H] a whole [src] as they refuse to be fed whole things!")
						return
					if(!belly_target)
						balloon_alert(user, "you can't feed [H] a whole [src] as they don't appear to have a belly to fit it!")
						return

				if(swallow_whole)
					user.balloon_alert_visible("[user] attempts to make [M] consume [src] whole into their [belly_target].")
				else
					user.balloon_alert_visible("[user] attempts to feed [M] [src].")

				var/feed_duration = 3 SECONDS
				if(swallow_whole)
					feed_duration = 5 SECONDS

				user.setClickCooldown(user.get_attack_speed(src))
				if(!do_mob(user, M, feed_duration)) return

				if(swallow_whole && !belly_target) return			// Just in case we lost belly mid-feed

				if(swallow_whole)
					add_attack_logs(user,M,"Whole-fed with [src.name] containing [reagentlist(src)] into [belly_target]", admin_notify = FALSE)
					user.visible_message("[user] successfully forces [src] into [M]'s [belly_target].")
					user.balloon_alert_visible("forces [src] into [M]'s [belly_target]")
				else
					add_attack_logs(user,M,"Fed with [src.name] containing [reagentlist(src)]", admin_notify = FALSE)
					user.visible_message("[user] feeds [M] [src].")
					user.balloon_alert_visible("feeds [M] [src].")

			else
				balloon_alert(user, "this creature does not seem to have a mouth!")
				return

		if(swallow_whole)
			user.drop_item()
			forceMove(belly_target)
			return 1
		else if(reagents)								//Handle ingestion of the reagent.
			playsound(M, eating_sound, rand(10,50), 1)
			if(reagents.total_volume)
				if(reagents.total_volume > bitesize)
					reagents.trans_to_mob(M, bitesize, CHEM_INGEST)
				else
					reagents.trans_to_mob(M, reagents.total_volume, CHEM_INGEST)
				bitecount++
				On_Consume(M)
			return 1

	return 0

/obj/item/reagent_containers/food/snacks/examine(mob/user)
	. = ..()
	if(Adjacent(user))
		if(food_inserted_micros && food_inserted_micros.len)
			. += span_notice("It has [english_list(food_inserted_micros)] stuck in it.")
		if(coating)
			. += span_notice("It's coated in [coating.name]!")
		if(bitecount==0)
			return .
		else if (bitecount==1)
			. += span_notice("It was bitten by someone!")
		else if (bitecount<=3)
			. += span_notice("It was bitten [bitecount] times!")
		else
			. += span_notice("It was bitten multiple times!")

/obj/item/reagent_containers/food/snacks/attackby(obj/item/W as obj, mob/user as mob)
	if(istype(W,/obj/item/storage))
		. = ..() // -> item/attackby()
		return

	// Eating with forks
	if(istype(W,/obj/item/material/kitchen/utensil))
		var/obj/item/material/kitchen/utensil/U = W
		U.load_food(user, src)
		return

	if(food_can_insert_micro && istype(W, /obj/item/holder))
		if(!(istype(W, /obj/item/holder/micro) || istype(W, /obj/item/holder/mouse)))
			. = ..()
			return

		if(package || canned)
			to_chat(user, span_warning("You cannot stuff anything into \the [src] without opening it first."))
			balloon_alert(user, "open \the [src] first!")
			return

		var/obj/item/holder/H = W

		if(!food_inserted_micros)
			food_inserted_micros = list()

		var/mob/living/M = H.held_mob

		M.forceMove(src)
		H.held_mob = null
		user.drop_from_inventory(H)
		qdel(H)

		food_inserted_micros += M

		to_chat(user, "Stuffed [M] into \the [src].")
		balloon_alert(user, "stuffs [M] into \the [src].")
		to_chat(M, span_warning("[user] stuffs you into \the [src]."))
		return

	if (is_sliceable())
		//these are used to allow hiding edge items in food that is not on a table/tray
		var/can_slice_here = isturf(src.loc) && ((locate(/obj/structure/table) in src.loc) || (locate(/obj/machinery/optable) in src.loc) || (locate(/obj/item/tray) in src.loc))
		var/hide_item = !has_edge(W) || !can_slice_here

		if (hide_item)
			if (W.w_class >= src.w_class || is_robot_module(W) || istype(W, /obj/item/holder))
				return

			if(tgui_alert(user,"You can't slice \the [src] here. Would you like to hide \the [W] inside it instead?","No Cutting Surface!",list("Yes","No")) != "Yes")
				to_chat(user, span_warning("You cannot slice \the [src] here! You need a table or at least a tray to do it."))
				balloon_alert(user, "you cannot slice \the [src] here! You need a table or at least a tray to do it.")
				return
			else
				to_chat(user, "Slipped \the [W] inside \the [src].")
				balloon_alert(user, "slipped \the [W] inside \the [src].")
				user.drop_from_inventory(W, src)
				add_fingerprint(user)
				contents += W
				return

		if (has_edge(W))
			if (!can_slice_here)
				to_chat(user, span_warning("You cannot slice \the [src] here! You need a table or at least a tray to do it."))
				balloon_alert(user, "you need a table or at least a tray to slice it.")
				return

			var/slices_lost = 0
			if (W.w_class > 3)
				user.visible_message(span_notice("\The [user] crudely slices \the [src] with [W]!"), span_notice("You crudely slice \the [src] with your [W]!"))
				user.balloon_alert_visible("crudely slices \the [src]", "crudely sliced \the [src]")
				slices_lost = rand(1,min(1,round(slices_num/2)))
			else
				user.visible_message(span_notice(span_bold("\The [user]") + " slices \the [src]!"), span_notice("You slice \the [src]!"))
				user.balloon_alert_visible("slices \the [src]", "sliced \the [src]!")
			var/reagents_per_slice = reagents.total_volume/slices_num
			for(var/i=1 to (slices_num-slices_lost))
				var/obj/slice = new slice_path (src.loc)
				reagents.trans_to_obj(slice, reagents_per_slice)
				if(food_inserted_micros && food_inserted_micros.len && istype(slice, /obj/item/reagent_containers/food/snacks))
					var/obj/item/reagent_containers/food/snacks/S = slice
					for(var/mob/living/F in food_inserted_micros)
						F.forceMove(S)
						if(!S.food_inserted_micros)
							S.food_inserted_micros = list()
						S.food_inserted_micros += F
						food_inserted_micros -= F
			on_slice_extra()

			qdel(src)
			return

/obj/item/reagent_containers/food/snacks/proc/on_slice_extra()
	return

/obj/item/reagent_containers/food/snacks/MouseDrop_T(mob/living/M, mob/user)
	if(!user.stat && istype(M) && (M == user) && Adjacent(M) && (M.get_effective_size(TRUE) <= 0.50) && food_can_insert_micro)
		if(!food_inserted_micros)
			food_inserted_micros = list()

		M.forceMove(src)

		food_inserted_micros += M

		to_chat(user, span_warning("You climb into \the [src]."))
		return

	return ..()

/obj/item/reagent_containers/food/snacks/proc/is_sliceable()
	return (slices_num && slice_path && slices_num > 0)

/obj/item/reagent_containers/food/snacks/Destroy()
	if(contents)
		for(var/atom/movable/something in contents)
			something.dropInto(loc)
			if(food_inserted_micros && (something in food_inserted_micros))
				food_inserted_micros -= something
	. = ..()

	return

/obj/item/reagent_containers/food/snacks/proc/unpackage(mob/user)
	package = FALSE
	to_chat(user, span_notice("You unwrap [src]."))
	balloon_alert(user, "unwrapped \the [src].")
	playsound(user,opening_sound, 15, 1)
	if(package_trash)
		var/obj/item/T = new package_trash
		user.put_in_hands(T)
	if(package_open_state)
		icon_state = package_open_state
		if(package_opening_state)
			flick(package_opening_state, src)

/obj/item/reagent_containers/food/snacks/proc/uncan(mob/user)
	canned = FALSE
	to_chat(user, span_notice("You unseal \the [src] with a crack of metal."))
	balloon_alert(user, "unsealed \the [src]")
	playsound(loc,opening_sound, rand(10,50), 1)
	if(canned_open_state)
		icon_state = canned_open_state

////////////////////////////////////////////////////////////////////////////////
/// FOOD END
////////////////////////////////////////////////////////////////////////////////
/obj/item/reagent_containers/food/snacks/attack_generic(var/mob/living/user)
	if(!isanimal(user) && !isalien(user))
		return
	user.visible_message(span_infoplain(span_bold("[user]") + " nibbles away at \the [src]."),span_info("You nibble away at \the [src]."))
	user.balloon_alert_visible("nibbles away at \the [src].","nibbled away at \the [src].")
	bitecount++
	if(reagents)
		reagents.trans_to_mob(user, bitesize, CHEM_INGEST)
	spawn(5)
		if(!src && !user.client)
			user.automatic_custom_emote(VISIBLE_MESSAGE,"[pick("burps", "cries for more", "burps twice", "looks at the area where the food was")]", check_stat = TRUE)
			qdel(src)
	On_Consume(user)

//////////////////////////////////////////////////
////////////////////////////////////////////Snacks
//////////////////////////////////////////////////
//Items in the "Snacks" subcategory are food items that people actually eat. The key points are that they are created
//	already filled with reagents and are destroyed when empty. Additionally, they make a "munching" noise when eaten.

//Notes by Darem: Food in the "snacks" subtype can hold a maximum of 50 units Generally speaking, you don't want to go over 40
//	total for the item because you want to leave space for extra condiments. If you want effect besides healing, add a reagent for
//	it. Try to stick to existing reagents when possible (so if you want a stronger healing effect, just use Tricordrazine). On use
//	effect (such as the old officer eating a donut code) requires a unique reagent (unless you can figure out a better way).

//The nutriment reagent and bitesize variable replace the old heal_amt and amount variables. Each unit of nutriment is equal to
//	2 of the old heal_amt variable. Bitesize is the rate at which the reagents are consumed. So if you have 6 nutriment and a
//	bitesize of 2, then it'll take 3 bites to eat. Unlike the old system, the contained reagents are evenly spread among all
//	the bites. No more contained reagents = no more bites.

//Here is an example of the new formatting for anyone who wants to add more food items.
///obj/item/reagent_containers/food/snacks/xenoburger				//Identification path for the object.
//	name = "Xenoburger"														//Name that displays in the UI.
//	desc = "Smells caustic. Tastes like heresy."							//Duh
//	icon_state = "xburger"													//Refers to an icon in food.dmi
//	nutriment_amt = 2														//How much nutriment to add.
//	bitesize = 3															//This is the amount each bite consumes.
///obj/item/reagent_containers/food/snacks/xenoburger/Initialize(mapload)	//Don't mess with this. (We use Initialize now instead of New())
//	. = ..()																//Same here.
//	reagents.add_reagent("xenomicrobes", 10)								//This is what is in the food item. you may copy/paste this line of code for all the contents.




/obj/item/reagent_containers/food/snacks/aesirsalad
	name = "Aesir salad"
	desc = "Probably too incredible for mortal men to fully enjoy."
	icon_state = "aesirsalad"
	trash = /obj/item/trash/snack_bowl
	filling_color = "#468C00"
	center_of_mass_x = 17
	center_of_mass_y = 11
	nutriment_amt = 8
	nutriment_desc = list("apples" = 3,"salad" = 5)
	bitesize = 3

/obj/item/reagent_containers/food/snacks/aesirsalad/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_DOCTORSDELIGHT, 8)
	reagents.add_reagent(REAGENT_ID_TRICORDRAZINE, 8)

/obj/item/reagent_containers/food/snacks/candy/donor
	name = "Donor Candy"
	desc = "A little treat for blood donors."
	trash = /obj/item/trash/candy
	nutriment_amt = 9
	nutriment_desc = list("candy" = 10)
	bitesize = 5

/obj/item/reagent_containers/food/snacks/candy/donor/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_SUGAR, 3)

/obj/item/reagent_containers/food/snacks/candy_corn
	name = "candy corn"
	desc = "It's a handful of candy corn. Cannot be stored in a detective's hat, alas."
	description_fluff = "Nobody knows why Nanotrasen keeps making these waxy pieces of sugar and bone glue, but a handful of people swear by them. Purportedly popular with Skrell children, dubiously enough."
	icon_state = "candy_corn"
	filling_color = "#FFFCB0"
	center_of_mass_x = 14
	center_of_mass_y = 10
	nutriment_amt = 4
	nutriment_desc = list("candy corn" = 4)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/candy_corn/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_SUGAR, 2)

/obj/item/reagent_containers/food/snacks/chocolatebar //not a vending item
	name = "Chocolate Bar"
	desc = "Such sweet, fattening food."
	icon_state = "chocolatebar"
	filling_color = "#7D5F46"
	center_of_mass_x = 15
	center_of_mass_y = 15
	nutriment_amt = 2
	nutriment_desc = list(REAGENT_ID_CHOCOLATE = 5)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/chocolatebar/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_SUGAR, 2)
	reagents.add_reagent(REAGENT_ID_COCO, 2)

/obj/item/reagent_containers/food/snacks/chocolatepiece
	name = "chocolate piece"
	desc = "A luscious milk chocolate piece filled with gooey caramel."
	icon_state =  "chocolatepiece"
	filling_color = "#7D5F46"
	center_of_mass_x = 15
	center_of_mass_y = 15
	nutriment_amt = 1
	nutriment_desc = list(REAGENT_ID_CHOCOLATE = 3, "caramel" = 2, "lusciousness" = 1)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/chocolatepiece/white
	name = "white chocolate piece"
	desc = "A creamy white chocolate piece drizzled in milk chocolate."
	icon_state = "chocolatepiece_white"
	filling_color = "#E2DAD3"
	nutriment_desc = list("white chocolate" = 3, "creaminess" = 1)

/obj/item/reagent_containers/food/snacks/chocolatepiece/truffle
	name = "chocolate truffle"
	desc = "A bite-sized milk chocolate truffle that could buy anyone's love."
	icon_state = "chocolatepiece_truffle"
	nutriment_desc = list(REAGENT_ID_CHOCOLATE = 3, "undying devotion" = 3)

/obj/item/reagent_containers/food/snacks/chocolateegg
	name = "Chocolate Egg"
	desc = "Such sweet, fattening food."
	icon_state = "chocolateegg"
	filling_color = "#7D5F46"
	center_of_mass_x = 16
	center_of_mass_y = 13
	nutriment_amt = 3
	nutriment_desc = list(REAGENT_ID_CHOCOLATE = 5)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/chocolateegg/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_SUGAR, 2)
	reagents.add_reagent(REAGENT_ID_COCO, 2)

/obj/item/reagent_containers/food/snacks/donut
	name = "donut"
	desc = "Goes great with Robust Coffee."
	description_fluff = "These donuts claim to be made fresh daily in a boutique bakery in New Reykjavik and delivered to Nanotrasen's hardworking asset protection crew. They're probably synthesized."
	icon = 'icons/obj/food_donuts.dmi'
	icon_state = "donut"
	filling_color = "#D9C386"
	nutriment_desc = list("sweetness", "donut")
	nutriment_amt = 3
	bitesize = 4
	var/overlay_state = "donut_inbox"

/obj/item/reagent_containers/food/snacks/donut/plain
	name = "plain donut"
	icon_state = "donut"
	desc = "A plain ol' donut."
/obj/item/reagent_containers/food/snacks/donut/plain/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_NUTRIMENT, 3, nutriment_desc)

/obj/item/reagent_containers/food/snacks/donut/plain/jelly
	name = "plain jelly donut"
	icon_state = "jelly"
	desc = "At least this one has jelly!"
/obj/item/reagent_containers/food/snacks/donut/plain/jelly/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_NUTRIMENT, 3, nutriment_desc)
	reagents.add_reagent(REAGENT_ID_BERRYJUICE, 5)

/obj/item/reagent_containers/food/snacks/donut/pink
	name = "pink frosted donut"
	icon_state = "donut_pink"
	desc = "This one has pink frosting!"
	overlay_state = "donut_pink_inbox"
/obj/item/reagent_containers/food/snacks/donut/pink/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_NUTRIMENT, 3, nutriment_desc)

/obj/item/reagent_containers/food/snacks/donut/pink/jelly
	name = "pink frosted jelly donut"
	icon_state = "jelly_pink"
	desc = "This one has pink frosting and a jelly filling!"
/obj/item/reagent_containers/food/snacks/donut/pink/jelly/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_NUTRIMENT, 3, nutriment_desc)
	reagents.add_reagent(REAGENT_ID_BERRYJUICE, 5)

/obj/item/reagent_containers/food/snacks/donut/purple
	name = "purple frosted donut"
	icon_state = "donut_purple"
	desc = "This one has purple frosting!"
	overlay_state = "donut_purple_inbox"
/obj/item/reagent_containers/food/snacks/donut/purple/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_NUTRIMENT, 3, nutriment_desc)

/obj/item/reagent_containers/food/snacks/donut/purple/jelly
	name = "purple frosted jelly donut"
	icon_state = "jelly_purple"
	desc = "This one has purple frosting and a jelly filling!"
/obj/item/reagent_containers/food/snacks/donut/purple/jelly/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_NUTRIMENT, 3, nutriment_desc)
	reagents.add_reagent(REAGENT_ID_BERRYJUICE, 5)

/obj/item/reagent_containers/food/snacks/donut/green
	name = "green frosted donut"
	icon_state = "donut_green"
	desc = "This one has green frosting!"
	overlay_state = "donut_green_inbox"
/obj/item/reagent_containers/food/snacks/donut/green/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_NUTRIMENT, 3, nutriment_desc)

/obj/item/reagent_containers/food/snacks/donut/green/jelly
	name = "green frosted jelly donut"
	icon_state = "jelly_green"
	desc = "This one has green frosting and a jelly filling!"
/obj/item/reagent_containers/food/snacks/donut/green/jelly/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_NUTRIMENT, 3, nutriment_desc)
	reagents.add_reagent(REAGENT_ID_BERRYJUICE, 5)

/obj/item/reagent_containers/food/snacks/donut/beige
	name = "beige frosted donut"
	icon_state = "donut_beige"
	desc = "This one has beige frosting!"
	overlay_state = "donut_beige_inbox"
/obj/item/reagent_containers/food/snacks/donut/beige/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_NUTRIMENT, 3, nutriment_desc)

/obj/item/reagent_containers/food/snacks/donut/beige/jelly
	name = "beige frosted jelly donut"
	icon_state = "jelly_beige"
	desc = "This one has beige frosting and a jelly filling!"
/obj/item/reagent_containers/food/snacks/donut/beige/jelly/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_NUTRIMENT, 3, nutriment_desc)
	reagents.add_reagent(REAGENT_ID_BERRYJUICE, 5)

/obj/item/reagent_containers/food/snacks/donut/choc
	name = "chocolate frosted donut"
	icon_state = "donut_choc"
	desc = "This one has chocolate frosting!"
	overlay_state = "donut_choc_inbox"
/obj/item/reagent_containers/food/snacks/donut/choc/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_NUTRIMENT, 3, nutriment_desc)
	reagents.add_reagent(REAGENT_ID_CHOCOLATE, 5)

/obj/item/reagent_containers/food/snacks/donut/choc/jelly
	name = "chocolate frosted jelly donut"
	icon_state = "jelly_choc"
	desc = "This one has chocolate frosting and a jelly filling!"
/obj/item/reagent_containers/food/snacks/donut/choc/jelly/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_NUTRIMENT, 3, nutriment_desc)
	reagents.add_reagent(REAGENT_ID_BERRYJUICE, 5)
	reagents.add_reagent(REAGENT_ID_CHOCOLATE, 5)

/obj/item/reagent_containers/food/snacks/donut/blue
	name = "blue frosted donut"
	icon_state = "donut_blue"
	desc = "This one has blue frosting!"
	overlay_state = "donut_blue_inbox"
/obj/item/reagent_containers/food/snacks/donut/blue/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_NUTRIMENT, 3, nutriment_desc)

/obj/item/reagent_containers/food/snacks/donut/blue/jelly
	name = "blue frosted jelly donut"
	icon_state = "jelly_blue"
	desc = "This one has blue frosting and a jelly filling!"
/obj/item/reagent_containers/food/snacks/donut/blue/jelly/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_NUTRIMENT, 3, nutriment_desc)
	reagents.add_reagent(REAGENT_ID_BERRYJUICE, 5)

/obj/item/reagent_containers/food/snacks/donut/yellow
	name = "yellow frosted donut"
	icon_state = "donut_yellow"
	desc = "This one has yellow frosting!"
	overlay_state = "donut_yellow_inbox"
/obj/item/reagent_containers/food/snacks/donut/yellow/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_NUTRIMENT, 3, nutriment_desc)

/obj/item/reagent_containers/food/snacks/donut/yellow/jelly
	name = "yellow frosted jelly donut"
	icon_state = "jelly_yellow"
	desc = "This one has yellow frosting and a jelly filling!"
/obj/item/reagent_containers/food/snacks/donut/yellow/jelly/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_NUTRIMENT, 3, nutriment_desc)
	reagents.add_reagent(REAGENT_ID_BERRYJUICE, 5)

/obj/item/reagent_containers/food/snacks/donut/olive
	name = "olive frosted donut"
	icon_state = "donut_olive"
	desc = "This one has olive frosting!"
	overlay_state = "donut_olive_inbox"
/obj/item/reagent_containers/food/snacks/donut/olive/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_NUTRIMENT, 3, nutriment_desc)

/obj/item/reagent_containers/food/snacks/donut/olive/jelly
	name = "olive frosted jelly donut"
	icon_state = "jelly_olive"
	desc = "This one has olive frosting and a jelly filling!"
/obj/item/reagent_containers/food/snacks/donut/olive/jelly/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_NUTRIMENT, 3, nutriment_desc)
	reagents.add_reagent(REAGENT_ID_BERRYJUICE, 5)

/obj/item/reagent_containers/food/snacks/donut/homer
	name = "frosted donut with sprinkles"
	icon_state = "donut_homer"
	desc = "It's a d'ohnut!"
	overlay_state = "donut_homer_inbox"
/obj/item/reagent_containers/food/snacks/donut/homer/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_NUTRIMENT, 3, nutriment_desc)
	reagents.add_reagent(REAGENT_ID_SPRINKLES, 1)

/obj/item/reagent_containers/food/snacks/donut/homer/jelly
	name = "frosted jelly donut with sprinkles"
	icon_state = "jelly_homer"
	desc = "It's a d'ohnut with jelly filling!"
/obj/item/reagent_containers/food/snacks/donut/homer/jelly/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_NUTRIMENT, 3, nutriment_desc)
	reagents.add_reagent(REAGENT_ID_SPRINKLES, 1)
	reagents.add_reagent(REAGENT_ID_BERRYJUICE, 5)

/obj/item/reagent_containers/food/snacks/donut/choc_sprinkles
	name = "chocolate sprinkles donut"
	icon_state = "donut_choc_sprinkles"
	desc = "Mmm, chocolate with sprinkles... approaching maximum donut."
	overlay_state = "donut_choc_sprinkles_inbox"
/obj/item/reagent_containers/food/snacks/donut/choc_sprinkles/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_NUTRIMENT, 3, nutriment_desc)
	reagents.add_reagent(REAGENT_ID_SPRINKLES, 1)
	reagents.add_reagent(REAGENT_ID_CHOCOLATE, 1)

/obj/item/reagent_containers/food/snacks/donut/choc_sprinkles/jelly
	name = "chocolate sprinkles jelly donut"
	icon_state = "jelly_choc_sprinkles"
	desc = "Pretty sure this is the most sugar you can pack into a donut."
/obj/item/reagent_containers/food/snacks/donut/choc_sprinkles/jelly/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_NUTRIMENT, 3, nutriment_desc)
	reagents.add_reagent(REAGENT_ID_SPRINKLES, 1)
	reagents.add_reagent(REAGENT_ID_BERRYJUICE, 5)
	reagents.add_reagent(REAGENT_ID_CHOCOLATE, 1)

/obj/item/reagent_containers/food/snacks/donut/meat
	name = "meat donut"
	icon_state = "donut_meat"
	desc = "This donut has ... meat? Is it made of meat?!"
	overlay_state = "donut_meat_inbox"
/obj/item/reagent_containers/food/snacks/donut/meat/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 3, nutriment_desc)

/obj/item/reagent_containers/food/snacks/donut/laugh
	name = "laugh donut"
	icon_state = "donut_laugh"
	desc = "Try not to laugh."
	overlay_state = "donut_laugh_inbox"
/obj/item/reagent_containers/food/snacks/donut/laugh/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_NUTRIMENT, 3, nutriment_desc)

/obj/item/reagent_containers/food/snacks/donut/laugh/jelly
	name = "laugh jelly donut"
	icon_state = "jelly_laugh"
	desc = "Try not to be jelly."
/obj/item/reagent_containers/food/snacks/donut/laugh/jelly/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_NUTRIMENT, 3, nutriment_desc)
	reagents.add_reagent(REAGENT_ID_BERRYJUICE, 5)


/obj/item/reagent_containers/food/snacks/donut/chaos
	name = "Chaos Donut"
	desc = "Like life, it never quite tastes the same."
	icon_state = "donut_chaos"
	filling_color = "#ED11E6"
	nutriment_amt = 2
	bitesize = 10
	overlay_state = "donut_chaos_inbox"

/obj/item/reagent_containers/food/snacks/donut/chaos/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_SPRINKLES, 1)
	switch(rand(1,10))
		if(1)
			reagents.add_reagent(REAGENT_ID_NUTRIMENT, 3, nutriment_desc)
		if(2)
			reagents.add_reagent(REAGENT_ID_CAPSAICIN, 3)
		if(3)
			reagents.add_reagent(REAGENT_ID_FROSTOIL, 3)
		if(4)
			reagents.add_reagent(REAGENT_ID_SPRINKLES, 3)
		if(5)
			reagents.add_reagent(REAGENT_ID_PHORON, 3)
		if(6)
			reagents.add_reagent(REAGENT_ID_COCO, 3)
		if(7)
			reagents.add_reagent(REAGENT_ID_SLIMEJELLY, 3)
		if(8)
			reagents.add_reagent(REAGENT_ID_BANANA, 3)
		if(9)
			reagents.add_reagent(REAGENT_ID_BERRYJUICE, 3)
		if(10)
			reagents.add_reagent(REAGENT_ID_TRICORDRAZINE, 3)

/obj/item/reagent_containers/food/snacks/donut/plain/jelly/poisonberry
	filling_color = "#ED1169"

/obj/item/reagent_containers/food/snacks/donut/plain/jelly/poisonberry/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_POISONBERRYJUICE, 5)

/obj/item/reagent_containers/food/snacks/donut/plain/jelly/slimejelly
	name = "slime jelly donut"
	filling_color = "#ED1169"

/obj/item/reagent_containers/food/snacks/donut/plain/jelly/slimejelly/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_SLIMEJELLY, 5)

/obj/item/reagent_containers/food/snacks/donut/plain/jelly/cherryjelly
	name = "cherry jelly donut"
	filling_color = "#ED1169"

/obj/item/reagent_containers/food/snacks/donut/plain/jelly/cherryjelly/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_CHERRYJELLY, 5)


/obj/item/reagent_containers/food/snacks/egg
	name = "egg"
	desc = "An egg!"
	icon_state = "egg"
	filling_color = "#FDFFD1"
	volume = 10
	center_of_mass_x = 16
	center_of_mass_y = 13

/obj/item/reagent_containers/food/snacks/egg/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_EGG, 3)

/obj/item/reagent_containers/food/snacks/egg/afterattack(obj/O as obj, mob/user as mob, proximity)
	if(istype(O,/obj/machinery/microwave))
		return . = ..()
	if(!(proximity && O.is_open_container()))
		return
	to_chat(user, "You crack \the [src] into \the [O].")
	reagents.trans_to(O, reagents.total_volume)
	user.drop_from_inventory(src)
	qdel(src)

/obj/item/reagent_containers/food/snacks/egg/throw_impact(atom/hit_atom)
	. = ..()
	new/obj/effect/decal/cleanable/egg_smudge(src.loc)
	src.reagents.splash(hit_atom, reagents.total_volume)
	src.visible_message(span_red("[src.name] has been squashed."),span_red("You hear a smack."))
	qdel(src)

/obj/item/reagent_containers/food/snacks/egg/attackby(obj/item/W, mob/user)
	if(istype( W, /obj/item/pen/crayon ))
		var/obj/item/pen/crayon/C = W
		var/clr = C.colourName

		if(!(clr in list("blue","green","mime","orange","purple","rainbow","red","yellow")))
			to_chat(user, span_blue("The egg refuses to take on this color!"))
			return

		to_chat(user, span_blue("You color \the [src] [clr]"))
		icon_state = "egg-[clr]"
	else
		. = ..()

/obj/item/reagent_containers/food/snacks/egg/blue
	icon_state = "egg-blue"

/obj/item/reagent_containers/food/snacks/egg/green
	icon_state = "egg-green"

/obj/item/reagent_containers/food/snacks/egg/mime
	icon_state = "egg-mime"

/obj/item/reagent_containers/food/snacks/egg/orange
	icon_state = "egg-orange"

/obj/item/reagent_containers/food/snacks/egg/purple
	icon_state = "egg-purple"

/obj/item/reagent_containers/food/snacks/egg/rainbow
	icon_state = "egg-rainbow"

/obj/item/reagent_containers/food/snacks/egg/red
	icon_state = "egg-red"

/obj/item/reagent_containers/food/snacks/egg/yellow
	icon_state = "egg-yellow"

/obj/item/reagent_containers/food/snacks/friedegg
	name = "Fried egg"
	desc = "A fried egg, with a touch of salt and pepper."
	icon_state = "friedegg"
	filling_color = "#FFDF78"
	center_of_mass_x = 16
	center_of_mass_y = 14
	bitesize = 1

/obj/item/reagent_containers/food/snacks/friedegg/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 3)
	reagents.add_reagent(REAGENT_ID_SODIUMCHLORIDE, 1)
	reagents.add_reagent(REAGENT_ID_BLACKPEPPER, 1)

/obj/item/reagent_containers/food/snacks/boiledegg
	name = "Boiled egg"
	desc = "A hard boiled egg."
	icon_state = "egg"
	filling_color = "#FFFFFF"

/obj/item/reagent_containers/food/snacks/boiledegg/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 2)

/obj/item/reagent_containers/food/snacks/organ
	name = "organ"
	desc = "It's good for you."
	icon = 'icons/obj/surgery.dmi'
	icon_state = "appendix"
	filling_color = "#E00D34"
	center_of_mass_x = 16
	center_of_mass_y = 16
	bitesize = 3

/obj/item/reagent_containers/food/snacks/organ/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, rand(3,5))
	reagents.add_reagent(REAGENT_ID_TOXIN, rand(1,3))

/obj/item/reagent_containers/food/snacks/tofu
	name = "Tofu"
	icon_state = REAGENT_ID_TOFU
	desc = "We all love tofu."
	filling_color = "#FFFEE0"
	center_of_mass_x = 17
	center_of_mass_y = 10
	nutriment_amt = 3
	nutriment_desc = list(REAGENT_ID_TOFU = 3, "goeyness" = 3)
	bitesize = 3

/obj/item/reagent_containers/food/snacks/tofurkey
	name = "Tofurkey"
	desc = "A fake turkey made from tofu."
	icon_state = "tofurkey"
	filling_color = "#FFFEE0"
	center_of_mass_x = 16
	center_of_mass_y = 8
	nutriment_amt = 12
	nutriment_desc = list("turkey" = 3, REAGENT_ID_TOFU = 5, "goeyness" = 4)
	bitesize = 3

/obj/item/reagent_containers/food/snacks/stuffing
	name = "Stuffing"
	desc = "Moist, peppery breadcrumbs for filling the body cavities of dead birds. Dig in!"
	icon_state = "stuffing"
	filling_color = "#C9AC83"
	center_of_mass_x = 16
	center_of_mass_y = 10
	nutriment_amt = 3
	nutriment_desc = list("dryness" = 2, "bread" = 2)
	bitesize = 1

/obj/item/reagent_containers/food/snacks/carpmeat
	name = "fillet"
	desc = "A fillet of carp meat"
	icon_state = "fishfillet"
	filling_color = "#FFDEFE"
	center_of_mass_x = 17
	center_of_mass_y = 13
	bitesize = 6

	var/toxin_type = REAGENT_ID_CARPOTOXIN
	var/toxin_amount = 3

/obj/item/reagent_containers/food/snacks/carpmeat/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_SEAFOOD, 3)
	if(toxin_type && toxin_amount)
		reagents.add_reagent(toxin_type, toxin_amount)

/obj/item/reagent_containers/food/snacks/carpmeat/fish
	desc = "A fillet of fish meat."
	toxin_type = null

/obj/item/reagent_containers/food/snacks/carpmeat/fish/sif
	desc = "A fillet of sivian fish meat."
	filling_color = "#2c2cff"
	color = "#2c2cff"

/obj/item/reagent_containers/food/snacks/carpmeat/ray
	desc = "A fillet of space ray meat."
	toxin_type = REAGENT_ID_STOXIN

/obj/item/reagent_containers/food/snacks/carpmeat/gnat
	desc = "A paltry sample of space-gnat meat. It looks pretty stringy and unpleasant, honestly."
	toxin_amount = 1

/obj/item/reagent_containers/food/snacks/carpmeat/shark
	desc = "A fillet of space shark meat. It looks rather tough and chewy."
	toxin_amount = 5

/obj/item/reagent_containers/food/snacks/crab_legs
	name = "steamed crab legs"
	desc = "Crab legs steamed and buttered to perfection. One day when the boss gets hungry..."
	icon_state = "crablegs"
	nutriment_amt = 2
	nutriment_desc = list("savory butter" = 2)
	bitesize = 2
	trash = /obj/item/trash/plate

/obj/item/reagent_containers/food/snacks/crab_legs/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_SEAFOOD, 6)
	reagents.add_reagent(REAGENT_ID_SODIUMCHLORIDE, 1)

/obj/item/reagent_containers/food/snacks/fishfingers
	name = "Fish Fingers"
	desc = "A finger of fish."
	icon_state = "fishfingers"
	filling_color = "#FFDEFE"
	center_of_mass_x = 16
	center_of_mass_y = 13
	bitesize = 3

/obj/item/reagent_containers/food/snacks/fishfingers/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_SEAFOOD, 4)

/obj/item/reagent_containers/food/snacks/zestfish
	name = "Zesty Fish"
	desc = "Lightly seasoned fish fillets."
	icon_state = "zestfish"
	filling_color = "#FFDEFE"
	center_of_mass_x = 16
	center_of_mass_y = 13
	bitesize = 3

/obj/item/reagent_containers/food/snacks/zestfish/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_SEAFOOD, 4)

/obj/item/reagent_containers/food/snacks/mushroomslice
	name = "mushroom slice"
	desc = "A slice of mushroom."
	icon_state = "hugemushroomslice"
	filling_color = "#E0D7C5"
	center_of_mass_x = 17
	center_of_mass_y = 16
	nutriment_amt = 3
	nutriment_desc = list("raw" = 2, PLANT_MUSHROOMS = 2)
	bitesize = 6

/obj/item/reagent_containers/food/snacks/mushroomslice/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PSILOCYBIN, 3)

/obj/item/reagent_containers/food/snacks/tomatomeat
	name = "tomato slice"
	desc = "A slice from a huge tomato"
	icon_state = "tomatomeat"
	filling_color = "#DB0000"
	center_of_mass_x = 17
	center_of_mass_y = 16
	nutriment_amt = 3
	nutriment_desc = list("raw" = 2, PLANT_TOMATO = 3)
	bitesize = 6

/obj/item/reagent_containers/food/snacks/bearmeat
	name = "bear meat"
	desc = "A very manly slab of meat."
	icon_state = "bearmeat"
	filling_color = "#DB0000"
	center_of_mass_x = 16
	center_of_mass_y = 10
	bitesize = 3

/obj/item/reagent_containers/food/snacks/bearmeat/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 12)
	reagents.add_reagent(REAGENT_ID_HYPERZINE, 5)

/obj/item/reagent_containers/food/snacks/xenomeat
	name = "xenomeat"
	desc = "A slab of green meat. Smells like acid."
	icon_state = "xenomeat"
	filling_color = "#43DE18"
	center_of_mass_x = 16
	center_of_mass_y = 10
	bitesize = 6

/obj/item/reagent_containers/food/snacks/xenomeat/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 6)
	reagents.add_reagent(REAGENT_ID_PACID,6)

/obj/item/reagent_containers/food/snacks/xenomeat/spidermeat // Substitute for recipes requiring xeno meat.
	name = "spider meat"
	desc = "A slab of green meat."
	icon_state = "xenomeat"
	filling_color = "#43DE18"
	center_of_mass_x = 16
	center_of_mass_y = 10
	bitesize = 6

/obj/item/reagent_containers/food/snacks/xenomeat/spidermeat/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_SPIDERTOXIN,6)
	reagents.remove_reagent(REAGENT_ID_PACID,6)

/obj/item/reagent_containers/food/snacks/meatball
	name = "meatball"
	desc = "A great meal all round."
	icon_state = "meatball"
	filling_color = "#DB0000"
	center_of_mass_x = 16
	center_of_mass_y = 16
	bitesize = 2

/obj/item/reagent_containers/food/snacks/meatball/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 3)

/obj/item/reagent_containers/food/snacks/sausage
	name = "Sausage"
	desc = "A piece of mixed, long meat."
	icon_state = "sausage"
	filling_color = "#DB0000"
	center_of_mass_x = 16
	center_of_mass_y = 16
	bitesize = 2

/obj/item/reagent_containers/food/snacks/sausage/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 6)

/obj/item/reagent_containers/food/snacks/donkpocket
	name = "\improper Donk-pocket"
	desc = "The food of choice for the seasoned traitor."
	description_fluff = "DONKpockets were originally a Nanotrasen product, an attempt to break into the food market controlled by Centauri Provisions. Somehow, Centauri wound up with the rights to the DONK brand, ending Nanotrasen's ambitions. They taste pretty okay."
	icon_state = "donkpocket"
	filling_color = "#DEDEAB"
	center_of_mass_x = 16
	center_of_mass_y = 10
	nutriment_amt = 2
	nutriment_desc = list("heartiness" = 1, "dough" = 2)
	var/warm = FALSE
	var/list/heated_reagents = list(REAGENT_ID_TRICORDRAZINE = 5)

/obj/item/reagent_containers/food/snacks/donkpocket/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 2)

/obj/item/reagent_containers/food/snacks/donkpocket/proc/heat()
	warm = 1
	for(var/reagent in heated_reagents)
		reagents.add_reagent(reagent, heated_reagents[reagent])
	bitesize = 6
	name = "warm [name]"
	cooltime()

/obj/item/reagent_containers/food/snacks/donkpocket/proc/cooltime()
	if (src.warm)
		spawn(420 SECONDS)
			if(!src?.reagents)
				return
			src.warm = 0
			for(var/reagent in heated_reagents)
				src.reagents.del_reagent(reagent)
			src.name = initial(name)
	return

/obj/item/reagent_containers/food/snacks/donkpocket/spicy
	name = "\improper Spicy-pocket"
	desc = "The classic snack food, now with a heat-activated spicy flair."
	icon_state = "donkpocketspicy"
	nutriment_amt = 2
	nutriment_desc = list("heartiness" = 1, "dough" = 2, "spice" = 1)

/obj/item/reagent_containers/food/snacks/donkpocket/teriyaki
	name = "\improper Teriyaki-pocket"
	desc = "An east-Asian take on the classic stationside snack."
	icon_state = "donkpocketteriyaki"
	nutriment_amt = 2
	nutriment_desc = list("meat" = 1, "dough" = 2, "soy sauce" = 2)

/obj/item/reagent_containers/food/snacks/donkpocket/pizza
	name = "\improper Pizza-pocket"
	desc = "Delicious, cheesy and surprisingly filling."
	icon_state = "donkpocketpizza"
	nutriment_amt = 2
	nutriment_desc = list("meat" = 1, "dough" = 2, REAGENT_ID_CHEESE= 2)

/obj/item/reagent_containers/food/snacks/donkpocket/honk
	name = "\improper Honk-pocket"
	desc = "The award-winning donk-pocket that won the hearts of clowns and humans alike."
	icon_state = "donkpocketbanana"
	nutriment_amt = 2
	nutriment_desc = list(REAGENT_ID_BANANA = 1, "dough" = 2, "children's antibiotics"= 1)

/obj/item/reagent_containers/food/snacks/donkpocket/berry
	name = "\improper Berry-pocket"
	desc = "A relentlessly sweet donk-pocket first created for use in Operation Dessert Storm."
	icon_state = "donkpocketberry"
	nutriment_amt = 2
	nutriment_desc = list("dough" = 2, "jam" = 2)

/obj/item/reagent_containers/food/snacks/donkpocket/gondola
	name = "\improper Gondola-pocket"
	desc = "The choice to use real gondola meat in the recipe is controversial, to say the least." //Only a monster would craft this.
	icon_state = "donkpocketberry"
	nutriment_amt = 2
	nutriment_desc = list("heartiness" = 1, "dough" = 2, "inner peace" = 1)

/obj/item/reagent_containers/food/snacks/donkpocket/dankpocket
	name = "\improper Dank-pocket"
	desc = "The food of choice for the seasoned botanist."
	icon_state = "dankpocket"
	nutriment_amt = 2
	nutriment_desc = list("heartiness" = 1, "dough" = 2)
	heated_reagents = list(REAGENT_ID_BLISS = 5)

/obj/item/reagent_containers/food/snacks/donkpocket/sinpocket
	name = "\improper Sin-pocket"
	desc = "The food of choice for the veteran. Do <B>NOT</B> overconsume."
	filling_color = "#6D6D00"
	heated_reagents = list(REAGENT_ID_DOCTORSDELIGHT = 5, REAGENT_ID_HYPERZINE = 0.75, REAGENT_ID_SYNAPTIZINE = 0.25)
	var/has_been_heated = 0

/obj/item/reagent_containers/food/snacks/donkpocket/sinpocket/attack_self(mob/user)
	if(has_been_heated)
		to_chat(user, span_notice("The heating chemicals have already been spent."))
		return
	has_been_heated = 1
	user.visible_message(span_notice("[user] crushes \the [src] package."), "You crush \the [src] package and feel a comfortable heat build up. Now just to wait for it to be ready.")
	spawn(200)
		if(!QDELETED(src))
			if(src.loc == user)
				to_chat(user, "You think \the [src] is ready to eat about now.")
			heat()

/obj/item/reagent_containers/food/snacks/brainburger
	name = "brainburger"
	desc = "A strange looking burger. It looks almost sentient."
	icon_state = "brainburger"
	filling_color = "#F2B6EA"
	center_of_mass_x = 15
	center_of_mass_y = 11
	bitesize = 2

/obj/item/reagent_containers/food/snacks/brainburger/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 6)
	reagents.add_reagent(REAGENT_ID_ALKYSINE, 6)

/obj/item/reagent_containers/food/snacks/ghostburger
	name = "Ghost Burger"
	desc = "Spooky! It doesn't look very filling."
	icon_state = "ghostburger"
	filling_color = "#FFF2FF"
	center_of_mass_x = 16
	center_of_mass_y = 11
	nutriment_desc = list("buns" = 3, "spookiness" = 3)
	nutriment_amt = 2
	bitesize = 2

/obj/item/reagent_containers/food/snacks/human
	var/hname = ""
	var/job = null
	filling_color = "#D63C3C"

/obj/item/reagent_containers/food/snacks/human/burger
	name = "-burger"
	desc = "A bloody burger."
	icon_state = "hburger"
	center_of_mass_x = 16
	center_of_mass_y = 11
	bitesize = 2

/obj/item/reagent_containers/food/snacks/human/burger/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 6)

/obj/item/reagent_containers/food/snacks/cheeseburger
	name = "cheeseburger"
	desc = "The cheese adds a good flavor."
	icon_state = "cheeseburger"
	center_of_mass_x = 16
	center_of_mass_y = 11
	nutriment_amt = 2
	nutriment_desc = list(REAGENT_ID_CHEESE = 2, "bun" = 2)

/obj/item/reagent_containers/food/snacks/cheeseburger/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 2)

/obj/item/reagent_containers/food/snacks/monkeyburger
	name = "burger"
	desc = "The cornerstone of every nutritious breakfast."
	icon_state = "hburger"
	filling_color = "#D63C3C"
	center_of_mass_x = 16
	center_of_mass_y = 11
	nutriment_amt = 3
	nutriment_desc = list("bun" = 2)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/monkeyburger/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 3)

/obj/item/reagent_containers/food/snacks/fishburger
	name = "Fillet -o- Carp Sandwich"
	desc = "Almost like a carp is yelling somewhere... Give me back that fillet -o- carp, give me that carp."
	icon_state = "fishburger"
	filling_color = "#FFDEFE"
	center_of_mass_x = 16
	center_of_mass_y = 10
	bitesize = 3

/obj/item/reagent_containers/food/snacks/fishburger/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 6)

/obj/item/reagent_containers/food/snacks/tofuburger
	name = "Tofu Burger"
	desc = "What.. is that meat?"
	icon_state = "tofuburger"
	filling_color = "#FFFEE0"
	center_of_mass_x = 16
	center_of_mass_y = 10
	nutriment_amt = 6
	nutriment_desc = list("bun" = 2, "pseudo-soy meat" = 3)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/roburger
	name = "roburger"
	desc = "The lettuce is the only organic component. Beep."
	icon_state = "roburger"
	filling_color = "#CCCCCC"
	center_of_mass_x = 16
	center_of_mass_y = 11
	nutriment_amt = 2
	nutriment_desc = list("bun" = 2, "metal" = 3)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/roburgerbig
	name = "roburger"
	desc = "This massive patty looks like poison. Beep."
	icon_state = "roburger"
	filling_color = "#CCCCCC"
	volume = 100
	center_of_mass_x = 16
	center_of_mass_y = 11
	bitesize = 0.1

/obj/item/reagent_containers/food/snacks/xenoburger
	name = "xenoburger"
	desc = "Smells caustic. Tastes like heresy."
	icon_state = "xburger"
	filling_color = "#43DE18"
	center_of_mass_x = 16
	center_of_mass_y = 11
	bitesize = 2

/obj/item/reagent_containers/food/snacks/xenoburger/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 8)

/obj/item/reagent_containers/food/snacks/clownburger
	name = JOB_CLOWN + " Burger"
	desc = "This tastes funny..."
	icon_state = "clownburger"
	filling_color = "#FF00FF"
	center_of_mass_x = 17
	center_of_mass_y = 12
	nutriment_amt = 6
	nutriment_desc = list("bun" = 2, "clown shoe" = 3)
	bitesize = 2


/obj/item/reagent_containers/food/snacks/mimeburger
	name = JOB_MIME + " Burger"
	desc = "Its taste defies language."
	icon_state = "mimeburger"
	filling_color = "#FFFFFF"
	center_of_mass_x = 16
	center_of_mass_y = 11
	nutriment_amt = 12
	nutriment_desc = list("bun" = 2, "face paint" = 3)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/omelette
	name = "Omelette Du Fromage"
	desc = "That's all you can say!"
	icon_state = "omelette"
	trash = /obj/item/trash/plate
	filling_color = "#FFF9A8"
	center_of_mass_x = 16
	center_of_mass_y = 13
	bitesize = 1

/obj/item/reagent_containers/food/snacks/omelette/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 8)

/obj/item/reagent_containers/food/snacks/muffin
	name = "Muffin"
	desc = "A delicious and spongy little cake"
	icon_state = "muffin"
	filling_color = "#E0CF9B"
	center_of_mass_x = 17
	center_of_mass_y = 4
	nutriment_amt = 6
	nutriment_desc = list("sweetness" = 3, "muffin" = 3)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/pie
	name = "Banana Cream Pie"
	desc = "Just like back home, on clown planet! HONK!"
	description_fluff = "One of the more esoteric terms of the Nanotrasen-Centauri Noncompetition Agreement of 2305 was a requirement that Nanotrasen stock these pies on all their stations. They're calibrated for comedic value, not taste."
	icon_state = "pie"
	trash = /obj/item/trash/plate
	filling_color = "#FBFFB8"
	center_of_mass_x = 16
	center_of_mass_y = 13
	nutriment_amt = 4
	nutriment_desc = list("pie" = 3, REAGENT_ID_CREAM = 2)
	bitesize = 3

/obj/item/reagent_containers/food/snacks/pie/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_BANANA,5)

/obj/item/reagent_containers/food/snacks/pie/throw_impact(atom/hit_atom)
	. = ..()
	new/obj/effect/decal/cleanable/pie_smudge(src.loc)
	src.visible_message(span_danger("\The [src.name] splats."),span_danger("You hear a splat."))
	qdel(src)

/obj/item/reagent_containers/food/snacks/berryclafoutis
	name = "Berry Clafoutis"
	desc = "No black birds, this is a good sign."
	icon_state = "berryclafoutis"
	trash = /obj/item/trash/plate
	center_of_mass_x = 16
	center_of_mass_y = 13
	nutriment_amt = 4
	nutriment_desc = list("sweetness" = 2, "pie" = 3)
	bitesize = 3

/obj/item/reagent_containers/food/snacks/ber
/obj/item/reagent_containers/food/snacks/berryclafoutis/berry/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_BERRYJUICE, 5)

/obj/item/reagent_containers/food/snacks/berryclafoutis/poison/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_POISONBERRYJUICE, 5)

/obj/item/reagent_containers/food/snacks/waffles
	name = "waffles"
	desc = "Mmm, waffles"
	icon_state = "waffles"
	trash = /obj/item/trash/waffles
	filling_color = "#E6DEB5"
	center_of_mass_x = 15
	center_of_mass_y = 11
	nutriment_amt = 8
	nutriment_desc = list("waffle" = 8)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/eggplantparm
	name = "Eggplant Parmigiana"
	desc = "The only good recipe for eggplant."
	icon_state = "eggplantparm"
	trash = /obj/item/trash/plate
	filling_color = "#4D2F5E"
	center_of_mass_x = 16
	center_of_mass_y = 11
	nutriment_amt = 6
	nutriment_desc = list(REAGENT_ID_CHEESE = 3, PLANT_EGGPLANT = 3)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/soylentgreen
	name = "Soylent Green"
	desc = "Not made of people. Honest." //Totally people.
	icon_state = "soylent_green"
	trash = /obj/item/trash/waffles
	filling_color = "#B8E6B5"
	center_of_mass_x = 15
	center_of_mass_y = 11
	bitesize = 2

/obj/item/reagent_containers/food/snacks/soylentgreen/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 10)

/obj/item/reagent_containers/food/snacks/soylenviridians
	name = "Soylen Virdians"
	desc = "Not made of people. Honest." //Actually honest for once.
	icon_state = "soylent_yellow"
	trash = /obj/item/trash/waffles
	filling_color = "#E6FA61"
	center_of_mass_x = 15
	center_of_mass_y = 11
	nutriment_amt = 10
	nutriment_desc = list("some sort of protein" = 10)  //seasoned VERY well.
	bitesize = 2

/obj/item/reagent_containers/food/snacks/meatpie
	name = "Meat-pie"
	icon_state = "meatpie"
	desc = "An old barber recipe, very delicious!"
	trash = /obj/item/trash/plate
	filling_color = "#948051"
	center_of_mass_x = 16
	center_of_mass_y = 13
	bitesize = 2

/obj/item/reagent_containers/food/snacks/meatpie/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 10)

/obj/item/reagent_containers/food/snacks/tofupie
	name = "Tofu-pie"
	icon_state = "meatpie"
	desc = "A delicious tofu pie."
	trash = /obj/item/trash/plate
	filling_color = "#FFFEE0"
	center_of_mass_x = 16
	center_of_mass_y = 13
	nutriment_amt = 10
	nutriment_desc = list(REAGENT_ID_TOFU = 2, "pie" = 8)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/amanita_pie
	name = "amanita pie"
	desc = "Sweet and tasty poison pie."
	icon_state = "amanita_pie"
	filling_color = "#FFCCCC"
	center_of_mass_x = 17
	center_of_mass_y = 9
	nutriment_amt = 5
	nutriment_desc = list("sweetness" = 3, PLANT_MUSHROOMS = 3, "pie" = 2)
	bitesize = 3

/obj/item/reagent_containers/food/snacks/amanita_pie/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_AMATOXIN, 3)
	reagents.add_reagent(REAGENT_ID_PSILOCYBIN, 1)

/obj/item/reagent_containers/food/snacks/plump_pie
	name = "plump pie"
	desc = "I bet you love stuff made out of plump helmets!"
	icon_state = "plump_pie"
	filling_color = "#B8279B"
	center_of_mass_x = 17
	center_of_mass_y = 9
	nutriment_amt = 8
	nutriment_desc = list("heartiness" = 2, PLANT_MUSHROOMS = 3, "pie" = 3)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/plump_pie/Initialize(mapload)
	. = ..()
	if(prob(10))
		name = "exceptional plump pie"
		desc = "Microwave is taken by a fey mood! It has cooked an exceptional plump pie!"
		reagents.add_reagent(REAGENT_ID_NUTRIMENT, 8, nutriment_desc)
		reagents.add_reagent(REAGENT_ID_TRICORDRAZINE, 5)

/obj/item/reagent_containers/food/snacks/xemeatpie
	name = "Xeno-pie"
	icon_state = "xenomeatpie"
	desc = "A delicious meatpie. Probably heretical."
	trash = /obj/item/trash/plate
	filling_color = "#43DE18"
	center_of_mass_x = 16
	center_of_mass_y = 13
	bitesize = 2

/obj/item/reagent_containers/food/snacks/xemeatpie/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 10)

/obj/item/reagent_containers/food/snacks/wingfangchu
	name = "Wing Fang Chu"
	desc = "A savory dish of alien wing wang in soy."
	icon_state = "wingfangchu"
	trash = /obj/item/trash/small_bowl
	filling_color = "#43DE18"
	center_of_mass_x = 17
	center_of_mass_y = 9
	bitesize = 2

/obj/item/reagent_containers/food/snacks/wingfangchu/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 6)

/obj/item/reagent_containers/food/snacks/human/kabob
	name = "-kabob"
	icon_state = "kabob"
	desc = "A human meat, on a stick."
	trash = /obj/item/stack/rods
	filling_color = "#A85340"
	center_of_mass_x = 17
	center_of_mass_y = 15
	bitesize = 2

/obj/item/reagent_containers/food/snacks/human/kabob/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 8)

/obj/item/reagent_containers/food/snacks/monkeykabob
	name = "Meat-kabob"
	icon_state = "kabob"
	desc = "Delicious meat, on a stick."
	trash = /obj/item/stack/rods
	filling_color = "#A85340"
	center_of_mass_x = 17
	center_of_mass_y = 15
	bitesize = 2

/obj/item/reagent_containers/food/snacks/monkeykabob/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 8)

/obj/item/reagent_containers/food/snacks/tofukabob
	name = "Tofu-kabob"
	icon_state = "kabob"
	desc = "Vegan meat, on a stick."
	trash = /obj/item/stack/rods
	filling_color = "#FFFEE0"
	bitesize = 2
	center_of_mass_x = 17
	center_of_mass_y = 15
	nutriment_amt = 8
	nutriment_desc = list(REAGENT_ID_TOFU = 3, "metal" = 1)

/obj/item/reagent_containers/food/snacks/cubancarp
	name = "Cuban Carp"
	desc = "A sandwich that burns your tongue and then leaves it numb!"
	icon_state = "cubancarp"
	trash = /obj/item/trash/plate
	filling_color = "#E9ADFF"
	center_of_mass_x = 12
	center_of_mass_y = 5
	nutriment_amt = 3
	nutriment_desc = list("toasted bread" = 3)
	bitesize = 3

/obj/item/reagent_containers/food/snacks/cubancarp/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 3)
	reagents.add_reagent(REAGENT_ID_CAPSAICIN, 3)

/obj/item/reagent_containers/food/snacks/popcorn
	name = "Popcorn"
	desc = "Now let's find some cinema."
	icon = 'icons/obj/food_snacks.dmi'
	icon_state = "popcorn"
	trash = /obj/item/trash/popcorn
	var/unpopped = 0
	filling_color = "#FFFAD4"
	center_of_mass_x = 16
	center_of_mass_y = 8
	nutriment_amt = 2
	nutriment_desc = list("popcorn" = 3)
	bitesize = 0.1 //This snack is supposed to be eaten for a long time.


/obj/item/reagent_containers/food/snacks/popcorn/Initialize(mapload)
	. = ..()
	unpopped = rand(1,10)

/obj/item/reagent_containers/food/snacks/popcorn/On_Consume(mob/living/M)
	if(prob(unpopped))	//lol ...what's the point?
		to_chat(M, span_red("You bite down on an un-popped kernel!"))
		unpopped = max(0, unpopped-1)
	. = ..()

/obj/item/reagent_containers/food/snacks/fries
	name = "Space Fries"
	desc = "AKA: French Fries, Freedom Fries, etc."
	icon_state = "fries"
	trash = /obj/item/trash/plate
	filling_color = "#EDDD00"
	center_of_mass_x = 16
	center_of_mass_y = 11
	nutriment_amt = 4
	nutriment_desc = list("fresh fries" = 4)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/fries
	nutriment_amt = 4
	nutriment_desc = list("fries" = 4)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/fries/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_OIL, 1.2)//This is mainly for the benefit of adminspawning

/obj/item/reagent_containers/food/snacks/onionrings
	name = "onion rings"
	desc = "Like circular fries but better."
	icon_state = "onionrings"
	trash = /obj/item/trash/plate
	filling_color = "#eddd00"
	center_of_mass_x = 16
	center_of_mass_y = 11
	nutriment_desc = list("fried onions" = 5)
	nutriment_amt = 5
	bitesize = 2

/obj/item/reagent_containers/food/snacks/microfries
	name = "micro fries"
	desc = "Soft and rubbery, should have fried them. Good for smaller crewmembers, maybe?"
	icon_state = "microfries"
	trash = /obj/item/trash/plate
	filling_color = "#EDDD00"
	nutriment_amt = 4
	nutriment_desc = list("soggy fries" = 4)
	center_of_mass_x = 16
	center_of_mass_y = 11
	bitesize = 2

/obj/item/reagent_containers/food/snacks/ovenfries
	name = "oven fries"
	desc = "Dark and crispy, but a bit dry."
	icon_state = "ovenfries"
	filling_color = "#EDDD00"
	nutriment_amt = 4
	nutriment_desc = list("crisp, dry fries" = 4)
	center_of_mass_x = 16
	center_of_mass_y = 11
	bitesize = 2

/obj/item/reagent_containers/food/snacks/carrotfries
	name = "Carrot Fries"
	desc = "Tasty fries from fresh Carrots."
	icon_state = "carrotfries"
	trash = /obj/item/trash/plate
	filling_color = "#FAA005"
	center_of_mass_x = 16
	center_of_mass_y = 11
	nutriment_amt = 3
	nutriment_desc = list(PLANT_CARROT = 3, "salt" = 1)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/carrotfries/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_IMIDAZOLINE, 3)


/obj/item/reagent_containers/food/snacks/cheesyfries
	name = "Cheesy Fries"
	desc = "Fries. Covered in cheese. Duh."
	icon_state = "cheesyfries"
	trash = /obj/item/trash/plate
	filling_color = "#EDDD00"
	center_of_mass_x = 16
	center_of_mass_y = 11
	nutriment_amt = 4
	nutriment_desc = list("fresh fries" = 3, REAGENT_ID_CHEESE = 3)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/cheesyfries/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 2)

/obj/item/reagent_containers/food/snacks/chilicheesefries
	name = "chili cheese fries"
	gender = PLURAL
	desc = "A mighty plate of fries, drowned in hot chili and cheese sauce. Because your arteries are overrated."
	icon_state = "chilicheesefries"
	trash = /obj/item/trash/plate
	filling_color = "#EDDD00"
	nutriment_amt = 8
	nutriment_desc = list("hearty, cheesy fries" = 8)
	center_of_mass_x = 16
	center_of_mass_y = 11
	bitesize = 4

/obj/item/reagent_containers/food/snacks/chilicheesefries/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 2)
	reagents.add_reagent(REAGENT_ID_CAPSAICIN, 2)

/obj/item/reagent_containers/food/snacks/blackpudding
	name = "Black Pudding"
	desc = "This doesn't seem like a pudding at all."
	icon_state = "blackpudding"
	filling_color = "#FF0000"
	center_of_mass_x = 16
	center_of_mass_y = 7
	bitesize = 3

/obj/item/reagent_containers/food/snacks/blackpudding/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 2)
	reagents.add_reagent(REAGENT_ID_BLOOD, 5)

/obj/item/reagent_containers/food/snacks/soydope
	name = "Soy Dope"
	desc = "Dope from a soy."
	icon_state = "soydope"
	trash = /obj/item/trash/plate
	filling_color = "#C4BF76"
	center_of_mass_x = 16
	center_of_mass_y = 10
	nutriment_amt = 2
	nutriment_desc = list("slime" = 2, "soy" = 2)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/spagetti
	name = "Spaghetti"
	desc = "A bundle of raw spaghetti."
	icon_state = "spagetti"
	filling_color = "#EDDD00"
	center_of_mass_x = 16
	center_of_mass_y = 16
	nutriment_amt = 1
	nutriment_desc = list("noodles" = 2)
	bitesize = 1

/obj/item/reagent_containers/food/snacks/badrecipe
	name = "Burned mess"
	desc = "Someone should be demoted from chef for this."
	icon_state = "badrecipe"
	filling_color = "#211F02"
	center_of_mass_x = 16
	center_of_mass_y = 12
	bitesize = 2

/obj/item/reagent_containers/food/snacks/badrecipe/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_SALMONELLA, 1)
	reagents.add_reagent(REAGENT_ID_CARBON, 3)

/obj/item/reagent_containers/food/snacks/meatsteak
	name = "Meat steak"
	desc = "A piece of hot spicy meat."
	icon_state = "meatstake"
	trash = /obj/item/trash/plate
	filling_color = "#7A3D11"
	center_of_mass_x = 16
	center_of_mass_y = 13
	bitesize = 3

/obj/item/reagent_containers/food/snacks/meatsteak/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 4)
	reagents.add_reagent(REAGENT_ID_SODIUMCHLORIDE, 1)
	reagents.add_reagent(REAGENT_ID_BLACKPEPPER, 1)

/obj/item/reagent_containers/food/snacks/spacylibertyduff
	name = "Spacy Liberty Duff"
	desc = "Jello gelatin, from Alfred Hubbard's cookbook"
	icon_state = "spacylibertyduff"
	trash = /obj/item/trash/snack_bowl
	filling_color = "#42B873"
	center_of_mass_x = 16
	center_of_mass_y = 8
	nutriment_amt = 6
	nutriment_desc = list(PLANT_MUSHROOMS = 6)
	bitesize = 3

/obj/item/reagent_containers/food/snacks/spacylibertyduff/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PSILOCYBIN, 6)

/obj/item/reagent_containers/food/snacks/amanitajelly
	name = "Amanita Jelly"
	desc = "Looks curiously toxic"
	icon_state = "amanitajelly"
	trash = /obj/item/trash/snack_bowl
	filling_color = "#ED0758"
	center_of_mass_x = 16
	center_of_mass_y = 5
	nutriment_amt = 6
	nutriment_desc = list("jelly" = 3, PLANT_MUSHROOMS = 3)
	bitesize = 3

/obj/item/reagent_containers/food/snacks/amanitajelly/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_AMATOXIN, 6)
	reagents.add_reagent(REAGENT_ID_PSILOCYBIN, 3)

/obj/item/reagent_containers/food/snacks/poppypretzel
	name = "Poppy pretzel"
	desc = "It's all twisted up!"
	icon_state = "poppypretzel"
	bitesize = 2
	filling_color = "#916E36"
	center_of_mass_x = 16
	center_of_mass_y = 10
	nutriment_amt = 5
	nutriment_desc = list("poppy seeds" = 2, "pretzel" = 3)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/monkeycube
	name = "monkey cube"
	desc = "Just add water!"
	flags = OPENCONTAINER
	icon_state = "monkeycube"
	bitesize = 12
	filling_color = "#ADAC7F"
	center_of_mass_x = 16
	center_of_mass_y = 14

	var/wrapped = 0
	var/monkey_type = "Monkey"

/obj/item/reagent_containers/food/snacks/monkeycube/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 10)

/obj/item/reagent_containers/food/snacks/monkeycube/attack_self(mob/user as mob)
	if(wrapped)
		Unwrap(user)

/obj/item/reagent_containers/food/snacks/monkeycube/proc/Expand()
	src.visible_message(span_infoplain(span_bold("\The [src]") + " expands!"))
	var/mob/living/carbon/human/H = new(get_turf(src))
	H.set_species(monkey_type)
	H.real_name = H.species.get_random_name()
	H.name = H.real_name
	H.low_sorting_priority = TRUE
	H.species.produceCopy(H.species.traits.Copy(),H,null,FALSE)
	if(ismob(loc))
		var/mob/M = loc
		M.unEquip(src)
	qdel(src)
	return 1

/obj/item/reagent_containers/food/snacks/monkeycube/proc/Unwrap(mob/user as mob)
	icon_state = "monkeycube"
	desc = "Just add water!"
	to_chat(user, "You unwrap the cube.")
	wrapped = 0
	flags |= OPENCONTAINER
	return

/obj/item/reagent_containers/food/snacks/monkeycube/On_Consume(var/mob/M)
	if(ishuman(M))
		var/mob/living/carbon/human/H = M
		H.visible_message(span_warning("A screeching creature bursts out of [M]'s chest!"))
		var/obj/item/organ/external/organ = H.get_organ(BP_TORSO)
		organ.take_damage(50, 0, 0, "Animal escaping the ribcage")
	Expand()

/obj/item/reagent_containers/food/snacks/monkeycube/on_reagent_change()
	if(reagents.has_reagent(REAGENT_ID_WATER))
		Expand()

/obj/item/reagent_containers/food/snacks/monkeycube/wrapped
	desc = "Still wrapped in some paper."
	icon_state = "monkeycubewrap"
	flags = 0
	wrapped = 1

/obj/item/reagent_containers/food/snacks/monkeycube/farwacube
	name = "farwa cube"
	monkey_type = SPECIES_MONKEY_TAJ

/obj/item/reagent_containers/food/snacks/monkeycube/wrapped/farwacube
	name = "farwa cube"
	monkey_type = SPECIES_MONKEY_TAJ

/obj/item/reagent_containers/food/snacks/monkeycube/stokcube
	name = "stok cube"
	monkey_type = SPECIES_MONKEY_UNATHI

/obj/item/reagent_containers/food/snacks/monkeycube/wrapped/stokcube
	name = "stok cube"
	monkey_type = SPECIES_MONKEY_UNATHI

/obj/item/reagent_containers/food/snacks/monkeycube/neaeracube
	name = "neaera cube"
	monkey_type = SPECIES_MONKEY_SKRELL

/obj/item/reagent_containers/food/snacks/monkeycube/wrapped/neaeracube
	name = "neaera cube"
	monkey_type = SPECIES_MONKEY_SKRELL

/obj/item/reagent_containers/food/snacks/spellburger
	name = "Spell Burger"
	desc = "This is absolutely Ei Nath."
	icon_state = "spellburger"
	filling_color = "#D505FF"
	nutriment_amt = 6
	nutriment_desc = list("magic" = 3, "buns" = 3)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/bigbiteburger
	name = "Big Bite Burger"
	desc = "Forget the Big Mac. THIS is the future!"
	icon_state = "bigbiteburger"
	filling_color = "#E3D681"
	center_of_mass_x = 16
	center_of_mass_y = 11
	nutriment_amt = 4
	nutriment_desc = list("buns" = 4)
	bitesize = 3

/obj/item/reagent_containers/food/snacks/bigbiteburger/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 10)

/obj/item/reagent_containers/food/snacks/enchiladas
	name = "Enchiladas"
	desc = "Viva La Mexico!"
	icon_state = "enchiladas"
	trash = /obj/item/trash/tray
	filling_color = "#A36A1F"
	center_of_mass_x = 16
	center_of_mass_y = 13
	nutriment_amt = 2
	nutriment_desc = list("tortilla" = 3, PLANT_CORN = 3)
	bitesize = 4

/obj/item/reagent_containers/food/snacks/enchiladas/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 6)
	reagents.add_reagent(REAGENT_ID_CAPSAICIN, 6)

/obj/item/reagent_containers/food/snacks/monkeysdelight
	name = "monkey's Delight"
	desc = "Eeee Eee!"
	icon_state = "monkeysdelight"
	trash = /obj/item/trash/tray
	filling_color = "#5C3C11"
	center_of_mass_x = 16
	center_of_mass_y = 13
	bitesize = 6

/obj/item/reagent_containers/food/snacks/monkeysdelight/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 10)
	reagents.add_reagent(REAGENT_ID_BANANA, 5)
	reagents.add_reagent(REAGENT_ID_BLACKPEPPER, 1)
	reagents.add_reagent(REAGENT_ID_SODIUMCHLORIDE, 1)

/obj/item/reagent_containers/food/snacks/baguette
	name = "Baguette"
	desc = "Bon appetit!"
	icon_state = "baguette"
	filling_color = "#E3D796"
	center_of_mass_x = 18
	center_of_mass_y = 12
	nutriment_amt = 6
	nutriment_desc = list("french bread" = 6)
	bitesize = 3

/obj/item/reagent_containers/food/snacks/baguette/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_BLACKPEPPER, 1)
	reagents.add_reagent(REAGENT_ID_SODIUMCHLORIDE, 1)

/obj/item/reagent_containers/food/snacks/fishandchips
	name = "Fish and Chips"
	desc = "I do say so myself chap."
	icon_state = "fishandchips"
	filling_color = "#E3D796"
	center_of_mass_x = 16
	center_of_mass_y = 16
	nutriment_amt = 3
	nutriment_desc = list("salt" = 1, "chips" = 3)
	bitesize = 3

/obj/item/reagent_containers/food/snacks/fishandchips/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 3)

/obj/item/reagent_containers/food/snacks/rofflewaffles
	name = "Roffle Waffles"
	desc = "Waffles from Roffle. Co."
	icon_state = "rofflewaffles"
	trash = /obj/item/trash/waffles
	filling_color = "#FF00F7"
	center_of_mass_x = 15
	center_of_mass_y = 11
	nutriment_amt = 8
	nutriment_desc = list("waffle" = 7, "sweetness" = 1)
	bitesize = 4

/obj/item/reagent_containers/food/snacks/rofflewaffles/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PSILOCYBIN, 8)

/obj/item/reagent_containers/food/snacks/jelliedtoast
	name = "Jellied Toast"
	desc = "A slice of bread covered with delicious jam."
	icon_state = "jellytoast"
	filling_color = "#B572AB"
	center_of_mass_x = 16
	center_of_mass_y = 8
	nutriment_amt = 1
	nutriment_desc = list("toasted bread" = 2)
	bitesize = 3

/obj/item/reagent_containers/food/snacks/jelliedtoast/cherry
	name = "Cherry Jellied Toast"

/obj/item/reagent_containers/food/snacks/jelliedtoast/slime
	name = "Slime Jellied Toast"

/obj/item/reagent_containers/food/snacks/jelliedtoast/cherry/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_CHERRYJELLY, 5)

/obj/item/reagent_containers/food/snacks/jelliedtoast/slime/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_SLIMEJELLY, 5)

/obj/item/reagent_containers/food/snacks/honeytoast
	name = "Honeyed Toast"
	desc = "For those who like their breakfast sweet."
	icon_state = "honeytoast"
	filling_color = "#FFC02D"
	nutriment_amt = 1
	nutriment_desc = list("sweet, crunchy bread" = 1)
	center_of_mass_x = 16
	center_of_mass_y = 9
	bitesize = 3

/obj/item/reagent_containers/food/snacks/cheesetoast
	name = "Cheesy Toast"
	desc = "A piece of toast lathered with butter, cheese, and spice."
	icon_state = "cheesytoast"
	filling_color = "#F9A617"
	nutriment_amt = 1
	nutriment_desc = list("cheese toast" = 8)
	center_of_mass_x = 16
	center_of_mass_y = 9
	bitesize = 3

/obj/item/reagent_containers/food/snacks/jellyburger
	name = "Jelly Burger"
	desc = "Culinary delight..?"
	icon_state = "jellyburger"
	filling_color = "#B572AB"
	center_of_mass_x = 16
	center_of_mass_y = 11
	nutriment_amt = 5
	nutriment_desc = list("buns" = 5)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/jellyburger/slime
	name = "Slime Jelly Burger"

/obj/item/reagent_containers/food/snacks/jellyburger/cherry
	name = "Cherry Jelly Burger"

/obj/item/reagent_containers/food/snacks/jellyburger/slime/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_SLIMEJELLY, 5)

/obj/item/reagent_containers/food/snacks/jellyburger/cherry/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_CHERRYJELLY, 5)

/obj/item/reagent_containers/food/snacks/stewedsoymeat
	name = "Stewed Soy Meat"
	desc = "Even non-vegetarians will LOVE this!"
	icon_state = "stewedsoymeat"
	trash = /obj/item/trash/plate
	center_of_mass_x = 16
	center_of_mass_y = 10
	nutriment_amt = 8
	nutriment_desc = list("soy" = 4, PLANT_TOMATO = 4)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/boiledspagetti
	name = "Boiled Spaghetti"
	desc = "A plain dish of noodles, this sucks."
	icon_state = "spagettiboiled"
	trash = /obj/item/trash/plate
	filling_color = "#FCEE81"
	center_of_mass_x = 16
	center_of_mass_y = 10
	nutriment_amt = 2
	nutriment_desc = list("noodles" = 2)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/boiledrice
	name = "Boiled Rice"
	desc = "A boring dish of boring rice."
	icon_state = "boiledrice"
	trash = /obj/item/trash/snack_bowl
	filling_color = "#FFFBDB"
	center_of_mass_x = 17
	center_of_mass_y = 11
	nutriment_amt = 2
	nutriment_desc = list(REAGENT_ID_RICE = 2)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/ricepudding
	name = "Rice Pudding"
	desc = "Where's the jam?"
	icon_state = "rpudding"
	trash = /obj/item/trash/snack_bowl
	filling_color = "#FFFBDB"
	center_of_mass_x = 17
	center_of_mass_y = 11
	nutriment_amt = 4
	nutriment_desc = list(REAGENT_ID_RICE = 2)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/kudzudonburi
	name = "Zhan-Kudzu Overtaker"
	desc = "Seasoned Kudzu and fish donburi."
	icon_state = "kudzudonburi"
	trash = /obj/item/trash/snack_bowl
	filling_color = "#FFFBDB"
	center_of_mass_x = 17
	center_of_mass_y = 11
	nutriment_amt = 16
	nutriment_desc = list(REAGENT_ID_RICE = 2, "gauze" = 4, "fish" = 10)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/kudzudonburi/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 4)

/obj/item/reagent_containers/food/snacks/pastatomato
	name = "Spaghetti"
	desc = "Spaghetti and crushed tomatoes. Just like your abusive father used to make!"
	icon_state = "pastatomato"
	trash = /obj/item/trash/plate
	filling_color = "#DE4545"
	center_of_mass_x = 16
	center_of_mass_y = 10
	nutriment_amt = 6
	nutriment_desc = list(PLANT_TOMATO = 3, "noodles" = 3)
	bitesize = 4

/obj/item/reagent_containers/food/snacks/pastatomato/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_TOMATOJUICE, 10)

/obj/item/reagent_containers/food/snacks/meatballspagetti
	name = "Spaghetti & Meatballs"
	desc = "Now that's a nic'e meatball!"
	icon_state = "meatballspagetti"
	trash = /obj/item/trash/plate
	filling_color = "#DE4545"
	center_of_mass_x = 16
	center_of_mass_y = 10
	nutriment_amt = 4
	nutriment_desc = list("noodles" = 4)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/meatballspagetti/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 4)

/obj/item/reagent_containers/food/snacks/spesslaw
	name = "Spesslaw"
	desc = "A lawyer's favourite"
	icon_state = "spesslaw"
	filling_color = "#DE4545"
	center_of_mass_x = 16
	center_of_mass_y = 10
	nutriment_amt = 4
	nutriment_desc = list("noodles" = 4)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/spesslaw/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 4)

/obj/item/reagent_containers/food/snacks/superbiteburger
	name = "Super Bite Burger"
	desc = "This is a mountain of a burger. FOOD!"
	icon_state = "superbiteburger"
	filling_color = "#CCA26A"
	center_of_mass_x = 16
	center_of_mass_y = 3
	nutriment_amt = 25
	nutriment_desc = list("buns" = 25)
	bitesize = 10

/obj/item/reagent_containers/food/snacks/superbiteburger/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 25)

/obj/item/reagent_containers/food/snacks/caramelapple
	name = "Caramel Apple"
	desc = "An apple coated in rich caramel."
	icon_state = "candiedapple1"
	trash = /obj/item/trash/stick
	filling_color = "#F21873"
	center_of_mass_x = 15
	center_of_mass_y = 13
	nutriment_amt = 3
	nutriment_desc = list(PLANT_APPLE = 3, "caramel" = 3, "sweetness" = 2)
	bitesize = 3

/obj/item/reagent_containers/food/snacks/candiedapple
	name = "Candied Apple"
	desc = "An apple coated in sugary sweetness."
	icon_state = "candiedapple2"
	trash = /obj/item/trash/stick
	filling_color = "#F21873"
	center_of_mass_x = 15
	center_of_mass_y = 13
	nutriment_amt = 3
	nutriment_desc = list(PLANT_APPLE = 3, "sweetness" = 2)
	bitesize = 3

/obj/item/reagent_containers/food/snacks/applepie
	name = "Apple Pie"
	desc = "A pie containing sweet sweet love... or apple."
	icon_state = "applepie"
	filling_color = "#E0EDC5"
	center_of_mass_x = 16
	center_of_mass_y = 13
	nutriment_amt = 4
	nutriment_desc = list("sweetness" = 2, PLANT_APPLE = 2, "pie" = 2)
	bitesize = 3

/obj/item/reagent_containers/food/snacks/cherrypie
	name = "Cherry Pie"
	desc = "Taste so good, make a grown man cry."
	icon_state = "cherrypie"
	filling_color = "#FF525A"
	center_of_mass_x = 16
	center_of_mass_y = 11
	nutriment_amt = 4
	nutriment_desc = list("sweetness" = 2, PLANT_CHERRY = 2, "pie" = 2)
	bitesize = 3

/obj/item/reagent_containers/food/snacks/twobread
	name = "Two Bread"
	desc = "It is very bitter and winy."
	description_fluff = "The most popular recipe from the Morpheus Cyberkinetics cookbook 'Calories for Organics'"
	icon_state = "twobread"
	filling_color = "#DBCC9A"
	center_of_mass_x = 15
	center_of_mass_y = 12
	nutriment_amt = 2
	nutriment_desc = list("sourness" = 2, "bread" = 2)
	bitesize = 3

// Sandwiches //////////////////////////////////////////////////

/obj/item/reagent_containers/food/snacks/sandwich
	name = "Sandwich"
	desc = "A grand creation of meat, cheese, bread, and several leaves of lettuce! Arthur Dent would be proud."
	icon_state = "sandwich"
	filling_color = "#D9BE29"
	center_of_mass_x = 16
	center_of_mass_y = 4
	nutriment_amt = 3
	nutriment_desc = list("bread" = 3, REAGENT_ID_CHEESE = 3)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/sandwich/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 3)

/obj/item/reagent_containers/food/snacks/clubsandwich
	name = "Club Sandwich"
	desc = "Tastes like the good feelings when you're part of a clique."
	icon_state = "clubsandwich"
	trash = "obj/item/trash/plate"
	nutriment_amt = 3
	nutriment_desc = list("a galactic economy coming together in pursuit of mundane foods" = 3)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/toastedsandwich
	name = "Toasted Sandwich"
	desc = "Now if you only had a pepper bar."
	icon_state = "toastedsandwich"
	filling_color = "#D9BE29"
	center_of_mass_x = 16
	center_of_mass_y = 4
	nutriment_amt = 3
	nutriment_desc = list("toasted bread" = 3, REAGENT_ID_CHEESE = 3)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/toastedsandwich/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 3)
	reagents.add_reagent(REAGENT_ID_CARBON, 2)

/obj/item/reagent_containers/food/snacks/grilledcheese
	name = "Grilled Cheese Sandwich"
	desc = "Goes great with Tomato soup!"
	icon_state = "toastedsandwich"
	filling_color = "#D9BE29"
	nutriment_amt = 3
	nutriment_desc = list("toasted bread" = 3, REAGENT_ID_CHEESE = 3)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/grilledcheese/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 4)

/obj/item/reagent_containers/food/snacks/jellysandwich
	name = "Jelly Sandwich"
	desc = "You wish you had some peanut butter to go with this..."
	icon_state = "jellysandwich"
	filling_color = "#9E3A78"
	center_of_mass_x = 16
	center_of_mass_y = 8
	nutriment_amt = 2
	nutriment_desc = list("bread" = 2)
	bitesize = 3

/obj/item/reagent_containers/food/snacks/jellysandwich/slime
	name = "Slime Jelly Sandwich"

/obj/item/reagent_containers/food/snacks/jellysandwich/slime
	name = "Cherry Jelly Sandwich"

/obj/item/reagent_containers/food/snacks/jellysandwich/peanutbutter
	name = "Peanut Butter Jelly Sandwich"

/obj/item/reagent_containers/food/snacks/jellysandwich/slime/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_SLIMEJELLY, 5)

/obj/item/reagent_containers/food/snacks/jellysandwich/cherry/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_CHERRYJELLY, 5)

/obj/item/reagent_containers/food/snacks/jellysandwich/peanutbutter
	desc = "You wish you had some peanut butter to go with this... Oh wait!"
	icon_state = "pbandj"

/obj/item/reagent_containers/food/snacks/jellysandwich/peanutbutter/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PEANUTBUTTER, 5)

// End Sandwiches //////////////////////////////////////////////

/obj/item/reagent_containers/food/snacks/boiledslimecore
	name = "Boiled Slime Core"
	desc = "A boiled red thing."
	icon_state = "boiledslimecore"
	bitesize = 3

/obj/item/reagent_containers/food/snacks/boiledslimecore/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_SLIMEJELLY, 5)

/obj/item/reagent_containers/food/snacks/plumphelmetbiscuit
	name = "plump helmet biscuit"
	desc = "This is a finely-prepared plump helmet biscuit. The ingredients are exceptionally minced plump helmet, and well-minced dwarven wheat flour."
	icon_state = "phelmbiscuit"
	filling_color = "#CFB4C4"
	center_of_mass_x = 16
	center_of_mass_y = 13
	nutriment_amt = 5
	nutriment_desc = list(PLANT_MUSHROOMS = 4)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/plumphelmetbiscuit/Initialize(mapload)
	. = ..()
	if(prob(10))
		name = "exceptional plump helmet biscuit"
		desc = "Microwave is taken by a fey mood! It has cooked an exceptional plump helmet biscuit!"
		reagents.add_reagent(REAGENT_ID_NUTRIMENT, 3, nutriment_desc)

/obj/item/reagent_containers/food/snacks/chawanmushi
	name = "chawanmushi"
	desc = "A legendary egg custard that makes friends out of enemies. Probably too hot for a cat to eat."
	icon_state = "chawanmushi"
	trash = /obj/item/trash/snack_bowl
	filling_color = "#F0F2E4"
	center_of_mass_x = 17
	center_of_mass_y = 10
	bitesize = 1

/obj/item/reagent_containers/food/snacks/chawanmushi/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 5)

/obj/item/reagent_containers/food/snacks/tossedsalad
	name = "tossed salad"
	desc = "A proper salad, basic and simple, with little bits of carrot, tomato and apple intermingled. Vegan!"
	icon_state = "herbsalad"
	trash = /obj/item/trash/snack_bowl
	filling_color = "#76B87F"
	center_of_mass_x = 17
	center_of_mass_y = 11
	nutriment_amt = 8
	nutriment_desc = list("salad" = 2, PLANT_TOMATO = 2, PLANT_CARROT = 2, PLANT_APPLE = 2)
	bitesize = 3

/obj/item/reagent_containers/food/snacks/validsalad
	name = "valid salad"
	desc = "It's just a salad of questionable 'herbs' with meatballs and fried potato slices. Nothing suspicious about it."
	icon_state = "validsalad"
	trash = /obj/item/trash/snack_bowl
	filling_color = "#76B87F"
	center_of_mass_x = 17
	center_of_mass_y = 11
	nutriment_amt = 6
	nutriment_desc = list("100% real salad")
	bitesize = 3

/obj/item/reagent_containers/food/snacks/validsalad/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 2)

/obj/item/reagent_containers/food/snacks/appletart
	name = "golden apple streusel tart"
	desc = "A tasty dessert that won't make it through a metal detector."
	icon_state = "gappletart"
	trash = /obj/item/trash/plate
	filling_color = "#FFFF00"
	center_of_mass_x = 16
	center_of_mass_y = 18
	nutriment_amt = 8
	nutriment_desc = list(PLANT_APPLE = 8)
	bitesize = 3

/obj/item/reagent_containers/food/snacks/appletart/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_GOLD, 5)

///////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////Soups/////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////

/obj/item/reagent_containers/food/snacks/meatballsoup
	name = "Meatball soup"
	desc = "You've got balls kid, BALLS!"
	icon_state = "meatballsoup"
	trash = /obj/item/trash/snack_bowl
	filling_color = "#785210"
	center_of_mass_x = 16
	center_of_mass_y = 8
	bitesize = 5
	eating_sound = 'sound/items/drink.ogg'

/obj/item/reagent_containers/food/snacks/meatballsoup/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 8)
	reagents.add_reagent(REAGENT_ID_WATER, 5)

/obj/item/reagent_containers/food/snacks/slimesoup
	name = "slime soup"
	desc = "If no water is available, you may substitute tears."
	icon_state = "slimesoup" //nonexistant? - 3/1/2020 FIXED. roro's live on. - 7/14/2020 - The fuck are you smoking, roro's is stupid, name it slimesoup so it's clear wtf it is.
	filling_color = "#C4DBA0"
	bitesize = 5
	eating_sound = 'sound/items/drink.ogg'

/obj/item/reagent_containers/food/snacks/slimesoup/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_SLIMEJELLY, 5)
	reagents.add_reagent(REAGENT_ID_WATER, 10)

/obj/item/reagent_containers/food/snacks/bloodsoup
	name = "Tomato soup"
	desc = "Smells like copper."
	icon_state = "tomatosoup"
	filling_color = "#FF0000"
	center_of_mass_x = 16
	center_of_mass_y = 7
	bitesize = 5
	eating_sound = 'sound/items/drink.ogg'

/obj/item/reagent_containers/food/snacks/bloodsoup/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 2)
	reagents.add_reagent(REAGENT_ID_BLOOD, 10)
	reagents.add_reagent(REAGENT_ID_WATER, 5)

/obj/item/reagent_containers/food/snacks/clownstears
	name = JOB_CLOWN + "'s Tears"
	desc = "Not very funny."
	icon_state = "clownstears"
	filling_color = "#C4FBFF"
	center_of_mass_x = 16
	center_of_mass_y = 7
	nutriment_amt = 4
	nutriment_desc = list("salt" = 1, "the worst joke" = 3)
	bitesize = 5
	eating_sound = 'sound/items/drink.ogg'

/obj/item/reagent_containers/food/snacks/clownstears/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_BANANA, 5)
	reagents.add_reagent(REAGENT_ID_WATER, 10)

/obj/item/reagent_containers/food/snacks/vegetablesoup
	name = "Vegetable soup"
	desc = "A true vegan meal" //TODO
	icon_state = "vegetablesoup"
	trash = /obj/item/trash/snack_bowl
	filling_color = "#AFC4B5"
	center_of_mass_x = 16
	center_of_mass_y = 8
	nutriment_desc = list(PLANT_CARROT = 2, PLANT_CORN = 2, PLANT_EGGPLANT = 2, PLANT_POTATO = 2)
	bitesize = 5
	eating_sound = 'sound/items/drink.ogg'

/obj/item/reagent_containers/food/snacks/vegetablesoup/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_VEGETABLESOUP, 10)

/obj/item/reagent_containers/food/snacks/nettlesoup
	name = "Nettle soup"
	desc = "To think, the botanist would've beat you to death with one of these."
	icon_state = "nettlesoup"
	trash = /obj/item/trash/snack_bowl
	filling_color = "#AFC4B5"
	center_of_mass_x = 16
	center_of_mass_y = 7
	nutriment_amt = 8
	nutriment_desc = list("salad" = 4, REAGENT_ID_EGG = 2, PLANT_POTATO = 2)
	bitesize = 5
	eating_sound = 'sound/items/drink.ogg'

/obj/item/reagent_containers/food/snacks/nettlesoup/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_WATER, 5)
	reagents.add_reagent(REAGENT_ID_TRICORDRAZINE, 5)

/obj/item/reagent_containers/food/snacks/mysterysoup
	name = "Mystery soup"
	desc = "The mystery is, why aren't you eating it?"
	icon_state = "mysterysoup"
	trash = /obj/item/trash/snack_bowl
	filling_color = "#F082FF"
	center_of_mass_x = 16
	center_of_mass_y = 6
	nutriment_amt = 1
	nutriment_desc = list("backwash" = 1)
	bitesize = 5
	eating_sound = 'sound/items/drink.ogg'

/obj/item/reagent_containers/food/snacks/mysterysoup/Initialize(mapload)
	. = ..()
	var/mysteryselect = pick(1,2,3,4,5,6,7,8,9,10)
	switch(mysteryselect)
		if(1)
			reagents.add_reagent(REAGENT_ID_NUTRIMENT, 6, nutriment_desc)
			reagents.add_reagent(REAGENT_ID_CAPSAICIN, 3)
			reagents.add_reagent(REAGENT_ID_TOMATOJUICE, 2)
		if(2)
			reagents.add_reagent(REAGENT_ID_NUTRIMENT, 6, nutriment_desc)
			reagents.add_reagent(REAGENT_ID_FROSTOIL, 3)
			reagents.add_reagent(REAGENT_ID_TOMATOJUICE, 2)
		if(3)
			reagents.add_reagent(REAGENT_ID_NUTRIMENT, 5, nutriment_desc)
			reagents.add_reagent(REAGENT_ID_WATER, 5)
			reagents.add_reagent(REAGENT_ID_TRICORDRAZINE, 5)
		if(4)
			reagents.add_reagent(REAGENT_ID_NUTRIMENT, 5, nutriment_desc)
			reagents.add_reagent(REAGENT_ID_WATER, 10)
		if(5)
			reagents.add_reagent(REAGENT_ID_NUTRIMENT, 2, nutriment_desc)
			reagents.add_reagent(REAGENT_ID_BANANA, 10)
		if(6)
			reagents.add_reagent(REAGENT_ID_NUTRIMENT, 6, nutriment_desc)
			reagents.add_reagent(REAGENT_ID_BLOOD, 10)
		if(7)
			reagents.add_reagent(REAGENT_ID_SLIMEJELLY, 10)
			reagents.add_reagent(REAGENT_ID_WATER, 10)
		if(8)
			reagents.add_reagent(REAGENT_ID_CARBON, 10)
			reagents.add_reagent(REAGENT_ID_TOXIN, 10)
		if(9)
			reagents.add_reagent(REAGENT_ID_NUTRIMENT, 5, nutriment_desc)
			reagents.add_reagent(REAGENT_ID_TOMATOJUICE, 10)
		if(10)
			reagents.add_reagent(REAGENT_ID_NUTRIMENT, 6, nutriment_desc)
			reagents.add_reagent(REAGENT_ID_TOMATOJUICE, 5)
			reagents.add_reagent(REAGENT_ID_IMIDAZOLINE, 5)

/obj/item/reagent_containers/food/snacks/wishsoup
	name = "Wish Soup"
	desc = "I wish this was soup."
	icon_state = "wishsoup"
	trash = /obj/item/trash/snack_bowl
	filling_color = "#D1F4FF"
	center_of_mass_x = 16
	center_of_mass_y = 11
	bitesize = 5
	eating_sound = 'sound/items/drink.ogg'

/obj/item/reagent_containers/food/snacks/wishsoup/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_WATER, 10)
	if(prob(25))
		src.desc = "A wish come true!"
		reagents.add_reagent(REAGENT_ID_NUTRIMENT, 8, list("something good" = 8))

/obj/item/reagent_containers/food/snacks/tomatosoup
	name = "Tomato Soup"
	desc = "Drinking this feels like being a vampire! A tomato vampire..."
	icon_state = "tomatosoup"
	trash = /obj/item/trash/snack_bowl
	filling_color = "#D92929"
	center_of_mass_x = 16
	center_of_mass_y = 7
	bitesize = 3
	eating_sound = 'sound/items/drink.ogg'

/obj/item/reagent_containers/food/snacks/tomatosoup/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_TOMATOSOUP, 10)

/obj/item/reagent_containers/food/snacks/mushroomsoup
	name = "chantrelle soup"
	desc = "A delicious and hearty mushroom soup."
	icon_state = "mushroomsoup"
	trash = /obj/item/trash/snack_bowl
	filling_color = "#E386BF"
	center_of_mass_x = 17
	center_of_mass_y = 10
	bitesize = 3
	eating_sound = 'sound/items/drink.ogg'

/obj/item/reagent_containers/food/snacks/mushroomsoup/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_MUSHROOMSOUP, 10)

/obj/item/reagent_containers/food/snacks/beetsoup
	name = "beet soup"
	desc = "Wait, how do you spell it again..?"
	icon_state = "beetsoup"
	trash = /obj/item/trash/snack_bowl
	filling_color = "#FAC9FF"
	center_of_mass_x = 15
	center_of_mass_y = 8
	bitesize = 3
	eating_sound = 'sound/items/drink.ogg'

/obj/item/reagent_containers/food/snacks/beetsoup/Initialize(mapload)
	. = ..()
	name = pick(list("borsch","bortsch","borstch","borsh","borshch","borscht"))
	reagents.add_reagent(REAGENT_ID_BEETSOUP, 10)

/obj/item/reagent_containers/food/snacks/soup/onion
	name = "onion soup"
	desc = "A soup with layers."
	icon_state = "onionsoup"
	trash = /obj/item/trash/snack_bowl
	filling_color = "#E0C367"
	center_of_mass_x = 16
	center_of_mass_y = 7
	bitesize = 3
	eating_sound = 'sound/items/drink.ogg'

/obj/item/reagent_containers/food/snacks/soup/onion/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_ONIONSOUP, 10)

/obj/item/reagent_containers/food/snacks/chickennoodlesoup
	name = "chicken noodle soup"
	gender = PLURAL
	desc = "A bright bowl of yellow broth with cuts of meat, noodles and carrots."
	icon_state = "chickennoodlesoup"
	filling_color = "#ead90c"
	bitesize = 5

/obj/item/reagent_containers/food/snacks/chickennoodlesoup/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_CHICKENNOODLESOUP, 10)

/obj/item/reagent_containers/food/snacks/stew
	name = "Stew"
	desc = "A nice and warm stew. Healthy and strong."
	icon_state = "stew"
	filling_color = "#9E673A"
	center_of_mass_x = 16
	center_of_mass_y = 5
	nutriment_amt = 6
	nutriment_desc = list(PLANT_TOMATO = 2, PLANT_POTATO = 2, PLANT_CARROT = 2, PLANT_EGGPLANT = 2, PLANT_MUSHROOMS = 2)
	drop_sound = 'sound/items/drop/shovel.ogg'
	pickup_sound = 'sound/items/pickup/shovel.ogg'
	bitesize = 10
	eating_sound = 'sound/items/drink.ogg'

/obj/item/reagent_containers/food/snacks/stew/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 4)
	reagents.add_reagent(REAGENT_ID_TOMATOJUICE, 5)
	reagents.add_reagent(REAGENT_ID_IMIDAZOLINE, 5)
	reagents.add_reagent(REAGENT_ID_WATER, 5)

/obj/item/reagent_containers/food/snacks/bearstew
	name = "bear stew"
	gender = PLURAL
	desc = "A thick, dark stew of bear meat and vegetables."
	icon_state = "bearstew"
	filling_color = "#9E673A"
	nutriment_amt = 6
	nutriment_desc = list("hearty stew" = 6)
	center_of_mass_x = 16
	center_of_mass_y = 5
	bitesize = 6
	eating_sound = 'sound/items/drink.ogg'

/obj/item/reagent_containers/food/snacks/bearstew/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 4)
	reagents.add_reagent(REAGENT_ID_HYPERZINE, 5)
	reagents.add_reagent(REAGENT_ID_TOMATOJUICE, 5)
	reagents.add_reagent(REAGENT_ID_IMIDAZOLINE, 5)
	reagents.add_reagent(REAGENT_ID_WATER, 5)


/obj/item/reagent_containers/food/snacks/hotchili
	name = "Hot Chili"
	desc = "A five alarm Texan Chili!"
	icon_state = "hotchili"
	trash = /obj/item/trash/snack_bowl
	filling_color = "#FF3C00"
	center_of_mass_x = 15
	center_of_mass_y = 9
	nutriment_amt = 3
	nutriment_desc = list("chilli peppers" = 3)
	bitesize = 5
	eating_sound = 'sound/items/drink.ogg'

/obj/item/reagent_containers/food/snacks/hotchili/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 3)
	reagents.add_reagent(REAGENT_ID_CAPSAICIN, 3)
	reagents.add_reagent(REAGENT_ID_TOMATOJUICE, 2)

/obj/item/reagent_containers/food/snacks/coldchili
	name = "Cold Chili"
	desc = "This slush is barely a liquid!"
	icon_state = "coldchili"
	filling_color = "#2B00FF"
	center_of_mass_x = 15
	center_of_mass_y = 9
	trash = /obj/item/trash/snack_bowl
	nutriment_amt = 3
	nutriment_desc = list("ice peppers" = 3)
	bitesize = 5
	eating_sound = 'sound/items/drink.ogg'

/obj/item/reagent_containers/food/snacks/coldchili/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 3)
	reagents.add_reagent(REAGENT_ID_FROSTOIL, 3)
	reagents.add_reagent(REAGENT_ID_TOMATOJUICE, 2)


/obj/item/reagent_containers/food/snacks/bearchili
	name = "bear chili"
	gender = PLURAL
	desc = "A dark, hearty chili. Can you bear the heat?"
	icon_state = "bearchili"
	trash = /obj/item/trash/snack_bowl
	filling_color = "#702708"
	nutriment_amt = 3
	nutriment_desc = list("dark, hearty chili" = 3)
	center_of_mass_x = 15
	center_of_mass_y = 9
	bitesize = 6
	eating_sound = 'sound/items/drink.ogg'

/obj/item/reagent_containers/food/snacks/bearchili/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 3)
	reagents.add_reagent(REAGENT_ID_CAPSAICIN, 3)
	reagents.add_reagent(REAGENT_ID_TOMATOJUICE, 2)
	reagents.add_reagent(REAGENT_ID_HYPERZINE, 5)

///////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////Sliceable/////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////

// All the food items that can be sliced into smaller bits like Meatbread and Cheesewheels

// sliceable is just an organization type path, it doesn't have any additional code or variables tied to it.

/obj/item/reagent_containers/food/snacks/sliceable
	w_class = ITEMSIZE_NORMAL //Whole pizzas and cakes shouldn't fit in a pocket, you can slice them if you want to do that.

/**
 *  A food item slice
 *
 *  This path contains some extra code for spawning slices pre-filled with
 *  reagents.
 */
/obj/item/reagent_containers/food/snacks/slice
	name = "slice of... something"
	var/whole_path  // path for the item from which this slice comes
	var/filled = FALSE  // should the slice spawn with any reagents

/**
 *  Spawn a new slice of food
 *
 *  If the slice's filled is TRUE, this will also fill the slice with the
 *  appropriate amount of reagents. Note that this is done by spawning a new
 *  whole item, transferring the reagents and deleting the whole item, which may
 *  have performance implications.
 */
/obj/item/reagent_containers/food/snacks/slice/Initialize(mapload)
	. = ..()
	if(filled)
		var/obj/item/reagent_containers/food/snacks/whole = new whole_path()
		if(whole && whole.slices_num)
			var/reagent_amount = whole.reagents.total_volume/whole.slices_num
			whole.reagents.trans_to_obj(src, reagent_amount)

		qdel(whole)

/obj/item/reagent_containers/food/snacks/sliceable/meatbread
	name = "meatbread loaf"
	desc = "The culinary base of every self-respecting eloquent gentleman."
	icon_state = "meatbread"
	slice_path = /obj/item/reagent_containers/food/snacks/slice/meatbread
	slices_num = 5
	filling_color = "#FF7575"
	center_of_mass_x = 19
	center_of_mass_y = 9
	nutriment_desc = list("bread" = 10)
	nutriment_amt = 10
	bitesize = 2

/obj/item/reagent_containers/food/snacks/sliceable/meatbread/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 20)

/obj/item/reagent_containers/food/snacks/slice/meatbread
	name = "meatbread slice"
	desc = "A slice of delicious meatbread."
	icon_state = "meatbreadslice"
	trash = /obj/item/trash/plate
	filling_color = "#FF7575"
	bitesize = 2
	center_of_mass_x = 16
	center_of_mass_y = 16
	whole_path = /obj/item/reagent_containers/food/snacks/sliceable/meatbread

/obj/item/reagent_containers/food/snacks/slice/meatbread/filled
	filled = TRUE

/obj/item/reagent_containers/food/snacks/sliceable/xenomeatbread
	name = "xenomeatbread loaf"
	desc = "The culinary base of every self-respecting eloquent gentleman. Extra Heretical."
	icon_state = "xenomeatbread"
	slice_path = /obj/item/reagent_containers/food/snacks/slice/xenomeatbread
	slices_num = 5
	filling_color = "#8AFF75"
	center_of_mass_x = 16
	center_of_mass_y = 9
	nutriment_desc = list("bread" = 10)
	nutriment_amt = 10
	bitesize = 2

/obj/item/reagent_containers/food/snacks/sliceable/xenomeatbread/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 20)

/obj/item/reagent_containers/food/snacks/slice/xenomeatbread
	name = "xenomeatbread slice"
	desc = "A slice of delicious meatbread. Extra Heretical."
	icon_state = "xenobreadslice"
	filling_color = "#8AFF75"
	bitesize = 2
	center_of_mass_x = 16
	center_of_mass_y = 13
	whole_path = /obj/item/reagent_containers/food/snacks/sliceable/xenomeatbread


/obj/item/reagent_containers/food/snacks/slice/xenomeatbread/filled
	filled = TRUE

/obj/item/reagent_containers/food/snacks/sliceable/bananabread
	name = "Banana-nut bread"
	desc = "A heavenly and filling treat."
	icon_state = "bananabread"
	slice_path = /obj/item/reagent_containers/food/snacks/slice/bananabread
	slices_num = 5
	filling_color = "#EDE5AD"
	center_of_mass_x = 16
	center_of_mass_y = 9
	nutriment_desc = list("bread" = 10)
	nutriment_amt = 10
	bitesize = 2

/obj/item/reagent_containers/food/snacks/sliceable/bananabread/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_BANANA, 20)

/obj/item/reagent_containers/food/snacks/slice/bananabread
	name = "Banana-nut bread slice"
	desc = "A slice of delicious banana bread."
	icon_state = "bananabreadslice"
	filling_color = "#EDE5AD"
	bitesize = 2
	center_of_mass_x = 16
	center_of_mass_y = 8
	whole_path = /obj/item/reagent_containers/food/snacks/sliceable/bananabread

/obj/item/reagent_containers/food/snacks/slice/bananabread/filled
	filled = TRUE

/obj/item/reagent_containers/food/snacks/sliceable/tofubread
	name = "Tofubread"
	icon_state = "Like meatbread but for vegetarians. Not guaranteed to give superpowers."
	icon_state = "tofubread"
	slice_path = /obj/item/reagent_containers/food/snacks/slice/tofubread
	slices_num = 5
	filling_color = "#F7FFE0"
	center_of_mass_x = 16
	center_of_mass_y = 9
	nutriment_desc = list(REAGENT_ID_TOFU = 10)
	nutriment_amt = 10
	bitesize = 2

/obj/item/reagent_containers/food/snacks/slice/tofubread
	name = "Tofubread slice"
	desc = "A slice of delicious tofubread."
	icon_state = "tofubreadslice"
	filling_color = "#F7FFE0"
	bitesize = 2
	center_of_mass_x = 16
	center_of_mass_y = 13
	whole_path = /obj/item/reagent_containers/food/snacks/sliceable/tofubread

/obj/item/reagent_containers/food/snacks/slice/tofubread/filled
	filled = TRUE


/obj/item/reagent_containers/food/snacks/slice/bread
	name = "Bread slice"
	desc = "A slice of home."
	icon_state = "breadslice"
	filling_color = "#D27332"
	bitesize = 2
	center_of_mass_x = 16
	center_of_mass_y = 4
	whole_path = /obj/item/reagent_containers/food/snacks/sliceable/bread

/obj/item/reagent_containers/food/snacks/slice/bread/filled
	filled = TRUE


/obj/item/reagent_containers/food/snacks/sliceable/creamcheesebread
	name = "Cream Cheese Bread"
	desc = "Yum yum yum!"
	icon_state = "creamcheesebread"
	slice_path = /obj/item/reagent_containers/food/snacks/slice/creamcheesebread
	slices_num = 5
	filling_color = "#FFF896"
	center_of_mass_x = 16
	center_of_mass_y = 9
	nutriment_desc = list("bread" = 6, REAGENT_ID_CREAM = 3, REAGENT_ID_CHEESE = 3)
	nutriment_amt = 5
	bitesize = 2

/obj/item/reagent_containers/food/snacks/sliceable/creamcheesebread/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 15)

/obj/item/reagent_containers/food/snacks/slice/creamcheesebread
	name = "Cream Cheese Bread slice"
	desc = "A slice of yum!"
	icon_state = "creamcheesebreadslice"
	filling_color = "#FFF896"
	bitesize = 2
	center_of_mass_x = 16
	center_of_mass_y = 14
	whole_path = /obj/item/reagent_containers/food/snacks/sliceable/creamcheesebread

/obj/item/reagent_containers/food/snacks/slice/creamcheesebread/filled
	filled = TRUE

/obj/item/reagent_containers/food/snacks/sliceable/carrotcake
	name = "Carrot Cake"
	desc = "A favorite desert of a certain wascally wabbit. Not a lie."
	icon_state = "carrotcake"
	slice_path = /obj/item/reagent_containers/food/snacks/slice/carrotcake
	slices_num = 5
	filling_color = "#FFD675"
	center_of_mass_x = 16
	center_of_mass_y = 10
	nutriment_desc = list("cake" = 10, "sweetness" = 10, PLANT_CARROT = 15)
	nutriment_amt = 25
	bitesize = 2

/obj/item/reagent_containers/food/snacks/sliceable/carrotcake/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_IMIDAZOLINE, 10)

/obj/item/reagent_containers/food/snacks/slice/carrotcake
	name = "Carrot Cake slice"
	desc = "Carrotty slice of Carrot Cake, carrots are good for your eyes! Also not a lie."
	icon_state = "carrotcake_slice"
	trash = /obj/item/trash/plate
	filling_color = "#FFD675"
	bitesize = 2
	center_of_mass_x = 16
	center_of_mass_y = 14
	whole_path = /obj/item/reagent_containers/food/snacks/sliceable/carrotcake

/obj/item/reagent_containers/food/snacks/slice/carrotcake/filled
	filled = TRUE

/obj/item/reagent_containers/food/snacks/sliceable/braincake
	name = "Brain Cake"
	desc = "A squishy cake-thing."
	icon_state = "braincake"
	slice_path = /obj/item/reagent_containers/food/snacks/slice/braincake
	slices_num = 5
	filling_color = "#E6AEDB"
	center_of_mass_x = 16
	center_of_mass_y = 10
	nutriment_desc = list("cake" = 10, "sweetness" = 10, "slime" = 15)
	nutriment_amt = 5
	bitesize = 2

/obj/item/reagent_containers/food/snacks/sliceable/braincake/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 25)
	reagents.add_reagent(REAGENT_ID_ALKYSINE, 10)

/obj/item/reagent_containers/food/snacks/slice/braincake
	name = "Brain Cake slice"
	desc = "Lemme tell you something about prions. THEY'RE DELICIOUS."
	icon_state = "braincakeslice"
	trash = /obj/item/trash/plate
	filling_color = "#E6AEDB"
	bitesize = 2
	center_of_mass_x = 16
	center_of_mass_y = 12
	whole_path = /obj/item/reagent_containers/food/snacks/sliceable/braincake

/obj/item/reagent_containers/food/snacks/slice/braincake/filled
	filled = TRUE

/obj/item/reagent_containers/food/snacks/sliceable/cheesecake
	name = "Cheese Cake"
	desc = "DANGEROUSLY cheesy."
	icon_state = "cheesecake"
	slice_path = /obj/item/reagent_containers/food/snacks/slice/cheesecake
	slices_num = 5
	filling_color = "#FAF7AF"
	center_of_mass_x = 16
	center_of_mass_y = 10
	nutriment_desc = list("cake" = 10, REAGENT_ID_CREAM = 10, REAGENT_ID_CHEESE = 15)
	nutriment_amt = 10
	bitesize = 2

/obj/item/reagent_containers/food/snacks/sliceable/cheesecake/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 15)

/obj/item/reagent_containers/food/snacks/slice/cheesecake
	name = "Cheese Cake slice"
	desc = "Slice of pure cheestisfaction."
	icon_state = "cheesecake_slice"
	trash = /obj/item/trash/plate
	filling_color = "#FAF7AF"
	bitesize = 2
	center_of_mass_x = 16
	center_of_mass_y = 14
	whole_path = /obj/item/reagent_containers/food/snacks/sliceable/cheesecake

/obj/item/reagent_containers/food/snacks/slice/cheesecake/filled
	filled = TRUE

/obj/item/reagent_containers/food/snacks/sliceable/peanutcake
	name = "Peanut Cake"
	desc = "DANGEROUSLY nutty. Sometimes literally."
	icon_state = "peanutcake"
	slice_path = /obj/item/reagent_containers/food/snacks/slice/peanutcake
	slices_num = 5
	filling_color = "#4F3500"
	center_of_mass_x = 16
	center_of_mass_y = 10
	nutriment_desc = list("cake" = 10, "peanuts" = 15)
	nutriment_amt = 10
	bitesize = 2

/obj/item/reagent_containers/food/snacks/sliceable/peanutcake/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 5)

/obj/item/reagent_containers/food/snacks/slice/peanutcake
	name = "Peanut Cake slice"
	desc = "Slice of nutty goodness."
	icon_state = "peanutcake_slice"
	trash = /obj/item/trash/plate
	filling_color = "#4F3500"
	bitesize = 2
	center_of_mass_x = 16
	center_of_mass_y = 14
	whole_path = /obj/item/reagent_containers/food/snacks/sliceable/peanutcake

/obj/item/reagent_containers/food/snacks/slice/peanutcake/filled
	filled = TRUE

/obj/item/reagent_containers/food/snacks/sliceable/plaincake
	name = "Vanilla Cake"
	desc = "A plain cake, not a lie."
	icon_state = "plaincake"
	slice_path = /obj/item/reagent_containers/food/snacks/slice/plaincake
	slices_num = 5
	filling_color = "#F7EDD5"
	center_of_mass_x = 16
	center_of_mass_y = 10
	nutriment_desc = list("cake" = 10, "sweetness" = 10, REAGENT_ID_VANILLA = 15)
	nutriment_amt = 20

/obj/item/reagent_containers/food/snacks/slice/plaincake
	name = "Vanilla Cake slice"
	desc = "Just a slice of cake, it is enough for everyone."
	icon_state = "plaincake_slice"
	trash = /obj/item/trash/plate
	filling_color = "#F7EDD5"
	bitesize = 2
	center_of_mass_x = 16
	center_of_mass_y = 14
	whole_path = /obj/item/reagent_containers/food/snacks/sliceable/plaincake

/obj/item/reagent_containers/food/snacks/slice/plaincake/filled
	filled = TRUE

/obj/item/reagent_containers/food/snacks/sliceable/orangecake
	name = "Orange Cake"
	desc = "A cake with added orange."
	icon_state = "orangecake"
	slice_path = /obj/item/reagent_containers/food/snacks/slice/orangecake
	slices_num = 5
	filling_color = "#FADA8E"
	center_of_mass_x = 16
	center_of_mass_y = 10
	nutriment_desc = list("cake" = 10, "sweetness" = 10, PLANT_ORANGE = 15)
	nutriment_amt = 20

/obj/item/reagent_containers/food/snacks/slice/orangecake
	name = "Orange Cake slice"
	desc = "Just a slice of cake, it is enough for everyone."
	icon_state = "orangecake_slice"
	trash = /obj/item/trash/plate
	filling_color = "#FADA8E"
	bitesize = 2
	center_of_mass_x = 16
	center_of_mass_y = 14
	whole_path = /obj/item/reagent_containers/food/snacks/sliceable/orangecake

/obj/item/reagent_containers/food/snacks/slice/orangecake/filled
	filled = TRUE

/obj/item/reagent_containers/food/snacks/sliceable/limecake
	name = "Lime Cake"
	desc = "A cake with added lime."
	icon_state = "limecake"
	slice_path = /obj/item/reagent_containers/food/snacks/slice/limecake
	slices_num = 5
	filling_color = "#CBFA8E"
	center_of_mass_x = 16
	center_of_mass_y = 10
	nutriment_desc = list("cake" = 10, "sweetness" = 10, PLANT_LIME = 15)
	nutriment_amt = 20

/obj/item/reagent_containers/food/snacks/slice/limecake
	name = "Lime Cake slice"
	desc = "Just a slice of cake, it is enough for everyone."
	icon_state = "limecake_slice"
	trash = /obj/item/trash/plate
	filling_color = "#CBFA8E"
	bitesize = 2
	center_of_mass_x = 16
	center_of_mass_y = 14
	whole_path = /obj/item/reagent_containers/food/snacks/sliceable/limecake

/obj/item/reagent_containers/food/snacks/slice/limecake/filled
	filled = TRUE

/obj/item/reagent_containers/food/snacks/sliceable/lemoncake
	name = "Lemon Cake"
	desc = "A cake with added lemon."
	icon_state = "lemoncake"
	slice_path = /obj/item/reagent_containers/food/snacks/slice/lemoncake
	slices_num = 5
	filling_color = "#FAFA8E"
	center_of_mass_x = 16
	center_of_mass_y = 10
	nutriment_desc = list("cake" = 10, "sweetness" = 10, PLANT_LEMON = 15)
	nutriment_amt = 20


/obj/item/reagent_containers/food/snacks/slice/lemoncake
	name = "Lemon Cake slice"
	desc = "Just a slice of cake, it is enough for everyone."
	icon_state = "lemoncake_slice"
	trash = /obj/item/trash/plate
	filling_color = "#FAFA8E"
	bitesize = 2
	center_of_mass_x = 16
	center_of_mass_y = 14
	whole_path = /obj/item/reagent_containers/food/snacks/sliceable/lemoncake

/obj/item/reagent_containers/food/snacks/slice/lemoncake/filled
	filled = TRUE

/obj/item/reagent_containers/food/snacks/sliceable/chocolatecake
	name = "Chocolate Cake"
	desc = "A cake with added chocolate."
	icon_state = "chocolatecake"
	slice_path = /obj/item/reagent_containers/food/snacks/slice/chocolatecake
	slices_num = 5
	filling_color = "#805930"
	center_of_mass_x = 16
	center_of_mass_y = 10
	nutriment_desc = list("cake" = 10, "sweetness" = 10, REAGENT_ID_CHOCOLATE = 15)
	nutriment_amt = 20

/obj/item/reagent_containers/food/snacks/slice/chocolatecake
	name = "Chocolate Cake slice"
	desc = "Just a slice of cake, it is enough for everyone."
	icon_state = "chocolatecake_slice"
	trash = /obj/item/trash/plate
	filling_color = "#805930"
	bitesize = 2
	center_of_mass_x = 16
	center_of_mass_y = 14
	whole_path = /obj/item/reagent_containers/food/snacks/sliceable/chocolatecake

/obj/item/reagent_containers/food/snacks/slice/chocolatecake/filled
	filled = TRUE

/obj/item/reagent_containers/food/snacks/sliceable/cheesewheel
	name = "Cheese wheel"
	desc = "A big wheel of delcious Cheddar."
	icon_state = "cheesewheel"
	slice_path = /obj/item/reagent_containers/food/snacks/cheesewedge
	slices_num = 5
	filling_color = "#FFF700"
	center_of_mass_x = 16
	center_of_mass_y = 10
	nutriment_desc = list(REAGENT_ID_CHEESE = 10)
	nutriment_amt = 10
	bitesize = 2

/obj/item/reagent_containers/food/snacks/sliceable/cheesewheel/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 10)

/obj/item/reagent_containers/food/snacks/cheesewedge
	name = "Cheese wedge"
	desc = "A wedge of delicious Cheddar. The cheese wheel it was cut from can't have gone far."
	icon_state = "cheesewedge"
	filling_color = "#FFF700"
	bitesize = 2
	center_of_mass_x = 16
	center_of_mass_y = 10

/obj/item/reagent_containers/food/snacks/sliceable/birthdaycake
	name = "Birthday Cake"
	desc = "Happy Birthday..."
	icon_state = "birthdaycake"
	slice_path = /obj/item/reagent_containers/food/snacks/slice/birthdaycake
	slices_num = 5
	filling_color = "#FFD6D6"
	center_of_mass_x = 16
	center_of_mass_y = 10
	nutriment_desc = list("cake" = 10, "sweetness" = 10)
	nutriment_amt = 20
	bitesize = 3

/obj/item/reagent_containers/food/snacks/sliceable/birthdaycake/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_SPRINKLES, 10)

/obj/item/reagent_containers/food/snacks/slice/birthdaycake
	name = "Birthday Cake slice"
	desc = "A slice of your birthday."
	icon_state = "birthdaycakeslice"
	trash = /obj/item/trash/plate
	filling_color = "#FFD6D6"
	bitesize = 2
	center_of_mass_x = 16
	center_of_mass_y = 14
	whole_path = /obj/item/reagent_containers/food/snacks/sliceable/birthdaycake

/obj/item/reagent_containers/food/snacks/slice/birthdaycake/filled
	filled = TRUE

/obj/item/reagent_containers/food/snacks/sliceable/bread
	name = "Bread"
	icon_state = "Some plain old Earthen bread."
	icon_state = "bread"
	slice_path = /obj/item/reagent_containers/food/snacks/slice/bread
	slices_num = 5
	filling_color = "#FFE396"
	center_of_mass_x = 16
	center_of_mass_y = 9
	nutriment_desc = list("bread" = 6)
	nutriment_amt = 6
	bitesize = 2

/obj/item/reagent_containers/food/snacks/watermelonslice
	name = "Watermelon Slice"
	desc = "A slice of watery goodness."
	icon_state = "watermelonslice"
	filling_color = "#FF3867"
	bitesize = 2
	center_of_mass_x = 16
	center_of_mass_y = 10

/obj/item/reagent_containers/food/snacks/sliceable/applecake
	name = "Apple Cake"
	desc = "A cake centred with apples."
	icon_state = "applecake"
	slice_path = /obj/item/reagent_containers/food/snacks/slice/applecake
	slices_num = 5
	filling_color = "#EBF5B8"
	center_of_mass_x = 16
	center_of_mass_y = 10
	nutriment_desc = list("cake" = 10, "sweetness" = 10, PLANT_APPLE = 15)
	nutriment_amt = 15

/obj/item/reagent_containers/food/snacks/slice/applecake
	name = "Apple Cake slice"
	desc = "A slice of heavenly cake."
	icon_state = "applecakeslice"
	trash = /obj/item/trash/plate
	filling_color = "#EBF5B8"
	bitesize = 2
	center_of_mass_x = 16
	center_of_mass_y = 14
	whole_path = /obj/item/reagent_containers/food/snacks/sliceable/applecake

/obj/item/reagent_containers/food/snacks/slice/applecake/filled
	filled = TRUE

/obj/item/reagent_containers/food/snacks/sliceable/pumpkinpie
	name = "Pumpkin Pie"
	desc = "A delicious treat for the autumn months."
	icon_state = "pumpkinpie"
	slice_path = /obj/item/reagent_containers/food/snacks/slice/pumpkinpie
	slices_num = 5
	filling_color = "#F5B951"
	center_of_mass_x = 16
	center_of_mass_y = 10
	nutriment_desc = list("pie" = 5, REAGENT_ID_CREAM = 5, PLANT_PUMPKIN = 5)
	nutriment_amt = 15

/obj/item/reagent_containers/food/snacks/slice/pumpkinpie
	name = "Pumpkin Pie slice"
	desc = "A slice of pumpkin pie, with whipped cream on top. Perfection."
	icon_state = "pumpkinpieslice"
	trash = /obj/item/trash/plate
	filling_color = "#F5B951"
	bitesize = 2
	center_of_mass_x = 16
	center_of_mass_y = 12
	whole_path = /obj/item/reagent_containers/food/snacks/sliceable/pumpkinpie

/obj/item/reagent_containers/food/snacks/slice/pumpkinpie/filled
	filled = TRUE

/obj/item/reagent_containers/food/snacks/cracker
	name = "Cracker"
	desc = "It's a salted cracker."
	icon_state = "cracker"
	filling_color = "#F5DEB8"
	center_of_mass_x = 16
	center_of_mass_y = 6
	nutriment_desc = list("salt" = 1, "cracker" = 2)
	w_class = ITEMSIZE_TINY
	nutriment_amt = 1

/obj/item/reagent_containers/food/snacks/sliceable/grilled_carp
	name = "Njarir Merana Grill"
	desc = "A well-dressed fish, seared to perfection and adorned with herbs and spices in a traditional Nerahni Tajaran style. Can be sliced into proper serving sizes."
	icon_state = "grilled_carp"
	slice_path = /obj/item/reagent_containers/food/snacks/grilled_carp_slice
	slices_num = 6
	trash = /obj/item/trash/snacktray

/obj/item/reagent_containers/food/snacks/sliceable/grilled_carp/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_SEAFOOD, 12)

/obj/item/reagent_containers/food/snacks/grilled_carp_slice
	name = "korlaaskak slice"
	desc = "A well-dressed fillet of carp, seared to perfection and adorned with herbs and spices."
	icon_state = "grilledcarp_slice"
	trash = /obj/item/trash/plate

/obj/item/reagent_containers/food/snacks/sliceable/keylimepie
	name = "key lime pie"
	desc = "A tart, sweet dessert. What's a key lime, anyway?"
	icon_state = "keylimepie"
	slice_path = /obj/item/reagent_containers/food/snacks/keylimepieslice
	slices_num = 5
	filling_color = "#F5B951"
	nutriment_amt = 16
	nutriment_desc = list(PLANT_LIME = 12, "graham crackers" = 4)
	center_of_mass_x = 16
	center_of_mass_y = 10

/obj/item/reagent_containers/food/snacks/sliceable/keylimepie/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 4)

/obj/item/reagent_containers/food/snacks/keylimepieslice
	name = "slice of key lime pie"
	desc = "A slice of tart pie, with whipped cream on top."
	icon_state = "keylimepieslice"
	trash = /obj/item/trash/plate
	filling_color = "#F5B951"
	bitesize = 3
	nutriment_desc = list(PLANT_LIME = 1)
	center_of_mass_x = 16
	center_of_mass_y = 12

/obj/item/reagent_containers/food/snacks/keylimepieslice/filled
	nutriment_amt = 1

/obj/item/reagent_containers/food/snacks/sliceable/quiche
	name = "quiche"
	desc = "Real men eat this, contrary to popular belief."
	icon_state = "quiche"
	slice_path = /obj/item/reagent_containers/food/snacks/quicheslice
	slices_num = 5
	filling_color = "#F5B951"
	nutriment_amt = 10
	nutriment_desc = list(REAGENT_ID_CHEESE = 5, REAGENT_ID_EGG = 5)
	center_of_mass_x = 16
	center_of_mass_y = 10

/obj/item/reagent_containers/food/snacks/sliceable/quiche/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 10)

/obj/item/reagent_containers/food/snacks/quicheslice
	name = "slice of quiche"
	desc = "A slice of delicious quiche. Eggy, cheesy goodness."
	icon_state = "quicheslice"
	trash = /obj/item/trash/plate
	filling_color = "#F5B951"
	bitesize = 3
	nutriment_desc = list("cheesy eggs" = 1)
	center_of_mass_x = 16
	center_of_mass_y = 12

/obj/item/reagent_containers/food/snacks/quicheslice/filled
	nutriment_amt = 1

/obj/item/reagent_containers/food/snacks/quicheslice/filled/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 1)

/obj/item/reagent_containers/food/snacks/sliceable/brownies
	name = "brownies"
	gender = PLURAL
	desc = "Halfway to fudge, or halfway to cake? Who cares!"
	icon_state = "brownies"
	slice_path = /obj/item/reagent_containers/food/snacks/browniesslice
	slices_num = 4
	trash = /obj/item/trash/brownies
	filling_color = "#301301"
	nutriment_amt = 8
	nutriment_desc = list("fudge" = 8)
	center_of_mass_x = 15
	center_of_mass_y = 9
	bitesize = 2

/obj/item/reagent_containers/food/snacks/sliceable/brownies/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 2)

/obj/item/reagent_containers/food/snacks/browniesslice
	name = "brownie"
	desc = "a dense, decadent chocolate brownie."
	icon_state = "browniesslice"
	trash = /obj/item/trash/plate
	filling_color = "#F5B951"
	bitesize = 2
	nutriment_desc = list("fudge" = 1)
	center_of_mass_x = 16
	center_of_mass_y = 12

/obj/item/reagent_containers/food/snacks/browniesslice/filled
	nutriment_amt = 1

/obj/item/reagent_containers/food/snacks/browniesslice/filled/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 1)

/obj/item/reagent_containers/food/snacks/sliceable/cosmicbrownies
	name = "cosmic brownies"
	gender = PLURAL
	desc = "Like, ultra-trippy. Brownies HAVE no gender, man." //Except I had to add one!
	icon_state = "cosmicbrownies"
	slice_path = /obj/item/reagent_containers/food/snacks/cosmicbrowniesslice
	slices_num = 4
	trash = /obj/item/trash/brownies
	filling_color = "#301301"
	nutriment_amt = 8
	nutriment_desc = list("fudge" = 8)
	center_of_mass_x = 15
	center_of_mass_y = 9
	bitesize = 3

/obj/item/reagent_containers/food/snacks/sliceable/cosmicbrownies/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 2)
	reagents.add_reagent(REAGENT_ID_AMBROSIAEXTRACT, 2)
	reagents.add_reagent(REAGENT_ID_BICARIDINE, 1)
	reagents.add_reagent(REAGENT_ID_KELOTANE, 1)
	reagents.add_reagent(REAGENT_ID_TOXIN, 1)

/obj/item/reagent_containers/food/snacks/cosmicbrowniesslice
	name = "cosmic brownie"
	desc = "a dense, decadent and fun-looking chocolate brownie."
	icon_state = "cosmicbrowniesslice"
	trash = /obj/item/trash/plate
	filling_color = "#F5B951"
	bitesize = 3
	nutriment_desc = list("fudge" = 1)
	center_of_mass_x = 16
	center_of_mass_y = 12

/obj/item/reagent_containers/food/snacks/cosmicbrowniesslice/filled
	nutriment_amt = 1

/obj/item/reagent_containers/food/snacks/cosmicbrowniesslice/filled/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 1)

/obj/item/reagent_containers/food/snacks/lasagna
	name = "lasagna"
	desc = "Meaty, tomato-y, and ready to eat-y. Favorite of cats."
	icon = 'icons/obj/food.dmi'
	icon_state = "lasagna"
	nutriment_amt = 5
	nutriment_desc = list(PLANT_TOMATO = 4, "meat" = 2)

/obj/item/reagent_containers/food/snacks/lasagna/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 2) //For meaty things.

/obj/item/reagent_containers/food/snacks/gigapuddi
	name = "Astro-Pudding"
	desc = "A crème caramel of astronomical size."
	icon = 'icons/obj/food.dmi'
	icon_state = "gigapuddi"
	nutriment_amt = 20
	nutriment_desc = list("caramel" = 20)
	bitesize = 2
	trash = /obj/item/trash/plate

/obj/item/reagent_containers/food/snacks/gigapuddi/happy
	name = "Astro-Pudding (Happy)"
	desc = "A crème caramel of astronomical size, made with extra love."
	icon = 'icons/obj/food.dmi'
	icon_state = "happypuddi"

/obj/item/reagent_containers/food/snacks/gigapuddi/anger
	name = "Astro-Pudding (Angry)"
	desc = "A crème caramel of astronomical size, made with extra hate."
	icon_state = "angerpuddi"

/obj/item/reagent_containers/food/snacks/sliceable/buchedenoel
	name = "\improper Buche de Noel"
	desc = "Yule love it!"
	icon = 'icons/obj/food.dmi'
	icon_state = "buche"
	slice_path = /obj/item/reagent_containers/food/snacks/bucheslice
	slices_num = 5
	w_class = 2
	nutriment_amt = 20
	nutriment_desc = list("spongy cake" = 20)
	bitesize = 3
	trash = /obj/item/trash/tray

/obj/item/reagent_containers/food/snacks/sliceable/buchedenoel/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_SUGAR, 9)
	reagents.add_reagent(REAGENT_ID_COCO, 5)

/obj/item/reagent_containers/food/snacks/bucheslice
	name = "\improper Buche de Noel slice"
	desc = "A slice of winter magic."
	icon = 'icons/obj/food.dmi'
	icon_state = "buche_slice"
	trash = /obj/item/trash/plate
	bitesize = 2

/* OLD RECIPE
/obj/item/reagent_containers/food/snacks/sliceable/turkey
	name = "turkey"
	desc = "Tastes like chicken."
	icon = 'icons/obj/food.dmi'
	icon_state = "turkey"
	slice_path = /obj/item/reagent_containers/food/snacks/turkeyslice
	slices_num = 6
	w_class = 2
	nutriment_amt = 20
	nutriment_desc = list("turkey" = 20)
	bitesize = 5
	trash = /obj/item/trash/tray

/obj/item/reagent_containers/food/snacks/sliceable/turkey/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_BLACKPEPPER, 1)
	reagents.add_reagent(REAGENT_ID_SODIUMCHLORIDE, 1)
	reagents.add_reagent(REAGENT_ID_COOKINGOIL, 1)

/obj/item/reagent_containers/food/snacks/turkeyslice
	name = "turkey drumstick"
	desc = "Forsooth!"
	icon = 'icons/obj/food.dmi'
	icon_state = "turkey_drumstick"
	trash = /obj/item/trash/plate
	bitesize = 2
*/

/obj/item/reagent_containers/food/snacks/sliceable/turkey
	name = "turkey"
	desc = "Tastes like chicken."
	icon = 'icons/obj/food.dmi'
	icon_state = "roastturkey"
	slice_path = /obj/item/reagent_containers/food/snacks/turkeyslice
	slices_num = 6
	w_class = 2
	nutriment_amt = 20
	nutriment_desc = list("turkey" = 20)
	bitesize = 5
	trash = /obj/item/trash/turkeybones
	var/list/extra_product = list(/obj/item/reagent_containers/food/snacks/turkeydrumstick = 2,
									/obj/item/trash/turkeybones = 1)

/obj/item/reagent_containers/food/snacks/sliceable/turkey/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_BLACKPEPPER, 1)
	reagents.add_reagent(REAGENT_ID_SODIUMCHLORIDE, 1)
	reagents.add_reagent(REAGENT_ID_COOKINGOIL, 1)

/obj/item/reagent_containers/food/snacks/sliceable/turkey/on_slice_extra()
	for(var/i in extra_product)
		for(var/j=1 to extra_product[i])
			new i(src.loc)

/obj/item/reagent_containers/food/snacks/turkeyslice
	name = "turkey'n'mash"
	desc = "Turkey slices with some delicious stuffing."
	icon = 'icons/obj/food.dmi'
	icon_state = "roastturkeynmash"
	trash = /obj/item/trash/plate
	bitesize = 2

/obj/item/reagent_containers/food/snacks/turkeydrumstick
	name = "turkey drumstick"
	desc = "The best part!"
	icon = 'icons/obj/food.dmi'
	icon_state = "roastturkeydrumstick"
	trash = null
	nutriment_amt = 8
	nutriment_desc = list("turkey" = 20)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/sliceable/suppermatter
	name = "suppermatter"
	desc = "Extremely dense and powerful food."
	slice_path = /obj/item/reagent_containers/food/snacks/suppermattershard
	slices_num = 10
	icon = 'icons/obj/food.dmi'
	icon_state = "suppermatter"
	nutriment_amt = 48
	nutriment_desc = list("pure power" = 48)
	bitesize = 12
	w_class = 2

/obj/item/reagent_containers/food/snacks/sliceable/suppermatter/Initialize(mapload)
	. = ..()
	set_light(1.4,2,"#FFFF00")

/obj/item/reagent_containers/food/snacks/suppermattershard
	name = "suppermatter shard"
	desc = "A single portion of power."
	icon = 'icons/obj/food.dmi'
	icon_state = "suppermattershard"
	bitesize = 3
	trash = null

/obj/item/reagent_containers/food/snacks/suppermattershard/Initialize(mapload)
	. = ..()
	set_light(1.4,1.4,"#FFFF00")

/obj/item/reagent_containers/food/snacks/sliceable/excitingsuppermatter
	name = "exciting suppermatter"
	desc = "Extremely dense, powerful and exciting food!"
	slice_path = /obj/item/reagent_containers/food/snacks/excitingsuppermattershard
	slices_num = 10
	icon = 'icons/obj/food.dmi'
	icon_state = "excitingsuppermatter"
	nutriment_amt = 60
	nutriment_desc = list("pure, indescribable power" = 60)
	bitesize = 12
	w_class = 2

/obj/item/reagent_containers/food/snacks/sliceable/excitingsuppermatter/Initialize(mapload)
	. = ..()
	set_light(1.4,2,"#FF0000")

/obj/item/reagent_containers/food/snacks/excitingsuppermattershard
	name = "exciting suppermatter shard"
	desc = "A single portion of exciting power!"
	icon = 'icons/obj/food.dmi'
	icon_state = "excitingsuppermattershard"
	bitesize = 4
	trash = null

/obj/item/reagent_containers/food/snacks/excitingsuppermattershard/Initialize(mapload)
	. = ..()
	set_light(1.4,1.4,"#FF0000")

/////////////////////////////////////////////////PIZZA/////////////////////////////////////////////////

/obj/item/reagent_containers/food/snacks/sliceable/pizza
	slices_num = 6
	filling_color = "#BAA14C"

/obj/item/reagent_containers/food/snacks/sliceable/pizza/margherita
	name = "Margherita"
	desc = "The golden standard of pizzas."
	icon_state = "pizzamargherita"
	slice_path = /obj/item/reagent_containers/food/snacks/slice/margherita
	slices_num = 6
	center_of_mass_x = 16
	center_of_mass_y = 11
	nutriment_desc = list("pizza crust" = 10, PLANT_TOMATO = 10, REAGENT_ID_CHEESE = 15)
	nutriment_amt = 35
	bitesize = 2

/obj/item/reagent_containers/food/snacks/sliceable/pizza/margherita/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 5)
	reagents.add_reagent(REAGENT_ID_TOMATOJUICE, 6)

/obj/item/reagent_containers/food/snacks/slice/margherita
	name = "Margherita slice"
	desc = "A slice of the classic pizza."
	icon_state = "pizzamargheritaslice"
	filling_color = "#BAA14C"
	bitesize = 2
	center_of_mass_x = 16
	center_of_mass_y = 13
	whole_path = /obj/item/reagent_containers/food/snacks/sliceable/pizza/margherita

/obj/item/reagent_containers/food/snacks/slice/margherita/filled
	filled = TRUE

/obj/item/reagent_containers/food/snacks/sliceable/pizza/pineapple
	name = "ham & pineapple pizza"
	desc = "One of the most debated pizzas in existence."
	icon_state = "pineapple_pizza"
	slice_path = /obj/item/reagent_containers/food/snacks/pineappleslice
	slices_num = 6
	center_of_mass_x = 16
	center_of_mass_y = 11
	nutriment_desc = list("pizza crust" = 10, PLANT_TOMATO = 10, "ham" = 10)
	nutriment_amt = 30
	bitesize = 2

/obj/item/reagent_containers/food/snacks/sliceable/pizza/pineapple/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 4)
	reagents.add_reagent(REAGENT_ID_CHEESE, 5)
	reagents.add_reagent(REAGENT_ID_TOMATOJUICE, 6)

/obj/item/reagent_containers/food/snacks/pineappleslice
	name = "ham & pineapple pizza slice"
	desc = "A slice of contraband."
	icon_state = "pineapple_pizza_slice"
	filling_color = "#BAA14C"
	bitesize = 2
	center_of_mass_x = 18
	center_of_mass_y = 13

/obj/item/reagent_containers/food/snacks/pineappleslice/filled
	nutriment_desc = list("pizza crust" = 5, PLANT_TOMATO = 5)
	nutriment_amt = 5

/obj/item/reagent_containers/food/snacks/sliceable/pizza/meatpizza
	name = "Meatpizza"
	desc = "A pizza with meat topping."
	icon_state = "meatpizza"
	slice_path = /obj/item/reagent_containers/food/snacks/slice/meatpizza
	slices_num = 6
	center_of_mass_x = 16
	center_of_mass_y = 11
	nutriment_desc = list("pizza crust" = 10, PLANT_TOMATO = 10, REAGENT_ID_CHEESE = 15, "meat" = 10)
	nutriment_amt = 10
	bitesize = 2

/obj/item/reagent_containers/food/snacks/sliceable/pizza/meatpizza/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 34)
	reagents.add_reagent(REAGENT_ID_TOMATOJUICE, 6)

/obj/item/reagent_containers/food/snacks/slice/meatpizza
	name = "Meatpizza slice"
	desc = "A slice of a meaty pizza."
	icon_state = "meatpizzaslice"
	filling_color = "#BAA14C"
	bitesize = 2
	center_of_mass_x = 16
	center_of_mass_y = 13
	whole_path = /obj/item/reagent_containers/food/snacks/sliceable/pizza/meatpizza

/obj/item/reagent_containers/food/snacks/slice/meatpizza/filled
	filled = TRUE

/obj/item/reagent_containers/food/snacks/sliceable/pizza/mushroompizza
	name = "Mushroompizza"
	desc = "Very special pizza."
	icon_state = "mushroompizza"
	slice_path = /obj/item/reagent_containers/food/snacks/slice/mushroompizza
	slices_num = 6
	center_of_mass_x = 16
	center_of_mass_y = 11
	nutriment_desc = list("pizza crust" = 10, PLANT_TOMATO = 10, REAGENT_ID_CHEESE = 5, PLANT_MUSHROOMS = 10)
	nutriment_amt = 35
	bitesize = 2

/obj/item/reagent_containers/food/snacks/sliceable/pizza/mushroompizza/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 5)

/obj/item/reagent_containers/food/snacks/slice/mushroompizza
	name = "Mushroompizza slice"
	desc = "Maybe it is the last slice of pizza in your life."
	icon_state = "mushroompizzaslice"
	filling_color = "#BAA14C"
	bitesize = 2
	center_of_mass_x = 16
	center_of_mass_y = 13
	whole_path = /obj/item/reagent_containers/food/snacks/sliceable/pizza/mushroompizza

/obj/item/reagent_containers/food/snacks/slice/mushroompizza/filled
	filled = TRUE

/obj/item/reagent_containers/food/snacks/sliceable/pizza/vegetablepizza
	name = "Vegetable pizza"
	desc = "No one of Tomato Sapiens were harmed during making this pizza."
	icon_state = "vegetablepizza"
	slice_path = /obj/item/reagent_containers/food/snacks/slice/vegetablepizza
	slices_num = 6
	center_of_mass_x = 16
	center_of_mass_y = 11
	nutriment_desc = list("pizza crust" = 10, PLANT_TOMATO = 10, REAGENT_ID_CHEESE = 5, PLANT_EGGPLANT = 5, PLANT_CARROT = 5, PLANT_CORN = 5)
	nutriment_amt = 25
	bitesize = 2

/obj/item/reagent_containers/food/snacks/sliceable/pizza/vegetablepizza/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 5)
	reagents.add_reagent(REAGENT_ID_TOMATOJUICE, 6)
	reagents.add_reagent(REAGENT_ID_IMIDAZOLINE, 12)

/obj/item/reagent_containers/food/snacks/slice/vegetablepizza
	name = "Vegetable pizza slice"
	desc = "A slice of the most green pizza of all pizzas not containing green ingredients."
	icon_state = "vegetablepizzaslice"
	filling_color = "#BAA14C"
	bitesize = 2
	center_of_mass_x = 16
	center_of_mass_y = 13
	whole_path = /obj/item/reagent_containers/food/snacks/sliceable/pizza/vegetablepizza

/obj/item/reagent_containers/food/snacks/slice/vegetablepizza/filled
	filled = TRUE

/obj/item/reagent_containers/food/snacks/sliceable/pizza/crunch
	name = "pizza crunch"
	desc = "This was once a normal pizza, but it has been coated in batter and deep-fried. Whatever toppings it once had are a mystery, but they're still under there, somewhere..."
	icon_state = "pizzacrunch"
	slice_path = /obj/item/reagent_containers/food/snacks/pizzacrunchslice
	slices_num = 6
	nutriment_amt = 25
	nutriment_desc = list("fried pizza" = 25)
	center_of_mass_x = 16
	center_of_mass_y = 11
	bitesize = 2

/obj/item/reagent_containers/food/snacks/pizzacrunchslice
	name = "pizza crunch slice"
	desc = "A little piece of a heart attack. It's toppings are a mystery, hidden under batter"
	icon_state = "pizzacrunchslice"
	filling_color = "#BAA14C"
	bitesize = 2
	center_of_mass_x = 18
	center_of_mass_y = 13

/obj/item/reagent_containers/food/snacks/sliceable/pizza/oldpizza
	name = "moldy pizza"
	desc = "This pizza might actually be alive.  There's mold all over."
	icon_state = "oldpizza"
	slice_path = /obj/item/reagent_containers/food/snacks/slice/oldpizza
	slices_num = 6
	center_of_mass_x = 16
	center_of_mass_y = 11
	nutriment_desc = list("stale pizza crust" = 10, "moldy tomato" = 10, "moldy cheese" = 5)
	nutriment_amt = 10
	bitesize = 2

/obj/item/reagent_containers/food/snacks/sliceable/pizza/oldpizza/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 5)
	reagents.add_reagent(REAGENT_ID_TOMATOJUICE, 6)
	reagents.add_reagent(REAGENT_ID_MOLD, 8)

/obj/item/reagent_containers/food/snacks/slice/oldpizza
	name = "moldy pizza slice"
	desc = "This used to be pizza..."
	icon_state = "oldpizzaslice"
	filling_color = "#BAA14C"
	bitesize = 2
	center_of_mass_x = 16
	center_of_mass_y = 13
	whole_path = /obj/item/reagent_containers/food/snacks/sliceable/pizza/oldpizza

/obj/item/pizzabox
	name = "pizza box"
	desc = "A box suited for pizzas."
	icon = 'icons/obj/food.dmi'
	icon_state = "pizzabox1"
	center_of_mass_x = 16
	center_of_mass_y = 6

	var/open = 0 // Is the box open?
	var/ismessy = 0 // Fancy mess on the lid
	var/obj/item/reagent_containers/food/snacks/sliceable/pizza/pizza // Content pizza
	var/list/boxes = list() // If the boxes are stacked, they come here
	var/boxtag = ""

/obj/item/pizzabox/update_icon()

	cut_overlays()

	// Set appropriate description
	if( open && pizza )
		desc = "A box suited for pizzas. It appears to have a [pizza.name] inside."
	else if( boxes.len > 0 )
		desc = "A pile of boxes suited for pizzas. There appears to be [boxes.len + 1] boxes in the pile."

		var/obj/item/pizzabox/topbox = boxes[boxes.len]
		var/toptag = topbox.boxtag
		if( toptag != "" )
			desc = "[desc] The box on top has a tag, it reads: '[toptag]'."
	else
		desc = "A box suited for pizzas."

		if( boxtag != "" )
			desc = "[desc] The box has a tag, it reads: '[boxtag]'."

	// Icon states and overlays
	if( open )
		if( ismessy )
			icon_state = "pizzabox_messy"
		else
			icon_state = "pizzabox_open"

		if( pizza )
			var/image/pizzaimg = image(icon = pizza.icon, icon_state = pizza.icon_state)	//VOREStation Edit: Icons for bad pizza
			pizzaimg.pixel_y = -3
			add_overlay(pizzaimg)

		return
	else
		// Stupid code because byondcode sucks
		var/doimgtag = 0
		if( boxes.len > 0 )
			var/obj/item/pizzabox/topbox = boxes[boxes.len]
			if( topbox.boxtag != "" )
				doimgtag = 1
		else
			if( boxtag != "" )
				doimgtag = 1

		if( doimgtag )
			var/image/tagimg = image("food.dmi", icon_state = "pizzabox_tag")
			tagimg.pixel_y = boxes.len * 3
			add_overlay(tagimg)

	icon_state = "pizzabox[boxes.len+1]"

/obj/item/pizzabox/attack_hand( mob/user as mob )

	if( open && pizza )
		user.put_in_hands( pizza )

		to_chat(user, span_warning("You take \the [src.pizza] out of \the [src]."))
		src.pizza = null
		update_icon()
		return

	if( boxes.len > 0 )
		if( user.get_inactive_hand() != src )
			..()
			return

		var/obj/item/pizzabox/box = boxes[boxes.len]
		boxes -= box

		user.put_in_hands( box )
		to_chat(user, span_warning("You remove the topmost [src] from your hand."))
		box.update_icon()
		update_icon()
		return
	..()

/obj/item/pizzabox/attack_self( mob/user as mob )

	if( boxes.len > 0 )
		return

	open = !open

	if( open && pizza )
		ismessy = 1

	update_icon()

/obj/item/pizzabox/attackby( obj/item/I as obj, mob/user as mob )
	if( istype(I, /obj/item/pizzabox/) )
		var/obj/item/pizzabox/box = I

		if( !box.open && !src.open )
			// Make a list of all boxes to be added
			var/list/boxestoadd = list()
			boxestoadd += box
			for(var/obj/item/pizzabox/i in box.boxes)
				boxestoadd += i

			if( (boxes.len+1) + boxestoadd.len <= 5 )
				user.drop_item()

				box.loc = src
				box.boxes = list() // Clear the box boxes so we don't have boxes inside boxes. - Xzibit
				src.boxes.Add( boxestoadd )

				box.update_icon()
				update_icon()

				to_chat(user, span_warning("You put \the [box] ontop of \the [src]!"))
			else
				to_chat(user, span_warning("The stack is too high!"))
		else
			to_chat(user, span_warning("Close \the [box] first!"))

		return

	if( istype(I, /obj/item/reagent_containers/food/snacks/sliceable/pizza/) ) // Long ass fucking object name

		if( src.open )
			user.drop_item()
			I.loc = src
			src.pizza = I

			update_icon()

			to_chat(user, span_warning("You put \the [I] in \the [src]!"))
		else
			to_chat(user, span_warning("You try to push \the [I] through the lid but it doesn't work!"))
		return

	if( istype(I, /obj/item/pen/) )

		if( src.open )
			return

		var/t = sanitize(tgui_input_text(user, "Enter what you want to add to the tag:", "Write", "", 30))

		var/obj/item/pizzabox/boxtotagto = src
		if( boxes.len > 0 )
			boxtotagto = boxes[boxes.len]

		boxtotagto.boxtag = copytext("[boxtotagto.boxtag][t]", 1, 30)

		update_icon()
		return
	. = ..()

/obj/item/pizzabox/margherita/Initialize(mapload)
	pizza = new /obj/item/reagent_containers/food/snacks/sliceable/pizza/margherita(src)
	boxtag = "Margherita Deluxe"
	. = ..()

/obj/item/pizzabox/vegetable/Initialize(mapload)
	pizza = new /obj/item/reagent_containers/food/snacks/sliceable/pizza/vegetablepizza(src)
	boxtag = "Gourmet Vegatable"
	. = ..()

/obj/item/pizzabox/mushroom/Initialize(mapload)
	pizza = new /obj/item/reagent_containers/food/snacks/sliceable/pizza/mushroompizza(src)
	boxtag = "Mushroom Special"
	. = ..()

/obj/item/pizzabox/meat/Initialize(mapload)
	pizza = new /obj/item/reagent_containers/food/snacks/sliceable/pizza/meatpizza(src)
	boxtag = "Meatlover's Supreme"
	. = ..()

/obj/item/pizzabox/pineapple/Initialize(mapload)
	pizza = new /obj/item/reagent_containers/food/snacks/sliceable/pizza/pineapple(src)
	boxtag = "Hawaiian Sunrise"
	. = ..()

/obj/item/pizzabox/old/Initialize(mapload)
	pizza = new /obj/item/reagent_containers/food/snacks/sliceable/pizza/oldpizza(src)
	boxtag = "Deluxe Gourmet"
	. = ..()

/obj/item/reagent_containers/food/snacks/dionaroast
	name = "roast diona"
	desc = "It's like an enormous, leathery carrot. With an eye."
	icon_state = "dionaroast"
	trash = /obj/item/trash/plate
	filling_color = "#75754B"
	center_of_mass_x = 16
	center_of_mass_y = 7
	nutriment_amt = 6
	nutriment_desc = list("a chorus of flavor" = 6)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/dionaroast/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_RADIUM, 2)

/obj/item/reagent_containers/food/snacks/dough
	name = "dough"
	desc = "A piece of dough."
	icon = 'icons/obj/food_ingredients.dmi'
	icon_state = "dough"
	bitesize = 2
	center_of_mass_x = 16
	center_of_mass_y = 13
	nutriment_amt = 3
	nutriment_desc = list("uncooked dough" = 3)

/obj/item/reagent_containers/food/snacks/dough/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 1)

// Dough + rolling pin = flat dough
/obj/item/reagent_containers/food/snacks/dough/attackby(obj/item/W as obj, mob/user as mob)
	if(istype(W,/obj/item/material/kitchen/rollingpin))
		new /obj/item/reagent_containers/food/snacks/sliceable/flatdough(src)
		to_chat(user, "You flatten the dough.")
		qdel(src)

// slicable into 3xdoughslices
/obj/item/reagent_containers/food/snacks/sliceable/flatdough
	name = "flat dough"
	desc = "A flattened dough."
	icon = 'icons/obj/food_ingredients.dmi'
	icon_state = "flat dough"
	slice_path = /obj/item/reagent_containers/food/snacks/doughslice
	slices_num = 3
	nutriment_amt = 3
	nutriment_desc = list("raw dough" = 3)
	center_of_mass_x = 16
	center_of_mass_y = 16

/obj/item/reagent_containers/food/snacks/sliceable/flatdough/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 1)

/obj/item/reagent_containers/food/snacks/doughslice
	name = "dough slice"
	desc = "A building block of an impressive dish."
	icon = 'icons/obj/food_ingredients.dmi'
	icon_state = "doughslice"
	slice_path = /obj/item/reagent_containers/food/snacks/spagetti
	slices_num = 1
	bitesize = 2
	center_of_mass_x = 17
	center_of_mass_y = 19
	nutriment_amt = 1
	nutriment_desc = list("uncooked dough" = 1)

/obj/item/reagent_containers/food/snacks/bun
	name = "bun"
	desc = "A base for any self-respecting burger."
	icon = 'icons/obj/food_ingredients.dmi'
	icon_state = "bun"
	bitesize = 2
	center_of_mass_x = 16
	center_of_mass_y = 12
	nutriment_amt = 4
	nutriment_desc = "bun"

/obj/item/reagent_containers/food/snacks/bun/attackby(obj/item/W as obj, mob/user as mob)
	// Bun + meatball = burger
	if(istype(W,/obj/item/reagent_containers/food/snacks/meatball))
		new /obj/item/reagent_containers/food/snacks/monkeyburger(src)
		to_chat(user, "You make a burger.")
		qdel(W)
		qdel(src)

	// Bun + cutlet = hamburger
	else if(istype(W,/obj/item/reagent_containers/food/snacks/cutlet))
		new /obj/item/reagent_containers/food/snacks/monkeyburger(src)
		to_chat(user, "You make a burger.")
		qdel(W)
		qdel(src)

	// Bun + sausage = hotdog
	else if(istype(W,/obj/item/reagent_containers/food/snacks/sausage))
		new /obj/item/reagent_containers/food/snacks/hotdog(src)
		to_chat(user, "You make a hotdog.")
		qdel(W)
		qdel(src)

// Burger + cheese wedge = cheeseburger
/obj/item/reagent_containers/food/snacks/monkeyburger/attackby(obj/item/reagent_containers/food/snacks/cheesewedge/W as obj, mob/user as mob)
	if(istype(W))// && !istype(src,/obj/item/reagent_containers/food/snacks/cheesewedge))
		new /obj/item/reagent_containers/food/snacks/cheeseburger(src)
		to_chat(user, "You make a cheeseburger.")
		qdel(W)
		qdel(src)
		return
	else
		. = ..()

// Human Burger + cheese wedge = cheeseburger
/obj/item/reagent_containers/food/snacks/human/burger/attackby(obj/item/reagent_containers/food/snacks/cheesewedge/W as obj, mob/user as mob)
	if(istype(W))
		new /obj/item/reagent_containers/food/snacks/cheeseburger(src)
		to_chat(user, "You make a cheeseburger.")
		qdel(W)
		qdel(src)
		return
	else
		. = ..()

/obj/item/reagent_containers/food/snacks/bunbun
	name = "\improper Bun Bun"
	desc = "A small bread monkey fashioned from two burger buns."
	icon_state = "bunbun"
	bitesize = 2
	center_of_mass_x = 16
	center_of_mass_y = 8
	nutriment_amt = 8
	nutriment_desc = list("bun" = 8)

/obj/item/reagent_containers/food/snacks/taco
	name = "taco"
	desc = "Take a bite!"
	icon_state = "taco"
	bitesize = 3
	center_of_mass_x = 21
	center_of_mass_y = 12
	nutriment_amt = 4
	nutriment_desc = list(REAGENT_ID_CHEESE = 2,"taco shell" = 2)

/obj/item/reagent_containers/food/snacks/taco/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 3)

/obj/item/reagent_containers/food/snacks/rawcutlet
	name = "raw cutlet"
	desc = "A thin piece of raw meat."
	icon = 'icons/obj/food_ingredients.dmi'
	icon_state = "rawcutlet"
	bitesize = 1
	center_of_mass_x = 17
	center_of_mass_y = 20

/obj/item/reagent_containers/food/snacks/rawcutlet/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 1)

/obj/item/reagent_containers/food/snacks/cutlet
	name = "cutlet"
	desc = "A tasty meat slice."
	icon = 'icons/obj/food_ingredients.dmi'
	icon_state = "cutlet"
	bitesize = 2
	center_of_mass_x = 17
	center_of_mass_y = 20

/obj/item/reagent_containers/food/snacks/cutlet/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 2)

/obj/item/reagent_containers/food/snacks/rawmeatball
	name = "raw meatball"
	desc = "A raw meatball."
	icon = 'icons/obj/food_ingredients.dmi'
	icon_state = "rawmeatball"
	bitesize = 2
	center_of_mass_x = 16
	center_of_mass_y = 15

/obj/item/reagent_containers/food/snacks/rawmeatball/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 2)

/obj/item/reagent_containers/food/snacks/hotdog
	name = "hotdog"
	desc = "Unrelated to dogs, maybe."
	icon_state = "hotdog"
	bitesize = 2
	center_of_mass_x = 16
	center_of_mass_y = 17

/obj/item/reagent_containers/food/snacks/hotdog/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 6)

///obj/item/reagent_containers/food/snacks/hotdog/old (Commented out on 4/23/2021 to make room for ancient hotdog)
//	name = "old hotdog"
//	desc = "Covered in mold.  You're not gonna eat that, are you?"
//
///obj/item/reagent_containers/food/snacks/hotdog/old/Initialize(mapload)
//	. = ..()
//	reagents.add_reagent(REAGENT_ID_MOLD, 6)

/obj/item/reagent_containers/food/snacks/flatbread
	name = "flatbread"
	desc = "Bland but filling."
	icon = 'icons/obj/food_ingredients.dmi'
	icon_state = "flatbread"
	bitesize = 2
	center_of_mass_x = 16
	center_of_mass_y = 16
	nutriment_amt = 3
	nutriment_desc = list("bread" = 3)

// potato + knife = raw sticks
/obj/item/reagent_containers/food/snacks/grown/attackby(obj/item/W, mob/user)
	if(seed && seed.kitchen_tag && seed.kitchen_tag == PLANT_POTATO && istype(W,/obj/item/material/knife))
		new /obj/item/reagent_containers/food/snacks/rawsticks(get_turf(src))
		to_chat(user, span_notice("You cut the potato."))
		qdel(src)
	else if(seed && seed.kitchen_tag && seed.kitchen_tag == PLANT_SUNFLOWERS && istype(W,/obj/item/material/knife))
		new /obj/item/reagent_containers/food/snacks/rawsunflower(get_turf(src))
		to_chat(user, span_notice("You remove the seeds from the flower, slightly damaging them."))
		qdel(src)
	else
		. = ..()

/obj/item/reagent_containers/food/snacks/rawsticks
	name = "raw potato sticks"
	desc = "Raw fries, not very tasty."
	icon = 'icons/obj/food_ingredients.dmi'
	icon_state = "rawsticks"
	bitesize = 2
	center_of_mass_x = 16
	center_of_mass_y = 12
	nutriment_amt = 3
	nutriment_desc = list("raw potato" = 3)

/obj/item/reagent_containers/food/snacks/rawsunflower
	name = "sunflower seeds"
	desc = "Raw sunflower seeds, alright. They look too damaged to plant."
	icon = 'icons/obj/food_ingredients.dmi'
	icon_state = "sunflowerseed"
	bitesize = 1
	center_of_mass_x = 17
	center_of_mass_y = 18
	nutriment_amt = 1
	nutriment_desc = list("starch" = 3)

/obj/item/reagent_containers/food/snacks/frostbelle
	name = "frostbelle bud"
	desc = "A frostbelle flower from Sif. Its petals shimmer with an inner light."
	icon = 'icons/obj/food_ingredients.dmi'
	icon_state = "frostbelle"
	bitesize = 1
	nutriment_amt = 1
	nutriment_desc = list("another world" = 2)
	catalogue_data = list(/datum/category_item/catalogue/flora/frostbelle)
	filling_color = "#5dadcf"

/obj/item/reagent_containers/food/snacks/frostbelle/Initialize(mapload)
	. = ..()
	set_light(1, 1, "#5dadcf")

	reagents.add_reagent(REAGENT_ID_OXYCODONE, 1)
	reagents.add_reagent(REAGENT_ID_SIFSAP, 5)
	reagents.add_reagent(REAGENT_ID_BLISS, 5)

/obj/item/reagent_containers/food/snacks/bellefritter
	name = "frostbelle fritters"
	desc = "Frostbelles, prepared traditionally."
	icon_state = "bellefritter"
	filling_color = "#5dadcf"
	center_of_mass_x = 16
	center_of_mass_y = 12
	do_coating_prefix = 0
	bitesize = 2

/obj/item/reagent_containers/food/snacks/bellefritter/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_BATTER, 10)
	reagents.add_reagent(REAGENT_ID_SUGAR, 5)

/obj/item/reagent_containers/food/snacks/roastedsunflower
	name = "roasted sunflower seeds"
	desc = "Roasted sunflower seeds!"
	icon = 'icons/obj/food.dmi'
	icon_state = "sunflowerseed"
	bitesize = 1
	center_of_mass_x = 15
	center_of_mass_y = 17
	nutriment_amt = 2
	nutriment_desc = list("salt" = 3)

/obj/item/reagent_containers/food/snacks/roastedpeanuts
	name = "peanuts"
	desc = "Stopped being the planetary airline food of Earth in 2120."
	icon = 'icons/obj/food.dmi'
	icon_state = "roastnuts"
	bitesize = 1
	center_of_mass_x = 15
	center_of_mass_y = 17
	nutriment_amt = 2
	nutriment_desc = list("salt" = 3)

/obj/item/reagent_containers/food/snacks/liquidfood
	name = "\improper LiquidFood Ration"
	desc = "A prepackaged grey slurry of all the essential nutrients for a spacefarer on the go. Should this be crunchy?"
	description_fluff = "A survival food commonly packed onto short-distance bluespace shuttles and similar vessels. Tastes like chalk, but is packed full of nutrients and will keep you alive."
	icon_state = "liquidfood"
	trash = /obj/item/trash/liquidfood
	filling_color = "#A8A8A8"
	survivalfood = TRUE
	center_of_mass_x = 16
	center_of_mass_y = 15
	nutriment_amt = 20
	nutriment_desc = list("chalk" = 6)
	bitesize = 4
	eating_sound = 'sound/items/drink.ogg'

/obj/item/reagent_containers/food/snacks/liquidfood/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_IRON, 3)

/obj/item/reagent_containers/food/snacks/liquidprotein
	name = "\improper LiquidProtein Ration"
	desc = "A variant of the liquidfood ration, designed for more carnivorous species. Only barely more appealing than regular liquidfood. Should this be crunchy?"
	icon_state = "liquidprotein"
	trash = /obj/item/trash/liquidprotein
	filling_color = "#A8A8A8"
	survivalfood = TRUE
	center_of_mass_x = 16
	center_of_mass_y = 15
	bitesize = 4
	eating_sound = 'sound/items/drink.ogg'

/obj/item/reagent_containers/food/snacks/liquidprotein/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 30)
	reagents.add_reagent(REAGENT_ID_IRON, 3)

/obj/item/reagent_containers/food/snacks/liquidvitamin
	name = "\improper VitaPaste Ration"
	desc = "A variant of the liquidfood ration, designed for any carbon-based life. Somehow worse than regular liquidfood. Should this be crunchy?"
	icon_state = "liquidvitamin"
	trash = /obj/item/trash/liquidvitamin
	filling_color = "#A8A8A8"
	survivalfood = TRUE
	center_of_mass_x = 16
	center_of_mass_y = 15
	bitesize = 4
	eating_sound = 'sound/items/drink.ogg'

/obj/item/reagent_containers/food/snacks/liquidvitamin/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_FLOUR, 20)
	reagents.add_reagent(REAGENT_ID_TRICORDRAZINE, 5)
	reagents.add_reagent(REAGENT_ID_PARACETAMOL, 5)
	reagents.add_reagent(REAGENT_ID_ENZYME, 1)
	reagents.add_reagent(REAGENT_ID_IRON, 3)

/obj/item/reagent_containers/food/snacks/meatcube
	name = "cubed meat"
	desc = "Fried, salted lean meat compressed into a cube. Not very appetizing."
	icon_state = "meatcube"
	filling_color = "#7a3d11"
	center_of_mass_x = 16
	center_of_mass_y = 16
	bitesize = 3

/obj/item/reagent_containers/food/snacks/meatcube/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 15)

/obj/item/reagent_containers/food/snacks/tastybread
	name = "bread tube"
	desc = "Bread in a tube. Chewy...and surprisingly tasty."
	description_fluff = "This is the product that brought Centauri Provisions into the limelight. A product of the earliest extrasolar colony of Heaven, the Bread Tube, while bland, contains all the nutrients a spacer needs to get through the day and is decidedly edible when compared to some of its competitors. Due to the high-fructose corn syrup content of NanoTrasen's own-brand bread tubes, many jurisdictions classify them as a confectionary."
	icon = 'icons/obj/food_snacks.dmi'
	icon_state = "tastybread"
	trash = /obj/item/trash/tastybread
	filling_color = "#A66829"
	center_of_mass_x = 17
	center_of_mass_y = 16
	nutriment_amt = 6
	nutriment_desc = list("bread" = 2, "sweetness" = 3)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/skrellsnacks
	name = "\improper SkrellSnax"
	desc = "Cured fungus shipped all the way from Qerr'balak, almost like jerky! Almost."
	description_fluff = "Despite the packaging, most SkrellSnax sold in Vir are produced using locally-grown, Qerr'Balak-native Go'moa fungi in controversial Skrell-owned biodomes on the suface of Sif. SkrellSnax were originally a product of Natuna, designed to welcome Ue-Katish refugees to their colony. The brand was recreated by Centauri Provisions after Natuna and SolGov broke off diplomatic relations."
	icon = 'icons/obj/food_snacks.dmi'
	icon_state = "skrellsnacks"
	trash = /obj/item/trash/skrellsnax
	filling_color = "#A66829"
	center_of_mass_x = 15
	center_of_mass_y = 12
	nutriment_amt = 10
	nutriment_desc = list(PLANT_MUSHROOMS = 5, "salt" = 5)
	bitesize = 3

/obj/item/reagent_containers/food/snacks/unajerky
	name = "Moghes Imported Sissalik Jerky"
	icon = 'icons/obj/food_snacks.dmi'
	icon_state = "unathitinred"
	desc = "An incredibly well made jerky, shipped in all the way from Moghes."
	description_fluff = "The exact meat and spices used in the curing of Sissalik Jerky are a well-kept secret, and thought to not exist at all outside of Hegemony space. Many have tried to replicate the flavour, but none have come close, so the brand remains a highly prized import. "
	trash = /obj/item/trash/unajerky
	filling_color = "#631212"
	center_of_mass_x = 15
	center_of_mass_y = 9
	drop_sound = 'sound/items/drop/soda.ogg'
	pickup_sound = 'sound/items/pickup/soda.ogg'
	bitesize = 2

/obj/item/reagent_containers/food/snacks/unajerky/Initialize(mapload)
	. =..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 8)
	reagents.add_reagent(REAGENT_ID_CAPSAICIN, 2)

/obj/item/reagent_containers/food/snacks/sashimi
	name = "sashimi"
	desc = "Expertly prepared. Hopefully the toxins got removed."
	filling_color = "#FFDEFE"
	icon_state = "sashimi"
	nutriment_amt = 6
	bitesize = 3

/obj/item/reagent_containers/food/snacks/sashimi/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 2)

/obj/item/reagent_containers/food/snacks/benedict
	name = "eggs benedict"
	desc = "Hey, there's only one egg in this!"
	filling_color = "#FFDF78"
	icon_state = "benedict"
	nutriment_amt = 4
	nutriment_desc = list("bread" = 2, "bacon" = 2, REAGENT_ID_EGG = 2)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/benedict/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 2)

/obj/item/reagent_containers/food/snacks/beans
	name = "baked beans"
	desc = "Musical fruit in a slightly less musical container."
	filling_color = "#FC6F28"
	icon_state = "bakedbeans"
	bitesize = 2

/obj/item/reagent_containers/food/snacks/beans/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_BEANPROTEIN, 6)

/obj/item/reagent_containers/food/snacks/cookie
	name = "chocolate chip cookie"
	desc = "Just like your mother used to make."
	filling_color = "#DBC94F"
	icon_state = "cookie"
	nutriment_amt = 5
	nutriment_desc = list("sweetness" = 2, "cookie" = 1, REAGENT_ID_CHOCOLATE = 2)
	bitesize = 1

/obj/item/reagent_containers/food/snacks/sugarcookie
	name = "sugar cookie"
	desc = "Just like your little sister used to make."
	filling_color = "#DBC94F"
	icon_state = "sugarcookie"
	nutriment_amt = 5
	nutriment_desc = list("sweetness" = 4, "cookie" = 1)
	bitesize = 1

/obj/item/reagent_containers/food/snacks/fortunecookie
	name = "Fortune cookie"
	desc = "A true prophecy in each cookie!"
	icon_state = "fortune_cookie"
	filling_color = "#E8E79E"
	center_of_mass_x = 15
	center_of_mass_y = 14
	nutriment_amt = 3
	nutriment_desc = list("fortune cookie" = 2)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/berrymuffin
	name = "berry muffin"
	desc = "A delicious and spongy little cake, with berries."
	icon_state = "berrymuffin"
	filling_color = "#E0CF9B"
	center_of_mass_x = 17
	center_of_mass_y = 4
	nutriment_amt = 6
	nutriment_desc = list("sweetness" = 2, "muffin" = 2, PLANT_BERRIES = 2)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/berrymuffin/berry/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_BERRYJUICE, 3)

/obj/item/reagent_containers/food/snacks/berrymuffin/poison/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_POISONBERRYJUICE, 3)

/obj/item/reagent_containers/food/snacks/ghostmuffin
	name = "booberry muffin"
	desc = "My stomach is a graveyard! No living being can quench my bloodthirst!"
	icon_state = "berrymuffin"
	filling_color = "#799ACE"
	center_of_mass_x = 17
	center_of_mass_y = 4
	nutriment_amt = 6
	nutriment_desc = list("spookiness" = 4, "muffin" = 1, PLANT_BERRIES = 1)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/ghostmuffin/berry/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_BERRYJUICE, 3)

/obj/item/reagent_containers/food/snacks/ghostmuffin/poison/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_POISONBERRYJUICE, 3)

/obj/item/reagent_containers/food/snacks/devilledegg
	name = "devilled eggs"
	desc = "Spicy homestyle favorite."
	icon_state = "devilledegg"
	filling_color = "#799ACE"
	center_of_mass_x = 17
	center_of_mass_y = 16
	nutriment_amt = 8
	nutriment_desc = list(REAGENT_ID_EGG = 4, PLANT_CHILI = 4)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/devilledegg/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_CAPSAICIN, 2)

/obj/item/reagent_containers/food/snacks/fruitsalad
	name = "fruit salad"
	desc = "Your standard fruit salad."
	icon_state = "fruitsalad"
	filling_color = "#FF3867"
	nutriment_amt = 10
	nutriment_desc = list("fruit" = 10)
	bitesize = 4

/obj/item/reagent_containers/food/snacks/flowerchildsalad
	name = "flowerchild poppy salad"
	desc = "A fragrant salad."
	icon_state = "flowerchildsalad"
	filling_color = "#FF3867"
	nutriment_amt = 10
	nutriment_desc = list("bittersweet" = 10)
	bitesize = 4

/obj/item/reagent_containers/food/snacks/rosesalad
	name = "flowerchild rose salad"
	desc = "A fragrant salad."
	icon_state = "rosesalad"
	filling_color = "#FF3867"
	nutriment_amt = 10
	nutriment_desc = list("bittersweet" = 10, REAGENT_ID_IRON = 5)
	bitesize = 4

/obj/item/reagent_containers/food/snacks/rosesalad/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_STOXIN, 2)

/obj/item/reagent_containers/food/snacks/eggbowl
	name = "egg bowl"
	desc = "A bowl of fried rice with egg mixed in."
	icon_state = "eggbowl"
	trash = /obj/item/trash/snack_bowl
	filling_color = "#FFFBDB"
	nutriment_amt = 6
	nutriment_desc = list(REAGENT_ID_RICE = 2, REAGENT_ID_EGG = 4)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/eggbowl/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 4)

/obj/item/reagent_containers/food/snacks/tortilla
	name = "tortilla"
	desc = "The base for all your burritos."
	icon_state = "tortilla"
	nutriment_amt = 2
	nutriment_desc = list("bread" = 2)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/cubannachos
	name = "cuban nachos"
	desc = "That's some dangerously spicy nachos."
	icon_state = "cubannachos"
	nutriment_amt = 6
	nutriment_desc = list("salt" = 1, REAGENT_ID_CHEESE = 2, "chili peppers" = 3)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/cubannachos/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_CAPSAICIN, 4)

/obj/item/reagent_containers/food/snacks/curryrice
	name = "curry rice"
	desc = "That's some dangerously spicy rice."
	icon_state = "curryrice"
	nutriment_amt = 6
	nutriment_desc = list("salt" = 1, REAGENT_ID_RICE = 2, "chili peppers" = 3)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/curryrice/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_CAPSAICIN, 4)

/obj/item/reagent_containers/food/snacks/piginblanket
	name = "pig in a blanket"
	desc = "A sausage embedded in soft, fluffy pastry. Free this pig from its blanket prison by eating it."
	icon_state = "piginblanket"
	nutriment_amt = 6
	nutriment_desc = list("meat" = 3, "pastry" = 3)
	bitesize = 3

/obj/item/reagent_containers/food/snacks/piginblanket/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 4)

/obj/item/reagent_containers/food/snacks/wormsickly
	name = "sickly worm"
	desc = "A worm, it doesn't look particularily healthy, but it will still serve as good fishing bait."
	icon_state = "worm_sickly"
	nutriment_amt = 1
	nutriment_desc = list("bugflesh" = 1)
	w_class = ITEMSIZE_TINY
	bitesize = 5

/obj/item/reagent_containers/food/snacks/wormsickly/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_FISHBAIT, 9)
	reagents.add_reagent(REAGENT_ID_PROTEIN,  3)

/obj/item/reagent_containers/food/snacks/worm
	name = "strange worm"
	desc = "A peculiar worm, freshly plucked from the earth."
	icon_state = "worm"
	nutriment_amt = 1
	nutriment_desc = list("bugflesh" = 1)
	w_class = ITEMSIZE_TINY
	bitesize = 5

/obj/item/reagent_containers/food/snacks/worm/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_FISHBAIT, 15)
	reagents.add_reagent(REAGENT_ID_PROTEIN,   5)

/obj/item/reagent_containers/food/snacks/wormdeluxe
	name = "deluxe worm"
	desc = "A fancy worm, genetically engineered to appeal to fish."
	icon_state = "worm_deluxe"
	nutriment_amt = 5
	nutriment_desc = list("bugflesh" = 1)
	w_class = ITEMSIZE_TINY
	bitesize = 5

/obj/item/reagent_containers/food/snacks/wormdeluxe/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_FISHBAIT, 30)
	reagents.add_reagent(REAGENT_ID_PROTEIN,  10)

/obj/item/reagent_containers/food/snacks/siffruit
	name = "pulsing fruit"
	desc = "A blue-ish sac encased in a tough black shell."
	icon = 'icons/obj/flora/foraging.dmi'
	icon_state = "siffruit"
	nutriment_amt = 2
	nutriment_desc = list("tart" = 1)
	w_class = ITEMSIZE_TINY

/obj/item/reagent_containers/food/snacks/siffruit/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_SIFSAP, 2)

/obj/item/reagent_containers/food/snacks/siffruit/afterattack(obj/O as obj, mob/user as mob, proximity)
	if(istype(O,/obj/machinery/microwave))
		return ..()
	if(!(proximity && O.is_open_container()))
		return
	to_chat(user, span_notice("You tear \the [src]'s sac open, pouring it into \the [O]."))
	reagents.trans_to(O, reagents.total_volume)
	user.drop_from_inventory(src)
	qdel(src)

/obj/item/reagent_containers/food/snacks/bagelplain
	name = "plain bagel"
	desc = "This bread's got chutzpah!"
	icon_state = "bagelplain"
	nutriment_amt = 6
	nutriment_desc = list("bread" = 6)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/bagelsunflower
	name = "sunflower seed bagel"
	desc = "This bread's got chutzpah - and sunflower seeds!"
	icon_state = "bagelsunflower"
	nutriment_amt = 7
	nutriment_desc = list("bread" = 4, "sunflower seeds" = 3)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/bagelcheese
	name = "cheese bagel"
	desc = "This bread's got cheese n' chutzpah!"
	icon_state = "bagelcheese"
	nutriment_amt = 8
	nutriment_desc = list("bread" = 4, REAGENT_ID_CHEESE = 4)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/bagelcheese/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 4)

/obj/item/reagent_containers/food/snacks/bagelraisin
	name = "cinnamon raisin bagel"
	desc = "This bread's got... Raisins!"
	icon_state = "bagelraisin"
	nutriment_amt = 8
	nutriment_desc = list("bread" = 4, "sweetness" = 4)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/bagelpoppy
	name = "poppy seed bagel"
	desc = "This bread's got Chutzpah, and poppy seeds!"
	icon_state = "bagelpoppy"
	nutriment_amt = 6
	nutriment_desc = list("bread" = 1, "sweetness" = 1)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/bageleverything
	name = "everything bagel"
	desc = "Mmm... Immeasurably unfathomable!"
	icon_state = "bageleverything"
	nutriment_amt = 20
	nutriment_desc = list("life" = 1, "death" = 1, "entropy" = 1)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/bageleverything/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PHORON, 5)
	reagents.add_reagent(REAGENT_ID_DEFECTIVENANITES, 5)

/obj/item/reagent_containers/food/snacks/bageltwo
	name = "two bagels"
	desc = "Noo! ...Two bagels!"
	icon_state = "bagelplain"

/obj/item/reagent_containers/food/snacks/bageltwo/Initialize(mapload)
	..()
	spawn_bagels()
	spawn_bagels()
	return INITIALIZE_HINT_QDEL

/obj/item/reagent_containers/food/snacks/bageltwo/proc/spawn_bagels()
	var/build_path = /obj/item/reagent_containers/food/snacks/bagelplain
	var/atom/A = new build_path(get_turf(src))
	if(pixel_x || pixel_y)
		A.pixel_x = pixel_x
		A.pixel_y = pixel_y

/obj/item/reagent_containers/food/snacks/macncheese
	name = "macaroni and cheese"
	desc = "The perfect combination of noodles and dairy."
	icon = 'icons/obj/food.dmi'
	icon_state = "macncheese"
	trash = /obj/item/trash/snack_bowl
	center_of_mass_x = 16
	center_of_mass_y = 16
	nutriment_amt = 9
	nutriment_desc = list("Cheese" = 5, "pasta" = 4, "happiness" = 1)
	bitesize = 3


//Code for dipping food in batter
/obj/item/reagent_containers/food/snacks/afterattack(obj/O as obj, mob/user as mob, proximity)
	if(O.is_open_container() && O.reagents && !(istype(O, /obj/item/reagent_containers/food)) && proximity)
		for (var/r in O.reagents.reagent_list)

			var/datum/reagent/R = r
			if (istype(R, /datum/reagent/nutriment/coating))
				if (apply_coating(R, user))
					return 1

	return . = ..()

//This proc handles drawing coatings out of a container when this food is dipped into it
/obj/item/reagent_containers/food/snacks/proc/apply_coating(var/datum/reagent/nutriment/coating/C, var/mob/user)
	if (coating)
		to_chat(user, "The [src] is already coated in [coating.name]!")
		return 0

	//Calculate the reagents of the coating needed
	var/req = 0
	for(var/datum/reagent/R as anything in reagents.reagent_list)
		if (istype(R, /datum/reagent/nutriment))
			req += R.volume * 0.2
		else
			req += R.volume * 0.1

	req += w_class*0.5

	if (!req)
		//the food has no reagents left, its probably getting deleted soon
		return 0

	if (C.volume < req)
		to_chat(user, span_warning("There's not enough [C.name] to coat the [src]!"))
		return 0

	var/id = C.id

	//First make sure there's space for our batter
	if (reagents.get_free_space() < req+5)
		var/extra = req+5 - reagents.get_free_space()
		reagents.maximum_volume += extra

	//Suck the coating out of the holder
	C.holder.trans_to_holder(reagents, req)

	//We're done with C now, repurpose the var to hold a reference to our local instance of it
	C = reagents.get_reagent(id)
	if (!C)
		return

	coating = C
	//Now we have to do the witchcraft with masking images
	//var/icon/I = new /icon(icon, icon_state)

	if (!flat_icon)
		flat_icon = getFlatIcon(src)
	var/icon/I = flat_icon
	color = "#FFFFFF" //Some fruits use the color var. Reset this so it doesnt tint the batter
	I.Blend(new /icon('icons/obj/food_custom.dmi', rgb(255,255,255)),ICON_ADD)
	I.Blend(new /icon('icons/obj/food_custom.dmi', coating.icon_raw),ICON_MULTIPLY)
	var/image/J = image(I)
	J.alpha = 200
	J.blend_mode = BLEND_OVERLAY
	J.tag = "coating"
	add_overlay(J)

	if (user)
		user.visible_message(span_notice("[user] dips \the [src] into \the [coating.name]"), span_notice("You dip \the [src] into \the [coating.name]"))

	return 1


//Called by cooking machines. This is mainly intended to set properties on the food that differ between raw/cooked
/obj/item/reagent_containers/food/snacks/proc/cook()
	if (coating)
		var/list/temp = overlays.Copy()
		for (var/i in temp)
			if (istype(i, /image))
				var/image/I = i
				if (I.tag == "coating")
					temp.Remove(I)
					break

		overlays = temp
		//Carefully removing the old raw-batter overlay

		if (!flat_icon)
			flat_icon = getFlatIcon(src)
		var/icon/I = flat_icon
		color = "#FFFFFF" //Some fruits use the color var
		I.Blend(new /icon('icons/obj/food_custom.dmi', rgb(255,255,255)),ICON_ADD)
		I.Blend(new /icon('icons/obj/food_custom.dmi', coating.icon_cooked),ICON_MULTIPLY)
		var/image/J = image(I)
		J.alpha = 200
		J.tag = "coating"
		add_overlay(J)


		if (do_coating_prefix == 1)
			name = "[coating.coated_adj] [name]"

	for(var/datum/reagent/R as anything in reagents.reagent_list)
		if (istype(R, /datum/reagent/nutriment/coating))
			var/datum/reagent/nutriment/coating/C = R
			C.data["cooked"] = 1
			C.name = C.cooked_name

/obj/item/reagent_containers/food/snacks/proc/on_consume(var/mob/eater, var/mob/feeder = null)
	if(!reagents.total_volume)
		eater.visible_message(span_notice("[eater] finishes eating \the [src]."),span_notice("You finish eating \the [src]."))

		if (!feeder)
			feeder = eater

		feeder.drop_from_inventory(src) // Drop food from inventory so it doesn't end up staying on the hud after qdel, and so inhands go away

		if(trash)
			if(ispath(trash,/obj/item))
				var/obj/item/TrashItem = new trash(feeder)
				feeder.put_in_hands(TrashItem)
			else if(istype(trash,/obj/item))
				feeder.put_in_hands(trash)
		qdel(src)
	return

////////////////////////////////////////////////////////////////////////////////
/// FOOD END
////////////////////////////////////////////////////////////////////////////////

/mob/living
	var/composition_reagent
	var/composition_reagent_quantity

///mob/living/simple_mob/adultslime	//The literal only thing in the game that uses this is commented out, so I comment out this too
//	composition_reagent = REAGENT_ID_SLIMEJELLY

/mob/living/carbon/alien/diona
	composition_reagent = REAGENT_ID_NUTRIMENT//Dionae are plants, so eating them doesn't give animal protein

/mob/living/simple_mob/slime
	composition_reagent = REAGENT_ID_SLIMEJELLY
	allow_mind_transfer = TRUE

/mob/living/simple_mob
	var/kitchen_tag = "animal" //Used for cooking with animals

/obj/item/reagent_containers/food/snacks/sliceable/cheesewheel
	slices_num = 8

/obj/item/reagent_containers/food/snacks/sausage/battered
	name = "battered sausage"
	desc = "A piece of mixed, long meat, battered and then deepfried."
	icon_state = "batteredsausage"
	filling_color = "#DB0000"
	center_of_mass_x = 16
	center_of_mass_y = 16
	do_coating_prefix = 0
	bitesize = 2


/obj/item/reagent_containers/food/snacks/sausage/battered/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 6)
	reagents.add_reagent(REAGENT_ID_BATTER, 1.7)
	reagents.add_reagent(REAGENT_ID_OIL, 1.5)

/obj/item/reagent_containers/food/snacks/jalapeno_poppers
	name = "jalapeno popper"
	desc = "A battered, deep-fried chilli pepper."
	icon_state = "popper"
	filling_color = "#00AA00"
	center_of_mass_x = 10
	center_of_mass_y = 6
	do_coating_prefix = 0
	nutriment_amt = 2
	nutriment_desc = list("chilli pepper" = 2)
	bitesize = 1

/obj/item/reagent_containers/food/snacks/jalapeno_poppers/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_BATTER, 2)
	reagents.add_reagent(REAGENT_ID_OIL, 2)

/obj/item/reagent_containers/food/snacks/mouseburger
	name = "mouse burger"
	desc = "Squeaky and a little furry."
	icon_state = "ratburger"
	center_of_mass_x = 16
	center_of_mass_y = 11
	bitesize = 2

/obj/item/reagent_containers/food/snacks/mouseburger/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 4)

/obj/item/reagent_containers/food/snacks/chickenkatsu
	name = "chicken katsu"
	desc = "An Earth delicacy consisting of chicken fried in a light beer batter."
	icon_state = "katsu"
	trash = /obj/item/trash/plate
	filling_color = "#E9ADFF"
	center_of_mass_x = 16
	center_of_mass_y = 16
	do_coating_prefix = 0
	bitesize = 1.5

/obj/item/reagent_containers/food/snacks/chickenkatsu/Initialize(mapload)
		. = ..()
		reagents.add_reagent(REAGENT_ID_PROTEIN, 6)
		reagents.add_reagent(REAGENT_ID_BEERBATTER, 2)
		reagents.add_reagent(REAGENT_ID_OIL, 1)


/obj/item/reagent_containers/food/snacks/sliceable/pizza/crunch/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_BATTER, 6.5)
	coating = reagents.get_reagent(REAGENT_ID_BATTER)
	reagents.add_reagent(REAGENT_ID_OIL, 4)

/obj/item/reagent_containers/food/snacks/funnelcake
	name = "funnel cake"
	desc = "A taste of the carnival. You can feel your blood pressure rising."
	icon_state = "funnelcake"
	filling_color = "#Ef1479"
	center_of_mass_x = 16
	center_of_mass_y = 12
	do_coating_prefix = 0
	bitesize = 2

/obj/item/reagent_containers/food/snacks/funnelcake/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_BATTER, 10)
	reagents.add_reagent(REAGENT_ID_SUGAR, 5)

/obj/item/reagent_containers/food/snacks/spreads
	name = "nutri-spread"
	desc = "A stick of plant-based nutriments in a semi-solid form. I can't believe it's not margarine!"
	icon_state = "marge"
	bitesize = 2
	center_of_mass_x = 16
	center_of_mass_y = 16
	nutriment_desc = list("margarine" = 1)
	nutriment_amt = 20

/obj/item/reagent_containers/food/snacks/spreads/butter
	name = "butter"
	icon_state = "butter"
	bitesize = 2
	center_of_mass_x = 16
	center_of_mass_y = 16
	nutriment_desc = list("butter" = 1)
	nutriment_amt = 0

/obj/item/reagent_containers/food/snacks/spreads/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_TRIGLYCERIDE, 20)
	reagents.add_reagent(REAGENT_ID_SODIUMCHLORIDE,1)

/obj/item/reagent_containers/food/snacks/rawcutlet/attackby(obj/item/W as obj, mob/user as mob)
	if(istype(W,/obj/item/material/knife))
		new /obj/item/reagent_containers/food/snacks/rawbacon(src)
		new /obj/item/reagent_containers/food/snacks/rawbacon(src)
		to_chat(user, "You slice the cutlet into thin strips of bacon.")
		qdel(src)
	else
		. = ..()

/obj/item/reagent_containers/food/snacks/rawbacon
	name = "raw bacon"
	desc = "A very thin piece of raw meat, cut from beef."
	icon_state = "rawbacon"
	bitesize = 1
	center_of_mass_x = 16
	center_of_mass_y = 16

/obj/item/reagent_containers/food/snacks/rawbacon/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 0.33)

/obj/item/reagent_containers/food/snacks/bacon
	name = "bacon"
	desc = "A tasty meat slice. You don't see any pigs on this station, do you?"
	icon_state = "bacon"
	bitesize = 2
	center_of_mass_x = 16
	center_of_mass_y = 16

/obj/item/reagent_containers/food/snacks/bacon/microwave
	name = "microwaved bacon"
	desc = "A tasty meat slice. You don't see any pigs on this station, do you?"
	icon_state = "bacon"
	bitesize = 2
	center_of_mass_x = 16
	center_of_mass_y = 16

/obj/item/reagent_containers/food/snacks/bacon/oven
	name = "oven-cooked bacon"
	desc = "A tasty meat slice. You don't see any pigs on this station, do you?"
	icon_state = "bacon"
	bitesize = 2
	center_of_mass_x = 16
	center_of_mass_y = 16

/obj/item/reagent_containers/food/snacks/bacon/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 0.33)
	reagents.add_reagent(REAGENT_ID_TRIGLYCERIDE, 1)

/obj/item/reagent_containers/food/snacks/bacon_stick
	name = "eggpop"
	desc = "A bacon wrapped boiled egg, conveniently skewered on a wooden stick."
	icon_state = "bacon_stick"
	trash = /obj/item/trash/stick

/obj/item/reagent_containers/food/snacks/bacon_stick/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 3)
	reagents.add_reagent(REAGENT_ID_EGG, 1)

/obj/item/reagent_containers/food/snacks/chilied_eggs
	name = "Redeemed eggs"
	desc = "Three deviled eggs floating in a bowl of meat chili. A popular lunchtime meal for Unathi, with mild religious undertones."
	icon_state = "chilied_eggs"
	trash = /obj/item/trash/snack_bowl

/obj/item/reagent_containers/food/snacks/chilied_eggs/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_EGG, 6)
	reagents.add_reagent(REAGENT_ID_PROTEIN, 2)

/obj/item/reagent_containers/food/snacks/bacon_and_eggs
	name = "bacon and eggs"
	desc = "A piece of bacon and two fried eggs."
	icon_state = "bacon_and_eggs"
	trash = /obj/item/trash/plate

/obj/item/reagent_containers/food/snacks/bacon_and_eggs/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 3)
	reagents.add_reagent(REAGENT_ID_EGG, 1)

/obj/item/reagent_containers/food/snacks/sweet_and_sour
	name = "sweet and sour pork"
	desc = "A traditional ancient sol recipe with a few liberties taken with meat selection."
	icon_state = "sweet_and_sour"
	nutriment_desc = list("sweet and sour" = 6)
	nutriment_amt = 6
	trash = /obj/item/trash/plate

/obj/item/reagent_containers/food/snacks/sweet_and_sour/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 3)

/obj/item/reagent_containers/food/snacks/corn_dog
	name = "corn dog"
	desc = "A cornbread covered sausage deepfried in oil."
	icon_state = "corndog"
	trash = /obj/item/trash/stick
	nutriment_desc = list("corn batter" = 4)
	nutriment_amt = 4

/obj/item/reagent_containers/food/snacks/corn_dog/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 3)

/obj/item/reagent_containers/food/snacks/truffle
	name = "chocolate truffle"
	desc = "Rich bite-sized chocolate."
	icon_state = "chocolatepiece_truffle"
	nutriment_amt = 0
	bitesize = 4

/obj/item/reagent_containers/food/snacks/truffle/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_COCO, 6)

/obj/item/reagent_containers/food/snacks/truffle/random
	name = "mystery chocolate truffle"
	desc = "Rich bite-sized chocolate with a mystery filling!"

/obj/item/reagent_containers/food/snacks/truffle/random/Initialize(mapload)
	. = ..()
	var/reagent_string = pick(list(REAGENT_ID_CREAM,REAGENT_ID_CHERRYJELLY,REAGENT_ID_MINT,REAGENT_ID_FROSTOIL,REAGENT_ID_CAPSAICIN,REAGENT_ID_CREAM,REAGENT_ID_COFFEE,REAGENT_ID_MILKSHAKE))
	reagents.add_reagent(reagent_string, 4)

/obj/item/reagent_containers/food/snacks/bacon_flatbread
	name = "bacon cheese flatbread"
	desc = "Not a pizza."
	icon_state = "bacon_flatbread"
	nutriment_desc = list("flatbread" = 5)
	nutriment_amt = 5

/obj/item/reagent_containers/food/snacks/bacon_flatbread/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 5)

/obj/item/reagent_containers/food/snacks/meat_pocket
	name = "meat pocket"
	desc = "Meat and cheese stuffed in a flatbread pocket, grilled to perfection."
	icon_state = "meat_pocket"
	nutriment_desc = list("flatbread" = 3)
	nutriment_amt = 3

/obj/item/reagent_containers/food/snacks/meat_pocket/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 3)

/obj/item/reagent_containers/food/snacks/fish_taco
	name = "fish taco"
	desc = "A questionably cooked fish taco decorated with herbs, spices, and special sauce."
	icon_state = "fishtaco"
	nutriment_desc = list("flatbread" = 3)
	nutriment_amt = 3

/obj/item/reagent_containers/food/snacks/fish_taco/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_SEAFOOD,3)

/obj/item/reagent_containers/food/snacks/nt_muffin
	name = "breakfast muffin"
	desc = "An english muffin with egg, cheese, and sausage, as sold in fast food joints galaxy-wide."
	icon_state = "eggmuffin"
	nutriment_desc = list("biscuit" = 3)
	nutriment_amt = 3

/obj/item/reagent_containers/food/snacks/nt_muffin/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN,5)

/obj/item/reagent_containers/food/snacks/pineapple_ring
	name = "pineapple rings"
	desc = "So retro."
	icon_state = "pineapple_ring"
	nutriment_desc = list("sweetness" = 2)
	nutriment_amt = 2

/obj/item/reagent_containers/food/snacks/pineapple_ring/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PINEAPPLEJUICE,3)


/obj/item/reagent_containers/food/snacks/burger/bacon
	name = "bacon burger"
	desc = "The cornerstone of every nutritious breakfast, now with bacon!"
	icon_state = "baconburger"
	filling_color = "#D63C3C"
	center_of_mass_x = 16
	center_of_mass_y = 11
	nutriment_desc = list("bun" = 2)
	nutriment_amt = 3
	bitesize = 2

/obj/item/reagent_containers/food/snacks/burger/bacon/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 4)

/obj/item/reagent_containers/food/snacks/blt
	name = "BLT"
	desc = "Bacon, lettuce, tomatoes. The perfect lunch."
	icon_state = "blt"
	filling_color = "#D63C3C"
	center_of_mass_x = 16
	center_of_mass_y = 16
	nutriment_desc = list("bread" = 4)
	nutriment_amt = 4
	bitesize = 2

/obj/item/reagent_containers/food/snacks/blt/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 4)

/obj/item/reagent_containers/food/snacks/porkbowl
	name = "pork bowl"
	desc = "A bowl of fried rice with cuts of meat."
	icon_state = "porkbowl"
	trash = /obj/item/trash/snack_bowl
	filling_color = "#FFFBDB"
	bitesize = 2

/obj/item/reagent_containers/food/snacks/porkbowl/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_RICE, 6)
	reagents.add_reagent(REAGENT_ID_PROTEIN, 4)

/obj/item/reagent_containers/food/snacks/mashedpotato
	name = "mashed potato"
	desc = "Pillowy mounds of mashed potato."
	icon_state = "mashedpotato"
	trash = /obj/item/trash/plate
	filling_color = "#EDDD00"
	center_of_mass_x = 16
	center_of_mass_y = 11
	nutriment_amt = 4
	nutriment_desc = list("mashed potatoes" = 4)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/loadedbakedpotato
	name = "Loaded Baked Potato"
	desc = "Totally baked."
	icon_state = "loadedbakedpotato"
	filling_color = "#9C7A68"
	center_of_mass_x = 16
	center_of_mass_y = 10
	nutriment_amt = 3
	nutriment_desc = list("baked potato" = 3)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/loadedbakedpotato/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 3)

/obj/item/reagent_containers/food/snacks/bangersandmash
	name = "Bangers and Mash"
	desc = "An English treat."
	icon_state = "bangersandmash"
	trash = /obj/item/trash/plate
	filling_color = "#EDDD00"
	center_of_mass_x = 16
	center_of_mass_y = 11
	nutriment_amt = 4
	nutriment_desc = list("fluffy potato" = 3, "sausage" = 2)
	bitesize = 4

/obj/item/reagent_containers/food/snacks/bangersandmash/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 3)

/obj/item/reagent_containers/food/snacks/cheesymash
	name = "Cheesy Mashed Potato"
	desc = "The only thing that could make mash better."
	icon_state = "cheesymash"
	trash = /obj/item/trash/plate
	filling_color = "#EDDD00"
	center_of_mass_x = 16
	center_of_mass_y = 11
	nutriment_amt = 4
	nutriment_desc = list("cheesy potato" = 4)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/cheesymash/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 3)

/obj/item/reagent_containers/food/snacks/croissant
	name = "croissant"
	desc = "True french cuisine."
	filling_color = "#E3D796"
	icon_state = "croissant"
	nutriment_amt = 4
	nutriment_desc = list("french bread" = 4)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/pancakes
	name = "pancakes"
	desc = "Pancakes, delicious."
	icon_state = "pancakes"
	trash = /obj/item/trash/plate
	center_of_mass_x = 15
	center_of_mass_y = 11
	nutriment_desc = list("pancake" = 8)
	nutriment_amt = 8
	bitesize = 2

/obj/item/reagent_containers/food/snacks/pancakes/berry
	name = "berry pancakes"
	desc = "Pancakes with berries, delicious."
	icon_state = "pancake_berry"
	trash = /obj/item/trash/plate
	center_of_mass_x = 15
	center_of_mass_y = 11
	nutriment_desc = list("pancake" = 4, "berry" = 4)
	nutriment_amt = 10
	bitesize = 2

/obj/item/reagent_containers/food/snacks/nugget
	name = "chicken nugget"
	icon_state = "nugget_lump"
	bitesize = 3

/obj/item/reagent_containers/food/snacks/nugget/Initialize(mapload)
	. = ..()
	var/shape = pick("lump", "star", "lizard", "corgi")
	desc = "A chicken nugget vaguely shaped like a [shape]."
	icon_state = "nugget_[shape]"
	reagents.add_reagent(REAGENT_ID_PROTEIN, 4)

/obj/item/reagent_containers/food/snacks/icecreamsandwich
	name = "ice cream sandwich"
	desc = "Portable ice cream in its own packaging."
	icon_state = "icecreamsandwich"
	filling_color = "#343834"
	center_of_mass_x = 15
	center_of_mass_y = 4
	nutriment_desc = list("ice cream" = 4)
	nutriment_amt = 4

/obj/item/reagent_containers/food/snacks/honeybun
	name = "honey bun"
	desc = "A sticky pastry bun glazed with honey."
	icon_state = "honeybun"
	nutriment_desc = list("pastry" = 1)
	nutriment_amt = 3
	bitesize = 3

/obj/item/reagent_containers/food/snacks/honeybun/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_HONEY, 3)

// Moved /bun/attackby() from /code/modules/food/food/snacks.dm
/obj/item/reagent_containers/food/snacks/bun/attackby(obj/item/W as obj, mob/user as mob)
	var/obj/item/reagent_containers/food/snacks/result = null
	// Bun + meatball = burger
	if(istype(W,/obj/item/reagent_containers/food/snacks/meatball))
		result = new /obj/item/reagent_containers/food/snacks/monkeyburger(src)
		to_chat(user, "You make a burger.")
		qdel(W)
		qdel(src)

	// Bun + cutlet = hamburger
	else if(istype(W,/obj/item/reagent_containers/food/snacks/cutlet))
		result = new /obj/item/reagent_containers/food/snacks/monkeyburger(src)
		to_chat(user, "You make a burger.")
		qdel(W)
		qdel(src)

	// Bun + sausage = hotdog
	else if(istype(W,/obj/item/reagent_containers/food/snacks/sausage))
		result = new /obj/item/reagent_containers/food/snacks/hotdog(src)
		to_chat(user, "You make a hotdog.")
		qdel(W)
		qdel(src)

	// Bun + mouse = mouseburger
	else if(istype(W,/obj/item/reagent_containers/food/snacks/variable/mob))
		var/obj/item/reagent_containers/food/snacks/variable/mob/MF = W

		switch (MF.kitchen_tag)
			if ("rodent")
				result = new /obj/item/reagent_containers/food/snacks/mouseburger(src)
				to_chat(user, "You make a mouseburger!")

	if (result)
		if (W.reagents)
			//Reagents of reuslt objects will be the sum total of both.  Except in special cases where nonfood items are used
			//Eg robot head
			result.reagents.clear_reagents()
			W.reagents.trans_to(result, W.reagents.total_volume)
			reagents.trans_to(result, reagents.total_volume)

		//If the bun was in your hands, the result will be too
		if (loc == user)
			user.drop_from_inventory(src)
			user.put_in_hands(result)

/obj/item/reagent_containers/food/snacks/tortilla
	name = "tortilla"
	desc = "A thin, flour-based tortilla that can be used in a variety of dishes, or can be served as is."
	icon_state = "tortilla"
	bitesize = 3
	nutriment_desc = list("tortilla" = 1)
	center_of_mass_x = 16
	center_of_mass_y = 16
	nutriment_amt = 6

//Old_Chips Guide//////////////////////////////////////

//doesn't work

///obj/item/reagent_containers/food/snacks/chip
//	name = "chip"
//	desc = "A portion sized chip good for dipping."
//	icon_state = "chip"
//	var/bitten_state = "chip_half"
//	bitesize = 1
//	center_of_mass_x = 16
//	center_of_mass_y = 16
//	nutriment_desc = list("chips" = 1)
//	nutriment_amt = 2
//	flags = OPENCONTAINER

///obj/item/reagent_containers/food/snacks/chip/on_consume(mob/M as mob)
//	if(reagents && reagents.total_volume)
//		icon_state = bitten_state
//	. = ..()

//Chips//////////////////////////////////////

/obj/item/reagent_containers/food/snacks/chip
	name = "chip"
	desc = "A portion sized chip good for dipping."
	icon_state = "chip"

	bitesize = 1
	center_of_mass_x = 16
	center_of_mass_y = 16
	nutriment_desc = list("chips" = 1)
	nutriment_amt = 2
	flags = OPENCONTAINER

/obj/item/reagent_containers/food/snacks/nacho
	name = "chip"
	desc = "A portion sized chip good for dipping."
	icon_state = "chip"
	bitesize = 1
	center_of_mass_x = 16
	center_of_mass_y = 16
	nutriment_desc = list("nacho" = 1)
	nutriment_amt = 2
	flags = OPENCONTAINER

/obj/item/reagent_containers/food/snacks/chip/salsa
	name = "salsa chip"
	desc = "A portion sized chip good for dipping. This one has salsa on it."
	icon_state = "chip_salsa"

/obj/item/reagent_containers/food/snacks/chip/guac
	name = "guac chip"
	desc = "A portion sized chip good for dipping. This one has guac on it."
	icon_state = "chip_guac"

/obj/item/reagent_containers/food/snacks/chip/cheese
	name = "cheese chip"
	desc = "A portion sized chip good for dipping. This one has cheese sauce on it."
	icon_state = "chip_cheese"

/obj/item/reagent_containers/food/snacks/chip/nacho
	name = "nacho chip"
	desc = "A nacho ship stray from a plate of cheesy nachos."
	icon_state = "nacho"
	nutriment_desc = list("nacho chips" = 1)

/obj/item/reagent_containers/food/snacks/chip/nacho/salsa
	name = "nacho chip"
	desc = "A nacho ship stray from a plate of cheesy nachos. This one has salsa on it."
	icon_state = "nacho_salsa"

/obj/item/reagent_containers/food/snacks/chip/nacho/guac
	name = "nacho chip"
	desc = "A nacho ship stray from a plate of cheesy nachos. This one has guac on it."
	icon_state = "nacho_guac"

/obj/item/reagent_containers/food/snacks/chip/nacho/cheese
	name = "nacho chip"
	desc = "A nacho ship stray from a plate of cheesy nachos. This one has extra cheese on it."
	icon_state = "nacho_cheese"

//Chip Baskets//////////////////////////////////////

/obj/item/reagent_containers/food/snacks/chipplate
	name = "basket of chips"
	desc = "A plate of chips intended for dipping."
	icon_state = "chip_basket"
	trash = /obj/item/trash/chipbasket
	var/vendingobject = /obj/item/reagent_containers/food/snacks/chip
	nutriment_desc = list("tortilla chips" = 10)
	bitesize = 1
	nutriment_amt = 10

/obj/item/reagent_containers/food/snacks/chipplate/attack_hand(mob/user as mob)
	var/obj/item/reagent_containers/food/snacks/returningitem = new vendingobject(loc)
	reagents.trans_to(returningitem, bitesize)
	returningitem.bitesize = 2
	user.put_in_hands(returningitem)
	if (reagents && reagents.total_volume)
		to_chat(user, "You take a chip from the plate.")
	else
		to_chat(user, "You take the last chip from the plate.")
		var/obj/waste = new trash(loc)
		if (loc == user)
			user.put_in_hands(waste)
		qdel(src)

/obj/item/reagent_containers/food/snacks/chipplate/MouseDrop(mob/user) //Dropping the chip onto the user
	if(istype(user) && user == usr)
		user.put_in_active_hand(src)
		src.pickup(user)
		return
	. = ..()

/obj/item/reagent_containers/food/snacks/chipplate/nachos
	name = "basket of nachos"
	desc = "A very cheesy basket of nacho."
	icon_state = "nachos"
	trash = /obj/item/trash/chipbasket
	vendingobject = /obj/item/reagent_containers/food/snacks/chip/nacho
	nutriment_desc = list("tortilla chips" = 10)
	bitesize = 1
	nutriment_amt = 14 //slightly better than just plain chips

//Dips//////////////////////////////////////

/obj/item/reagent_containers/food/snacks/dip
	name = "queso dip"
	desc = "A simple, cheesy dip consisting of tomatos, cheese, and spices."
	var/nachotrans = /obj/item/reagent_containers/food/snacks/chip/nacho/cheese
	var/chiptrans = /obj/item/reagent_containers/food/snacks/chip/cheese
	icon_state = "dip_cheese"
	trash = /obj/item/trash/small_bowl
	bitesize = 1
	nutriment_desc = list("queso" = 20)
	center_of_mass_x = 16
	center_of_mass_y = 16
	nutriment_amt = 20

/obj/item/reagent_containers/food/snacks/dip/attackby(obj/item/reagent_containers/food/snacks/item as obj, mob/user as mob)
	. = ..()
	var/obj/item/reagent_containers/food/snacks/returningitem
	if(istype(item,/obj/item/reagent_containers/food/snacks/chip/nacho) && item.icon_state == "chip_nacho")
		returningitem = new nachotrans(src)
	else if (istype(item,/obj/item/reagent_containers/food/snacks/chip) && (item.icon_state == "chip" || item.icon_state == "chip_half"))
		returningitem = new chiptrans(src)
	if(returningitem)
		returningitem.reagents.clear_reagents() //Clear the new chip
		var/memed = 0
		item.reagents.trans_to(returningitem, item.reagents.total_volume) //Old chip to new chip
		if(item.icon_state == "chip_half")
			returningitem.icon_state = "[returningitem.icon_state]_half"
			returningitem.bitesize = clamp(returningitem.reagents.total_volume,1,10)
		else if(prob(1))
			memed = 1
			to_chat(user, "You scoop up some dip with the chip, but mid-scop, the chip breaks off into the dreadful abyss of dip, never to be seen again...")
			returningitem.icon_state = "[returningitem.icon_state]_half"
			returningitem.bitesize = clamp(returningitem.reagents.total_volume,1,10)
		else
			returningitem.bitesize = clamp(returningitem.reagents.total_volume*0.5,1,10)
		qdel(item)
		reagents.trans_to(returningitem, bitesize) //Dip to new chip
		user.put_in_hands(returningitem)

		if (reagents && reagents.total_volume)
			if(!memed)
				to_chat(user, "You scoop up some dip with the chip.")
		else
			if(!memed)
				to_chat(user, "You scoop up the remaining dip with the chip.")
			var/obj/waste = new trash(loc)
			if (loc == user)
				user.put_in_hands(waste)
			qdel(src)

/obj/item/reagent_containers/food/snacks/dip/salsa
	name = "salsa dip"
	desc = "Traditional Sol chunky salsa dip containing tomatos, peppers, and spices."
	nachotrans = /obj/item/reagent_containers/food/snacks/chip/nacho/salsa
	chiptrans = /obj/item/reagent_containers/food/snacks/chip/salsa
	icon_state = "dip_salsa"
	nutriment_desc = list("salsa" = 20)
	nutriment_amt = 20

/obj/item/reagent_containers/food/snacks/dip/guac
	name = "guac dip"
	desc = "A recreation of the ancient Sol 'Guacamole' dip using tofu, limes, and spices. This recreation obviously leaves out mole meat."
	nachotrans = /obj/item/reagent_containers/food/snacks/chip/nacho/guac
	chiptrans = /obj/item/reagent_containers/food/snacks/chip/guac
	icon_state = "dip_guac"
	nutriment_desc = list("guacmole" = 20)
	nutriment_amt = 20

//Burritos//////////////////////////////////////

/obj/item/reagent_containers/food/snacks/fuegoburrito
	name = "fuego phoron burrito"
	desc = "A super spicy vegetarian burrito."
	icon_state = "fuegoburrito"
	nutriment_amt = 6
	nutriment_desc = list("chilli peppers" = 5, "tortilla" = 1)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/fuegoburrito/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_CAPSAICIN, 4)

/obj/item/reagent_containers/food/snacks/meatburrito
	name = "carne asada burrito"
	desc = "Sliced meat and beans, it's another basic burrito!"
	icon_state = "carneburrito"
	nutriment_amt = 6
	nutriment_desc = list("tortilla" = 3, "meat" = 3)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/meatburrito/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 6)

/obj/item/reagent_containers/food/snacks/cheeseburrito
	name = "Cheese burrito"
	desc = "It's a burrito filled with beans and cheese."
	icon_state = "cheeseburrito"
	nutriment_amt = 6
	nutriment_desc = list("tortilla" = 3, REAGENT_ID_CHEESE = 3)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/cheeseburrito/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 2)

/obj/item/reagent_containers/food/snacks/eggroll
	name = "egg roll"
	desc = "Free with orders over 10 thalers."
	icon_state = "eggroll"
	filling_color = "#799ACE"
	center_of_mass_x = 17
	center_of_mass_y = 4
	nutriment_amt = 4
	nutriment_desc = list(REAGENT_ID_EGG = 4)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/eggroll/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 2)

/obj/item/reagent_containers/food/snacks/burrito
	name = "chilli burrito"
	desc = "Minced meat wrapped in a flour tortilla. It's a burrito by definition."
	icon_state = "burrito"
	bitesize = 4
	center_of_mass_x = 16
	center_of_mass_y = 16
	nutriment_desc = list("tortilla" = 6)
	nutriment_amt = 6

/obj/item/reagent_containers/food/snacks/burrito/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 4)

/obj/item/reagent_containers/food/snacks/burrito_spicy
	name = "spicy burrito"
	desc = "Spicy meat wrapped in a flour tortilla."
	icon_state = "spicyburrito"
	bitesize = 4
	center_of_mass_x = 16
	center_of_mass_y = 16
	nutriment_desc = list("tortilla" = 6)
	nutriment_amt = 6

/obj/item/reagent_containers/food/snacks/burrito_spicy/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 6)

/obj/item/reagent_containers/food/snacks/burrito_cheese
	name = "carne queso burrito"
	desc = "Meat and melted cheese wrapped in a flour tortilla."
	icon_state = "cheesemeatburrito"
	bitesize = 4
	center_of_mass_x = 16
	center_of_mass_y = 16
	nutriment_desc = list("tortilla" = 6)
	nutriment_amt = 6

/obj/item/reagent_containers/food/snacks/burrito_cheese/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 6)

/obj/item/reagent_containers/food/snacks/burrito_cheese_spicy
	name = "spicy cheese burrito"
	desc = "Melted cheese, beans and chillis wrapped in a flour tortilla."
	icon_state = "spicycheesemeatburrito"
	bitesize = 4
	center_of_mass_x = 16
	center_of_mass_y = 16
	nutriment_desc = list("tortilla" = 6)
	nutriment_amt = 6

/obj/item/reagent_containers/food/snacks/burrito_cheese_spicy/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 6)

/obj/item/reagent_containers/food/snacks/burrito_vegan
	name = "vegan burrito"
	desc = "Tofu wrapped in a flour tortilla."
	icon_state = "veganburrito"
	bitesize = 4
	center_of_mass_x = 16
	center_of_mass_y = 16
	nutriment_desc = list("tortilla" = 6)
	nutriment_amt = 6

/obj/item/reagent_containers/food/snacks/burrito_vegan/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_TOFU, 6)

/obj/item/reagent_containers/food/snacks/breakfast_wrap
	name = "breakfast wrap"
	desc = "Bacon, eggs, cheese, and tortilla grilled to perfection."
	icon_state = "breakfastwrap"
	bitesize = 4
	center_of_mass_x = 16
	center_of_mass_y = 16
	nutriment_desc = list("tortilla" = 6)
	nutriment_amt = 6

/obj/item/reagent_containers/food/snacks/burrito_mystery
	name = "mystery meat burrito"
	desc = "The mystery is, why aren't you BSAing it?"
	icon_state = "mysteryburrito"
	bitesize = 5
	center_of_mass_x = 16
	center_of_mass_y = 16
	nutriment_desc = list("regret" = 6)
	nutriment_amt = 6

/obj/item/reagent_containers/food/snacks/burrito_hell
	name = "el diablo"
	desc = "Meat and an insane amount of chillis packed in a flour tortilla. The " + JOB_CHAPLAIN + " will see you now."
	icon_state = "hellfireburrito"
	bitesize = 4
	center_of_mass_x = 16
	center_of_mass_y = 16
	nutriment_desc = list("hellfire" = 6)
	nutriment_amt = 24// 10 Chilis is a lot.

/obj/item/reagent_containers/food/snacks/burrito_hell/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 9)
	reagents.add_reagent(REAGENT_ID_CONDENSEDCAPSAICIN, 10) //what could possibly go wrong

//End Burritos///////////////////////////////////

/obj/item/reagent_containers/food/snacks/hatchling_suprise
	name = "hatchling suprise"
	desc = "A poached egg on top of three slices of bacon. A typical breakfast for hungry Unathi children."
	icon_state = "hatchling_suprise"
	trash = /obj/item/trash/snack_bowl

/obj/item/reagent_containers/food/snacks/hatchling_suprise/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_EGG, 2)
	reagents.add_reagent(REAGENT_ID_PROTEIN, 4)

/obj/item/reagent_containers/food/snacks/red_sun_special
	name = "red sun special"
	desc = "One lousy piece of sausage sitting on melted cheese curds. A popular utilitarian meal for the Unathi of Moghes."
	icon_state = "red_sun_special"
	trash = /obj/item/trash/plate

/obj/item/reagent_containers/food/snacks/red_sun_special/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 2)

/obj/item/reagent_containers/food/snacks/riztizkzi_sea
	name = "moghesian sea delight"
	desc = "Three raw eggs floating in a sea of blood. An authentic replication of an ancient Unathi delicacy."
	icon_state = "riztizkzi_sea"
	trash = /obj/item/trash/snack_bowl

/obj/item/reagent_containers/food/snacks/riztizkzi_sea/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_EGG, 4)

/obj/item/reagent_containers/food/snacks/father_breakfast
	name = "breakfast of champions"
	desc = "A sausage and an omelette on top of a grilled steak."
	icon_state = "father_breakfast"
	trash = /obj/item/trash/plate

/obj/item/reagent_containers/food/snacks/father_breakfast/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_EGG, 4)
	reagents.add_reagent(REAGENT_ID_PROTEIN, 6)

/obj/item/reagent_containers/food/snacks/stuffed_meatball
	name = "stuffed meatball" //YES
	desc = "A meatball loaded with cheese."
	icon_state = "stuffed_meatball"
	trash = /obj/item/trash/small_bowl

/obj/item/reagent_containers/food/snacks/stuffed_meatball/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 4)

/obj/item/reagent_containers/food/snacks/egg_pancake
	name = "meat pancake"
	desc = "An omelette baked on top of a giant meat patty. This monstrousity is typically shared between four people during a dinnertime meal."
	icon_state = "egg_pancake"
	trash = /obj/item/trash/plate

/obj/item/reagent_containers/food/snacks/egg_pancake/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 6)
	reagents.add_reagent(REAGENT_ID_EGG, 2)

/obj/item/reagent_containers/food/snacks/redcurry
	name = "red curry"
	gender = PLURAL
	desc = "A bowl of creamy red curry with meat and rice. This one looks savory."
	icon_state = "redcurry"
	trash = /obj/item/trash/snack_bowl
	filling_color = "#f73333"
	nutriment_amt = 8
	nutriment_desc = list("savory meat and rice" = 8)
	center_of_mass_x = 16
	center_of_mass_y = 8
	bitesize = 3

/obj/item/reagent_containers/food/snacks/redcurry/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 7)

/obj/item/reagent_containers/food/snacks/greencurry
	name = "green curry"
	gender = PLURAL
	desc = "A bowl of creamy green curry with tofu, hot peppers and rice. This one looks spicy!"
	icon_state = "greencurry"
	trash = /obj/item/trash/snack_bowl
	filling_color = "#58b76c"
	nutriment_amt = 12
	nutriment_desc = list("tofu and rice" = 12)
	center_of_mass_x = 16
	center_of_mass_y = 8
	bitesize = 3

/obj/item/reagent_containers/food/snacks/greencurry/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 1)
	reagents.add_reagent(REAGENT_ID_CAPSAICIN, 2)

/obj/item/reagent_containers/food/snacks/yellowcurry
	name = "yellow curry"
	gender = PLURAL
	desc = "A bowl of creamy yellow curry with potatoes, peanuts and rice. This one looks mild."
	icon_state = "yellowcurry"
	trash = /obj/item/trash/snack_bowl
	filling_color = "#bc9509"
	nutriment_amt = 13
	nutriment_desc = list("rice and potatoes" = 13)
	center_of_mass_x = 16
	center_of_mass_y = 8
	bitesize = 3

/obj/item/reagent_containers/food/snacks/yellowcurry/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 2)

/obj/item/reagent_containers/food/snacks/bearburger
	name = "bearburger"
	desc = "The solution to your unbearable hunger."
	icon_state = "bearburger"
	filling_color = "#5d5260"
	center_of_mass_x = 15
	center_of_mass_y = 11
	bitesize = 5

/obj/item/reagent_containers/food/snacks/bearburger/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 4) //So spawned burgers will not be empty I guess?

/obj/item/reagent_containers/food/snacks/bibimbap
	name = "bibimbap bowl"
	desc = "A traditional Korean meal of meat and mixed vegetables. It's served on a bed of rice, and topped with a fried egg."
	icon_state = "bibimbap"
	trash = /obj/item/trash/snack_bowl
	filling_color = "#4f2100"
	nutriment_amt = 10
	nutriment_desc = list(REAGENT_ID_EGG = 5, "vegetables" = 5)
	center_of_mass_x = 15
	center_of_mass_y = 9
	bitesize = 4

/obj/item/reagent_containers/food/snacks/bibimbap/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 10)

/obj/item/reagent_containers/food/snacks/lomein
	name = "lo mein"
	gender = PLURAL
	desc = "A popular Chinese noodle dish. Chopsticks optional."
	icon_state = "lomein"
	trash = /obj/item/trash/plate
	filling_color = "#FCEE81"
	nutriment_amt = 8
	nutriment_desc = list("noodles" = 6, "sesame sauce" = 2)
	center_of_mass_x = 16
	center_of_mass_y = 10
	bitesize = 2

/obj/item/reagent_containers/food/snacks/lomein/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 2)

/obj/item/reagent_containers/food/snacks/friedrice
	name = "fried rice"
	gender = PLURAL
	desc = "A less-boring dish of less-boring rice!"
	icon_state = "friedrice"
	trash = /obj/item/trash/snack_bowl
	filling_color = "#FFFBDB"
	nutriment_amt = 7
	nutriment_desc = list(REAGENT_ID_RICE = 7)
	center_of_mass_x = 17
	center_of_mass_y = 11
	bitesize = 2

/obj/item/reagent_containers/food/snacks/chickenfillet
	name = "chicken fillet sandwich"
	desc = "Fried chicken, in sandwich format. Beauty is simplicity."
	icon_state = "chickenfillet"
	filling_color = "#E9ADFF"
	nutriment_amt = 4
	nutriment_desc = list("breading" = 4)
	center_of_mass_x = 16
	center_of_mass_y = 16
	bitesize = 3

/obj/item/reagent_containers/food/snacks/chickenfillet/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 8)

/obj/item/reagent_containers/food/snacks/friedmushroom
	name = "fried mushroom"
	desc = "A tender, beer-battered plump helmet, fried to crispy perfection."
	icon_state = "friedmushroom"
	filling_color = "#EDDD00"
	nutriment_amt = 4
	nutriment_desc = list("alcoholic mushrooms" = 4)
	center_of_mass_x = 16
	center_of_mass_y = 11
	bitesize = 5

/obj/item/reagent_containers/food/snacks/friedmushroom/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 2)

/obj/item/reagent_containers/food/snacks/pisanggoreng
	name = "pisang goreng"
	gender = PLURAL
	desc = "Crispy, starchy, sweet banana fritters. Popular street food in parts of Sol."
	icon_state = "pisanggoreng"
	trash = /obj/item/trash/plate
	filling_color = "#301301"
	nutriment_amt = 8
	nutriment_desc = list("sweet bananas" = 8)
	center_of_mass_x = 16
	center_of_mass_y = 11
	bitesize = 3

/obj/item/reagent_containers/food/snacks/pisanggoreng/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 1)

/obj/item/reagent_containers/food/snacks/meatbun
	name = "meat and leaf bun"
	desc = "A soft, fluffy flour bun also known as baozi. This one is filled with a meat and cabbage filling."
	filling_color = "#DEDEAB"
	icon_state = "meatbun"
	nutriment_amt = 5
	nutriment_desc = list("fried meat" = 5)
	center_of_mass_x = 16
	center_of_mass_y = 11
	bitesize = 2

/obj/item/reagent_containers/food/snacks/meatbun/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 4)

/obj/item/reagent_containers/food/snacks/spicedmeatbun
	name = "char sui meat bun"
	desc = "A soft, fluffy flour bun also known as baozi. This one is filled with a traditionally spiced meat filling."
	filling_color = "#EDD7D7"
	icon_state = "meatbun"
	nutriment_amt = 5
	nutriment_desc = list("char sui" = 5)
	center_of_mass_x = 16
	center_of_mass_y = 11
	bitesize = 5

/obj/item/reagent_containers/food/snacks/spicedmeatbun/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 3)

/obj/item/reagent_containers/food/snacks/custardbun
	name = "custard bun"
	desc = "A soft, fluffy flour bun also known as baozi. This one is filled with an egg custard."
	filling_color = "#EBEDC2"
	icon_state = "meatbun"
	nutriment_amt = 6
	nutriment_desc = list("egg custard" = 6)
	center_of_mass_x = 16
	center_of_mass_y = 11
	bitesize = 6

/obj/item/reagent_containers/food/snacks/chickenmomo
	name = "chicken momo"
	gender = PLURAL
	desc = "A plate of spiced and steamed chicken dumplings. The style originates from south Asia."
	icon_state = "momo"
	trash = /obj/item/trash/snacktray
	filling_color = "#edd7d7"
	nutriment_amt = 9
	nutriment_desc = list("spiced chicken" = 9)
	center_of_mass_x = 15
	center_of_mass_y = 9
	bitesize = 3

/obj/item/reagent_containers/food/snacks/chickenmomo/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 6)

/obj/item/reagent_containers/food/snacks/veggiemomo
	name = "veggie momo"
	gender = PLURAL
	desc = "A plate of spiced and steamed vegetable dumplings. The style originates from south Asia."
	icon_state = "momo"
	trash = /obj/item/trash/snacktray
	filling_color = "#edd7d7"
	nutriment_amt = 13
	nutriment_desc = list("spiced vegetables" = 13)
	center_of_mass_x = 15
	center_of_mass_y = 9
	bitesize = 3

/obj/item/reagent_containers/food/snacks/veggiemomo/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 2)

/obj/item/reagent_containers/food/snacks/risotto
	name = "risotto"
	gender = PLURAL
	desc = "A creamy, savory rice dish from southern Europe, typically cooked slowly with wine and broth. This one has bits of mushroom."
	icon_state = "risotto"
	trash = /obj/item/trash/snack_bowl
	filling_color = "#edd7d7"
	nutriment_amt = 9
	nutriment_desc = list("savory rice" = 6, REAGENT_ID_CREAM = 3)
	center_of_mass_x = 15
	center_of_mass_y = 9
	bitesize = 2

/obj/item/reagent_containers/food/snacks/risotto/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 1)

/obj/item/reagent_containers/food/snacks/risottoballs
	name = "risotto balls"
	gender = PLURAL
	desc = "Mushroom risotto that has been battered and deep fried. The best use of leftovers!"
	icon_state = "risottoballs"
	trash = /obj/item/trash/snack_bowl
	filling_color = "#edd7d7"
	nutriment_amt = 1
	nutriment_desc = list(REAGENT_ID_BATTER = 1)
	center_of_mass_x = 15
	center_of_mass_y = 9
	bitesize = 3

/obj/item/reagent_containers/food/snacks/poachedegg
	name = "poached egg"
	desc = "A delicately poached egg with a runny yolk. Healthier than its fried counterpart."
	icon_state = "poachedegg"
	trash = /obj/item/trash/plate
	filling_color = "#FFDF78"
	nutriment_amt = 1
	nutriment_desc = list(REAGENT_ID_EGG = 1)
	center_of_mass_x = 16
	center_of_mass_y = 14
	bitesize = 2

/obj/item/reagent_containers/food/snacks/poachedegg/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 3)
	reagents.add_reagent(REAGENT_ID_BLACKPEPPER, 1)

/obj/item/reagent_containers/food/snacks/ribplate
	name = "plate of ribs"
	desc = "A half-rack of ribs, brushed with some sort of honey-glaze. Why are there no napkins on board?"
	icon_state = "ribplate"
	trash = /obj/item/trash/plate
	filling_color = "#7A3D11"
	nutriment_amt = 6
	nutriment_desc = list(REAGENT_ID_BARBECUE = 6)
	center_of_mass_x = 16
	center_of_mass_y = 13
	bitesize = 4

/obj/item/reagent_containers/food/snacks/ribplate/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 6)
	reagents.add_reagent(REAGENT_ID_TRIGLYCERIDE, 2)
	reagents.add_reagent(REAGENT_ID_BLACKPEPPER, 1)
	reagents.add_reagent(REAGENT_ID_HONEY, 5)

/obj/item/reagent_containers/food/snacks/omurice
	name = "omelette rice"
	desc = "Just like your Japanese animes!"
	icon = 'icons/obj/food.dmi'
	icon_state = "omurice"
	trash = /obj/item/trash/plate
	nutriment_amt = 8
	nutriment_desc = list(REAGENT_ID_RICE = 4, REAGENT_ID_EGG = 4)
	bitesize = 1

/obj/item/reagent_containers/food/snacks/omurice/heart
	name = "omelette rice (Love)"
	icon = 'icons/obj/food.dmi'
	icon_state = "omuriceheart"

/obj/item/reagent_containers/food/snacks/omurice/face
	name = "omelette rice (Cute)"
	icon = 'icons/obj/food.dmi'
	icon_state = "omuriceface"

/obj/item/reagent_containers/food/snacks/cinnamonbun
	name = "cinnamon bun"
	desc = "Life needs frosting!"
	icon = 'icons/obj/food.dmi'
	icon_state = "cinnamonbun"
	trash = null
	nutriment_amt = 8
	nutriment_desc = list("cinnamon sugar" = 4, "frosting" = 4)
	bitesize = 1

////////////////////////////////////////////////////////////////////////////
//////////////////////////////Candy Vend Items//////////////////////////////
////////////////////////////////////////////////////////////////////////////

/obj/item/reagent_containers/food/snacks/mint
	name = REAGENT_ID_MINT
	desc = "it is only wafer thin."
	icon_state = "mint"
	filling_color = "#F2F2F2"
	center_of_mass_x = 16
	center_of_mass_y = 14
	bitesize = 1

/obj/item/reagent_containers/food/snacks/mint/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_MINT, 1)

/obj/item/reagent_containers/food/snacks/mint/admints
	desc = "Spearmint, peppermint's non-festive cousin."
	icon = 'icons/obj/food_snacks.dmi'
	icon_state = "admint"

/obj/item/storage/box/admints
	name = "Ad-mints"
	desc = "A pack of air fresheners for your mouth."
	description_fluff = "Ad-mints earned their name, and reputation when a Major Bill's senior executive attended a meeting at a large a marketing firm and was so astounded by the quality of their complimentary mints, that he immediately bought the company - the mints company, not the ad agency - and began providing 'Ad-mints' on every MBT flight."
	icon = 'icons/obj/food_snacks.dmi'
	icon_state = "admint_pack"
	item_state = "candy"
	slot_flags = SLOT_EARS
	w_class = 1
	starts_with = list(/obj/item/reagent_containers/food/snacks/mint/admints = 6)
	can_hold = list(/obj/item/reagent_containers/food/snacks/mint/admints)
	use_sound = 'sound/items/drop/paper.ogg'
	drop_sound = 'sound/items/drop/wrapper.ogg'
	max_storage_space = 6
	foldable = null
	trash = /obj/item/trash/admints

/obj/item/reagent_containers/food/snacks/candy
	name = "\improper Grandma Ellen's Candy Bar"
	desc = "Now without nuts!"
	description_fluff = "Hard candies were banned from many early human colony ships due to the tendency for brittle, sticky chunks to find their way inside vital equipment in zero-G conditions. This only made them all the more popular to new arrivees, and the Grandpa Elliot's brand was Tau Ceti's answer to that demand."
	icon = 'icons/obj/food_snacks.dmi'
	icon_state = "candy"
	trash = /obj/item/trash/candy
	filling_color = "#7D5F46"
	center_of_mass_x = 15
	center_of_mass_y = 15
	nutriment_amt = 1
	nutriment_desc = list("candy" = 1)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/candy/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_SUGAR, 3)

/obj/item/reagent_containers/food/snacks/namagashi
	name = "\improper Ryo-kucha Namagashi"
	desc = "Sweet Japanese gummy like candy that are just bursting with flavor!"
	icon = 'icons/obj/food_snacks.dmi'
	icon_state = "namagashi"
	trash = /obj/item/trash/namagashi
	filling_color = "#7D5F46"
	center_of_mass_x = 15
	center_of_mass_y = 15
	nutriment_amt = 1
	nutriment_desc = list("candy" = 2, "sweetness" = 2)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/namagashi/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_SUGAR, 2)

/obj/item/reagent_containers/food/snacks/candy/proteinbar
	name = "\improper SwoleMAX protein bar"
	desc = "Guaranteed to get you feeling perfectly overconfident."
	description_fluff = "NanoMed's SwoleMAX boasts the highest density of protein mush per square inch among leading protein bar brands. While formulated for strength training, this high nutrient density in a mostly-solid form makes SwoleMAX a popular alternative for spacers looking to mix up their usual diet of pastes and gooes."
	icon = 'icons/obj/food_snacks.dmi'
	icon_state = "proteinbar"
	trash = /obj/item/trash/candy/proteinbar
	nutriment_amt = 9
	nutriment_desc = list("candy" = 1, REAGENT_ID_PROTEIN = 8)
	bitesize = 6

/obj/item/reagent_containers/food/snacks/candy/proteinbar/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 4)
	reagents.add_reagent(REAGENT_ID_SUGAR, 4)

/obj/item/reagent_containers/food/snacks/candy/gummy
	name = "\improper AlliCo Gummies"
	desc = "Somehow, there's never enough cola bottles."
	description_fluff = "AlliCo's grab-bags of gummy candies come in over a thousand novelty shapes and dozens of flavours. Shoes, astronauts, bunny rabbits and singularities all make an appearance."
	icon = 'icons/obj/food_snacks.dmi'
	icon_state = "candy_gums"
	trash = /obj/item/trash/candy/gums
	nutriment_amt = 5
	nutriment_desc = list("artificial fruit flavour" = 2)
	bitesize = 1

/obj/item/reagent_containers/food/snacks/candy/gummy/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_SUGAR, 5)

/obj/item/reagent_containers/food/snacks/cookiesnack
	name = "Carps Ahoy! miniature cookies"
	desc = "Now 100% carpotoxin free!"
	description_fluff = "Carps Ahoy! cookies are required to sell under the 'Cap'n Choco' name in certain markets, out of concerns that children will become desensitized to the very real dangers of Space Carp."
	icon = 'icons/obj/food_snacks.dmi'
	icon_state = "cookiesnack"
	trash = /obj/item/trash/cookiesnack
	filling_color = "#DBC94F"
	nutriment_amt = 3
	nutriment_desc = list("sweetness" = 1, "stale cookie" = 2)
	bitesize = 1

/obj/item/reagent_containers/food/snacks/fruitbar
	name = "\improper ChewMAX fruit bar"
	desc = "Guaranteed to get you feeling comfortably superior."
	description_fluff = "NanoMed's ChewMAX is the low-carb alternative to the SwoleMAX range! Want short-term energy but not really interested in sustaining it? Hate fat but don't entirely understand nutrition? Just really like fruit? ChewMAX is for you!"
	icon = 'icons/obj/food_snacks.dmi'
	icon_state = "fruitbar"
	trash = /obj/item/trash/candy/fruitbar
	nutriment_amt = 13
	nutriment_desc = list("apricot" = 2, REAGENT_ID_SUGAR = 2, "dates" = 2, "cranberry" = 2, PLANT_APPLE = 2)
	bitesize = 6

/obj/item/reagent_containers/food/snacks/fruitbar/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_SUGAR, 4)

/////////////////////////////////////////////////////////////////////////////
//////////////////////////////Candy Bars (1-10)//////////////////////////////
/////////////////////////////////////////////////////////////////////////////

/obj/item/reagent_containers/food/snacks/cb01
	name = "\improper Tau Ceti Bar"
	desc = "A dark chocolate caramel and nougat bar made famous on Binma."
	description_fluff = "Binma's signature chocolate bar, the Tau Ceti Bar was originally made with cheap, heavily preserved ingredients available to Sol's first colonists. The modern recipe attempts to recreate this, baffling many not accustomed to its slightly stale taste."
	filling_color = "#552200"
	icon = 'icons/obj/food_snacks.dmi'
	icon_state = "cb01"
	trash = /obj/item/trash/candy/cb01
	nutriment_amt = 4
	nutriment_desc = list("stale chocolate" = 2, "nougat" = 1, "caramel" = 1)
	w_class = 1
	bitesize = 2

/obj/item/reagent_containers/food/snacks/cb01/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_SUGAR, 1)

/obj/item/reagent_containers/food/snacks/cb02
	name = "\improper Hundred-Thousand Thaler Bar"
	desc = "An ironically cheap puffed rice caramel milk chocolate bar."
	description_fluff = "The Hundred-Thousand Thaler bar has been the focal point of dozens of exonet and radio giveaway pranks over its long history. In 2260 the company got in on the action, offering a prize of one-hundred thousand one-hundred thousand thaler bars to one lucky entrant, who reportedly turned down the prize in favour of a 250 Thaler cash prize."
	filling_color = "#552200"
	icon = 'icons/obj/food_snacks.dmi'
	icon_state = "cb02"
	trash = /obj/item/trash/candy/cb02
	nutriment_amt = 4
	nutriment_desc = list(REAGENT_ID_CHOCOLATE = 2, "caramel" = 1, "puffed rice" = 1)
	w_class = 1
	bitesize = 2

/obj/item/reagent_containers/food/snacks/cb02/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_SUGAR, 1)

/obj/item/reagent_containers/food/snacks/cb03
	name = "\improper Aerostat Bar"
	desc = "Bubbly milk chocolate."
	description_fluff = "An early slogan claimed the chocolate's bubbles where made with 'real Venusian gases', which is thought to have seriously harmed sales. The claim remains true, since the main production plant remains on Venus, but the company tries to avoid association with toxic air."
	filling_color = "#552200"
	icon = 'icons/obj/food_snacks.dmi'
	icon_state = "cb03"
	trash = /obj/item/trash/candy/cb03
	nutriment_amt = 4
	nutriment_desc = list(REAGENT_ID_CHOCOLATE = 4)
	w_class = 1
	bitesize = 2

/obj/item/reagent_containers/food/snacks/cb03/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_SUGAR, 1)

/obj/item/reagent_containers/food/snacks/cb04
	name = "\improper Lars' Saltlakris"
	desc = "Milk chocolate embedded with chunks of salty licorice."
	description_fluff = "Produced exclusively in Kalmar for sale in Vir, Lars' Saltlakris is one of the system's most popular home-grown confectionaries."
	filling_color = "#552200"
	icon = 'icons/obj/food_snacks.dmi'
	icon_state = "cb04"
	trash = /obj/item/trash/candy/cb04
	nutriment_amt = 4
	nutriment_desc = list(REAGENT_ID_CHOCOLATE = 2, "salt = 1", "licorice" = 1)
	w_class = 1
	bitesize = 2

/obj/item/reagent_containers/food/snacks/cb04/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_SUGAR, 1)

/obj/item/reagent_containers/food/snacks/cb05
	name = "\improper Andromeda Bar"
	desc = "A cheap milk chocolate bar loaded with sugar."
	description_fluff = "The galaxy's top-selling chocolate brand for almost 400 years. Also comes in dozens of varieties, including caramel, cookie, fruit and nut, and almond. This is just the basic stuff, though."
	filling_color = "#552200"
	icon = 'icons/obj/food_snacks.dmi'
	icon_state = "cb05"
	trash = /obj/item/trash/candy/cb05
	nutriment_amt = 3
	nutriment_desc = list("milk chocolate" = 2)
	w_class = 1
	bitesize = 3

/obj/item/reagent_containers/food/snacks/cb05/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_SUGAR, 3)

/obj/item/reagent_containers/food/snacks/cb06
	name = "\improper Mocha Crunch"
	desc = "A large latte flavored wafer chocolate bar."
	description_fluff = "Lightly caffeinated, the Mocha Crunch is often considered to be more of an authentic coffee taste than most vending machine coffees."
	filling_color = "#552200"
	icon = 'icons/obj/food_snacks.dmi'
	icon_state = "cb06"
	trash = /obj/item/trash/candy/cb06
	nutriment_amt = 4
	nutriment_desc = list(REAGENT_ID_CHOCOLATE = 2, REAGENT_ID_COFFEE = 1, "vanilla wafer" = 1)
	w_class = 1
	bitesize = 3

/obj/item/reagent_containers/food/snacks/cb06/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_SUGAR, 1)
	reagents.add_reagent(REAGENT_ID_COFFEE, 1)

/obj/item/reagent_containers/food/snacks/cb07
	name = "\improper TaroMilk Bar"
	desc = "A light milk chocolate shell with a Taro paste filling. Chewy!"
	description_fluff = "The best-selling Kishari snack finally made its way to the galactic stage in 2318. Whether it is here to stay remains to be seen, though it has found some popularity with the Skrell.."
	filling_color = "#552200"
	icon = 'icons/obj/food_snacks.dmi'
	icon_state = "cb07"
	trash = /obj/item/trash/candy/cb07
	nutriment_amt = 4
	nutriment_desc = list(REAGENT_ID_CHOCOLATE = 2, "taro" = 2)
	w_class = 1
	bitesize = 3

/obj/item/reagent_containers/food/snacks/cb07/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_SUGAR, 1)

/obj/item/reagent_containers/food/snacks/cb08
	name = "\improper Cronk Bar"
	desc = "A large puffed malt milk chocolate bar."
	description_fluff = "The Cronk Bar proudly 'Comes in one flavour, so you'll never pick the wrong one!'. Its enduring popularity may be in part due to a longstanding deal with the SCG Fleet to include Cronk in standard military rations."
	filling_color = "#552200"
	icon = 'icons/obj/food_snacks.dmi'
	icon_state = "cb08"
	trash = /obj/item/trash/candy/cb08
	nutriment_amt = 3
	nutriment_desc = list(REAGENT_ID_CHOCOLATE = 2, "malt puffs" = 1)
	w_class = 1
	bitesize = 3

/obj/item/reagent_containers/food/snacks/cb08/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_SUGAR, 2)

/obj/item/reagent_containers/food/snacks/cb09
	name = "\improper Kaju Mamma! Bar"
	desc = "A massive cluster of cashews and peanuts covered in a condensed milk solid."
	description_fluff = "Based on traditional South Asian desserts, the Kaju Mamma! is a deceptively soft, sweet bar voted 'Most allergenic candy' nineteen years running."
	filling_color = "#552200"
	icon = 'icons/obj/food_snacks.dmi'
	icon_state = "cb09"
	trash = /obj/item/trash/candy/cb09
	nutriment_amt = 6
	nutriment_desc = list("peanuts" = 3, "condensed milk" = 1, "cashews" = 2)
	w_class = 1
	bitesize = 3

/obj/item/reagent_containers/food/snacks/cb09/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_SUGAR, 1)
	reagents.add_reagent(REAGENT_ID_MILK, 1)
	reagents.add_reagent(REAGENT_ID_PEANUTOIL, 1)

/obj/item/reagent_containers/food/snacks/cb10
	name = "\improper Shantak Bar"
	desc = "Nuts, nougat, peanuts, and caramel covered in chocolate."
	description_fluff = "Despite being often mistaken for a regional favourite, the Shantak Bar is sold under different 'localized' names in almost every human system in the galaxy, and adds up to being the third best selling confection produced by Centauri Provisions."
	filling_color = "#552200"
	icon = 'icons/obj/food_snacks.dmi'
	icon_state = "cb10"
	trash = /obj/item/trash/candy/cb10
	nutriment_amt = 5
	nutriment_desc = list(REAGENT_ID_CHOCOLATE = 2, "caramel" = 1, "peanuts" = 1, "nougat" = 1)
	w_class = 1
	bitesize = 3

/obj/item/reagent_containers/food/snacks/cb10/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_SUGAR, 1)
	reagents.add_reagent(REAGENT_ID_PROTEIN, 1)
	reagents.add_reagent(REAGENT_ID_PEANUTOIL, 1)

////////////////////Misc Vend Items////////////////////////////////////////////////////////////////

/obj/item/reagent_containers/food/snacks/chips
	name = "\improper What-The-Crisps"
	desc = "Commander Riker's What-The-Crisps, lightly salted."
	description_fluff = "What-The-Crisps' retro-styled starship commander has been a marketing staple for almost 200 years. Actual potatos haven't been used in potato chips for centuries. They're mostly a denatured nutrient slurry pressed into a chip-shaped mold and salted. Still tastes the same."
	icon = 'icons/obj/food_snacks.dmi'
	icon_state = "chips"
	trash = /obj/item/trash/chips
	filling_color = "#E8C31E"
	center_of_mass_x = 15
	center_of_mass_y = 15
	nutriment_amt = 3
	nutriment_desc = list("salt" = 1, "chips" = 2)
	bitesize = 1

/obj/item/reagent_containers/food/snacks/chips/bbq
	name = "\improper Legendary BBQ Chips"
	desc = "You know I can't grab your ghost chips!"
	description_fluff = "A local brand, Legendary Chips have proudly sponsored Virgo-Erigone's anti-drink-piloting campaign since 2310."
	icon = 'icons/obj/food_snacks.dmi'
	icon_state = "chips_bbq"
	trash = /obj/item/trash/chips/bbq
	nutriment_amt = 3
	nutriment_desc = list("salt" = 1, "barbeque sauce" = 2)

/obj/item/reagent_containers/food/snacks/chips/snv
	name = "\improper Mike's Salt & Vinegar Chips"
	desc = "Painful to eat yet you just can't stop!"
	description_fluff = "Mike's Salt & Vinegar chips have been a staple of parties and events for decades, the chosen secondary dish to ordinary chips."
	icon = 'icons/obj/food_snacks.dmi'
	icon_state = "chips_snv"
	trash = /obj/item/trash/chips/snv
	nutriment_amt = 3
	nutriment_desc = list("salt" = 1, REAGENT_ID_VINEGAR = 2)

/obj/item/reagent_containers/food/snacks/tastybread
	name = "bread tube"
	desc = "Bread in a tube. Chewy...and surprisingly tasty."
	description_fluff = "This is the product that brought Centauri Provisions into the limelight. A product of the earliest extrasolar colony of Heaven, the Bread Tube, while bland, contains all the nutrients a spacer needs to get through the day and is decidedly edible when compared to some of its competitors. Due to the high-fructose corn syrup content of NanoTrasen's own-brand bread tubes, many jurisdictions classify them as a confectionary."
	icon = 'icons/obj/food_snacks.dmi'
	icon_state = "tastybread"
	trash = /obj/item/trash/tastybread
	filling_color = "#A66829"
	center_of_mass_x = 17
	center_of_mass_y = 16
	nutriment_amt = 6
	nutriment_desc = list("bread" = 2, "sweetness" = 3)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/skrellsnacks
	name = "\improper SkrellSnax"
	desc = "Cured fungus shipped all the way from Qerr'balak, almost like jerky! Almost."
	description_fluff = "Despite the packaging, most SkrellSnax sold in Vir are produced using locally-grown, Qerr'Balak-native Go'moa fungi in controversial Skrell-owned biodomes on the suface of Sif. SkrellSnax were originally a product of Natuna, designed to welcome Ue-Katish refugees to their colony. The brand was recreated by Centauri Provisions after Natuna and SolGov broke off diplomatic relations."
	icon = 'icons/obj/food_snacks.dmi'
	icon_state = "skrellsnacks"
	trash = /obj/item/trash/skrellsnax
	filling_color = "#A66829"
	center_of_mass_x = 15
	center_of_mass_y = 12
	nutriment_amt = 10
	nutriment_desc = list(PLANT_MUSHROOMS = 5, "salt" = 5)
	bitesize = 3

/obj/item/reagent_containers/food/snacks/sosjerky
	name = "Scaredy's Private Reserve Beef Jerky"
	icon = 'icons/obj/food_snacks.dmi'
	icon_state = "sosjerky"
	desc = "Beef jerky made from the finest space-reared cows."
	description_fluff = "Raising cows in low-gravity environments has the natural result of particularly tender meat. The jerking process largely undoes this apparent benefit, but it's just too damn efficient to ship not to."
	trash = /obj/item/trash/sosjerky
	filling_color = "#631212"
	center_of_mass_x = 15
	center_of_mass_y = 9
	bitesize = 2

/obj/item/reagent_containers/food/snacks/sosjerky/Initialize(mapload)
	. =..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 8)

/obj/item/reagent_containers/food/snacks/unajerky
	name = "Moghes Imported Sissalik Jerky"
	icon = 'icons/obj/food_snacks.dmi'
	icon_state = "unathitinred"
	desc = "An incredibly well made jerky, shipped in all the way from Moghes."
	description_fluff = "The exact meat and spices used in the curing of Sissalik Jerky are a well-kept secret, and thought to not exist at all outside of Hegemony space. Many have tried to replicate the flavour, but none have come close, so the brand remains a highly prized import. "
	trash = /obj/item/trash/unajerky
	filling_color = "#631212"
	center_of_mass_x = 15
	center_of_mass_y = 9
	drop_sound = 'sound/items/drop/soda.ogg'
	pickup_sound = 'sound/items/pickup/soda.ogg'
	bitesize = 2

/obj/item/reagent_containers/food/snacks/unajerky/Initialize(mapload)
	. =..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 8)
	reagents.add_reagent(REAGENT_ID_CAPSAICIN, 2)

/obj/item/reagent_containers/food/snacks/tuna
	name = "\improper Tuna Snax"
	icon = 'icons/obj/food_snacks.dmi'
	icon_state = "tuna"
	desc = "A packaged dried fish snack, guaranteed to do not contain space carp. Actual fish content may vary."
	description_fluff = "Launched by Centuari Provisions to target the Tajaran immigrant market, Tuna Snax also found a surprising niche among Vir's sizable Scandinavian population. Elsewhere, the dried fish flakes are widely considered disgusting."
	trash = /obj/item/trash/tuna
	filling_color = "#FFDEFE"
	center_of_mass_x = 17
	center_of_mass_y = 13
	nutriment_amt = 3
	nutriment_desc = list("smoked fish" = 5)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/tuna/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 4)

/obj/item/reagent_containers/food/snacks/pistachios
	name = "pistachios"
	icon = 'icons/obj/food_snacks.dmi'
	icon_state = "pistachios"
	desc = "Pistachios. There is absolutely nothing remarkable about these."
	trash = /obj/item/trash/pistachios
	filling_color = "#825D26"
	center_of_mass_x = 17
	center_of_mass_y = 13
	nutriment_desc = list("nuts" = 1)
	nutriment_amt = 3
	bitesize = 1

/obj/item/reagent_containers/food/snacks/semki
	name = "\improper Semki"
	icon = 'icons/obj/food_snacks.dmi'
	icon_state = "semki"
	desc = "Sunflower seeds. A favorite among both birds and gopniks."
	trash = /obj/item/trash/semki
	filling_color = "#68645D"
	center_of_mass_x = 17
	center_of_mass_y = 13
	nutriment_desc = list("sunflower seeds" = 1)
	nutriment_amt = 6
	bitesize = 1

/obj/item/reagent_containers/food/snacks/squid
	name = "\improper Calamari Crisps"
	icon = 'icons/obj/food_snacks.dmi'
	icon_state = "squid"
	desc = "Space squid tentacles, Carefully removed (from the squid) then dried into strips of delicious rubbery goodness!"
	trash = /obj/item/trash/squid
	filling_color = "#c0a9d7"
	center_of_mass_x = 15
	center_of_mass_y = 9
	nutriment_desc = list("fish" = 1, "salt" = 1)
	nutriment_amt = 2
	bitesize = 1

/obj/item/reagent_containers/food/snacks/squid/true/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 4)

/obj/item/reagent_containers/food/snacks/croutons
	name = "\improper Suhariki"
	icon = 'icons/obj/food_snacks.dmi'
	icon_state = "croutons"
	desc = "Fried bread cubes. Popular in some Solar territories."
	trash = /obj/item/trash/croutons
	filling_color = "#c6b17f"
	center_of_mass_x = 15
	center_of_mass_y = 9
	nutriment_desc = list("bread" = 1, "salt" = 1)
	nutriment_amt = 3
	bitesize = 1

/obj/item/reagent_containers/food/snacks/salo
	name = "\improper Salo"
	icon = 'icons/obj/food_snacks.dmi'
	icon_state = "pigfat"
	desc = "Pig fat. Salted. Just as good as it sounds."
	trash = /obj/item/trash/salo
	filling_color = "#e0bcbc"
	center_of_mass_x = 15
	center_of_mass_y = 9
	nutriment_desc = list("fat" = 1, "salt" = 1)
	nutriment_amt = 2
	bitesize = 2

/obj/item/reagent_containers/food/snacks/salo/true/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 8)

/obj/item/reagent_containers/food/snacks/driedfish
	name = "\improper Vobla"
	icon = 'icons/obj/food_snacks.dmi'
	icon_state = "driedfish"
	desc = "Dried salted beer snack fish."
	trash = /obj/item/trash/driedfish
	filling_color = "#c8a5bb"
	center_of_mass_x = 15
	center_of_mass_y = 9
	nutriment_desc = list("fish" = 1, "salt" = 1)
	nutriment_amt = 2
	bitesize = 1

/obj/item/reagent_containers/food/snacks/driedfish/Initialize(mapload)
	.=..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 4)

/obj/item/reagent_containers/food/snacks/no_raisin
	name = "4no Raisins"
	icon = 'icons/obj/food_snacks.dmi'
	icon_state = "4no_raisins"
	desc = "Best raisins in the universe. Not sure why."
	description_fluff = "Originally Raisin Blend no. 4, 4noraisins obtained their current name in the Skadi Positronic Exclusion Crisis of 2202, where they were rebranded as part of the protests. The exclusion crisis, so the story goes, involved positronic immigration being banned for no raisin."
	trash = /obj/item/trash/raisins
	filling_color = "#343834"
	center_of_mass_x = 15
	center_of_mass_y = 4
	nutriment_desc = list("dried raisins" = 6)
	nutriment_amt = 6

///obj/item/reagent_containers/food/snacks/spacetwinkie (Commented out to replace with packaged version 04/14/2021)
//	name = "Spacer Snack Cake"
//	icon = 'icons/obj/food_snacks.dmi'
//	icon_state = "space_twinkie"
//	desc = "Guaranteed to survive longer than you will."
//	description_fluff = "Despite Spacer advertisements consistently portraying their snack cakes as life-saving, tear-jerking survival food for spacers in all kinds of dramatic scenarios, the Spacer Snack Cake has been statistically proven to lower survival rates on all missions where it is present."
//	filling_color = "#FFE591"
//	center_of_mass_x = 15
//	center_of_mass_y = 11
//	bitesize = 2
//
///obj/item/reagent_containers/food/snacks/spacetwinkie/Initialize(mapload)
//	. = ..()
//	reagents.add_reagent(REAGENT_ID_SUGAR, 4)

/obj/item/reagent_containers/food/snacks/cheesiehonkers
	name = "Cheesie Honkers"
	icon = 'icons/obj/food_snacks.dmi'
	icon_state = "cheesie_honkers"
	desc = "Bite sized cheesie snacks that will honk all over your mouth."
	description_fluff = "The origins of the flourescent orange dust produced by Cheesie Honkers is considered a trade secret, despite having been leaked on the exonet decades ago. It's the cheese."
	trash = /obj/item/trash/cheesie
	filling_color = "#FFA305"
	center_of_mass_x = 15
	center_of_mass_y = 9
	nutriment_amt = 4
	nutriment_desc = list(REAGENT_ID_CHEESE = 5, "chips" = 2)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/syndicake
	name = "Syndi-Cakes"
	icon = 'icons/obj/food_snacks.dmi'
	icon_state = "syndi_cakes"
	desc = "An extremely moist snack cake that tastes just as good after being nuked."
	description_fluff = "Spacer Snack Cakes' meaner, tastier cousin. The Syndi-Cakes brand was at risk of dissolution in 2275 when it was revealed that the entire production chain was a Nos Amis joint. The brand was quickly aquired by Centauri Provisions and some mild hallucinogenic 'add-ins' were axed from the recipe."
	trash = /obj/item/trash/syndi_cakes
	filling_color = "#FF5D05"
	center_of_mass_x = 16
	center_of_mass_y = 10
	nutriment_desc = list("sweetness" = 3, "cake" = 1)
	nutriment_amt = 4
	bitesize = 3

/obj/item/reagent_containers/food/snacks/syndicake/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_DOCTORSDELIGHT, 5)

////////////////////sol_vend (Mars Mart)////////////////////////////////////////////////////

/obj/item/reagent_containers/food/snacks/triton
	name = "\improper Tidal Gobs"
	icon = 'icons/obj/food_snacks.dmi'
	icon_state = "tidegobs"
	desc = "Contains over 9000% of your daily recommended intake of salt."
	trash = /obj/item/trash/tidegobs
	filling_color = "#2556b0"
	center_of_mass_x = 15
	center_of_mass_y = 9
	nutriment_desc = list("salt" = 4, "seagull?" = 1)
	nutriment_amt = 5
	bitesize = 2

/obj/item/reagent_containers/food/snacks/saturn
	name = "\improper Saturn-Os"
	icon = 'icons/obj/food_snacks.dmi'
	icon_state = "saturn0s"
	desc = "A peanut flavored snack that looks like the rings of Saturn!"
	trash = /obj/item/trash/saturno
	filling_color = "#dca319"
	center_of_mass_x = 15
	center_of_mass_y = 9
	nutriment_desc = list("salt" = 4, PLANT_PEANUT = 2,  "wood?" = 1)
	nutriment_amt = 5
	bitesize = 2

/obj/item/reagent_containers/food/snacks/jupiter
	name = "\improper Jove Gello"
	icon = 'icons/obj/food_snacks.dmi'
	icon_state = "jupiter"
	desc = "By Joove! It's some kind of gel."
	trash = /obj/item/trash/jupiter
	filling_color = "#dc1919"
	center_of_mass_x = 15
	center_of_mass_y = 9
	nutriment_desc = list("sweetness" = 4, REAGENT_ID_VANILLA = 1)
	nutriment_amt = 5
	bitesize = 2

/obj/item/reagent_containers/food/snacks/pluto
	name = "\improper Plutonian Rods"
	icon = 'icons/obj/food_snacks.dmi'
	icon_state = "pluto"
	desc = "Baseless tasteless nutrithick rods to get you through the day. Now even less rash inducing!"
	trash = /obj/item/trash/pluto
	filling_color = "#ffffff"
	center_of_mass_x = 15
	center_of_mass_y = 9
	nutriment_desc = list("chalk" = 4, "sadness" = 1)
	nutriment_amt = 5
	bitesize = 2

/obj/item/reagent_containers/food/snacks/mars
	name = "\improper Frouka"
	icon = 'icons/obj/food_snacks.dmi'
	icon_state = "mars"
	desc = "A steaming self-heated bowl of sweet eggs and taters!"
	trash = /obj/item/trash/mars
	filling_color = "#d2c63f"
	center_of_mass_x = 15
	center_of_mass_y = 9
	nutriment_desc = list("eggs" = 4, PLANT_POTATO = 4, REAGENT_ID_MUSTARD = 2)
	nutriment_amt = 8
	bitesize = 2

/obj/item/reagent_containers/food/snacks/venus
	name = "\improper Venusian Hot Cakes"
	icon = 'icons/obj/food_snacks.dmi'
	icon_state = "venus"
	desc = "Hot takes on hot cakes, a timeless classic now finally fit for human consumption!"
	trash = /obj/item/trash/venus
	filling_color = "#d2c63f"
	center_of_mass_x = 15
	center_of_mass_y = 9
	nutriment_desc = list("heat" = 4, "burning!" = 1)
	nutriment_amt = 5
	bitesize = 2

/obj/item/reagent_containers/food/snacks/venus/Initialize(mapload)
	.=..()
	reagents.add_reagent(REAGENT_ID_CAPSAICIN, 5)

/obj/item/reagent_containers/food/snacks/sun_snax
	name = "\improper Sun Snax!"
	icon = 'icons/obj/food_snacks.dmi'
	icon_state = "sun_snax"
	desc = "A Sol favorite, Sun Snax! Sun dried corn chips coated in a super spicy seasoning!"
	trash = /obj/item/trash/sun_snax
	filling_color = "#d2c63f"
	center_of_mass_x = 15
	center_of_mass_y = 9
	nutriment_desc = list("heat" = 3, "burning!" = 2)
	nutriment_amt = 3
	bitesize = 1

/obj/item/reagent_containers/food/snacks/sun_snax/Initialize(mapload)
	.=..()
	reagents.add_reagent(REAGENT_ID_CAPSAICIN, 6)

/obj/item/reagent_containers/food/snacks/oort
	name = "\improper Oort Cloud Rocks"
	icon = 'icons/obj/food_snacks.dmi'
	icon_state = "oort"
	desc = "Pop rocks themed on the outermost reaches of the Sol system, new formula guarantees fewer shrapnel induced oral injuries."
	trash = /obj/item/trash/oort
	filling_color = "#3f7dd2"
	center_of_mass_x = 15
	center_of_mass_y = 9
	nutriment_desc = list("fizz" = 4, "sweetness" = 1)
	nutriment_amt = 5
	bitesize = 2

/obj/item/reagent_containers/food/snacks/oort/Initialize(mapload)
	.=..()
	reagents.add_reagent(REAGENT_ID_FROSTOIL,5)

/obj/item/reagent_containers/food/snacks/pretzels
	name = "\improper Value Pretzel Snack"
	icon = 'icons/obj/food_snacks.dmi'
	icon_state = "pretzel"
	trash = /obj/item/trash/pretzel
	desc = "A tasty bread like snack that is seasoned with what tastes like salt... but you're not so sure it's actually salt."
	filling_color = "#916E36"
	center_of_mass_x = 15
	center_of_mass_y = 9
	nutriment_desc = list("salt" = 2, "pretzel" = 3)
	nutriment_amt = 3
	bitesize = 1

/obj/item/reagent_containers/food/snacks/hakarl
	name = "\improper Indigo Co. Hákarl"
	icon = 'icons/obj/food_snacks.dmi'
	icon_state = "hakarl"
	trash = /obj/item/trash/hakarl
	desc = "Fermented space shark, like chewing a urine soaked mattress."
	description_fluff = "A form of fermented shark that originated on Earth as far back as the 17th century. Modern Hakarl is made from vat-made fermented shark and is distributed across the galaxy as a delicacy. However, few are able to stand the smell or taste of the meat."
	filling_color = "#916E36"
	center_of_mass_x = 15
	center_of_mass_y = 9
	nutriment_desc = list("fish" = 2, "salt" = 2, REAGENT_ID_AMMONIA = 1)
	nutriment_amt = 4
	bitesize = 1

////////////////////weeb_vend (Nippon-tan!)////////////////////////////////////////////////////

/obj/item/reagent_containers/food/snacks/ricecake
	name = "rice cake"
	icon = 'icons/obj/food_snacks.dmi'
	icon_state = "ricecake"
	desc = "Ancient earth snack food made from balled up rice."
	nutriment_desc = list(REAGENT_ID_RICE = 4, "sweetness" = 1)
	nutriment_amt = 5
	bitesize = 2

/obj/item/reagent_containers/food/snacks/dorayaki
	name = "dorayaki"
	icon = 'icons/obj/food_snacks.dmi'
	icon_state = "dorayaki"
	desc = "Two small pancake-like patties made from castella wrapped around a filling of sweet azuki bean paste."
	nutriment_desc = list("cake" = 3, "sweetness" = 2)
	nutriment_amt = 6
	bitesize = 2

/obj/item/reagent_containers/food/snacks/daifuku
	name = "daifuku"
	icon = 'icons/obj/food_snacks.dmi'
	icon_state = "daifuku"
	desc = "Small round mochi stuffed with sweetened red bean paste."
	nutriment_desc = list("cake" = 2, "sweetness" = 3)
	nutriment_amt = 6
	bitesize = 2

/obj/item/reagent_containers/food/snacks/weebonuts
	name = "\improper Red Alert Nuts!"
	icon = 'icons/obj/food_snacks.dmi'
	icon_state = "weebonuts"
	trash = /obj/item/trash/weebonuts
	desc = "A bag of Red Alert! brand spicy nuts. Goes well with your beer!"
	nutriment_desc = list("nuts" = 4, "spicyness" = 1)
	nutriment_amt = 5
	bitesize = 2

/obj/item/reagent_containers/food/snacks/weebonuts/Initialize(mapload)
	.=..()
	reagents.add_reagent(REAGENT_ID_CAPSAICIN,1)

/obj/item/reagent_containers/food/snacks/wasabi_peas
	name = "\improper Hadokikku Peas"
	icon = 'icons/obj/food_snacks.dmi'
	icon_state = "wasabi_peas"
	trash = /obj/item/trash/wasabi_peas
	desc = "A bag of Hadokikku brand wasabi peas, a delicious snack imported directly form Sol."
	nutriment_desc = list("peas" = 4, "spicyness" = 1)
	nutriment_amt = 6
	bitesize = 2

/obj/item/reagent_containers/food/snacks/wasabi_peas/Initialize(mapload)
	.=..()
	reagents.add_reagent(REAGENT_ID_CAPSAICIN,1)

/obj/item/reagent_containers/food/snacks/chocobanana
	name = "\improper Choco Banana"
	icon = 'icons/obj/food_snacks.dmi'
	icon_state = "chocobanana"
	trash = /obj/item/trash/stick
	desc = "A chocolate and sprinkles coated banana. On a stick."
	nutriment_desc = list("chocolate banana" = 4, REAGENT_ID_SPRINKLES = 1)
	nutriment_amt = 5
	bitesize = 2

/obj/item/reagent_containers/food/snacks/chocobanana/Initialize(mapload)
	.=..()
	reagents.add_reagent(REAGENT_ID_SPRINKLES, 10)

/obj/item/reagent_containers/food/snacks/goma_dango
	name = "\improper Goma dango"
	icon = 'icons/obj/food_snacks.dmi'
	icon_state = "goma_dango"
	trash = /obj/item/trash/stick
	desc = "Sticky rice balls served on a skewer with a crispy rice flour outer layer and a thick red bean paste inner layer."
	nutriment_desc = list(REAGENT_ID_RICE = 4, "earthy flavor" = 1)
	nutriment_amt = 5
	bitesize = 2

/obj/item/reagent_containers/food/snacks/hanami_dango
	name = "\improper Hanami dango"
	icon = 'icons/obj/food_snacks.dmi'
	icon_state = "hanami_dango"
	trash = /obj/item/trash/stick
	desc = "Three rice balls, each with a unique flavoring, served on a skewer. A traditional Japanese treat."
	description_fluff = "Hanami dango is a traditional Japanese treat that is normally served during Hanami, a tradition dated back as early as the 8th century. Hanami, or cherry blossom viewing, is a spring time celebration that celebrates the cherry blossoms turning of color. It is a time of renewal, of life, and of beauty."
	nutriment_desc = list(REAGENT_ID_RICE = 4, "earthy flavor" = 1)
	nutriment_amt = 5
	bitesize = 2

////////////////////ancient_vend (Hot Food - Old)////////////////////////////////////////////////////

/obj/item/reagent_containers/food/snacks/old
	name = "master old-food"
	desc = "they're all inedible and potentially dangerous items"
	center_of_mass_x = 15
	center_of_mass_y = 9
	nutriment_desc = list("rot" = 5, REAGENT_ID_MOLD = 5)
	nutriment_amt = 10
	bitesize = 3
	filling_color = "#336b42"
/obj/item/reagent_containers/food/snacks/old/Initialize(mapload)
	.=..()
	reagents.add_reagent(pick(list(
				REAGENT_ID_FUEL,
				REAGENT_ID_AMATOXIN,
				REAGENT_ID_CARPOTOXIN,
				REAGENT_ID_ZOMBIEPOWDER,
				REAGENT_ID_CRYPTOBIOLIN,
				REAGENT_ID_PSILOCYBIN)), 5)
	reagents.add_reagent(REAGENT_ID_SALMONELLA, 5)

/obj/item/reagent_containers/food/snacks/old/pizza
	name = "\improper Pizza!"
	desc = "It's so stale you could probably cut something with the cheese."
	icon_state = "ancient_pizza"

/obj/item/reagent_containers/food/snacks/old/burger
	name = "\improper Giga Burger!"
	desc = "At some point in time this probably looked delicious."
	icon_state = "ancient_burger"

/obj/item/reagent_containers/food/snacks/old/horseburger
	name = "\improper Horse Burger!"
	desc = "Even if you were hungry enough to eat a horse, it'd be a bad idea to eat this."
	icon_state = "ancient_horse_burger"

/obj/item/reagent_containers/food/snacks/old/fries
	name = "\improper Space Fries!"
	desc = "The salt appears to have preserved these, still stale and gross."
	icon_state = "ancient_fries"

/obj/item/reagent_containers/food/snacks/old/hotdog
	name = "\improper Space Dog!"
	desc = "This one is probably only marginally less safe to eat than when it was first created.."
	icon_state = "ancient_hotdog"

/obj/item/reagent_containers/food/snacks/old/taco
	name = "\improper Taco!"
	desc = "Interestingly, the shell has gone soft and the contents have gone stale."
	icon_state = "ancient_taco"

//////////////////////Canned Foods - crack open and eat (ADDED 04/11/2021)//////////////////////

/obj/item/reagent_containers/food/snacks/canned
	icon = 'icons/obj/food_canned.dmi'
	opening_sound = 'sound/effects/tincanopen.ogg'
	canned = TRUE

//////////Just a short line of Canned Consumables, great for treasure in faraway abandoned outposts//////////

/obj/item/reagent_containers/food/snacks/canned/beef
	name = "canned beef"
	icon_state = "beef"
	desc = "A can of premium preserved vat-grown holstein beef. Now 99.9% bone free!"
	trash = /obj/item/trash/beef
	canned_open_state = "beef-open"
	filling_color = "#663300"
	center_of_mass_x = 15
	center_of_mass_y = 9
	nutriment_desc = list("beef" = 1)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/canned/beef/Initialize(mapload)
	.=..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 4)
	reagents.add_reagent(REAGENT_ID_SODIUMCHLORIDE, 2)

/obj/item/reagent_containers/food/snacks/canned/beans
	name = "baked beans"
	icon_state = "beans"
	desc = "Luna Colony beans. Carefully synthethized from soy."
	trash = /obj/item/trash/beans
	canned_open_state = "beans-open"
	filling_color = "#ff6633"
	center_of_mass_x = 15
	center_of_mass_y = 9
	nutriment_desc = list(REAGENT_BEANPROTEIN = 1, "tomato sauce" = 1)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/canned/beans/Initialize(mapload)
	.=..()
	reagents.add_reagent(REAGENT_ID_BEANPROTEIN, 5)
	reagents.add_reagent(REAGENT_ID_TOMATOJUICE, 5)

/obj/item/reagent_containers/food/snacks/canned/tomato
	name = "tomato soup"
	icon_state = "tomato"
	desc = "Plain old unseasoned tomato soup. This can has no use-by date."
	trash = /obj/item/trash/tomato
	package_open_state = "tomato-open"
	filling_color = "#ae0000"
	center_of_mass_x = 15
	center_of_mass_y = 9
	bitesize = 3

/obj/item/reagent_containers/food/snacks/canned/tomato/Initialize(mapload)
	.=..()
	reagents.add_reagent(REAGENT_ID_TOMATOSOUP, 12)

/obj/item/reagent_containers/food/snacks/canned/spinach
	name = "spinach"
	icon_state = "spinach"
	desc = "Wup-Az! Brand canned spinach. Notably has less iron in it than a watermelon."
	trash = /obj/item/trash/spinach
	canned_open_state = "spinach-open"
	filling_color = "#003300"
	center_of_mass_x = 15
	center_of_mass_y = 9
	nutriment_desc = list("soggy" = 1, "vegetable" = 1)
	bitesize = 3

/obj/item/reagent_containers/food/snacks/canned/spinach/Initialize(mapload)
	.=..()
	reagents.add_reagent(REAGENT_ID_ADRENALINE, 4)
	reagents.add_reagent(REAGENT_ID_HYPERZINE, 4)
	reagents.add_reagent(REAGENT_ID_IRON, 4)

//////////////////////////////Advanced Canned Food//////////////////////////////

/obj/item/reagent_containers/food/snacks/canned/caviar
	name = "\improper Terran Caviar"
	icon_state = "fisheggs"
	desc = "Terran caviar, or space carp eggs. Carefully faked using alginate, artificial flavoring and salt. Skrell approved!"
	trash = /obj/item/trash/fishegg
	canned_open_state = "fisheggs-open"
	filling_color = "#000000"
	center_of_mass_x = 15
	center_of_mass_y = 9
	nutriment_desc = list("salt" = 1)
	bitesize = 1

/obj/item/reagent_containers/food/snacks/canned/caviar/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_SEAFOOD, 5)

/obj/item/reagent_containers/food/snacks/canned/caviar/true
	name = "\improper Classic Terran Caviar"
	icon_state = "carpeggs"
	desc = "Terran caviar, or space carp eggs. Banned by the Vir Food Health Administration for exceeding the legally set amount of carpotoxins in food stuffs."
	trash = /obj/item/trash/carpegg
	canned_open_state = "carpeggs-open"
	filling_color = "#330066"
	center_of_mass_x = 15
	center_of_mass_y = 9
	nutriment_desc = list("salt" = 1, "a numbing sensation" = 1)
	bitesize = 1

/obj/item/reagent_containers/food/snacks/canned/caviar/true/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_SEAFOOD, 4)
	reagents.add_reagent(REAGENT_ID_CARPOTOXIN, 1)

/obj/item/reagent_containers/food/snacks/canned/maps
	name = "\improper MAPS"
	icon_state = "maps"
	desc = "A re-branding of a classic Earth snack! Contains mostly edible ingredients."
	trash = /obj/item/trash/maps
	canned_open_state = "maps-open"
	filling_color = "#330066"
	center_of_mass_x = 15
	center_of_mass_y = 9
	bitesize = 2

/obj/item/reagent_containers/food/snacks/canned/maps/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 6)
	reagents.add_reagent(REAGENT_ID_SODIUMCHLORIDE, 2)

/obj/item/reagent_containers/food/snacks/canned/appleberry
	name = "\improper Appleberry Bits"
	icon_state = "appleberry"
	desc = "A classic snack favored by Sol astronauts. Made from dried apple-hybidized berries grown on the lunar colonies."
	trash = /obj/item/trash/appleberry
	canned_open_state = "appleberry-open"
	filling_color = "#FFFFFF"
	center_of_mass_x = 15
	center_of_mass_y = 9
	nutriment_desc = list(PLANT_APPLE = 1, "sweetness" = 1)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/canned/appleberry/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_MILK, 8)
	reagents.add_reagent(REAGENT_ID_SUGAR, 5)

/obj/item/reagent_containers/food/snacks/canned/ntbeans
	name = "baked beans"
	icon_state = "ntbeans"
	desc = "Musical fruit in a slightly less musical container. Now with bacon!"
	trash = /obj/item/trash/ntbeans
	canned_open_state = "ntbeans-open"
	filling_color = "#FC6F28"
	center_of_mass_x = 15
	center_of_mass_y = 9
	bitesize = 2

/obj/item/reagent_containers/food/snacks/canned/ntbeans/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_BEANPROTEIN, 6)
	reagents.add_reagent(REAGENT_ID_PROTEIN, 2)

/obj/item/reagent_containers/food/snacks/canned/brainzsnax
	name = "\improper BrainzSnax"
	icon_state = "brainzsnax"
	desc = "A can of grey matter marketed for xenochimeras."
	description_fluff = "As the cartoon brain with limbs proudly proclaims, \"It's meat. Eat it!\" On the can is printed \"Rich in limbic system\" and \
	under that in infinitely small letters, \"Warning, product must be eaten within two hours of opening. May contain prion disease. \
	GrubCo LTD is not liable for any brain damage occurring after consumption of product.\""
	trash = /obj/item/trash/brainzsnax
	canned_open_state = "brainzsnax-open"
	filling_color = "#caa3c9"
	center_of_mass_x = 15
	center_of_mass_y = 9
	bitesize = 2
	var/brainmeat = REAGENT_ID_BRAINPROTEIN

/obj/item/reagent_containers/food/snacks/canned/brainzsnax/Initialize(mapload)
	. = ..()
	reagents.add_reagent(brainmeat, 10)

/obj/item/reagent_containers/food/snacks/canned/brainzsnax/red
	name = "\improper BrainzSnax RED"
	icon_state = "brainzsnaxred"
	desc = "A can of grey matter marketed for xenochimeras. This one has added tomato sauce."
	description_fluff = "As the cartoonish brain with limbs proudly proclaims, \"It's meat. Eat it!\" On the can is printed \"Yummy red stuff!\" and \
	under that in infinitely small letters, \"Warning, product must be eaten within two hours of opening. May contain prion disease. \
	GrubCo LTD is not liable for any brain damage occurring after consumption of product.\""
	trash = /obj/item/trash/brainzsnaxred
	canned_open_state = "brainzsnaxred-open"
	filling_color = "#a6898d"
	center_of_mass_x = 15
	center_of_mass_y = 9
	bitesize = 2
	brainmeat = REAGENT_ID_REDBRAINPROTEIN

//////////////Packaged Food - break open and eat//////////////

/obj/item/reagent_containers/food/snacks/packaged
	icon = 'icons/obj/food_package.dmi'
	opening_sound = 'sound/effects/packagedfoodopen.ogg'
	package = TRUE

//////////////Lunar Cakes - proof of concept//////////////

/obj/item/reagent_containers/food/snacks/packaged/lunacake
	name = "\improper Lunar Cake"
	icon_state = "lunacake"
	desc = "Now with 20% less lawsuit enabling rhegolith!"
	package_trash = /obj/item/trash/lunacakewrap
	package_open_state = "lunacake_open"
	filling_color = "#ffffff"
	center_of_mass_x = 15
	center_of_mass_y = 9
	nutriment_amt = 6
	nutriment_desc = list("sweetness" = 4, REAGENT_ID_VANILLA = 1)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/packaged/darklunacake
	name = "\improper Dark Lunar Cake"
	icon_state = "mooncake"
	desc = "Explore the dark side! May contain trace amounts of reconstituted cocoa."
	package_trash = /obj/item/trash/mooncakewrap
	package_open_state = "lunacake_open"
	filling_color = "#ffffff"
	center_of_mass_x = 15
	center_of_mass_y = 9
	nutriment_amt = 6
	nutriment_desc = list("sweetness" = 4, REAGENT_ID_CHOCOLATE = 1)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/packaged/mochicake
	name = "\improper Mochi Cake"
	icon_state = "mochicake"
	desc = "Konnichiwa! Many go lucky rice cakes in future!"
	package_trash = /obj/item/trash/mochicakewrap
	package_open_state = "lunacake_open"
	filling_color = "#ffffff"
	center_of_mass_x = 15
	center_of_mass_y = 9
	nutriment_amt = 6
	nutriment_desc = list("sweetness" = 4, REAGENT_ID_RICE = 1)
	bitesize = 2

//////////////Advanced Package Foods//////////////

/obj/item/reagent_containers/food/snacks/packaged/spacetwinkie
	name = "\improper Spacer Snack Cake"
	icon_state = "spacercake"
	desc = "Guaranteed to survive longer than you will."
	description_fluff = "Despite Spacer advertisements consistently portraying their snack cakes as life-saving, \
	tear-jerking survival food for spacers in all kinds of dramatic scenarios, the Spacer Snack Cake has been \
	statistically proven to lower survival rates on all missions where it is present."
	package_trash = /obj/item/trash/spacer_cake_wrap
	package_open_state = "spacercake_open"
	filling_color = "#FFE591"
	center_of_mass_x = 15
	center_of_mass_y = 11
	nutriment_amt = 4
	nutriment_desc = list("sweetness" = 4, "cake" = 2)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/packaged/spacetwinkie/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_SUGAR, 4)

/obj/item/reagent_containers/food/snacks/packaged/genration
	name = "generic ration"
	icon_state = "genration"
	desc = "The most basic form of ration - meant to barely sustain life."
	trash = /obj/item/trash/genration
	package_open_state = "genration_open"
	filling_color = "#FFFFFF"
	center_of_mass_x = 15
	center_of_mass_y = 11
	nutriment_amt = 4
	nutriment_desc = list("chalk" = 6)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/packaged/meatration
	name = "meat ration"
	icon_state = "meatration"
	desc = "A meat flavored ration. Emphasis on 'meat flavored' as there is likely no real meat in this."
	trash = /obj/item/trash/meatration
	package_open_state = "meatration_open"
	filling_color = "#FFFFFF"
	center_of_mass_x = 15
	center_of_mass_y = 11
	nutriment_amt = 4
	nutriment_desc = list("chalk" = 3, "meat" = 3)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/packaged/meatration/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_PROTEIN, 4)

/obj/item/reagent_containers/food/snacks/packaged/vegration
	name = "veggie ration"
	icon_state = "vegration"
	desc = "Dried veggies in a bag. Depressing and near flavorless."
	trash = /obj/item/trash/vegration
	package_open_state = "vegration_open"
	filling_color = "#FFFFFF"
	center_of_mass_x = 15
	center_of_mass_y = 11
	nutriment_amt = 4
	nutriment_desc = list("sadness" = 3, "veggie" = 3)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/packaged/sweetration
	name = "desert ration"
	icon_state = "baseration"
	desc = "A rare ration from an era gone by filled with a sweet tasty treat that no modern company has been able to recreate."
	trash = /obj/item/trash/sweetration
	package_open_state = "baseration_open"
	filling_color = "#FFFFFF"
	center_of_mass_x = 15
	center_of_mass_y = 11
	nutriment_amt = 4
	nutriment_desc = list("sweetness" = 5, "cake" = 1)
	bitesize = 2

/obj/item/reagent_containers/food/snacks/packaged/sweetration/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_SUGAR, 6)

/obj/item/reagent_containers/food/snacks/packaged/vendburger
	name = "packaged burger"
	icon_state = "smolburger"
	desc = "A burger stored in a plastic wrapping for vending machine distribution. Surely it tastes fine!"
	package_trash = /obj/item/trash/smolburger
	package_open_state = "smolburger_open"
	nutriment_amt = 3
	nutriment_desc = list("stale burger" = 3)

/obj/item/reagent_containers/food/snacks/packaged/vendburger/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_SODIUMCHLORIDE, 1)

/obj/item/reagent_containers/food/snacks/packaged/vendhotdog
	name = "packaged hotdog"
	icon_state = "smolhotdog"
	desc = "A hotdog stored in a plastic wrapping for vending machine distribution. Surely it tastes fine!"
	package_trash = /obj/item/trash/smolhotdog
	package_open_state = "smolhotdog_open"
	nutriment_amt = 3
	nutriment_desc = list("stale hotdog" = 3)

/obj/item/reagent_containers/food/snacks/packaged/vendhotdog/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_SODIUMCHLORIDE, 1)

/obj/item/reagent_containers/food/snacks/packaged/vendburrito
	name = "packaged burrito"
	icon_state = "smolburrito"
	desc = "A burrito stored in a plastic wrapping for vending machine distribution. Surely it tastes fine!"
	package_trash = /obj/item/trash/smolburrito
	package_open_state = "smolburrito_open"
	nutriment_amt = 3
	nutriment_desc = list("stale burrito" = 3)

/obj/item/reagent_containers/food/snacks/packaged/vendburrito/Initialize(mapload)
	. = ..()
	reagents.add_reagent(REAGENT_ID_SODIUMCHLORIDE, 1)
