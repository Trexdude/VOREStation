/obj/item/transfer_valve
	name = "tank transfer valve"
	desc = "Regulates the transfer of air between two tanks"
	icon = 'icons/obj/assemblies.dmi'
	icon_state = "valve_1"
	var/obj/item/tank/tank_one
	var/obj/item/tank/tank_two
	var/obj/item/assembly/attached_device
	var/mob/attacher = null
	var/valve_open = 0
	var/toggle = 1

/obj/item/transfer_valve/attackby(obj/item/item, mob/user)
	var/turf/location = get_turf(src) // For admin logs
	if(istype(item, /obj/item/tank))
		if(tank_one && tank_two)
			to_chat(user, span_warning("There are already two tanks attached, remove one first."))
			return

		if(!tank_one)
			tank_one = item
			user.drop_item()
			item.forceMove(src)
			to_chat(user, span_notice("You attach the tank to the transfer valve."))
		else if(!tank_two)
			tank_two = item
			user.drop_item()
			item.forceMove(src)
			to_chat(user, span_notice("You attach the tank to the transfer valve."))
			message_admins("[key_name_admin(user)] attached both tanks to a transfer valve. [ADMIN_JMP(location)]")
			log_game("[key_name_admin(user)] attached both tanks to a transfer valve.")

		update_icon()
		SStgui.update_uis(src) // update all UIs attached to src
//TODO: Have this take an assemblyholder
	else if(isassembly(item))
		var/obj/item/assembly/A = item
		if(A.secured)
			to_chat(user, span_notice("The device is secured."))
			return
		if(attached_device)
			to_chat(user, span_warning("There is already an device attached to the valve, remove it first."))
			return
		user.remove_from_mob(item)
		attached_device = A
		A.forceMove(src)
		to_chat(user, span_notice("You attach the [item] to the valve controls and secure it."))
		A.holder = src
		A.toggle_secure()	//this calls update_icon(), which calls update_icon() on the holder (i.e. the bomb).

		GLOB.bombers += "[key_name(user)] attached a [item] to a transfer valve."
		message_admins("[key_name_admin(user)] attached a [item] to a transfer valve. [ADMIN_JMP(location)]")
		log_game("[key_name_admin(user)] attached a [item] to a transfer valve.")
		attacher = user
		SStgui.update_uis(src) // update all UIs attached to src
	return


/obj/item/transfer_valve/HasProximity(turf/T, datum/weakref/WF, old_loc)
	SIGNAL_HANDLER
	if(isnull(WF))
		return
	var/atom/movable/AM = WF.resolve()
	if(isnull(AM))
		log_debug("DEBUG: HasProximity called without reference on [src].")
	attached_device?.HasProximity(T, WF, old_loc)

/obj/item/transfer_valve/Moved(old_loc, direction, forced)
	. = ..()
	if(isturf(old_loc))
		unsense_proximity(callback = TYPE_PROC_REF(/atom,HasProximity), center = old_loc)
	if(isturf(loc))
		sense_proximity(callback = TYPE_PROC_REF(/atom,HasProximity))

/obj/item/transfer_valve/attack_self(mob/user)
	tgui_interact(user)

/obj/item/transfer_valve/tgui_state(mob/user)
	return GLOB.tgui_inventory_state

/obj/item/transfer_valve/tgui_interact(mob/user, datum/tgui/ui = null)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "TransferValve", name) // 460, 320
		ui.open()

/obj/item/transfer_valve/tgui_data(mob/user)
	var/list/data = list()
	data["tank_one"] = tank_one ? tank_one.name : null
	data["tank_two"] = tank_two ? tank_two.name : null
	data["attached_device"] = attached_device ? attached_device.name : null
	data["valve"] = valve_open
	return data

