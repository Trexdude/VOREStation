var/datum/antagonist/xenos/xenomorphs

/datum/antagonist/xenos
	id = MODE_XENOMORPH
	role_type = BE_ALIEN
	role_text = "Genaprawn"
	role_text_plural = "Genaprawns"
	mob_path = /mob/living/carbon/alien/larva
	bantype = "Xenomorph"
	flags = ANTAG_OVERRIDE_MOB | ANTAG_RANDSPAWN | ANTAG_OVERRIDE_JOB | ANTAG_VOTABLE
	welcome_text = "Hiss! You are a larval alien. Hide and bide your time until you are ready to evolve."
	antaghud_indicator = "hudalien"

	hard_cap = 5
	hard_cap_round = 8
	initial_spawn_req = 4
	initial_spawn_target = 6

	spawn_announcement = "Unidentified lifesigns detected coming aboard the station. Secure any exterior access, including ducting and ventilation."
	spawn_announcement_title = "Lifesign Alert"
	spawn_announcement_sound = 'sound/AI/aliens.ogg'
	spawn_announcement_delay = 5000

/datum/antagonist/xenos/New(var/no_reference)
	..()
	if(!no_reference)
		xenomorphs = src

/datum/antagonist/xenos/attempt_random_spawn()
	if(CONFIG_GET(flag/aliens_allowed)) ..()

/datum/antagonist/xenos/proc/get_vents()
	var/list/vents = list()
	for(var/obj/machinery/atmospherics/unary/vent_pump/temp_vent in GLOB.machines)
		if(!temp_vent.welded && temp_vent.network && (temp_vent.loc.z in using_map.station_levels))
			if(temp_vent.network.normal_members.len > 50)
				vents += temp_vent
	return vents

/datum/antagonist/xenos/create_objectives(var/datum/mind/player)
	if(!..())
		return
	player.objectives += new /datum/objective/survive()
	player.objectives += new /datum/objective/escape()

/datum/antagonist/xenos/place_mob(var/mob/living/player)
	player.forceMove(get_turf(pick(get_vents())))
