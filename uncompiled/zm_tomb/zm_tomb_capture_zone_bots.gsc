
#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;
#include maps\mp\zombies\_zm_laststand;
#include maps\mp\zm_tomb_capture_zones;

#include scripts\zm\zm_bo2_bots;

main()
{
	if(getdvar("mapname") != "zm_tomb")
		return;

	level thread zm_tomb_bot_capture_coordinator();

	scripts\zm\zm_bo2_bots::bot_tomb_register_objective_provider(::bot_tomb_explore_objective_capture, 50);
}

bot_tomb_explore_objective_capture()
{
	target_zone = bot_tomb_find_uncaptured_zone();

	if(isdefined(target_zone) && isdefined(target_zone.origin))
		return target_zone.origin;

	return undefined;
}

zm_tomb_bot_capture_coordinator()
{
	level endon("end_game");

	for(;;)
	{
		foreach(player in get_players())
		{
			if(!isdefined(player.pers["isbot"]))
				continue;

			if(isdefined(player.bot_tomb_capture_coordinated))
				continue;

			player.bot_tomb_capture_coordinated = true;

			player thread bot_tomb_capture_watch_respawn();
		}

		wait 1;
	}
}

bot_tomb_capture_watch_respawn()
{
	self endon("disconnect");

	level endon("end_game");

	for(;;)
	{
		if(isalive(self))
			self thread bot_tomb_capture_think();

		self waittill("spawned_player");
	}
}

bot_tomb_capture_think()
{
	self endon("disconnect");
	self endon("death");

	level endon("end_game");

	for(;;)
	{
		self bot_tomb_capture_update();

		wait 0.5;
	}
}

