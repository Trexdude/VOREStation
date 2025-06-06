//Procedures in this file: Organic limb repair
//////////////////////////////////////////////////////////////////
//						LIMB REPAIR SURGERY						//
//////////////////////////////////////////////////////////////////
/datum/surgery_step/repairflesh/
	surgery_name = "Repair Flesh"
	priority = 1
	can_infect = 1
	blood_level = 1
	req_open = 1

/datum/surgery_step/repairflesh/can_use(mob/living/user, mob/living/carbon/human/target, target_zone, obj/item/tool)
/* VOREStation Removal for Mlem Reasons(TM)
	if (target.stat == DEAD) // Sorry defibs, your subjects need to have pumping fluids for these to work.
		return 0
*/
	if (isslime(target))
		return 0
	if (target_zone == O_EYES || target_zone == O_MOUTH)
		return 0
	if (!hasorgans(target))
		return 0
	var/obj/item/organ/external/affected = target.get_organ(target_zone)
	if (affected == null)
		return 0
	if (affected.is_stump())
		return 0
	if (affected.robotic >= ORGAN_ROBOT)
		return 0
	if(coverage_check(user, target, affected, tool))
		return 0
	return 1


//////////////////////////////////////////////////////////////////
//						SCAN STEP								//
//////////////////////////////////////////////////////////////////

/datum/surgery_step/repairflesh/scan_injury
	surgery_name = "Scan Injury"
	allowed_tools = list(
	/obj/item/autopsy_scanner = 100,
	/obj/item/analyzer = 10
	)

	priority = 2

	can_infect = 0 //The only exception here. Sweeping a scanner probably won't transfer many germs.

	min_duration = 20
	max_duration = 40

/datum/surgery_step/repairflesh/scan_injury/can_use(mob/living/user, mob/living/carbon/human/target, target_zone, obj/item/tool)
	if(..())
		var/obj/item/organ/external/affected = target.get_organ(target_zone)
		if(affected.burn_stage || affected.brute_stage)
			return 0
		return 1
	return 0

/datum/surgery_step/repairflesh/scan_injury/begin_step(mob/living/user, mob/living/carbon/human/target, target_zone, obj/item/tool)
	var/obj/item/organ/external/affected = target.get_organ(target_zone)
	user.visible_message(span_notice("[user] begins scanning [target]'s [affected] with \the [tool]."), \
	span_notice("You begin scanning [target]'s [affected] with \the [tool]."))
	user.balloon_alert_visible("begins scanning [target]'s [affected]", "scaning \the [affected]")
	..()

/datum/surgery_step/repairflesh/scan_injury/end_step(mob/living/user, mob/living/carbon/human/target, target_zone, obj/item/tool)
	var/obj/item/organ/external/affected = target.get_organ(target_zone)
	user.visible_message(span_notice("[user] finishes scanning [target]'s [affected]."), \
	span_notice("You finish scanning [target]'s [affected]."))
	user.balloon_alert_visible("finishes scanning [target]'s [affected]", "finished scanning \the [affected]")
	if(affected.brute_dam)
		to_chat(user, span_notice("The muscle in [target]'s [affected] is notably bruised."))
		if(affected.status & ORGAN_BROKEN)
			to_chat(user, span_warning("\The [target]'s [affected] is broken!"))
		affected.brute_stage = max(1, affected.brute_stage)
	if(affected.burn_dam)
		to_chat(user, span_notice("\The muscle in [target]'s [affected] is notably charred."))
		affected.burn_stage = max(1, affected.burn_stage)

/datum/surgery_step/repairflesh/scan_injury/fail_step(mob/living/user, mob/living/carbon/human/target, target_zone, obj/item/tool)
	var/obj/item/organ/external/affected = target.get_organ(target_zone)
	user.visible_message(span_warning("[user]'s hand slips, dropping \the [tool] onto [target]'s [affected]!") , \
	span_warning("Your hand slips, dropping \the [tool] onto [target]'s [affected]!") )
	user.balloon_alert_visible("slips, dropping \the [tool].", "your hand slips, dropping \the [tool] onto \the [affected].")
	affected.createwound(BRUISE, 10)

