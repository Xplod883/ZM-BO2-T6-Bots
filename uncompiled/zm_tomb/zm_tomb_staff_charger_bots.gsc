
#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;
#include maps\mp\zombies\_zm_laststand;

#include scripts\zm\zm_bo2_bots;

main()
{
	if(getdvar("mapname") != "zm_tomb")
		return;

	level thread zm_tomb_bot_staff_charger_coordinator();
}

zm_tomb_bot_staff_charger_coordinator()
{
	level endon("end_game");

	for(;;)
	{
		foreach(player in get_players())
		{
			if(!isdefined(player.pers["isbot"]))
				continue;

			if(isdefined(player.bot_tomb_charger_coordinated))
				continue;

			player.bot_tomb_charger_coordinated = true;

			player thread bot_tomb_charger_watch_respawn();
		}

		wait 1;
	}
}

bot_tomb_charger_watch_respawn()
{
	self endon("disconnect");

	level endon("end_game");

	for(;;)
	{
		if(isalive(self))
			self thread bot_tomb_charger_think();

		self waittill("spawned_player");
	}
}

bot_tomb_charger_think()
{
	self endon("disconnect");
	self endon("death");

	level endon("end_game");

	for(;;)
	{
		self bot_tomb_charger_update();

		wait 0.5;
	}
}

bot_tomb_charger_update()
{
	if(self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
		return;

	if(is_true(self.bot.is_using_box) || is_true(self.bot.is_buying) || is_true(self.bot.is_reviving) || is_true(self.bot.is_selfreviving) || is_true(self.bot.is_throwing_grenade))
		return;

	if(is_true(self.bot.is_panicking))
		return;

	if(isdefined(level.bot_train_leader) && level.bot_train_leader == self)
		return;

	if(is_true(self.bot_tomb_is_digging) || is_true(self.bot_tomb_is_crafting) || is_true(self.bot_tomb_is_crystal_questing))
		return;

	if(is_true(self.bot_tomb_is_charging))
		return;

	if(!isdefined(level.a_elemental_staffs))
		return;

	foreach(staff in level.a_elemental_staffs)
	{
		if(!isdefined(staff) || !isdefined(staff.charge_trigger))
			continue;

		if(is_true(staff.charger.is_charged) && !is_true(staff.charger.full))
		{
			self bot_tomb_charger_pursue(staff, "retrieve");
			return;
		}

		if(!is_true(staff.charger.is_inserted) && self hasweapon(staff.weapname))
		{
			self bot_tomb_charger_pursue(staff, "insert");
			return;
		}
	}
}

bot_tomb_charger_pursue(staff, str_action)
{
	target = staff.charger.origin;

	if(!findpath(self.origin, target, undefined, 0, 1))
		return;

	dist_sq = distancesquared(self.origin, target);

	if(dist_sq > 22500)
	{
		if(!self hasgoal("staff_charger") || distancesquared(self getgoal("staff_charger"), target) > 2500)
		{
			self cancelgoal("staff_charger");
			self addgoal(target, 50, 2, "staff_charger");
		}

		return;
	}

	self cancelgoal("staff_charger");

	self thread bot_tomb_charger_do_interact(staff, str_action);
}

bot_tomb_charger_do_interact(staff, str_action)
{
	self endon("disconnect");
	level endon("end_game");

	self.bot_tomb_is_charging = true;

	self thread bot_tomb_charger_cleanup_watcher();

	self allowattack(0);
	self pressads(0);

	if(self getgoal("wander") || self hasgoal("wander"))
		self cancelgoal("wander");

	timeout = gettime() + 4000;

	while(gettime() < timeout)
	{
		if(!isdefined(self) || !isalive(self))
			break;

		if(!isdefined(staff) || !isdefined(staff.charge_trigger))
			break;

		if(str_action == "insert" && (is_true(staff.charger.is_inserted) || !self hasweapon(staff.weapname)))
			break;

		if(str_action == "retrieve" && (!is_true(staff.charger.is_charged) || is_true(staff.charger.full)))
			break;

		if(self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
			break;

		if(distancesquared(self.origin, staff.charger.origin) > 22500)
			break;

		self lookat(self bot_tomb_charger_get_lookat_point(staff.charger.origin));

		staff.charge_trigger notify("trigger", self);

		wait 0.05;
	}

	if(isdefined(self) && isalive(self))
		self clearlookat();

	self notify("tomb_charger_attempt_done");
}

bot_tomb_charger_get_lookat_point(pos)
{
	eye_z = self.origin[2] + 45;

	return (pos[0], pos[1], eye_z);
}

bot_tomb_charger_cleanup_watcher()
{
	self waittill_any("tomb_charger_attempt_done", "death", "disconnect");

	self.bot_tomb_is_charging = false;
}