bot_tomb_capture_update()
{
	if(self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
		return;

	if(is_true(self.bot.is_using_box) || is_true(self.bot.is_reviving) || is_true(self.bot.is_selfreviving) || is_true(self.bot.is_throwing_grenade))
		return;

	if(is_true(self.bot.is_panicking))
		return;

	if(is_true(self.bot.is_dodging_robot))
		return;

	if(is_true(self.bot_tomb_is_capturing))
		return;

	if(!isdefined(level.zone_capture) || !isdefined(level.zone_capture.zones))
		return;

	contested = bot_tomb_find_contested_zone();

	if(isdefined(contested))
	{
		self bot_tomb_pursue_zone(contested);
		return;
	}

	if(self hasgoal("capture_zone"))
		self cancelgoal("capture_zone");

	if(flag("zone_capture_in_progress"))
		return;

	target_zone = bot_tomb_find_uncaptured_zone();

	if(!isdefined(target_zone))
	{
		if(self hasgoal("capture_start"))
			self cancelgoal("capture_start");

		return;
	}

	if(self.score < maps\mp\zm_tomb_capture_zones::get_generator_capture_start_cost())
	{
		if(self hasgoal("capture_start"))
			self cancelgoal("capture_start");

		return;
	}

	self bot_tomb_pursue_generator_start(target_zone);
}

bot_tomb_find_contested_zone()
{
	foreach(key, zone in level.zone_capture.zones)
	{
		if(isdefined(zone) && zone ent_flag("zone_contested"))
			return zone;
	}

	return undefined;
}

bot_tomb_find_uncaptured_zone()
{
	closest = undefined;
	closest_dist_sq = 999999999;

	foreach(key, zone in level.zone_capture.zones)
	{
		if(!isdefined(zone))
			continue;

		if(zone ent_flag("player_controlled") || zone ent_flag("zone_contested"))
			continue;

		if(isdefined(zone.tomb_bot_claimer) && zone.tomb_bot_claimer != self && isalive(zone.tomb_bot_claimer))
			continue;

		d = distancesquared(self.origin, zone.origin);

		if(d < closest_dist_sq)
		{
			closest_dist_sq = d;
			closest = zone;
		}
	}

	return closest;
}

bot_tomb_get_cached_generator_stubs()
{
	if(!isdefined(level.tomb_bot_generator_stub_cache_time) || gettime() - level.tomb_bot_generator_stub_cache_time > 2000)
	{
		level.tomb_bot_generator_stub_cache_time = gettime();
		level.tomb_bot_generator_stub_cache = bot_tomb_scan_generator_stubs();
	}

	return level.tomb_bot_generator_stub_cache;
}

bot_tomb_scan_generator_stubs()
{
	found = [];

	if(isdefined(level.zones))
	{
		foreach(zonekey, zonedata in level.zones)
		{
			if(!isdefined(zonedata) || !isdefined(zonedata.unitrigger_stubs))
				continue;

			foreach(stub in zonedata.unitrigger_stubs)
			{
				if(isdefined(stub) && isdefined(stub.generator_struct))
					found[found.size] = stub;
			}
		}
	}

	if(isdefined(level._unitriggers) && isdefined(level._unitriggers.dynamic_stubs))
	{
		foreach(stub in level._unitriggers.dynamic_stubs)
		{
			if(isdefined(stub) && isdefined(stub.generator_struct))
				found[found.size] = stub;
		}
	}

	return found;
}

bot_tomb_find_generator_stub_for_zone(zone)
{
	stubs = bot_tomb_get_cached_generator_stubs();

	foreach(stub in stubs)
	{
		if(isdefined(stub.generator_struct) && stub.generator_struct == zone)
			return stub;
	}

	return undefined;
}

bot_tomb_pursue_zone(zone)
{
	if(!findpath(self.origin, zone.origin, undefined, 0, 1))
		return;

	dist_sq = distancesquared(self.origin, zone.origin);

	if(dist_sq > 32400)
	{
		if(!self hasgoal("capture_zone") || distancesquared(self getgoal("capture_zone"), zone.origin) > 2500)
		{
			self cancelgoal("capture_zone");
			self addgoal(zone.origin, 100, 3, "capture_zone");
		}

		return;
	}

	if(self hasgoal("capture_zone"))
		self cancelgoal("capture_zone");
}

bot_tomb_pursue_generator_start(zone)
{
	stub = bot_tomb_find_generator_stub_for_zone(zone);

	if(!isdefined(stub))
		return;

	if(!findpath(self.origin, zone.origin, undefined, 0, 1))
		return;

	dist_sq = distancesquared(self.origin, zone.origin);

	if(dist_sq > 22500)
	{
		zone.tomb_bot_claimer = self;

		if(!self hasgoal("capture_start") || distancesquared(self getgoal("capture_start"), zone.origin) > 900)
		{
			self cancelgoal("capture_start");
			self addgoal(zone.origin, 40, 3, "capture_start");
		}

		return;
	}

	self cancelgoal("capture_start");

	self thread bot_tomb_do_start_capture(zone, stub);
}

bot_tomb_do_start_capture(zone, stub)
{
	self endon("disconnect");
	level endon("end_game");

	self.bot_tomb_is_capturing = true;

	self thread bot_tomb_capture_cleanup_watcher(zone);

	self allowattack(0);
	self pressads(0);

	if(self getgoal("wander") || self hasgoal("wander"))
		self cancelgoal("wander");

	n_ent = self getentitynumber();
	attempt_end = gettime() + 3000;

	while(gettime() < attempt_end)
	{
		if(!isdefined(self) || !isalive(self))
			break;

		if(!isdefined(zone))
			break;

		if(zone ent_flag("player_controlled") || zone ent_flag("zone_contested") || flag("zone_capture_in_progress"))
			break;

		if(self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
			break;

		if(is_true(self.bot.is_dodging_robot))
			break;

		if(self.score < maps\mp\zm_tomb_capture_zones::get_generator_capture_start_cost())
			break;

		if(distancesquared(self.origin, zone.origin) > 22500)
			break;

		self lookat(zone.origin);

		if(isdefined(stub.playertrigger) && isdefined(stub.playertrigger[n_ent]))
			stub.playertrigger[n_ent] notify("trigger", self);

		wait 0.05;
	}

	if(isdefined(self) && isalive(self))
		self clearlookat();

	self notify("tomb_capture_attempt_done");
}

bot_tomb_capture_cleanup_watcher(zone)
{
	self waittill_any("tomb_capture_attempt_done", "death", "disconnect");

	if(isdefined(zone) && isdefined(zone.tomb_bot_claimer) && zone.tomb_bot_claimer == self)
		zone.tomb_bot_claimer = undefined;

	self.bot_tomb_is_capturing = false;
}

bot_tomb_get_lookat_point(pos)
{
	eye_z = self.origin[2] + 45;

	return (pos[0], pos[1], eye_z);
}