//////////////////////////////////////////////////////////////////
//						BURN STEP								//
//////////////////////////////////////////////////////////////////

/datum/surgery_step/repairflesh/repair_burns
	surgery_name = "Repair Burns"
	allowed_tools = list(
	/obj/item/stack/medical/advanced/ointment = 100,
	/obj/item/stack/medical/ointment = 50,
	/obj/item/tape_roll = 30,
	/obj/item/taperoll = 10
	)

	priority = 3

	min_duration = 90
	max_duration = 120

/datum/surgery_step/repairflesh/repair_burns/can_use(mob/living/user, mob/living/carbon/human/target, target_zone, obj/item/tool)
	if(..())
		var/obj/item/organ/external/affected = target.get_organ(target_zone)
		if(affected.burn_stage < 1 || !(affected.burn_dam))
			return 0
		return 1
	return 0

/datum/surgery_step/repairflesh/repair_burns/begin_step(mob/living/user, mob/living/carbon/human/target, target_zone, obj/item/tool)
	var/obj/item/organ/external/affected = target.get_organ(target_zone)
	if(istype(tool, /obj/item/tape_roll) || istype(tool, /obj/item/taperoll))
		user.visible_message(span_warning("[user] begins taping up [target]'s [affected] with \the [tool]."), \
	span_notice("You begin taping up [target]'s [affected] with \the [tool]."))
		user.balloon_alert_visible("begins taping up \the [target]", "taping up \the [affected]")
		affected.jostle_bone(10)
	else if(istype(tool, /obj/item/surgical/hemostat) || istype(tool, /obj/item/surgical/FixOVein))
		user.visible_message(span_notice("[user] begins mending the charred blood vessels in [target]'s [affected] with \the [tool]."), \
	span_notice("You begin mending the charred blood vessels in [target]'s [affected] with \the [tool]."))
		user.balloon_alert_visible("begins mending the charred blood vessels in [affected].", "mends the charred blood vessels in [affected].")
	else
		user.visible_message(span_notice("[user] begins coating the charred tissue in [target]'s [affected] with \the [tool]."), \
	span_notice("You begin coating the charred tissue in [target]'s [affected] with \the [tool]."))
		user.balloon_alert_visible("begins coating the charred tissue in \the [affected]", "coating the charred tssue in \the [affected]")
	..()

/datum/surgery_step/repairflesh/repair_burns/end_step(mob/living/user, mob/living/carbon/human/target, target_zone, obj/item/tool)
	var/obj/item/organ/external/affected = target.get_organ(target_zone)
	if(istype(tool, /obj/item/tape_roll) || istype(tool, /obj/item/taperoll))
		user.visible_message(span_notice("[user] finishes taping up [target]'s [affected] with \the [tool]."), \
	span_notice("You finish taping up [target]'s [affected] with \the [tool]."))
		user.balloon_alert_visible("tapes up \the [affected]", "taped up \the [affected]")
		affected.createwound(BRUISE, 10)
	affected.heal_damage(0, 25, 0, 0)
	if(!(affected.burn_dam))
		affected.burn_stage = 0
	if(istype(tool, /obj/item/stack))
		var/obj/item/stack/T = tool
		T.use(1)
	..()

/datum/surgery_step/repairflesh/repair_burns/fail_step(mob/living/user, mob/living/carbon/human/target, target_zone, obj/item/tool)
	var/obj/item/organ/external/affected = target.get_organ(target_zone)
	user.visible_message(span_danger("[user]'s hand slips, tearing up [target]'s [affected] with \the [tool]."), \
	span_danger("Your hand slips, tearing up [target]'s [affected] with \the [tool]."))
	user.balloon_alert_visible("slips, tearing up \the [affected]", "you slip, tearing up \the [affected]")
	affected.createwound(BRUISE, 10)
	affected.createwound(CUT, 5)
	if(istype(tool, /obj/item/stack) && prob(30))
		var/obj/item/stack/T = tool
		T.use(1)
	..()