/obj/item/transfer_valve/tgui_act(action, params, datum/tgui/ui)
	if(..())
		return
	. = TRUE
	switch(action)
		if("tankone")
			remove_tank(tank_one)
		if("tanktwo")
			remove_tank(tank_two)
		if("toggle")
			toggle_valve()
		if("device")
			if(attached_device)
				attached_device.attack_self(ui.user)
		if("remove_device")
			if(attached_device)
				attached_device.forceMove(get_turf(src))
				attached_device.holder = null
				attached_device = null
				update_icon()
		else
			. = FALSE
	if(.)
		update_icon()
		add_fingerprint(ui.user)

/obj/item/transfer_valve/proc/process_activation(var/obj/item/D)
	if(toggle)
		toggle = FALSE
		toggle_valve()
		VARSET_IN(src, toggle, TRUE, 5 SECONDS)

/obj/item/transfer_valve/update_icon()
	cut_overlays()
	underlays = null

	if(!tank_one && !tank_two && !attached_device)
		icon_state = "valve_1"
		return
	icon_state = "valve"

	if(tank_one)
		add_overlay("[tank_one.icon_state]")
	if(tank_two)
		var/icon/J = new(icon, icon_state = "[tank_two.icon_state]")
		J.Shift(WEST, 13)
		underlays += J
	if(attached_device)
		add_overlay("device")

/obj/item/transfer_valve/proc/remove_tank(obj/item/tank/T)
	if(tank_one == T)
		split_gases()
		tank_one = null
	else if(tank_two == T)
		split_gases()
		tank_two = null
	else
		return

	T.forceMove(get_turf(src))
	update_icon()

/obj/item/transfer_valve/proc/merge_gases()
	if(valve_open)
		return
	tank_two.air_contents.volume += tank_one.air_contents.volume
	var/datum/gas_mixture/temp
	temp = tank_one.air_contents.remove_ratio(1)
	tank_two.air_contents.merge(temp)
	valve_open = 1

/obj/item/transfer_valve/proc/split_gases()
	if(!valve_open)
		return

	valve_open = 0

	if(QDELETED(tank_one) || QDELETED(tank_two))
		return

	var/ratio1 = tank_one.air_contents.volume/tank_two.air_contents.volume
	var/datum/gas_mixture/temp
	temp = tank_two.air_contents.remove_ratio(ratio1)
	tank_one.air_contents.merge(temp)
	tank_two.air_contents.volume -=  tank_one.air_contents.volume


	/*
	Exadv1: I know this isn't how it's going to work, but this was just to check
	it explodes properly when it gets a signal (and it does).
	*/

/obj/item/transfer_valve/proc/toggle_valve()
	if(!valve_open && (tank_one && tank_two))
		var/turf/bombturf = get_turf(src)
		var/area/A = get_area(bombturf)

		var/attacher_name = ""
		if(!attacher)
			attacher_name = "Unknown"
		else
			attacher_name = "[attacher.name]([attacher.ckey])"

		var/log_str = "Bomb valve opened in <A href='byond://?_src_=holder;[HrefToken(TRUE)];adminplayerobservecoodjump=1;X=[bombturf.x];Y=[bombturf.y];Z=[bombturf.z]'>[A.name]</a> "
		log_str += "with [attached_device ? attached_device : "no device"] attacher: [attacher_name]"

		if(attacher)
			log_str += ADMIN_QUE(attacher)

		var/mob/mob = get_mob_by_key(src.fingerprintslast)
		var/last_touch_info = ""
		if(mob)
			last_touch_info = ADMIN_QUE(mob)

		log_str += " Last touched by: [src.fingerprintslast][last_touch_info]"
		GLOB.bombers += log_str
		message_admins(log_str, 0, 1)
		log_game(log_str)
		merge_gases()

	else if(valve_open==1 && (tank_one && tank_two))
		split_gases()

	src.update_icon()

// this doesn't do anything but the timer etc. expects it to be here
// eventually maybe have it update icon to show state (timer, prox etc.) like old bombs
/obj/item/transfer_valve/proc/c_state()
	return