//////////////////////////////////////////////////////////////////
//						BRUTE STEP								//
//////////////////////////////////////////////////////////////////

/datum/surgery_step/repairflesh/repair_brute
	surgery_name = "Repair Brute"
	allowed_tools = list(
	/obj/item/stack/medical/advanced/bruise_pack = 100,
	/obj/item/stack/medical/bruise_pack = 50,
	/obj/item/tape_roll = 40,
	/obj/item/taperoll = 10
	)

	priority = 3

	min_duration = 90
	max_duration = 120

/datum/surgery_step/repairflesh/repair_brute/can_use(mob/living/user, mob/living/carbon/human/target, target_zone, obj/item/tool)
	if(..())
		var/obj/item/organ/external/affected = target.get_organ(target_zone)
		if(affected.brute_stage < 1 || !(affected.brute_dam))
			return 0
		return 1
	return 0

/datum/surgery_step/repairflesh/repair_brute/begin_step(mob/living/user, mob/living/carbon/human/target, target_zone, obj/item/tool)
	var/obj/item/organ/external/affected = target.get_organ(target_zone)
	if(istype(tool, /obj/item/tape_roll) || istype(tool, /obj/item/taperoll))
		user.visible_message(span_warning("[user] begins taping up [target]'s [affected] with \the [tool]."), \
	span_notice("You begin taping up [target]'s [affected] with \the [tool]."))
		user.balloon_alert_visible("begins to tape up \the [affected].", "taping up \the [affected].")
		affected.jostle_bone(10)
	else if(istype(tool, /obj/item/surgical/FixOVein) || istype(tool, /obj/item/surgical/bonesetter))
		user.visible_message(span_notice("[user] begins mending the torn tissue in [target]'s [affected] with \the [tool]."), \
	span_notice("You begin mending the torn tissue in [target]'s [affected] with \the [tool]."))
		user.balloon_alert_visible("begins mending torn tissue in \the [affected]", "mending torn issue in \the [affected]")
	else
		user.visible_message(span_notice("[user] begins coating the tissue in [target]'s [affected] with \the [tool]."), \
	span_notice("You begin coating the tissue in [target]'s [affected] with \the [tool]."))
		user.balloon_alert_visible("begins coating tissue in \the [affected]", "coating tissue in \the [affected]")
	..()

/datum/surgery_step/repairflesh/repair_brute/end_step(mob/living/user, mob/living/carbon/human/target, target_zone, obj/item/tool)
	var/obj/item/organ/external/affected = target.get_organ(target_zone)
	if(istype(tool, /obj/item/tape_roll) || istype(tool, /obj/item/taperoll))
		user.visible_message(span_notice("[user] finishes taping up [target]'s [affected] with \the [tool]."), \
	span_notice("You finish taping up [target]'s [affected] with \the [tool]."))
		user.balloon_alert_visible("tapes up \the [affected]", "taped up \the [affected]")
		affected.createwound(BRUISE, 10)
	affected.heal_damage(25, 0, 0, 0)
	if(!(affected.brute_dam))
		affected.brute_stage = 0
	if(istype(tool, /obj/item/stack))
		var/obj/item/stack/T = tool
		T.use(1)
	..()

/datum/surgery_step/repairflesh/repair_brute/fail_step(mob/living/user, mob/living/carbon/human/target, target_zone, obj/item/tool)
	var/obj/item/organ/external/affected = target.get_organ(target_zone)
	user.visible_message(span_danger("[user]'s hand slips, tearing up [target]'s [affected] with \the [tool]."), \
	span_danger("Your hand slips, tearing up [target]'s [affected] with \the [tool]."))
	user.balloon_alert_visible("slips, tearing up \the [affected]", "your hand slips, tearing up \the [affected]")
	affected.createwound(BRUISE, 10)
	affected.createwound(CUT, 5)
	if(istype(tool, /obj/item/stack) && prob(30))
		var/obj/item/stack/T = tool
		T.use(1)
	..()
